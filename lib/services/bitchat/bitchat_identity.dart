import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent bitchat identity: an Ed25519 signing keypair + an X25519 ("Noise"
/// static) keypair. The peer id is the first 16 hex chars of SHA-256(X25519
/// public key) — byte-exact with Android's derivation.
class BitchatIdentity {
  static final _ed = Ed25519();
  static final _x = X25519();
  static final _sha = Sha256();

  static const _kSignSeed = 'bitchat_ed25519_seed';
  static const _kNoiseSeed = 'bitchat_x25519_seed';

  late SimpleKeyPair _signKeyPair;
  late Uint8List signingPublicKey; // 32 bytes (Ed25519)
  late Uint8List noisePublicKey; // 32 bytes (X25519 static)
  late String peerIDHex; // 16 hex chars
  late Uint8List senderID; // 8 bytes

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Ed25519 signing key (persisted seed).
    final signSeedB64 = prefs.getString(_kSignSeed);
    if (signSeedB64 != null) {
      _signKeyPair = await _ed.newKeyPairFromSeed(base64Decode(signSeedB64));
    } else {
      _signKeyPair = await _ed.newKeyPair();
      final seed = await _signKeyPair.extractPrivateKeyBytes();
      await prefs.setString(_kSignSeed, base64Encode(seed));
    }
    signingPublicKey = Uint8List.fromList((await _signKeyPair.extractPublicKey()).bytes);

    // X25519 static key (persisted seed).
    SimpleKeyPair noiseKeyPair;
    final noiseSeedB64 = prefs.getString(_kNoiseSeed);
    if (noiseSeedB64 != null) {
      noiseKeyPair = await _x.newKeyPairFromSeed(base64Decode(noiseSeedB64));
    } else {
      noiseKeyPair = await _x.newKeyPair();
      final seed = await noiseKeyPair.extractPrivateKeyBytes();
      await prefs.setString(_kNoiseSeed, base64Encode(seed));
    }
    noisePublicKey = Uint8List.fromList((await noiseKeyPair.extractPublicKey()).bytes);

    // peerID = first 16 hex chars of SHA-256(noise public key).
    final hash = await _sha.hash(noisePublicKey);
    final fullHex = _toHex(Uint8List.fromList(hash.bytes));
    peerIDHex = fullHex.substring(0, 16);
    senderID = _hexToBytes(peerIDHex, 8);
  }

  /// Ed25519 signature (64 bytes) over [data].
  Future<Uint8List> sign(Uint8List data) async {
    final sig = await _ed.sign(data, keyPair: _signKeyPair);
    return Uint8List.fromList(sig.bytes);
  }

  /// Verify an Ed25519 [signature] over [data] against [publicKey] (32 bytes).
  static Future<bool> verify(
      Uint8List signature, Uint8List data, Uint8List publicKey) async {
    try {
      final pk = SimplePublicKey(publicKey, type: KeyPairType.ed25519);
      return await _ed.verify(data,
          signature: Signature(signature, publicKey: pk));
    } catch (_) {
      return false;
    }
  }

  static String _toHex(Uint8List b) {
    final sb = StringBuffer();
    for (final x in b) {
      sb.write(x.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  /// Hex string → exactly [size] bytes (zero-padded / truncated), like Android's
  /// `hexStringToByteArray`.
  static Uint8List _hexToBytes(String hex, int size) {
    final out = Uint8List(size);
    var i = 0;
    var s = hex;
    while (s.length >= 2 && i < size) {
      final byte = int.tryParse(s.substring(0, 2), radix: 16);
      if (byte != null) out[i] = byte;
      s = s.substring(2);
      i++;
    }
    return out;
  }

  /// Public helper: 8-byte sender/recipient id → 16-char hex peer id.
  static String bytesToPeerHex(Uint8List bytes) => _toHex(bytes);
}
