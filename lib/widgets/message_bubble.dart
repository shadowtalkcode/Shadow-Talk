import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
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
  final VoidCallback? onTap;

  const MessageBubble(
      {super.key, required this.message, this.onLongPress, this.onTap});

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
          onTap: onTap,
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
    final src = message.content;
    final uploading = message.transferState == TransferState.loading;
    final placeholder = Container(
      width: 250,
      height: 250,
      color: Colors.black26,
      child: const Icon(Icons.image, color: Colors.white54, size: 48),
    );

    Widget img;
    if (src.startsWith('http')) {
      img = Image.network(
        src,
        width: 250,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : Container(
                width: 250,
                height: 250,
                color: Colors.black26,
                child: const Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white54)),
              ),
        errorBuilder: (context, error, stack) => placeholder,
      );
    } else if (src.startsWith('/')) {
      // Local file (an optimistic, still-uploading photo).
      img = Image.file(File(src),
          width: 250, fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => placeholder);
    } else {
      img = Image.asset(src,
          width: 250, fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => placeholder);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Hero only for the uploaded (URL) image, which is what opens
          // fullscreen — gives the WhatsApp-style zoom-open transition.
          src.startsWith('http')
              ? Hero(tag: 'img_${message.messageId}', child: img)
              : img,
          if (uploading)
            Container(
              width: 250,
              height: 250,
              color: Colors.black38,
              child: const Center(
                  child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  Widget _voice() {
    final uploading = message.transferState == TransferState.loading;
    return _VoicePlayer(
      // http URL once uploaded; a local path while still uploading.
      url: message.content,
      durationLabel: message.mediaDuration ?? '00:00',
      sent: _sent,
      uploading: uploading,
      seed: message.messageId,
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

/// WhatsApp-style voice note: a play/pause button, a seekable waveform whose
/// played bars fill in, and a duration that counts up while playing — with a
/// small mic icon. Streams the audio from its Storage URL; shows a spinner
/// while the note is still uploading.
class _VoicePlayer extends StatefulWidget {
  final String url;
  final String durationLabel;
  final bool sent;
  final bool uploading;
  final String seed; // gives each note a stable, distinct waveform shape

  const _VoicePlayer({
    required this.url,
    required this.durationLabel,
    required this.sent,
    required this.uploading,
    required this.seed,
  });

  @override
  State<_VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<_VoicePlayer> {
  static const int _barCount = 26;

  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription> _subs = [];
  late final List<double> _bars;
  PlayerState _state = PlayerState.stopped;
  Duration _pos = Duration.zero;
  Duration _total = Duration.zero;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random(widget.seed.hashCode);
    _bars = List.generate(_barCount, (_) => 5 + rnd.nextDouble() * 19);

    _subs.add(_player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _state = s);
    }));
    _subs.add(_player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _pos = p);
    }));
    _subs.add(_player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _total = d);
    }));
    _subs.add(_player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _state = PlayerState.stopped;
          _pos = Duration.zero;
        });
      }
    }));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  bool get _playable => !widget.uploading && widget.url.startsWith('http');

  Future<void> _toggle() async {
    if (!_playable) return;
    if (_state == PlayerState.playing) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.url));
    }
  }

  void _seekToFraction(double f) {
    if (!_playable || _total.inMilliseconds == 0) return;
    final clamped = f.clamp(0.0, 1.0);
    _player.seek(Duration(milliseconds: (clamped * _total.inMilliseconds).round()));
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final txt =
        widget.sent ? AppColors.sentMessageText : AppColors.receivedMessageText;
    final played = widget.sent ? Colors.white : AppColors.primary;
    final unplayed =
        widget.sent ? Colors.white.withValues(alpha: 0.45) : AppColors.surfaceAlt;
    final playing = _state == PlayerState.playing;
    final progress = _total.inMilliseconds > 0
        ? (_pos.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final label = (playing || _pos > Duration.zero)
        ? _fmt(_pos)
        : widget.durationLabel;

    return SizedBox(
      width: 232,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Play / pause / uploading button.
          GestureDetector(
            onTap: _toggle,
            child: SizedBox(
              width: 40,
              height: 40,
              child: widget.uploading
                  ? Padding(
                      padding: const EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: played),
                    )
                  : Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                      color: played, size: 40),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Seekable waveform.
                LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (d) => _seekToFraction(d.localPosition.dx / w),
                      onHorizontalDragUpdate: (d) =>
                          _seekToFraction(d.localPosition.dx / w),
                      child: SizedBox(
                        height: 26,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            for (var i = 0; i < _bars.length; i++)
                              Expanded(
                                child: Center(
                                  child: Container(
                                    height: _bars[i],
                                    margin:
                                        const EdgeInsets.symmetric(horizontal: 1),
                                    decoration: BoxDecoration(
                                      color: (i / _bars.length) <= progress
                                          ? played
                                          : unplayed,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 12, color: txt.withValues(alpha: 0.85))),
                    const Spacer(),
                    Icon(Icons.mic, size: 15, color: txt.withValues(alpha: 0.7)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
