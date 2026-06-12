import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
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
  final String type; // 'text' | 'image' | ...
  final int ts;
  final int status;

  LiveMessage({
    required this.id,
    required this.from,
    required this.to,
    required this.text,
    required this.type,
    required this.ts,
    required this.status,
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

  String? get uid => _uid;
  bool get isReady => _ready;

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
      _ready = true;
      _log('start → ready as uid=$_uid');
    } catch (e) {
      _ready = false;
      _log('start → setup failed (rules?): $e');
    }
    return _uid;
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
      'photoUrl': p.photoPath ?? '',
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
    final snap = await _root.child('users').child(uid).get();
    if (!snap.exists || snap.value is! Map) return null;
    final m = snap.value as Map;
    return DirUser(
      uid: uid,
      name: (m['name'] ?? 'User').toString(),
      phone: (m['phone'] ?? '').toString(),
      photo: (m['photoUrl'] ?? '').toString().isEmpty ? null : m['photoUrl'].toString(),
    );
  }

  // ---- Messages ----------------------------------------------------------
  Future<void> sendText(String peerUid, String text, {String type = 'text'}) async {
    final uid = _uid;
    if (uid == null || text.trim().isEmpty) return;
    final chatId = chatIdWith(peerUid);
    final ref = _convRef(chatId).child('messages').push();
    final msg = {
      'from': uid,
      'to': peerUid,
      'text': text.trim(),
      'type': type,
      'ts': ServerValue.timestamp,
      'status': MsgStat.sent,
    };
    await ref.set(msg);

    // Update both users' chat index.
    final now = DateTime.now().millisecondsSinceEpoch;
    await _indexRef(uid).child(peerUid).update({
      'lastText': text.trim(),
      'lastTs': now,
      'lastFromMe': true,
      'unread': 0,
    });
    final peerIndex = _indexRef(peerUid).child(uid);
    await peerIndex.update({
      'lastText': text.trim(),
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
    return _convRef(chatId)
        .child('messages')
        .orderByChild('ts')
        .onValue
        .map((event) {
      final out = <LiveMessage>[];
      final val = event.snapshot.value;
      if (val is Map) {
        val.forEach((k, v) {
          if (v is Map) out.add(LiveMessage.fromMap(k.toString(), v));
        });
        out.sort((a, b) => a.ts.compareTo(b.ts));
      }
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
      return summaries;
    }).handleError((Object e) {
      // Swallow permission-denied that fires right after sign-out / account
      // deletion (the auth token is gone but the listener hasn't torn down yet).
      _log('chatsList stream closed: $e');
    });
  }
}
