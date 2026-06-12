import 'dart:convert';
import 'dart:typed_data';

/// TLV-encoded identity announcement — byte-exact with Android/iOS
/// `IdentityAnnouncement`: nickname + Noise(X25519) static pubkey + Ed25519
/// signing pubkey.
class IdentityAnnouncement {
  final String nickname;
  final Uint8List noisePublicKey; // 32 bytes (X25519 static)
  final Uint8List signingPublicKey; // 32 bytes (Ed25519)

  IdentityAnnouncement(this.nickname, this.noisePublicKey, this.signingPublicKey);

  static const int _tlvNickname = 0x01;
  static const int _tlvNoiseKey = 0x02;
  static const int _tlvSigningKey = 0x03;

  Uint8List? encode() {
    final nick = utf8.encode(nickname);
    if (nick.length > 255 || noisePublicKey.length > 255 || signingPublicKey.length > 255) {
      return null;
    }
    final b = BytesBuilder();
    b.addByte(_tlvNickname);
    b.addByte(nick.length);
    b.add(nick);
    b.addByte(_tlvNoiseKey);
    b.addByte(noisePublicKey.length);
    b.add(noisePublicKey);
    b.addByte(_tlvSigningKey);
    b.addByte(signingPublicKey.length);
    b.add(signingPublicKey);
    return b.toBytes();
  }

  static IdentityAnnouncement? decode(Uint8List data) {
    var offset = 0;
    String? nickname;
    Uint8List? noiseKey;
    Uint8List? signingKey;
    while (offset + 2 <= data.length) {
      final type = data[offset];
      offset += 1;
      final length = data[offset];
      offset += 1;
      if (offset + length > data.length) return null;
      final value = Uint8List.sublistView(data, offset, offset + length);
      offset += length;
      switch (type) {
        case _tlvNickname:
          nickname = utf8.decode(value, allowMalformed: true);
          break;
        case _tlvNoiseKey:
          noiseKey = Uint8List.fromList(value);
          break;
        case _tlvSigningKey:
          signingKey = Uint8List.fromList(value);
          break;
        default:
          break; // skip unknown TLV (forward-compatible)
      }
    }
    if (nickname != null && noiseKey != null && signingKey != null) {
      return IdentityAnnouncement(nickname, noiseKey, signingKey);
    }
    return null;
  }
}
