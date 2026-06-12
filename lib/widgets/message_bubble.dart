import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/message.dart';
import '../theme/app_colors.dart';
import '../utils/time_format.dart';

/// A chat row (bubble + time stamp below) matching the XD conversation design.
/// Sent bubbles are purple with a squared bottom-right corner; received bubbles
/// are dark rounded pills. Large single emoji messages render without a bubble.
class MessageBubble extends StatelessWidget {
  final Message message;
  final VoidCallback? onLongPress;

  const MessageBubble({super.key, required this.message, this.onLongPress});

  bool get _sent => message.isSent;

  bool get _isBigEmoji {
    if (message.kind != MessageKind.text) return false;
    final t = message.content.trim();
    if (t.isEmpty || t.length > 6) return false;
    final emoji = RegExp(
        r'^[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2190}-\u{21FF}\u{2B00}-\u{2BFF}️‍]+$',
        unicode: true);
    return emoji.hasMatch(t);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      child: Column(
        crossAxisAlignment:
            _sent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          _isBigEmoji ? _bigEmoji() : _bubble(context),
          const SizedBox(height: 6),
          // Time + delivery tick (tick only on our own sent messages), exactly
          // like Android: single grey = sent, double grey = delivered, double
          // blue = read.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                TimeFormat.clock24(message.timestamp),
                style: const TextStyle(fontSize: 13, color: AppColors.messageTime),
              ),
              if (_sent && message.kind != MessageKind.deleted) ...[
                const SizedBox(width: 5),
                _StatusTick(status: message.status),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _bigEmoji() => Text(message.content, style: const TextStyle(fontSize: 72));

  Widget _bubble(BuildContext context) {
    final radius = _sent
        ? const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
            bottomLeft: Radius.circular(28),
            bottomRight: Radius.circular(8),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
            bottomLeft: Radius.circular(8),
            bottomRight: Radius.circular(28),
          );

    final isImage = message.kind == MessageKind.image;
    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
      child: Material(
        color: _sent ? AppColors.sentBubble : AppColors.receivedBubble,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onLongPress: onLongPress,
          child: Padding(
            padding: isImage
                ? const EdgeInsets.all(4)
                : const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: _content(),
          ),
        ),
      ),
    );
  }

  Color get _txt =>
      _sent ? AppColors.sentMessageText : AppColors.receivedMessageText;

  Widget _content() {
    switch (message.kind) {
      case MessageKind.image:
        return _image();
      case MessageKind.voice:
      case MessageKind.audio:
        return _voice();
      case MessageKind.file:
        return _file();
      case MessageKind.location:
        return _location();
      case MessageKind.contact:
        return _contact();
      case MessageKind.deleted:
        return _deleted();
      default:
        return _text();
    }
  }

  Widget _text() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.quoted != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
              border: const Border(left: BorderSide(color: AppColors.primary, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message.quoted!.authorName,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _sent ? Colors.white : AppColors.primary)),
                const SizedBox(height: 2),
                Text(message.quoted!.preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        color: _txt.withValues(alpha: 0.8))),
              ],
            ),
          ),
        Text(message.content, style: TextStyle(fontSize: 17, color: _txt, height: 1.35)),
      ],
    );
  }

  Widget _image() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Image.asset(
        message.content,
        width: 250,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => Container(
          width: 250,
          height: 250,
          color: Colors.black26,
          child: const Icon(Icons.image, color: Colors.white54, size: 48),
        ),
      ),
    );
  }

  Widget _voice() {
    return SizedBox(
      width: 250,
      child: Row(
        children: [
          Expanded(child: SizedBox(height: 28, child: _Waveform(sent: _sent))),
          const SizedBox(width: 12),
          Text(message.mediaDuration ?? '00:00',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: _txt)),
          const SizedBox(width: 12),
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
                color: AppColors.primary, shape: BoxShape.circle),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 26),
          ),
        ],
      ),
    );
  }

  Widget _file() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _sent ? Colors.white24 : AppColors.primary.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.insert_drive_file,
              color: _sent ? Colors.white : AppColors.primary),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message.fileName ?? 'Document',
                style: TextStyle(fontSize: 15, color: _txt, fontWeight: FontWeight.w600)),
            Text(message.fileSize ?? '',
                style: TextStyle(fontSize: 12, color: _txt.withValues(alpha: 0.7))),
          ],
        ),
      ],
    );
  }

  Widget _location() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 220,
            height: 110,
            color: const Color(0xFF2A3D2E),
            child: const Center(
                child: Icon(Icons.location_on, color: Colors.redAccent, size: 40)),
          ),
        ),
        const SizedBox(height: 6),
        Text(message.locationName ?? 'Shared location',
            style: TextStyle(fontSize: 15, color: _txt)),
      ],
    );
  }

  Widget _contact() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: _sent ? Colors.white24 : AppColors.surface,
          child: const Icon(Icons.person, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message.contactName ?? 'Contact',
                style: TextStyle(fontSize: 15, color: _txt, fontWeight: FontWeight.w600)),
            Text(message.contactPhone ?? '',
                style: TextStyle(fontSize: 12, color: _txt.withValues(alpha: 0.7))),
          ],
        ),
      ],
    );
  }

  Widget _deleted() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.block, size: 16, color: _txt.withValues(alpha: 0.7)),
        const SizedBox(width: 6),
        Text('This message was deleted',
            style: TextStyle(
                fontSize: 15,
                fontStyle: FontStyle.italic,
                color: _txt.withValues(alpha: 0.7))),
      ],
    );
  }
}

/// Delivery indicator for a sent message — mirrors Android's `messageStat`
/// drawables: clock (pending), single grey check (sent), double grey check
/// (delivered/received), double blue check (read).
class _StatusTick extends StatelessWidget {
  final MessageStatus status;
  const _StatusTick({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.pending:
        return const Icon(Icons.access_time, size: 14, color: AppColors.messageTime);
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 16, color: AppColors.messageTime);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 16, color: AppColors.messageTime);
      case MessageStatus.read:
        return const Icon(Icons.done_all, size: 16, color: AppColors.readState);
    }
  }
}

/// Static purple waveform used for voice bubbles.
class _Waveform extends StatelessWidget {
  final bool sent;
  const _Waveform({required this.sent});

  static const _bars = [
    8, 14, 20, 11, 22, 16, 24, 12, 18, 9, 21, 15, 25, 13, 19, 10, 16, 8,
    14, 11, 17, 9, 20, 12, 7
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _bars.length; i++)
          Container(
            width: 3,
            height: _bars[i].toDouble(),
            margin: const EdgeInsets.symmetric(horizontal: 1.2),
            decoration: BoxDecoration(
              color: i < _bars.length * 0.55
                  ? (sent ? Colors.white : AppColors.primary)
                  : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );
  }
}
