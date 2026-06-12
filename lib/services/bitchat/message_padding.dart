import 'dart:typed_data';

/// Privacy-preserving padding — a byte-exact port of the Android/iOS bitchat
/// `MessagePadding`. Normalises packet sizes to standard blocks (PKCS#7).
class MessagePadding {
  static const List<int> _blockSizes = [256, 512, 1024, 2048];

  /// Smallest block that fits `dataSize + 16` (AES-GCM tag allowance), else the
  /// original size for very large (to-be-fragmented) messages.
  static int optimalBlockSize(int dataSize) {
    final totalSize = dataSize + 16;
    for (final block in _blockSizes) {
      if (totalSize <= block) return block;
    }
    return dataSize;
  }

  /// PKCS#7 pad to [targetSize]; all pad bytes equal the pad length. Pad length
  /// must fit a single byte (≤255), otherwise the data is returned unchanged.
  static Uint8List pad(Uint8List data, int targetSize) {
    if (data.length >= targetSize) return data;
    final paddingNeeded = targetSize - data.length;
    if (paddingNeeded <= 0 || paddingNeeded > 255) return data;
    final result = Uint8List(targetSize);
    result.setRange(0, data.length, data);
    for (var i = data.length; i < targetSize; i++) {
      result[i] = paddingNeeded;
    }
    return result;
  }

  /// Strict PKCS#7 unpad; returns the original data if padding is invalid.
  static Uint8List unpad(Uint8List data) {
    if (data.isEmpty) return data;
    final paddingLength = data[data.length - 1] & 0xFF;
    if (paddingLength <= 0 || paddingLength > data.length) return data;
    final start = data.length - paddingLength;
    for (var i = start; i < data.length; i++) {
      if (data[i] != data[data.length - 1]) return data;
    }
    return Uint8List.sublistView(data, 0, start);
  }
}
