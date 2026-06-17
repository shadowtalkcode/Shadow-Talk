import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../theme/app_colors.dart';

/// Bottom message composer: a paperclip (attach), the text field, a mic that
/// records a voice note, and a purple send button. While recording, the bar
/// switches to a red "Recording mm:ss" strip with cancel + send.
class ChatInputBar extends StatefulWidget {
  final ValueChanged<String> onSend;
  final VoidCallback onAttach;

  /// Called with the recorded audio file + its length once the user taps send.
  final void Function(File file, int durationMs)? onVoiceRecorded;
  final ValueChanged<bool>? onTypingChanged;

  const ChatInputBar({
    super.key,
    required this.onSend,
    required this.onAttach,
    this.onVoiceRecorded,
    this.onTypingChanged,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _ctrl = TextEditingController();
  bool _hasText = false;

  final _recorder = Record();
  bool _recording = false;
  String? _recPath;
  Duration _elapsed = Duration.zero;
  Timer? _recTimer;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final has = _ctrl.text.trim().isNotEmpty;
      if (has != _hasText) {
        setState(() => _hasText = has);
        widget.onTypingChanged?.call(has);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _recTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _ctrl.clear();
    setState(() => _hasText = false);
  }

  // ---- Voice recording ----------------------------------------------------
  Future<void> _startRecording() async {
    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Microphone permission is needed for voice notes')));
        }
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(path: path, encoder: AudioEncoder.aacLc);
      _recPath = path;
      _elapsed = Duration.zero;
      setState(() => _recording = true);
      _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _elapsed += const Duration(seconds: 1));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Couldn't start recording: $e")));
      }
    }
  }

  Future<void> _stopAndSend() async {
    _recTimer?.cancel();
    final path = await _recorder.stop();
    final ms = _elapsed.inMilliseconds;
    setState(() => _recording = false);
    if (path != null && ms >= 1000) {
      widget.onVoiceRecorded?.call(File(path), ms);
    } else {
      // Too short — discard.
      _safeDelete(path ?? _recPath);
      if (mounted && ms < 1000) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hold longer to record a voice note')));
      }
    }
    _recPath = null;
  }

  Future<void> _cancelRecording() async {
    _recTimer?.cancel();
    final path = await _recorder.stop();
    setState(() => _recording = false);
    _safeDelete(path ?? _recPath);
    _recPath = null;
  }

  void _safeDelete(String? path) {
    if (path == null) return;
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  String get _elapsedText {
    final m = _elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(32),
          ),
          child: _recording ? _recordingRow() : _composerRow(),
        ),
      ),
    );
  }

  Widget _recordingRow() {
    return Row(
      children: [
        GestureDetector(
          onTap: _cancelRecording,
          child: const Icon(Icons.delete_outline, color: AppColors.red, size: 26),
        ),
        const SizedBox(width: 14),
        const _PulsingDot(),
        const SizedBox(width: 10),
        Expanded(
          child: Text('Recording  $_elapsedText',
              style: const TextStyle(color: AppColors.white, fontSize: 16)),
        ),
        GestureDetector(
          onTap: _stopAndSend,
          child: const Icon(Icons.send_rounded, color: AppColors.primary, size: 26),
        ),
      ],
    );
  }

  Widget _composerRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: widget.onAttach,
          child: const Icon(Icons.attach_file, color: AppColors.textDesc, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _ctrl,
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(color: AppColors.white, fontSize: 17),
            cursorColor: AppColors.primary,
            decoration: const InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: 'Type a Message',
              hintStyle: TextStyle(color: AppColors.textDesc, fontSize: 17),
              contentPadding: EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 12),
        if (_hasText)
          GestureDetector(
            onTap: _send,
            child: const Icon(Icons.send_rounded, color: AppColors.primary, size: 26),
          )
        else ...[
          GestureDetector(
            onTap: _startRecording,
            child: const Icon(Icons.mic_none_rounded, color: AppColors.textDesc, size: 26),
          ),
          const SizedBox(width: 14),
          GestureDetector(
            onTap: widget.onAttach,
            child: const Icon(Icons.near_me, color: AppColors.primary, size: 26),
          ),
        ],
      ],
    );
  }
}

/// Small pulsing red dot shown while recording.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.25).animate(_c),
      child: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
      ),
    );
  }
}
