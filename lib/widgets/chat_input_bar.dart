import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Bottom message composer matching the XD design: a dark rounded pill with a
/// paperclip (attach), the text field, a mic, and a purple paper-plane send.
class ChatInputBar extends StatefulWidget {
  final ValueChanged<String> onSend;
  final VoidCallback onAttach;
  final VoidCallback onVoice;
  final ValueChanged<bool>? onTypingChanged;

  const ChatInputBar({
    super.key,
    required this.onSend,
    required this.onAttach,
    required this.onVoice,
    this.onTypingChanged,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _ctrl = TextEditingController();
  bool _hasText = false;

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
    super.dispose();
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _ctrl.clear();
    setState(() => _hasText = false);
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
          child: Row(
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
                  onTap: widget.onVoice,
                  child: const Icon(Icons.mic_none_rounded, color: AppColors.textDesc, size: 26),
                ),
                const SizedBox(width: 14),
                GestureDetector(
                  onTap: widget.onAttach,
                  child: Transform.rotate(
                    angle: 0,
                    child: const Icon(Icons.near_me, color: AppColors.primary, size: 26),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
