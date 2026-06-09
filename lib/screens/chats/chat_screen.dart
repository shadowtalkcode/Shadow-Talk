import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/chat_repository.dart';
import '../../models/enums.dart';
import '../../models/message.dart';
import '../../theme/app_colors.dart';
import '../../widgets/attachment_sheet.dart';
import '../../widgets/avatar.dart';
import '../../widgets/chat_input_bar.dart';
import '../../widgets/common.dart';
import '../../widgets/message_bubble.dart';
import 'contact_details_screen.dart';

/// Conversation screen. Matches XD reference 07/07b.
class ChatScreen extends StatefulWidget {
  final String chatId;
  const ChatScreen({super.key, required this.chatId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _repo = ChatRepository.instance;
  final _scroll = ScrollController();
  Message? _replyTo;

  @override
  void initState() {
    super.initState();
    _repo.setActiveChat(widget.chatId);
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  @override
  void dispose() {
    _repo.setActiveChat(null);
    _scroll.dispose();
    super.dispose();
  }

  void _jumpToBottom({bool animate = false}) {
    if (!_scroll.hasClients) return;
    final t = _scroll.position.maxScrollExtent;
    if (animate) {
      _scroll.animateTo(t, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      _scroll.jumpTo(t);
    }
  }

  String _quotePreview(Message m) {
    switch (m.kind) {
      case MessageKind.text:
        return m.content;
      case MessageKind.image:
        return '📷 Photo';
      case MessageKind.voice:
        return '🎤 Voice message';
      case MessageKind.file:
        return '📄 ${m.fileName ?? 'Document'}';
      default:
        return 'Message';
    }
  }

  void _send(String text) {
    QuotedMessage? q;
    final r = _replyTo;
    if (r != null) {
      q = QuotedMessage(
        messageId: r.messageId,
        authorName: r.isSent ? 'You' : _repo.chatById(widget.chatId).user.userName,
        preview: _quotePreview(r),
        kind: r.kind,
      );
    }
    _repo.sendText(widget.chatId, text, quoted: q);
    setState(() => _replyTo = null);
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom(animate: true));
  }

  Future<void> _onAttach() async {
    final option = await AttachmentSheet.show(context);
    if (option == null) return;
    switch (option) {
      case AttachmentOption.gallery:
      case AttachmentOption.camera:
        _repo.sendMedia(widget.chatId, MessageKind.image,
            content: 'assets/images/image2.png', fileSize: '1.4 MB');
        break;
      case AttachmentOption.file:
        _repo.sendMedia(widget.chatId, MessageKind.file,
            fileName: 'document.pdf', fileSize: '512 KB');
        break;
      case AttachmentOption.audio:
        _repo.sendMedia(widget.chatId, MessageKind.audio, mediaDuration: '02:31');
        break;
      case AttachmentOption.location:
        _repo.sendMedia(widget.chatId, MessageKind.location,
            lat: 37.7749, lng: -122.4194, locationName: 'San Francisco, CA');
        break;
      case AttachmentOption.contact:
        _repo.sendMedia(widget.chatId, MessageKind.contact,
            contactName: 'Alex Doe', contactPhone: '+1 555 0190');
        break;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom(animate: true));
  }

  void _onVoice() {
    _repo.sendMedia(widget.chatId, MessageKind.voice, mediaDuration: '00:08');
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom(animate: true));
  }

  void _showMessageActions(Message m) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply, color: AppColors.iconTint),
              title: const Text('Reply', style: TextStyle(color: AppColors.white)),
              onTap: () {
                Navigator.pop(context);
                setState(() => _replyTo = m);
              },
            ),
            if (m.kind == MessageKind.text)
              ListTile(
                leading: const Icon(Icons.content_copy, color: AppColors.iconTint),
                title: const Text('Copy', style: TextStyle(color: AppColors.white)),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: m.content));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.iconTint),
              title: const Text('Delete for me', style: TextStyle(color: AppColors.white)),
              onTap: () {
                _repo.deleteForMe(widget.chatId, m.messageId);
                Navigator.pop(context);
              },
            ),
            if (m.isSent && m.kind != MessageKind.deleted)
              ListTile(
                leading: const Icon(Icons.delete_forever, color: AppColors.red),
                title: const Text('Delete for everyone', style: TextStyle(color: AppColors.red)),
                onTap: () {
                  _repo.deleteForEveryone(widget.chatId, m.messageId);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: ListenableBuilder(
              listenable: _repo,
              builder: (context, _) {
                final chat = _repo.chatById(widget.chatId);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scroll.hasClients &&
                      _scroll.position.pixels >
                          _scroll.position.maxScrollExtent - 220) {
                    _jumpToBottom(animate: true);
                  }
                });
                if (chat.messages.isEmpty) {
                  return const Center(
                    child: Text('No messages yet. Say hi 👋',
                        style: TextStyle(color: AppColors.textDesc)),
                  );
                }
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: chat.messages.length,
                  itemBuilder: (context, i) => MessageBubble(
                    message: chat.messages[i],
                    onLongPress: () => _showMessageActions(chat.messages[i]),
                  ),
                );
              },
            ),
          ),
          // Typing line
          ListenableBuilder(
            listenable: _repo,
            builder: (context, _) {
              final chat = _repo.chatById(widget.chatId);
              if (!chat.isTyping) return const SizedBox.shrink();
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 6),
                child: Text('${chat.user.userName} is typing...',
                    style: const TextStyle(color: AppColors.textDesc, fontSize: 14)),
              );
            },
          ),
          if (_replyTo != null) _replyPreview(),
          ChatInputBar(onSend: _send, onAttach: _onAttach, onVoice: _onVoice),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final chat = _repo.chatById(widget.chatId);
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 0,
      leadingWidth: 36,
      leading: const BackButton(color: AppColors.white),
      title: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ContactDetailsScreen(user: chat.user)),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Avatar(user: chat.user, size: 46, showBorder: false),
                if (!chat.user.isGroup)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.background, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ListenableBuilder(
                listenable: _repo,
                builder: (context, _) {
                  final c = _repo.chatById(widget.chatId);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(c.user.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.white)),
                      Text(
                        c.isTyping ? 'typing…' : (c.user.isGroup ? 'tap for group info' : 'Active Now'),
                        style: const TextStyle(fontSize: 14, color: AppColors.textDesc),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.videocam, color: AppColors.white),
          onPressed: () => _comingSoon('Video call'),
        ),
        IconButton(
          icon: const Icon(Icons.call, color: AppColors.white),
          onPressed: () => _comingSoon('Voice call'),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  void _comingSoon(String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what is not available in this build')),
    );
  }

  Widget _replyPreview() {
    final m = _replyTo!;
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
      child: Row(
        children: [
          Container(width: 3, height: 38, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  m.isSent ? 'You' : _repo.chatById(widget.chatId).user.userName,
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(_quotePreview(m),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textDesc, fontSize: 13)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.iconTint),
            onPressed: () => setState(() => _replyTo = null),
          ),
        ],
      ),
    );
  }
}
