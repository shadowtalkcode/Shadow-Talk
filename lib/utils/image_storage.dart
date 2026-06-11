import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Persists picked images. `image_picker` returns files in the OS temp
/// directory, which iOS can purge at any time and whose app-container UUID
/// changes on reinstall — so storing that path leads to `PathNotFoundException`
/// later. Copying the file into the app's Documents directory keeps it stable.
class ImageStorage {
  ImageStorage._();

  /// Copies [srcPath] into `<documents>/profile_photos/` and returns the new
  /// path. Falls back to [srcPath] if the copy fails for any reason.
  static Future<String> persist(String srcPath) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final photos = Directory('${dir.path}/profile_photos');
      if (!await photos.exists()) await photos.create(recursive: true);
      final dot = srcPath.lastIndexOf('.');
      final ext = (dot >= 0) ? srcPath.substring(dot) : '.jpg';
      final dest =
          '${photos.path}/profile_${DateTime.now().millisecondsSinceEpoch}$ext';
      await File(srcPath).copy(dest);
      debugPrint('🖼️ IMG: persisted → $dest');
      return dest;
    } catch (e) {
      debugPrint('🖼️ IMG: persist failed ($e) — keeping original path');
      return srcPath;
    }
  }
}
