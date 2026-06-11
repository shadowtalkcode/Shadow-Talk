import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/enums.dart';
import '../../models/message.dart';
import '../../models/user.dart';
import '../../services/chat_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/time_format.dart';
import '../../widgets/avatar.dart';
import '../../widgets/chat_input_bar.dart';
import '../../widgets/common.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/typing_indicator.dart';
import '../calls/call_launcher.dart';

/// Live 1:1 conversation backed by Firebase Realtime Database (real send/receive,
/// status, presence, typing) — the real-chat equivalent of the Android app.
class LiveChatScreen extends StatefulWidget {
  final String peerUid;
  final String peerName;
  final String? peerPhoto;

  const LiveChatScreen({
    super.key,
    required this.peerUid,
    required this.peerName,
    this.peerPhoto,
  });

  @override
  State<LiveChatScreen> createState() => _LiveChatScreenState();
}

class _LiveChatScreenState extends State<LiveChatScreen> {
  final _chat = ChatService.instance;
  final _scroll = ScrollController();
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    // Mark the conversation as read when opened.
    _chat.markIncoming(widget.peerUid, read: true);
  }

  @override
  void dispose() {
    _chat.setTyping(widget.peerUid, false);
    _typingTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _jumpToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(_scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  Future<void> _send(String text) async {
    _chat.setTyping(widget.peerUid, false);
    try {
      await _chat.sendText(widget.peerUid, text);
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't send — check your connection/permissions")),
      );
    }
  }

  void _onTyping(bool hasText) {
    _chat.setTyping(widget.peerUid, hasText);
    _typingTimer?.cancel();
    if (hasText) {
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _chat.setTyping(widget.peerUid, false);
      });
    }
  }

  Message _toMessage(LiveMessage m) {
    final isSent = m.isSentBy(_chat.uid);
    return Message(
      messageId: m.id,
      chatId: widget.peerUid,
      isSent: isSent,
      kind: m.type == 'image' ? MessageKind.image : MessageKind.text,
      content: m.text,
      timestamp: DateTime.fromMillisecondsSinceEpoch(m.ts == 0 ? DateTime.now().millisecondsSinceEpoch : m.ts),
      status: switch (m.status) {
        MsgStat.read => MessageStatus.read,
        MsgStat.delivered => MessageStatus.delivered,
        _ => MessageStatus.sent,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final peerUser = User(uid: widget.peerUid, userName: widget.peerName);
    return GradientScaffold(
      appBar: _appBar(peerUser),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<LiveMessage>>(
              stream: _chat.messages(widget.peerUid),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? const [];
                // Mark newly arrived incoming messages as read while viewing.
                if (messages.any((m) => !m.isSentBy(_chat.uid) && m.status < MsgStat.read)) {
                  _chat.markIncoming(widget.peerUid, read: true);
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scroll.hasClients &&
                      _scroll.position.pixels >
                          _scroll.position.maxScrollExtent - 250) {
                    _jumpToBottom();
                  }
                });
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('No messages yet. Say hi 👋',
                        style: TextStyle(color: AppColors.textDesc)),
                  );
                }
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, i) => MessageBubble(message: _toMessage(messages[i])),
                );
              },
            ),
          ),
          // Typing line
          StreamBuilder<bool>(
            stream: _chat.peerTyping(widget.peerUid),
            builder: (context, snap) {
              if (snap.data != true) return const SizedBox.shrink();
              return const Align(
                alignment: Alignment.centerLeft,
                child: TypingIndicator(),
              );
            },
          ),
          ChatInputBar(
            onSend: _send,
            onAttach: () => _comingSoon('Attachments'),
            onVoice: () => _comingSoon('Voice messages'),
            onTypingChanged: _onTyping,
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _appBar(User peerUser) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 0,
      leadingWidth: 36,
      leading: const BackButton(color: AppColors.white),
      title: Row(
        children: [
          Avatar(user: peerUser, size: 44, showBorder: false),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.peerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.white)),
                StreamBuilder<Presence>(
                  stream: _chat.presenceOf(widget.peerUid),
                  builder: (context, snap) {
                    final p = snap.data;
                    final text = p == null
                        ? 'offline'
                        : p.online
                            ? 'Active Now'
                            : (p.lastSeen > 0
                                ? 'last seen ${TimeFormat.shortStamp(DateTime.fromMillisecondsSinceEpoch(p.lastSeen))}'
                                : 'offline');
                    return Text(text,
                        style: TextStyle(
                            fontSize: 13,
                            color: (p?.online ?? false) ? AppColors.green : AppColors.textDesc));
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
            icon: const Icon(Icons.videocam, color: AppColors.white),
            onPressed: () => startCall(context,
                peerUid: widget.peerUid,
                peerName: widget.peerName,
                peerPhoto: widget.peerPhoto,
                isVideo: true)),
        IconButton(
            icon: const Icon(Icons.call, color: AppColors.white),
            onPressed: () => startCall(context,
                peerUid: widget.peerUid,
                peerName: widget.peerName,
                peerPhoto: widget.peerPhoto,
                isVideo: false)),
        const SizedBox(width: 4),
      ],
    );
  }

  void _comingSoon(String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what are not available in this build')),
    );
  }
}
