import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadow_talk_flutter/services/bitchat/binary_protocol.dart';
import 'package:shadow_talk_flutter/services/bitchat/bitchat_identity.dart';
import 'package:shadow_talk_flutter/services/bitchat/identity_announcement.dart';
import 'package:shadow_talk_flutter/services/bitchat/message_padding.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('MessagePadding pad/unpad round-trip (PKCS#7)', () {
    final data = Uint8List.fromList(List.generate(100, (i) => i % 251));
    final block = MessagePadding.optimalBlockSize(data.length);
    expect(block, 256);
    final padded = MessagePadding.pad(data, block);
    expect(padded.length, 256);
    // PKCS#7: trailing bytes equal pad length.
    expect(padded.last, 256 - 100);
    final unpadded = MessagePadding.unpad(padded);
    expect(unpadded, data);
  });

  test('BinaryProtocol encode→decode round-trip (broadcast MESSAGE)', () {
    final sender = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
    final payload = Uint8List.fromList(utf8.encode('hello mesh 👋'));
    final sig = Uint8List.fromList(List.generate(64, (i) => (i * 7) & 0xFF));
    final pkt = BitchatPacket(
      type: MessageType.message,
      senderID: sender,
      recipientID: kBroadcastRecipient,
      timestamp: 1781000000000,
      payload: payload,
      signature: sig,
      ttl: 7,
    );
    final bytes = BinaryProtocol.encode(pkt)!;
    // Padded to a block size.
    expect(bytes.length, 256);

    final decoded = BinaryProtocol.decode(bytes)!;
    expect(decoded.version, 1);
    expect(decoded.type, MessageType.message);
    expect(decoded.ttl, 7);
    expect(decoded.timestamp, 1781000000000);
    expect(decoded.senderID, sender);
    expect(decoded.recipientID, kBroadcastRecipient);
    expect(decoded.payload, payload);
    expect(decoded.signature, sig);
  });

  test('BinaryProtocol decode rejects garbage', () {
    expect(BinaryProtocol.decode(Uint8List.fromList([0, 0, 0])), isNull);
  });

  test('IdentityAnnouncement TLV encode→decode round-trip', () {
    final noiseKey = Uint8List.fromList(List.generate(32, (i) => i));
    final signKey = Uint8List.fromList(List.generate(32, (i) => 255 - i));
    final ann = IdentityAnnouncement('Alice', noiseKey, signKey);
    final encoded = ann.encode()!;
    // TLV: 1+1+5 (nick) + 1+1+32 + 1+1+32 = 75 bytes.
    expect(encoded.length, 75);
    final decoded = IdentityAnnouncement.decode(encoded)!;
    expect(decoded.nickname, 'Alice');
    expect(decoded.noisePublicKey, noiseKey);
    expect(decoded.signingPublicKey, signKey);
  });

  test('toBinaryDataForSigning fixes TTL=0 and drops signature', () {
    final pkt = BitchatPacket(
      type: MessageType.announce,
      senderID: Uint8List(8),
      timestamp: 123,
      payload: Uint8List.fromList([9, 9, 9]),
      ttl: 7,
    );
    final signingBytes = pkt.toBinaryDataForSigning()!;
    final decoded = BinaryProtocol.decode(signingBytes)!;
    expect(decoded.ttl, 0);
    expect(decoded.signature, isNull);
  });

  test('Signed ANNOUNCE verifies against announced signing key (Android gate)',
      () async {
    SharedPreferences.setMockInitialValues({});
    final id = BitchatIdentity();
    await id.init();

    // peerID is 16 hex chars; senderID is its 8 bytes.
    expect(id.peerIDHex.length, 16);
    expect(id.senderID.length, 8);
    expect(id.signingPublicKey.length, 32);
    expect(id.noisePublicKey.length, 32);

    // Build a signed ANNOUNCE exactly like the mesh service does.
    final tlv = IdentityAnnouncement('Alice', id.noisePublicKey, id.signingPublicKey).encode()!;
    final announce = BitchatPacket(
      type: MessageType.announce,
      senderID: id.senderID,
      timestamp: 1781000000000,
      payload: tlv,
      ttl: 7,
    );
    final signature = await id.sign(announce.toBinaryDataForSigning()!);
    announce.signature = signature;

    // Wire encode → decode (what a peer receives).
    final wire = BinaryProtocol.encode(announce)!;
    final received = BinaryProtocol.decode(wire)!;
    final receivedAnn = IdentityAnnouncement.decode(received.payload)!;

    // A peer verifies the signature over the *canonical signing bytes* using the
    // announced signing public key — this is what flips Android's
    // `isVerifiedNickname` to true and lets our broadcasts through.
    final canonical = received.toBinaryDataForSigning()!;
    final ok = await BitchatIdentity.verify(
        received.signature!, canonical, receivedAnn.signingPublicKey);
    expect(ok, isTrue);

    // Tampered signature must fail.
    final bad = Uint8List.fromList(received.signature!);
    bad[0] ^= 0xFF;
    final okBad = await BitchatIdentity.verify(bad, canonical, receivedAnn.signingPublicKey);
    expect(okBad, isFalse);
  });
}
