import 'package:flutter/material.dart';

import '../../services/status_service.dart';
import '../../utils/time_format.dart';

/// Full-screen story viewer (like Android/WhatsApp status): segmented progress
/// bars, auto-advance, tap to navigate, marks each item seen. For your own
/// statuses it shows a "seen by" count and a delete action.
class StoryViewer extends StatefulWidget {
  final UserTale tale;
  const StoryViewer({super.key, required this.tale});

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress;
  int _index = 0;
  bool _paused = false;

  static const _itemDuration = Duration(seconds: 5);

  List<StatusItem> get _items => widget.tale.items;
  StatusItem get _current => _items[_index];

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(vsync: this, duration: _itemDuration)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _next();
      });
    _start();
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  void _start() {
    if (!widget.tale.isMine) {
      StatusService.instance.markSeen(_current.ownerUid, _current.id);
    }
    _progress.forward(from: 0);
  }

  void _next() {
    if (_index < _items.length - 1) {
      setState(() => _index++);
      _start();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _prev() {
    if (_index > 0) {
      setState(() => _index--);
      _start();
    } else {
      _progress.forward(from: 0);
    }
  }

  void _onTapDown(TapDownDetails d) {
    final w = MediaQuery.sizeOf(context).width;
    if (d.globalPosition.dx < w * 0.33) {
      _prev();
    } else {
      _next();
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _current;
    return Scaffold(
      backgroundColor: item.isText ? Color(item.backgroundColor) : Colors.black,
      body: GestureDetector(
        onTapDown: _onTapDown,
        onLongPressStart: (_) {
          setState(() => _paused = true);
          _progress.stop();
        },
        onLongPressEnd: (_) {
          setState(() => _paused = false);
          _progress.forward();
        },
        child: Stack(
          children: [
            // Content
            Positioned.fill(
              child: item.isText
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Text(
                          item.text,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    )
                  : Center(
                      child: Image.network(
                        item.content,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, p) => p == null
                            ? child
                            : const CircularProgressIndicator(color: Colors.white),
                        errorBuilder: (context, error, stack) => const Icon(
                            Icons.broken_image, color: Colors.white54, size: 64),
                      ),
                    ),
            ),
            // Top bars + header
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: Row(
                      children: [
                        for (var i = 0; i < _items.length; i++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: _Segment(
                                fill: i < _index
                                    ? 1.0
                                    : i > _index
                                        ? 0.0
                                        : null,
                                controller: i == _index ? _progress : null,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: Row(
                      children: [
                        const BackButton(color: Colors.white),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.tale.name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                              Text(
                                item.ts == 0
                                    ? ''
                                    : TimeFormat.shortStamp(
                                        DateTime.fromMillisecondsSinceEpoch(item.ts)),
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        if (widget.tale.isMine)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.white),
                            onPressed: _deleteCurrent,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_paused)
              const Center(
                child: Icon(Icons.pause, color: Colors.white24, size: 64),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteCurrent() async {
    _progress.stop();
    await StatusService.instance.deleteStatus(_current);
    if (!mounted) return;
    if (_items.length <= 1) {
      Navigator.of(context).maybePop();
    } else {
      setState(() {
        _items.removeAt(_index);
        if (_index >= _items.length) _index = _items.length - 1;
      });
      _start();
    }
  }

}

class _Segment extends StatelessWidget {
  final double? fill; // null => animate from controller
  final AnimationController? controller;
  const _Segment({this.fill, this.controller});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 3,
        child: controller != null
            ? AnimatedBuilder(
                animation: controller!,
                builder: (context, _) => _bar(controller!.value),
              )
            : _bar(fill ?? 0),
      ),
    );
  }

  Widget _bar(double value) {
    return Stack(
      children: [
        Container(color: Colors.white24),
        FractionallySizedBox(
          widthFactor: value.clamp(0, 1),
          child: Container(color: Colors.white),
        ),
      ],
    );
  }
}
