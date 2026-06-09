import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../models/call_log.dart';
import '../models/chat.dart';
import '../models/enums.dart';
import '../models/message.dart';
import '../models/status_update.dart';
import '../models/user.dart';
import 'mock_data.dart';

/// Single source of truth for chat state. Backed by in-memory mock data and
/// exposed app-wide via a singleton + [ChangeNotifier] so the UI rebuilds
/// reactively (no Provider dependency needed — use [ListenableBuilder]).
class ChatRepository extends ChangeNotifier {
  ChatRepository._() {
    _chats = MockData.buildChats();
    _calls = MockData.buildCalls();
    _statuses = MockData.buildStatuses();
    _sortChats();
  }

  static final ChatRepository instance = ChatRepository._();

  final _rng = Random();
  int _idSeq = 0;

  late List<Chat> _chats;
  late List<CallLog> _calls;
  late List<StatusUpdate> _statuses;

  User get me => MockData.me;
  List<Chat> get chats => List.unmodifiable(_chats);
  List<CallLog> get calls => List.unmodifiable(_calls);
  List<StatusUpdate> get statuses => List.unmodifiable(_statuses);

  int get totalUnread =>
      _chats.fold(0, (sum, c) => sum + c.unreadCount);

  Chat chatById(String chatId) =>
      _chats.firstWhere((c) => c.chatId == chatId);

  String _newId() => 'local_${DateTime.now().millisecondsSinceEpoch}_${_idSeq++}';

  /// Notify listeners, deferring to after the current frame if we're called
  /// mid-build/layout (e.g. from a widget's initState during navigation) to
  /// avoid "setState() called during build" errors.
  void _safeNotify() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    } else {
      notifyListeners();
    }
  }

  void _sortChats() {
    _chats.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
  }

  // ---- Reads -------------------------------------------------------------
  void markRead(String chatId) {
    final chat = chatById(chatId);
    if (chat.unreadCount == 0) return;
    chat.unreadCount = 0;
    _safeNotify();
  }

  // ---- Sending -----------------------------------------------------------
  /// Sends a text message and kicks off the status lifecycle + a simulated
  /// reply from the peer.
  void sendText(String chatId, String text, {QuotedMessage? quoted}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final msg = Message(
      messageId: _newId(),
      chatId: chatId,
      isSent: true,
      kind: MessageKind.text,
      content: trimmed,
      timestamp: DateTime.now(),
      status: MessageStatus.pending,
      quoted: quoted,
    );
    _appendOutgoing(chatId, msg);
  }

  /// Sends a media/other-kind message (image, file, location, contact, voice…).
  void sendMedia(
    String chatId,
    MessageKind kind, {
    String content = '',
    String? mediaDuration,
    String? fileSize,
    String? fileName,
    double? lat,
    double? lng,
    String? locationName,
    String? contactName,
    String? contactPhone,
  }) {
    final msg = Message(
      messageId: _newId(),
      chatId: chatId,
      isSent: true,
      kind: kind,
      content: content,
      timestamp: DateTime.now(),
      status: MessageStatus.pending,
      transferState: TransferState.success,
      mediaDuration: mediaDuration,
      fileSize: fileSize,
      fileName: fileName,
      lat: lat,
      lng: lng,
      locationName: locationName,
      contactName: contactName,
      contactPhone: contactPhone,
    );
    _appendOutgoing(chatId, msg);
  }

  void _appendOutgoing(String chatId, Message msg) {
    final chat = chatById(chatId);
    chat.messages.add(msg);
    _sortChats();
    _safeNotify();

    // Simulate the sending → sent → delivered → read lifecycle.
    Timer(const Duration(milliseconds: 500), () {
      msg.status = MessageStatus.sent;
      _safeNotify();
    });
    Timer(const Duration(milliseconds: 1200), () {
      msg.status = MessageStatus.delivered;
      _safeNotify();
    });

    if (chat.user.isGroup) return; // no auto-reply for groups

    // Peer "typing" then a canned reply.
    Timer(const Duration(milliseconds: 1600), () {
      chat.isTyping = true;
      _safeNotify();
    });
    Timer(Duration(milliseconds: 2600 + _rng.nextInt(1500)), () {
      msg.status = MessageStatus.read;
      chat.isTyping = false;
      final reply = Message(
        messageId: _newId(),
        chatId: chatId,
        isSent: false,
        kind: MessageKind.text,
        content: MockData.autoReplies[_rng.nextInt(MockData.autoReplies.length)],
        timestamp: DateTime.now(),
        status: MessageStatus.delivered,
      );
      chat.messages.add(reply);
      // If the user isn't viewing, bump unread.
      if (_activeChatId != chatId) {
        chat.unreadCount += 1;
      }
      _sortChats();
      _safeNotify();
    });
  }

  // ---- Active chat tracking (so we don't bump unread while viewing) -------
  String? _activeChatId;
  void setActiveChat(String? chatId) {
    _activeChatId = chatId;
    if (chatId != null) markRead(chatId);
  }

  // ---- Message ops -------------------------------------------------------
  void deleteForMe(String chatId, String messageId) {
    final chat = chatById(chatId);
    chat.messages.removeWhere((m) => m.messageId == messageId);
    _safeNotify();
  }

  void deleteForEveryone(String chatId, String messageId) {
    final chat = chatById(chatId);
    final msg = chat.messages.firstWhere((m) => m.messageId == messageId);
    final idx = chat.messages.indexOf(msg);
    chat.messages[idx] = Message(
      messageId: msg.messageId,
      chatId: chatId,
      isSent: msg.isSent,
      kind: MessageKind.deleted,
      content: '',
      timestamp: msg.timestamp,
      status: msg.status,
    );
    _safeNotify();
  }

  // ---- Chat ops ----------------------------------------------------------
  void toggleMute(String chatId) {
    chatById(chatId).isMuted = !chatById(chatId).isMuted;
    _safeNotify();
  }

  void clearChat(String chatId) {
    chatById(chatId).messages.clear();
    _safeNotify();
  }

  void deleteChat(String chatId) {
    _chats.removeWhere((c) => c.chatId == chatId);
    _safeNotify();
  }

  /// Returns an existing chat for [user] or creates a new empty one.
  Chat openChatWith(User user) {
    final existing = _chats.where((c) => c.user.uid == user.uid);
    if (existing.isNotEmpty) return existing.first;
    final chat = Chat(chatId: 'c_${user.uid}', user: user);
    _chats.insert(0, chat);
    _safeNotify();
    return chat;
  }

  // ---- Search ------------------------------------------------------------
  List<Chat> searchChats(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return chats;
    return _chats.where((c) {
      if (c.user.userName.toLowerCase().contains(q)) return true;
      return c.messages.any((m) =>
          m.kind == MessageKind.text && m.content.toLowerCase().contains(q));
    }).toList();
  }
}
