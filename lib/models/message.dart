import 'enums.dart';

/// A quoted/replied-to message reference. Ported from Android `QuotedMessage`.
class QuotedMessage {
  final String messageId;
  final String authorName; // "You" or contact name
  final String preview; // text snippet shown in the reply chip
  final MessageKind kind;

  const QuotedMessage({
    required this.messageId,
    required this.authorName,
    required this.preview,
    this.kind = MessageKind.text,
  });
}

/// A single chat message. Ported from Android `Message` (Realm) model with the
/// fields needed for the chat UI.
class Message {
  final String messageId;
  final String chatId;
  final bool isSent; // true => outgoing (me), false => incoming
  final MessageKind kind;
  String content; // text, or asset/path for media
  final DateTime timestamp;
  MessageStatus status;
  TransferState transferState;

  // Media extras
  final String? mediaDuration; // for voice/audio/video, e.g. "00:14"
  final String? fileSize; // e.g. "4 MB"
  final String? fileName;

  // Voice
  bool voiceSeen;

  // Location
  final double? lat;
  final double? lng;
  final String? locationName;

  // Contact card
  final String? contactName;
  final String? contactPhone;

  final QuotedMessage? quoted;
  final bool isForwarded;

  // For day separator rows
  final String? dayLabel;

  Message({
    required this.messageId,
    required this.chatId,
    required this.isSent,
    required this.kind,
    this.content = '',
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.transferState = TransferState.none,
    this.mediaDuration,
    this.fileSize,
    this.fileName,
    this.voiceSeen = false,
    this.lat,
    this.lng,
    this.locationName,
    this.contactName,
    this.contactPhone,
    this.quoted,
    this.isForwarded = false,
    this.dayLabel,
  });

  bool get isMedia =>
      kind == MessageKind.image ||
      kind == MessageKind.video ||
      kind == MessageKind.audio ||
      kind == MessageKind.voice ||
      kind == MessageKind.file;
}
