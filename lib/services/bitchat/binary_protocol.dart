import 'dart:io' show ZLibDecoder;
import 'dart:typed_data';

import 'message_padding.dart';

/// bitchat message types — byte-exact with the Android/iOS protocol.
class MessageType {
  static const int announce = 0x01;
  static const int message = 0x02; // all user messages (broadcast & private)
  static const int leave = 0x03;
  static const int noiseHandshake = 0x10;
  static const int noiseEncrypted = 0x11;
  static const int fragment = 0x20;
  static const int requestSync = 0x21;
  static const int fileTransfer = 0x22;
}

/// All-0xFF recipient id = broadcast.
final Uint8List kBroadcastRecipient = Uint8List.fromList(List.filled(8, 0xFF));

class _Flags {
  static const int hasRecipient = 0x01;
  static const int hasSignature = 0x02;
  static const int isCompressed = 0x04;
}

/// A decoded/encodable bitchat packet — mirrors Android `BitchatPacket`.
class BitchatPacket {
  final int version;
  final int type;
  final Uint8List senderID; // 8 bytes
  final Uint8List? recipientID; // 8 bytes when present
  final int timestamp; // ms since epoch (unsigned 64)
  final Uint8List payload;
  Uint8List? signature; // 64 bytes when present
  int ttl;

  BitchatPacket({
    this.version = 1,
    required this.type,
    required this.senderID,
    this.recipientID,
    required this.timestamp,
    required this.payload,
    this.signature,
    required this.ttl,
  });

  /// Canonical bytes used for Ed25519 signing — signature omitted and TTL fixed
  /// to 0 (so relay TTL changes don't invalidate the signature).
  Uint8List? toBinaryDataForSigning() => BinaryProtocol.encode(BitchatPacket(
        version: version,
        type: type,
        senderID: senderID,
        recipientID: recipientID,
        timestamp: timestamp,
        payload: payload,
        signature: null,
        ttl: 0,
      ));

  Uint8List? toBinaryData() => BinaryProtocol.encode(this);
}

/// Binary protocol encode/decode — byte-exact with Android `BinaryProtocol`.
/// (We never compress on send — uncompressed is valid and Android decodes it;
/// we *do* decode compressed packets that Android/iOS may send.)
class BinaryProtocol {
  static const int _headerSizeV1 = 13;
  static const int _headerSizeV2 = 15;
  static const int _senderIdSize = 8;
  static const int _recipientIdSize = 8;
  static const int _signatureSize = 64;

  static int _headerSize(int version) => version == 1 ? _headerSizeV1 : _headerSizeV2;

  static Uint8List? encode(BitchatPacket packet) {
    try {
      final payload = packet.payload; // never compressed on our side
      final headerSize = _headerSize(packet.version);
      final recipientBytes = packet.recipientID != null ? _recipientIdSize : 0;
      final signatureBytes = packet.signature != null ? _signatureSize : 0;
      final capacity = headerSize + _senderIdSize + recipientBytes + payload.length + signatureBytes + 16;
      final buf = BytesBuilder();
      final bd = ByteData(capacity < 512 ? 512 : capacity);
      var p = 0;

      bd.setUint8(p++, packet.version);
      bd.setUint8(p++, packet.type);
      bd.setUint8(p++, packet.ttl);
      bd.setUint64(p, packet.timestamp, Endian.big);
      p += 8;

      var flags = 0;
      if (packet.recipientID != null) flags |= _Flags.hasRecipient;
      if (packet.signature != null) flags |= _Flags.hasSignature;
      bd.setUint8(p++, flags);

      final payloadDataSize = payload.length;
      if (packet.version >= 2) {
        bd.setUint32(p, payloadDataSize, Endian.big);
        p += 4;
      } else {
        bd.setUint16(p, payloadDataSize, Endian.big);
        p += 2;
      }
      // Header written into bd[0..p); copy then append the variable sections.
      buf.add(Uint8List.sublistView(bd, 0, p));

      // SenderID (exactly 8 bytes, zero-padded)
      final sender = Uint8List(_senderIdSize);
      sender.setRange(0, packet.senderID.length.clamp(0, _senderIdSize),
          packet.senderID.sublist(0, packet.senderID.length.clamp(0, _senderIdSize)));
      buf.add(sender);

      // RecipientID
      if (packet.recipientID != null) {
        final r = Uint8List(_recipientIdSize);
        final src = packet.recipientID!;
        r.setRange(0, src.length.clamp(0, _recipientIdSize),
            src.sublist(0, src.length.clamp(0, _recipientIdSize)));
        buf.add(r);
      }

      buf.add(payload);

      if (packet.signature != null) {
        buf.add(packet.signature!.sublist(0, _signatureSize.clamp(0, packet.signature!.length)));
      }

      final result = buf.toBytes();
      final optimal = MessagePadding.optimalBlockSize(result.length);
      return MessagePadding.pad(result, optimal);
    } catch (_) {
      return null;
    }
  }

