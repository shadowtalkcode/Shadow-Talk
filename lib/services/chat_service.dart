import 'dart:async';
import 'dart:io';

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'profile_store.dart';

void _log(String m) => debugPrint('💬 CHAT: $m');

/// Message delivery status (mirrors Android MessageStat): 1=sent, 2=delivered,
/// 3=read.
class MsgStat {
  static const int sent = 1;
  static const int delivered = 2;
  static const int read = 3;
}

/// A live chat message.
class LiveMessage {
  final String id;
  final String from;
  final String to;
  final String text;
  final String type; // 'text' | 'image' | 'voice' | ...
  final int ts;
  final int status;
  final int durationMs; // voice/audio length, 0 otherwise

  LiveMessage({
    required this.id,
    required this.from,
    required this.to,
    required this.text,
    required this.type,
    required this.ts,
    required this.status,
    this.durationMs = 0,
  });

  bool isSentBy(String? uid) => from == uid;

  factory LiveMessage.fromMap(String id, Map data) => LiveMessage(
        id: id,
        from: (data['from'] ?? '').toString(),
        to: (data['to'] ?? '').toString(),
        text: (data['text'] ?? '').toString(),
        type: (data['type'] ?? 'text').toString(),
        ts: (data['ts'] is int) ? data['ts'] as int : 0,
        status: (data['status'] is int) ? data['status'] as int : MsgStat.sent,
        durationMs: (data['duration'] is int) ? data['duration'] as int : 0,
      );
}

/// A row in the chats list.
class ChatSummary {
  final String peerUid;
  final String peerName;
  final String? peerPhoto;
  final String lastText;
  final int lastTs;
  final bool lastFromMe;
  final int unread;

  ChatSummary({
    required this.peerUid,
    required this.peerName,
    required this.peerPhoto,
    required this.lastText,
    required this.lastTs,
    required this.lastFromMe,
    required this.unread,
  });
}

/// A user found in the directory.
class DirUser {
  final String uid;
  final String name;
  final String phone;
  final String? photo;
  DirUser({required this.uid, required this.name, required this.phone, this.photo});
}

/// Peer presence.
class Presence {
  final bool online;
  final int lastSeen;
  Presence(this.online, this.lastSeen);
}

