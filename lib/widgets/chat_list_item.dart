import 'package:flutter/material.dart';

import '../models/chat.dart';
import '../models/enums.dart';
import '../models/message.dart';
import '../theme/app_colors.dart';
import '../utils/time_format.dart';
import 'avatar.dart';

/// One row in the chat list. Ported from row_chats.xml.
class ChatListItem extends StatelessWidget {
  final Chat chat;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const ChatListItem({
    super.key,
    required this.chat,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final last = chat.lastMessage;
    final unread = chat.unreadCount;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Avatar(user: chat.user, size: 60),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.user.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        last == null ? '' : TimeFormat.shortStamp(last.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: unread > 0 ? AppColors.primary : AppColors.textDesc,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (chat.isTyping)
                        const Expanded(
                          child: Text(
                            'typing…',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14, color: AppColors.typing),
                          ),
                        )
                      else ...[
                        if (last != null && last.isSent && last.kind != MessageKind.deleted)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: _StatusTick(status: last.status),
                          ),
                        Expanded(
                          child: Text(
                            _previewText(last),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textDesc,
                            ),
                          ),
                        ),
                      ],
                      if (chat.isMuted)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(Icons.volume_off_rounded,
                              size: 16, color: AppColors.textDesc),
                        ),
                      if (unread > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          constraints: const BoxConstraints(minWidth: 20),
                          decoration: const BoxDecoration(
                            color: AppColors.unreadBadgeBg,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$unread',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.unreadBadgeText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _previewText(Message? m) {
    if (m == null) return 'Tap to start chatting';
    switch (m.kind) {
      case MessageKind.text:
        return m.content;
      case MessageKind.image:
        return '📷 Photo';
      case MessageKind.video:
        return '🎥 Video';
      case MessageKind.voice:
        return '🎤 Voice message';
      case MessageKind.audio:
        return '🎵 Audio';
      case MessageKind.file:
        return '📄 ${m.fileName ?? 'Document'}';
      case MessageKind.location:
        return '📍 Location';
      case MessageKind.contact:
        return '👤 ${m.contactName ?? 'Contact'}';
      case MessageKind.sticker:
        return 'Sticker';
      case MessageKind.deleted:
        return 'This message was deleted';
      case MessageKind.groupEvent:
      case MessageKind.day:
        return '';
    }
  }
}

class _StatusTick extends StatelessWidget {
  final MessageStatus status;
  const _StatusTick({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.pending:
        return const Icon(Icons.access_time, size: 14, color: AppColors.textDesc);
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 15, color: AppColors.textDesc);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 15, color: AppColors.textDesc);
      case MessageStatus.read:
        return const Icon(Icons.done_all, size: 15, color: AppColors.readState);
    }
  }
}
