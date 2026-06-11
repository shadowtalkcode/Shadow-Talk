import 'package:flutter/material.dart';

import '../../services/status_service.dart';
import '../../theme/app_colors.dart';

/// Compose a text status with a coloured background (like the Android text
/// status editor). Posts to RTDB on send.
class TextStatusComposer extends StatefulWidget {
  const TextStatusComposer({super.key});

  @override
  State<TextStatusComposer> createState() => _TextStatusComposerState();
}

class _TextStatusComposerState extends State<TextStatusComposer> {
  final _ctrl = TextEditingController();
  bool _posting = false;

  static const _backgrounds = <int>[
    0xFF7E58FC, // purple
    0xFF4B26BF,
    0xFFEA5659, // coral
    0xFF128C7E, // teal
    0xFF3AA0FF, // blue
    0xFFF7931A, // orange
    0xFFFF95C9, // pink
    0xFF222230, // dark
  ];
  int _bgIndex = 0;

  int get _bg => _backgrounds[_bgIndex];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      Navigator.pop(context);
      return;
    }
    setState(() => _posting = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await StatusService.instance.postTextStatus(text, _bg);
      navigator.pop(true);
    } catch (e) {
      setState(() => _posting = false);
      messenger.showSnackBar(SnackBar(content: Text("Couldn't post status: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(_bg),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Background colour',
            icon: const Icon(Icons.palette_outlined, color: Colors.white),
            onPressed: () => setState(
                () => _bgIndex = (_bgIndex + 1) % _backgrounds.length),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: TextField(
                    controller: _ctrl,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    maxLines: null,
                    maxLength: 280,
                    cursorColor: Colors.white,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                      hintText: 'Type a status…',
                      hintStyle: TextStyle(color: Colors.white70, fontSize: 26),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: _posting ? null : _post,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: _posting
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
