import 'message.dart';
import 'user.dart';

/// A conversation. Ported from Android `Chat` (Realm) model.
class Chat {
  final String chatId;
  final User user;
  final List<Message> messages;
  int unreadCount;
  bool isMuted;
  bool isTyping; // transient UI state (peer is typing)

  Chat({
    required this.chatId,
    required this.user,
    List<Message>? messages,
    this.unreadCount = 0,
    this.isMuted = false,
    this.isTyping = false,
  }) : messages = messages ?? [];

  Message? get lastMessage => messages.isEmpty ? null : messages.last;

  DateTime get lastActivity =>
      lastMessage?.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
}
