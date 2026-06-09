/// Message content kinds. Mirrors the Android `MessageType` constants but
/// collapsed into a single direction-agnostic enum (direction is tracked
/// separately via [Message.isSent]).
enum MessageKind {
  text,
  image,
  video,
  audio,
  voice,
  file,
  contact,
  location,
  sticker,
  deleted,
  groupEvent,
  day, // date separator row
}

/// Delivery status. Mirrors Android `MessageStat`:
/// PENDING(0), SENT(1), RECEIVED/DELIVERED(2), READ(3).
enum MessageStatus { pending, sent, delivered, read }

/// Media transfer state. Mirrors Android `DownloadUploadStat`.
enum TransferState { none, loading, success, failed, cancelled }

/// Call direction / outcome for the Calls tab.
enum CallType { incoming, outgoing, missed }