/// Real-time 1:1 chat backend over Firebase Realtime Database — same
/// user-facing behaviour as the Android app (live send/receive, message status,
/// presence, typing).
///
/// IMPORTANT: the conversation data lives **under the `messages/` subtree**,
/// because the Shadow Talk Firebase security rules only grant access to the
/// nodes the Android app uses (`messages`, `users`, `presence`, `uidByPhone`,
/// `typingStat`, …). Top-level `chats`/`userChats` nodes are denied by the
/// rules, so writing there silently fails with permission-denied. The `messages`
/// node is open read/write and its rules cascade to every descendant, so we
/// nest the conversation + per-user index beneath it:
///
/// ```
///   users/{uid}                              : { name, phone, photoUrl }
///   uidByPhone/{phone}                       : uid
///   presence/{uid}                           : { online, lastSeen }
///   messages/conv/{chatId}/messages/{msgId}  : { from, to, text, type, ts, status }
///   messages/conv/{chatId}/typing/{uid}      : bool
///   messages/index/{uid}/{peerUid}           : { lastText, lastTs, lastFromMe, unread }
/// ```
class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  String? _uid;
  bool _ready = false;

  // In-memory caches so screens render INSTANTLY (no spinner) while the live
  // stream refreshes in the background — the WhatsApp-style "open is instant".
  final Map<String, DirUser> _userCache = {};
  List<ChatSummary> _chatsCache = const [];
  final Map<String, List<LiveMessage>> _messagesCache = {};

  String? get uid => _uid;
  bool get isReady => _ready;

  /// Last-known chat list (for StreamBuilder initialData).
  List<ChatSummary> get cachedChats => _chatsCache;

  /// Last-known messages for a conversation (for StreamBuilder initialData).
  List<LiveMessage> cachedMessages(String peerUid) =>
      _messagesCache[chatIdWith(peerUid)] ?? const [];

  /// Synchronously returns a cached user profile if we've fetched it (e.g. the
  /// chat list / directory populated it) — used to show a peer's CURRENT photo.
  DirUser? cachedUser(String uid) => _userCache[uid];

  DatabaseReference get _root => _db.ref();

  /// Conversation node (messages + typing) for a chat, under the open
  /// `messages/` subtree so the security rules permit it.
  DatabaseReference _convRef(String chatId) =>
      _root.child('messages').child('conv').child(chatId);

  /// Per-user recent-chats index, also under the open `messages/` subtree.
  DatabaseReference _indexRef(String uid) =>
      _root.child('messages').child('index').child(uid);

  static String sanitizePhone(String phone) =>
      phone.replaceAll(RegExp(r'[^0-9]'), '');

  /// Deterministic chat id for a pair of users.
  String chatIdWith(String peerUid) {
    final a = _uid ?? '';
    final ids = [a, peerUid]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  /// Signs in (anonymously if needed), registers the user, and sets presence.
  /// Returns the uid, or null if auth/DB is unavailable.
  Future<String?> start() async {
    _uid = await AuthService.instance.ensureSignedIn();
    if (_uid == null) {
      _log('start → no uid (anonymous auth disabled / phone auth unavailable)');
      _ready = false;
      return null;
    }
    try {
      await registerSelf();
      await _setupPresence();
      // Keep the chat index synced to disk in the background so the chat list
      // is warm and opens instantly next time.
      try {
        _indexRef(_uid!).keepSynced(true);
      } catch (_) {}
      _ready = true;
      _log('start → ready as uid=$_uid');
    } catch (e) {
      _ready = false;
      _log('start → setup failed (rules?): $e');
    }
    return _uid;
  }

  /// Upload the user's profile photo to Storage and persist its download URL
  /// (so peers can render it), then propagate it to `users/{uid}`. Returns the
  /// URL, or null on failure.
  Future<String?> setProfilePhoto(File file) async {
    if (!_ready) await start();
    final uid = _uid;
    if (uid == null) return null;
    try {
      final ref = FirebaseStorage.instance.ref('profilePhotos/$uid.jpg');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      await ProfileStore.instance.save(photoUrl: url);
      await registerSelf();
      return url;
    } catch (e) {
      _log('setProfilePhoto failed: $e');
      return null;
    }
  }

  /// Writes the current user's directory entry from the saved profile + phone.
  Future<void> registerSelf() async {
    final uid = _uid;
    if (uid == null) return;
    final p = ProfileStore.instance;
    final phone = sanitizePhone(p.phone.isEmpty ? AuthService.instance.phoneNumber : p.phone);
    final name = p.name.isEmpty ? 'Shadow Talk user' : p.name;
    await _root.child('users').child(uid).update({
      'uid': uid,
      'name': name,
      'phone': phone,
      // The uploaded download URL (not the device-local path) so peers can load
      // it. Empty until the user picks a photo (then setProfilePhoto fills it).
      'photoUrl': p.photoUrl ?? '',
      'updatedAt': ServerValue.timestamp,
    });
    if (phone.isNotEmpty) {
      await _root.child('uidByPhone').child(phone).set(uid);
    }
  }

  Future<void> _setupPresence() async {
    final uid = _uid;
    if (uid == null) return;
    final ref = _root.child('presence').child(uid);
    await ref.onDisconnect().set({'online': false, 'lastSeen': ServerValue.timestamp});
    await ref.set({'online': true, 'lastSeen': ServerValue.timestamp});
  }

  Future<void> setOnline(bool online) async {
    final uid = _uid;
    if (uid == null) return;
    await _root.child('presence').child(uid).set({
      'online': online,
      'lastSeen': ServerValue.timestamp,
    });
  }

  // ---- Directory ---------------------------------------------------------
  Future<DirUser?> findUserByPhone(String phone) async {
    final p = sanitizePhone(phone);
    if (p.isEmpty) return null;
    final idSnap = await _root.child('uidByPhone').child(p).get();
    if (!idSnap.exists) return null;
    final peerUid = idSnap.value.toString();
    return getUser(peerUid);
  }

  Future<DirUser?> getUser(String uid) async {
    // Serve from cache instantly; this is hit once per chat in the list, so
    // caching keeps the chat list from re-fetching every profile on each update.
    final cached = _userCache[uid];
    if (cached != null) return cached;
    final snap = await _root.child('users').child(uid).get();
    if (!snap.exists || snap.value is! Map) return null;
    final m = snap.value as Map;
    final user = DirUser(
      uid: uid,
      name: (m['name'] ?? 'User').toString(),
      phone: (m['phone'] ?? '').toString(),
      photo: (m['photoUrl'] ?? '').toString().isEmpty ? null : m['photoUrl'].toString(),
    );
    _userCache[uid] = user;
    return user;
  }

  /// Live directory of every registered Shadow Talk user except yourself.
  ///
  /// Lets people discover each other without typing an exact phone number —
  /// once two devices register, each appears in the other's New Chat list.
  Stream<List<DirUser>> usersStream() {
    return _root.child('users').onValue.map((event) {
      final val = event.snapshot.value;
      if (val is! Map) return <DirUser>[];
      final me = _uid;
      final list = <DirUser>[];
      val.forEach((key, v) {
        if (v is! Map) return;
        final uid = (v['uid'] ?? key).toString();
        if (uid.isEmpty || uid == me) return; // skip self
        list.add(DirUser(
          uid: uid,
          name: (v['name'] ?? 'User').toString(),
          phone: (v['phone'] ?? '').toString(),
          photo: (v['photoUrl'] ?? '').toString().isEmpty
              ? null
              : v['photoUrl'].toString(),
        ));
      });
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  // ---- Messages ----------------------------------------------------------
  Future<void> sendText(String peerUid, String text, {String type = 'text'}) async {
    if (text.trim().isEmpty) return;
    await _postMessage(peerUid, text: text.trim(), type: type, preview: text.trim());
  }

  /// Pick→send an image: upload to Storage, then post an `image` message whose
  /// `text` is the download URL. Mirrors the Android media-message flow.
  Future<void> sendImage(String peerUid, File file) async {
    final url = await _uploadMedia(peerUid, file, 'jpg');
    await _postMessage(peerUid,
        text: url, type: 'image', preview: '📷 Photo');
  }

  /// Record→send a voice note: upload the audio, post a `voice` message with the
  /// URL and its duration (ms) so the bubble can show a player.
  Future<void> sendVoice(String peerUid, File file, int durationMs) async {
    final url = await _uploadMedia(peerUid, file, 'm4a');
    await _postMessage(peerUid,
        text: url,
        type: 'voice',
        preview: '🎤 Voice message',
        extra: {'duration': durationMs});
  }

  Future<String> _uploadMedia(String peerUid, File file, String ext) async {
    final chatId = chatIdWith(peerUid);
    final id = '${DateTime.now().microsecondsSinceEpoch}';
    final ref = FirebaseStorage.instance.ref('chatMedia/$chatId/$id.$ext');
    final task = await ref.putFile(file);
    return task.ref.getDownloadURL();
  }

  /// Write a message + update both users' chat index. [preview] is the short
  /// text shown in the chat list (e.g. "📷 Photo").
  Future<void> _postMessage(
    String peerUid, {
    required String text,
    required String type,
    required String preview,
    Map<String, Object?> extra = const {},
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final chatId = chatIdWith(peerUid);
    final ref = _convRef(chatId).child('messages').push();
    await ref.set({
      'from': uid,
      'to': peerUid,
      'text': text,
      'type': type,
      'ts': ServerValue.timestamp,
      'status': MsgStat.sent,
      ...extra,
    });

    // Update both users' chat index.
    final now = DateTime.now().millisecondsSinceEpoch;
    await _indexRef(uid).child(peerUid).update({
      'lastText': preview,
      'lastTs': now,
      'lastFromMe': true,
      'unread': 0,
    });
    final peerIndex = _indexRef(peerUid).child(uid);
    await peerIndex.update({
      'lastText': preview,
      'lastTs': now,
      'lastFromMe': false,
    });
    await peerIndex.child('unread').runTransaction((current) {
      final c = (current is int) ? current : 0;
      return Transaction.success(c + 1);
    });
  }

  /// Live messages for a conversation, ordered oldest→newest.
  Stream<List<LiveMessage>> messages(String peerUid) {
    final chatId = chatIdWith(peerUid);
    final ref = _convRef(chatId).child('messages');
    // Keep this conversation warm on disk so reopening it is instant.
    try {
      ref.keepSynced(true);
    } catch (_) {}
    return ref.orderByChild('ts').onValue.map((event) {
      final out = <LiveMessage>[];
      final val = event.snapshot.value;
      if (val is Map) {
        val.forEach((k, v) {
          if (v is Map) out.add(LiveMessage.fromMap(k.toString(), v));
        });
        out.sort((a, b) => a.ts.compareTo(b.ts));
      }
      _messagesCache[chatId] = out; // for instant initialData next open
      return out;
    }).handleError((Object e) => _log('messages stream closed: $e'));
  }

  /// Marks incoming messages delivered, and (if [read]) read; resets unread.
  Future<void> markIncoming(String peerUid, {required bool read}) async {
    final uid = _uid;
    if (uid == null) return;
    final chatId = chatIdWith(peerUid);
    final ref = _convRef(chatId).child('messages');
    final snap = await ref.get();
    if (snap.value is Map) {
      final updates = <String, Object?>{};
      (snap.value as Map).forEach((k, v) {
        if (v is Map && v['to'] == uid) {
          final st = (v['status'] is int) ? v['status'] as int : MsgStat.sent;
          final target = read ? MsgStat.read : MsgStat.delivered;
          if (st < target) updates['$k/status'] = target;
        }
      });
      if (updates.isNotEmpty) await ref.update(updates);
    }
    if (read) {
      await _indexRef(uid).child(peerUid).child('unread').set(0);
    }
  }

  // ---- Typing ------------------------------------------------------------
  Future<void> setTyping(String peerUid, bool typing) async {
    final uid = _uid;
    if (uid == null) return;
    await _convRef(chatIdWith(peerUid)).child('typing').child(uid).set(typing);
  }

  Stream<bool> peerTyping(String peerUid) {
    return _convRef(chatIdWith(peerUid))
        .child('typing')
        .child(peerUid)
        .onValue
        .map((e) => e.snapshot.value == true)
        .handleError((Object e) => _log('typing stream closed: $e'));
  }

  // ---- Presence ----------------------------------------------------------
  Stream<Presence> presenceOf(String peerUid) {
    return _root.child('presence').child(peerUid).onValue.map((e) {
      final v = e.snapshot.value;
      if (v is Map) {
        return Presence(v['online'] == true, (v['lastSeen'] is int) ? v['lastSeen'] as int : 0);
      }
      return Presence(false, 0);
    }).handleError((Object e) => _log('presence stream closed: $e'));
  }

  // ---- Chats list --------------------------------------------------------
  /// Resets local session state and marks the user offline. Call before signing
  /// out so live listeners stop and presence is updated while we still have a
  /// valid auth token.
  Future<void> stop() async {
    try {
      await setOnline(false);
    } catch (_) {}
    _ready = false;
    _uid = null;
  }

  Stream<List<ChatSummary>> chatsList() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _indexRef(uid).onValue.asyncMap((event) async {
      final val = event.snapshot.value;
      final summaries = <ChatSummary>[];
      if (val is Map) {
        for (final entry in val.entries) {
          final peerUid = entry.key.toString();
          final m = entry.value;
          if (m is! Map) continue;
          final user = await getUser(peerUid);
          summaries.add(ChatSummary(
            peerUid: peerUid,
            peerName: user?.name ?? 'User',
            peerPhoto: user?.photo,
            lastText: (m['lastText'] ?? '').toString(),
            lastTs: (m['lastTs'] is int) ? m['lastTs'] as int : 0,
            lastFromMe: m['lastFromMe'] == true,
            unread: (m['unread'] is int) ? m['unread'] as int : 0,
          ));
        }
        summaries.sort((a, b) => b.lastTs.compareTo(a.lastTs));
      }
      _chatsCache = summaries;
      return summaries;
    }).handleError((Object e) {
      // Swallow permission-denied that fires right after sign-out / account
      // deletion (the auth token is gone but the listener hasn't torn down yet).
      _log('chatsList stream closed: $e');
    });
  }
}
