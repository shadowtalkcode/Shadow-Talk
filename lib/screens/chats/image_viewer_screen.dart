import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../theme/app_colors.dart';

/// One photo in the fullscreen gallery.
class ViewerImage {
  final String url;
  final String heroTag;
  final String sender; // "You" / peer name
  final String time; // formatted timestamp
  const ViewerImage({
    required this.url,
    required this.heroTag,
    required this.sender,
    required this.time,
  });
}

/// Fullscreen photo gallery — swipe between every photo in the conversation
/// (like Android `FullscreenActivity`'s ViewPager / WhatsApp), pinch-to-zoom,
/// a sender/time bar that toggles on tap, plus Save-to-gallery and Share.
class ImageViewerScreen extends StatefulWidget {
  final List<ViewerImage> images;
  final int initialIndex;

  const ImageViewerScreen({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late final PageController _pager =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  bool _showBars = true;
  bool _busy = false;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  ViewerImage get _current => widget.images[_index];

  Future<File> _download(String url) async {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/st_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.writeAsBytes(res.bodyBytes);
    return file;
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (!await Gal.hasAccess(toAlbum: true)) {
        await Gal.requestAccess(toAlbum: true);
      }
      final res = await http.get(Uri.parse(_current.url));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      await Gal.putImageBytes(res.bodyBytes,
          name: 'ShadowTalk_${DateTime.now().millisecondsSinceEpoch}');
      messenger.showSnackBar(
          const SnackBar(content: Text('Saved to your photos')));
    } catch (e) {
      messenger.showSnackBar(
          const SnackBar(content: Text("Couldn't save photo")));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await _download(_current.url);
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      messenger.showSnackBar(
          const SnackBar(content: Text("Couldn't share photo")));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _showBars
          ? AppBar(
              backgroundColor: Colors.black.withValues(alpha: 0.55),
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_current.sender,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600)),
                  Text(
                    widget.images.length > 1
                        ? '${_current.time}  ·  ${_index + 1}/${widget.images.length}'
                        : _current.time,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.download_rounded),
                  tooltip: 'Save',
                  onPressed: _busy ? null : _save,
                ),
                IconButton(
                  icon: const Icon(Icons.share),
                  tooltip: 'Share',
                  onPressed: _busy ? null : _share,
                ),
              ],
            )
          : null,
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => setState(() => _showBars = !_showBars),
            child: PageView.builder(
              controller: _pager,
              itemCount: widget.images.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                final img = widget.images[i];
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Center(
                    child: Hero(
                      tag: img.heroTag,
                      child: Image.network(
                        img.url,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) =>
                            progress == null
                                ? child
                                : const Center(
                                    child: CircularProgressIndicator(
                                        color: AppColors.primary)),
                        errorBuilder: (context, error, stack) => const Center(
                          child: Icon(Icons.broken_image,
                              color: Colors.white38, size: 64),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_busy)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                  minHeight: 2, color: AppColors.primary),
            ),
        ],
      ),
    );
  }
}
