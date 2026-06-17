import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
import 'image_viewer_screen.dart';

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

  /// Locally-shown messages that are still uploading/sending, so media appears
  /// instantly with an "uploading" indicator instead of only after the upload
  /// completes. Removed once the real message lands in the Firebase stream.
  final List<Message> _pending = [];
  int _localSeq = 0;

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

  /// With the reversed list the newest message sits at scroll offset 0.
  void _jumpToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(0,
        duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  String _addPending(Message Function(String id) build) {
    final id = 'local_${_localSeq++}';
    setState(() => _pending.add(build(id)));
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
    return id;
  }

  void _removePending(String id) {
    if (!mounted) return;
    setState(() => _pending.removeWhere((m) => m.messageId == id));
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
    final kind = switch (m.type) {
      'image' => MessageKind.image,
      'voice' || 'audio' => MessageKind.voice,
      _ => MessageKind.text,
    };
    return Message(
      messageId: m.id,
      chatId: widget.peerUid,
      isSent: isSent,
      kind: kind,
      content: m.text, // text, or media download URL
      mediaDuration: kind == MessageKind.voice ? _fmtDuration(m.durationMs) : null,
      timestamp: DateTime.fromMillisecondsSinceEpoch(m.ts == 0 ? DateTime.now().millisecondsSinceEpoch : m.ts),
      status: switch (m.status) {
        MsgStat.read => MessageStatus.read,
        MsgStat.delivered => MessageStatus.delivered,
        _ => MessageStatus.sent,
      },
    );
  }

  void _openImage(List<Message> all, Message tapped) {
    // All photos in the conversation, so the viewer can swipe between them.
    final photos = all
        .where((x) => x.kind == MessageKind.image && x.content.startsWith('http'))
        .toList();
    final viewerImages = photos
        .map((x) => ViewerImage(
              url: x.content,
              heroTag: 'img_${x.messageId}',
              sender: x.isSent ? 'You' : widget.peerName,
              time: TimeFormat.clock24(x.timestamp),
            ))
        .toList();
    final initial = photos.indexWhere((x) => x.messageId == tapped.messageId);
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ImageViewerScreen(
        images: viewerImages,
        initialIndex: initial < 0 ? 0 : initial,
      ),
    ));
  }

  static String _fmtDuration(int ms) {
    final total = (ms / 1000).round();
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final peerUser = User(
        uid: widget.peerUid,
        userName: widget.peerName,
        photoUrl: widget.peerPhoto);
    return GradientScaffold(
      appBar: _appBar(peerUser),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<LiveMessage>>(
              stream: _chat.messages(widget.peerUid),
              // Show the last-known messages instantly so the chat opens with no
              // spinner/flash while the live stream refreshes.
              initialData: _chat.cachedMessages(widget.peerUid),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? const <LiveMessage>[];
                // Mark newly arrived incoming messages as read while viewing.
                if (messages.any((m) => !m.isSentBy(_chat.uid) && m.status < MsgStat.read)) {
                  _chat.markIncoming(widget.peerUid, read: true);
                }
                // Real messages + still-uploading local ones, oldest→newest.
                final all = [
                  ...messages.map(_toMessage),
                  ..._pending,
                ]..sort((a, b) => a.timestamp.compareTo(b.timestamp));

                if (all.isEmpty) {
                  // Don't flash "No messages yet" before the first load lands.
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox.shrink();
                  }
                  return const Center(
                    child: Text('No messages yet. Say hi 👋',
                        style: TextStyle(color: AppColors.textDesc)),
                  );
                }
                // reverse:true anchors the view at the newest message, so the
                // chat always opens at the bottom even while images load.
                return ListView.builder(
                  controller: _scroll,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: all.length,
                  itemBuilder: (context, i) {
                    final m = all[all.length - 1 - i];
                    final tappableImage = m.kind == MessageKind.image &&
                        m.content.startsWith('http');
                    return MessageBubble(
                      message: m,
                      onTap: tappableImage ? () => _openImage(all, m) : null,
                    );
                  },
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
            onAttach: _pickAndSendImage,
            onVoiceRecorded: _sendVoice,
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

  Future<void> _pickAndSendImage() async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 1600);
    if (picked == null) return;
    // Show the photo immediately (local file) with an uploading overlay.
    final pendingId = _addPending((id) => Message(
          messageId: id,
          chatId: widget.peerUid,
          isSent: true,
          kind: MessageKind.image,
          content: picked.path,
          timestamp: DateTime.now(),
          status: MessageStatus.pending,
          transferState: TransferState.loading,
        ));
    try {
      await _chat.sendImage(widget.peerUid, File(picked.path));
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't send photo — check Storage setup/connection")),
      );
    } finally {
      _removePending(pendingId);
    }
  }

  Future<void> _sendVoice(File file, int durationMs) async {
    final messenger = ScaffoldMessenger.of(context);
    // Show the voice note immediately with an uploading indicator.
    final pendingId = _addPending((id) => Message(
          messageId: id,
          chatId: widget.peerUid,
          isSent: true,
          kind: MessageKind.voice,
          content: file.path,
          mediaDuration: _fmtDuration(durationMs),
          timestamp: DateTime.now(),
          status: MessageStatus.pending,
          transferState: TransferState.loading,
        ));
    try {
      await _chat.sendVoice(widget.peerUid, file, durationMs);
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't send voice note — check Storage setup/connection")),
      );
    } finally {
      _removePending(pendingId);
      try {
        if (file.existsSync()) file.deleteSync();
      } catch (_) {}
    }
  }
}