  static BitchatPacket? decode(Uint8List data) {
    final asIs = _decodeCore(data);
    if (asIs != null) return asIs;
    final unpadded = MessagePadding.unpad(data);
    if (identical(unpadded, data) || _listEq(unpadded, data)) return null;
    return _decodeCore(unpadded);
  }

  static BitchatPacket? _decodeCore(Uint8List raw) {
    try {
      if (raw.length < _headerSizeV1 + _senderIdSize) return null;
      final bd = ByteData.sublistView(raw);
      var p = 0;

      final version = bd.getUint8(p++);
      if (version != 1 && version != 2) return null;

      final type = bd.getUint8(p++);
      final ttl = bd.getUint8(p++);
      final timestamp = bd.getUint64(p, Endian.big);
      p += 8;

      final flags = bd.getUint8(p++);
      final hasRecipient = (flags & _Flags.hasRecipient) != 0;
      final hasSignature = (flags & _Flags.hasSignature) != 0;
      final isCompressed = (flags & _Flags.isCompressed) != 0;

      final int payloadLength;
      if (version >= 2) {
        payloadLength = bd.getUint32(p, Endian.big);
        p += 4;
      } else {
        payloadLength = bd.getUint16(p, Endian.big);
        p += 2;
      }

      var expected = _headerSize(version) + _senderIdSize + payloadLength;
      if (hasRecipient) expected += _recipientIdSize;
      if (hasSignature) expected += _signatureSize;
      if (raw.length < expected) return null;

      final senderID = Uint8List.sublistView(raw, p, p + _senderIdSize);
      p += _senderIdSize;

      Uint8List? recipientID;
      if (hasRecipient) {
        recipientID = Uint8List.sublistView(raw, p, p + _recipientIdSize);
        p += _recipientIdSize;
      }

      Uint8List payload;
      if (isCompressed) {
        if (payloadLength < 2) return null;
        final originalSize = bd.getUint16(p, Endian.big);
        p += 2;
        final compressed = Uint8List.sublistView(raw, p, p + payloadLength - 2);
        p += payloadLength - 2;
        final out = _inflateRaw(compressed, originalSize);
        if (out == null) return null;
        payload = out;
      } else {
        payload = Uint8List.fromList(Uint8List.sublistView(raw, p, p + payloadLength));
        p += payloadLength;
      }

      Uint8List? signature;
      if (hasSignature) {
        signature = Uint8List.fromList(Uint8List.sublistView(raw, p, p + _signatureSize));
        p += _signatureSize;
      }

      return BitchatPacket(
        version: version,
        type: type,
        senderID: Uint8List.fromList(senderID),
        recipientID: recipientID == null ? null : Uint8List.fromList(recipientID),
        timestamp: timestamp,
        payload: payload,
        signature: signature,
        ttl: ttl,
      );
    } catch (_) {
      return null;
    }
  }

  /// Raw DEFLATE inflate (iOS COMPRESSION_ZLIB produces headerless deflate).
  static Uint8List? _inflateRaw(Uint8List compressed, int originalSize) {
    try {
      final out = ZLibDecoder(raw: true).convert(compressed);
      return Uint8List.fromList(out);
    } catch (_) {
      try {
        final out = ZLibDecoder(raw: false).convert(compressed);
        return Uint8List.fromList(out);
      } catch (_) {
        return null;
      }
    }
  }

  static bool _listEq(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
