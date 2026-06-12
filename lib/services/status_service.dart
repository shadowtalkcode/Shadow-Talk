import 'dart:io';

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'chat_service.dart';
import 'profile_store.dart';

void _log(String m) => debugPrint('📸 STATUS: $m');

/// Status types (mirror Android StatusType).
class StatusType {
  static const int image = 1;
  static const int video = 2;
  static const int text = 3;
}

/// Statuses expire after 24h (like Android).
const int kStatusTtlMs = 24 * 60 * 60 * 1000;

/// A single status item.
class StatusItem {
  final String id;
  final String ownerUid;
  final int type;
  final int ts;
  final String content; // image URL (image/video)
  final String text; // text status
  final int backgroundColor; // ARGB int for text status
  bool seen;

  StatusItem({
    required this.id,
    required this.ownerUid,
    required this.type,
    required this.ts,
    this.content = '',
    this.text = '',
    this.backgroundColor = 0xFF7E58FC,
    this.seen = false,
  });

  bool get isText => type == StatusType.text;

  factory StatusItem.fromMap(String id, String ownerUid, Map m) => StatusItem(
        id: id,
        ownerUid: ownerUid,
        type: (m['type'] is int) ? m['type'] as int : StatusType.image,
        ts: (m['timestamp'] is int) ? m['timestamp'] as int : 0,
        content: (m['content'] ?? '').toString(),
        text: (m['text'] ?? '').toString(),
        backgroundColor: (m['backgroundColor'] is int)
            ? m['backgroundColor'] as int
            : 0xFF7E58FC,
      );
}

/// A user's grouped statuses (one ring in the tales strip).
class UserTale {
  final String uid;
  final String name;
  final String? photo;
  final List<StatusItem> items;
  final bool isMine;

  UserTale({
    required this.uid,
    required this.name,
    required this.photo,
    required this.items,
    required this.isMine,
  });

  bool get allSeen => items.isNotEmpty && items.every((s) => s.seen);
  int get latestTs => items.isEmpty ? 0 : items.map((s) => s.ts).reduce((a, b) => a > b ? a : b);
}

/// Someone who viewed my status.
class StatusViewer {
  final String uid;
  final String name;
  final String? photo;
  final int seenAt;
  StatusViewer(this.uid, this.name, this.photo, this.seenAt);
}

/// Status (stories/tales) backend over Firebase Realtime Database + Storage,
/// mirroring the Android app's schema so it interoperates with it:
///
/// ```
///   status/{uid}/{statusId}      : { statusId, userId, type, content, timestamp, duration }
///   textStatus/{uid}/{statusId}  : { statusId, userId, type:3, text, fontName, backgroundColor, timestamp }
///   statusSeenUids/{owner}/{statusId}/{viewer} : { uid, seenAt }
/// ```
class StatusService {
  StatusService._();
  static final StatusService instance = StatusService._();

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  DatabaseReference get _root => _db.ref();
  String? get _uid => ChatService.instance.uid ?? AuthService.instance.uid;

  int _newId() => DateTime.now().microsecondsSinceEpoch;

  // ---- Posting -----------------------------------------------------------
  Future<void> postTextStatus(String text, int backgroundColor) async {
    final uid = _uid;
    if (uid == null || text.trim().isEmpty) return;
    final id = 's_${_newId()}';
    await _root.child('textStatus').child(uid).child(id).set({
      'statusId': id,
      'userId': uid,
      'type': StatusType.text,
      'text': text.trim(),
      'fontName': '',
      'backgroundColor': backgroundColor,
      'timestamp': ServerValue.timestamp,
      'duration': 0,
    });
    _log('posted text status $id');
  }

  Future<void> postImageStatus(File file) async {
    final uid = _uid;
    if (uid == null) return;
    final id = 's_${_newId()}';
    final ref = FirebaseStorage.instance.ref('status/$uid/$id.jpg');
    final task = await ref.putFile(file);
    final url = await task.ref.getDownloadURL();
    await _root.child('status').child(uid).child(id).set({
      'statusId': id,
      'userId': uid,
      'type': StatusType.image,
      'content': url,
      'timestamp': ServerValue.timestamp,
      'duration': 0,
    });
    _log('posted image status $id');
  }

  Future<void> deleteStatus(StatusItem item) async {
    final uid = _uid;
    if (uid == null) return;
    final path = item.isText ? 'textStatus' : 'status';
    await _root.child(path).child(uid).child(item.id).remove();
  }

  // ---- Loading -----------------------------------------------------------
  /// Loads a single user's active (<24h) statuses, with my seen-state filled in.
  Future<List<StatusItem>> statusesOf(String ownerUid) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final me = _uid;
    final items = <StatusItem>[];
    for (final path in ['status', 'textStatus']) {
      final snap = await _root.child(path).child(ownerUid).get();
      if (snap.value is Map) {
        (snap.value as Map).forEach((k, v) {
          if (v is Map) {
            final item = StatusItem.fromMap(k.toString(), ownerUid, v);
            // Match Android: a status is active only while it's < 24h old
            // (timestamp within the last 24h). Anything older — or missing a
            // timestamp — has expired and is hidden.
            final expired = item.ts == 0 || now - item.ts >= kStatusTtlMs;
            if (!expired) {
              items.add(item);
            } else if (ownerUid == me) {
              // Proactively remove my own expired statuses so they truly
              // disappear from the backend (not just hidden on read).
              _root.child(path).child(ownerUid).child(item.id).remove();
            }
          }
        });
      }
    }
    // Seen-state for friends' statuses.
    if (me != null && ownerUid != me) {
      for (final item in items) {
        final s = await _root
            .child('statusSeenUids')
            .child(ownerUid)
            .child(item.id)
            .child(me)
            .get();
        item.seen = s.exists;
      }
    }
    items.sort((a, b) => a.ts.compareTo(b.ts));
    return items;
  }

  /// My own active statuses (live).
  Stream<List<StatusItem>> myStatuses() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    final now = DateTime.now().millisecondsSinceEpoch;
    return _root.child('textStatus').child(uid).onValue.asyncMap((_) async {
      final items = <StatusItem>[];
      for (final path in ['status', 'textStatus']) {
        final snap = await _root.child(path).child(uid).get();
        if (snap.value is Map) {
          (snap.value as Map).forEach((k, v) {
            if (v is Map) {
              final item = StatusItem.fromMap(k.toString(), uid, v);
              if (item.ts != 0 && now - item.ts < kStatusTtlMs) items.add(item);
            }
          });
        }
      }
      items.sort((a, b) => a.ts.compareTo(b.ts));
      return items;
    });
  }

  /// The tales strip: my tale (always) + chat partners with active statuses.
  Future<List<UserTale>> loadTales() async {
    final me = _uid;
    if (me == null) return [];
    final tales = <UserTale>[];

    // My tale.
    final mine = await statusesOf(me);
    tales.add(UserTale(
      uid: me,
      name: 'My tale',
      photo: ProfileStore.instance.photoPath,
      items: mine,
      isMine: true,
    ));

    // Chat partners' tales.
    final partners = await _chatPartners();
    for (final p in partners) {
      final items = await statusesOf(p);
      if (items.isEmpty) continue;
      final user = await ChatService.instance.getUser(p);
      tales.add(UserTale(
        uid: p,
        name: user?.name ?? 'User',
        photo: user?.photo,
        items: items,
        isMine: false,
      ));
    }
    // Friends with unseen statuses first.
    final friends = tales.where((t) => !t.isMine).toList()
      ..sort((a, b) {
        if (a.allSeen != b.allSeen) return a.allSeen ? 1 : -1;
        return b.latestTs.compareTo(a.latestTs);
      });
    return [tales.first, ...friends];
  }

  Future<List<String>> _chatPartners() async {
    final me = _uid;
    if (me == null) return [];
    try {
      // The per-user chat index lives under the open `messages/` subtree (the
      // security rules deny top-level `userChats`). Mirrors ChatService.
      final snap = await _root.child('messages').child('index').child(me).get();
      if (snap.value is Map) {
        return (snap.value as Map).keys.map((k) => k.toString()).toList();
      }
    } catch (_) {}
    return [];
  }

  // ---- Seen tracking -----------------------------------------------------
  Future<void> markSeen(String ownerUid, String statusId) async {
    final me = _uid;
    if (me == null || ownerUid == me) return;
    await _root
        .child('statusSeenUids')
        .child(ownerUid)
        .child(statusId)
        .child(me)
        .set({'uid': me, 'seenAt': ServerValue.timestamp});
  }

  /// Who viewed one of my statuses.
  Future<List<StatusViewer>> seenBy(String statusId) async {
    final me = _uid;
    if (me == null) return [];
    final snap =
        await _root.child('statusSeenUids').child(me).child(statusId).get();
    final viewers = <StatusViewer>[];
    if (snap.value is Map) {
      for (final entry in (snap.value as Map).entries) {
        final uid = entry.key.toString();
        final m = entry.value;
        final seenAt = (m is Map && m['seenAt'] is int) ? m['seenAt'] as int : 0;
        final user = await ChatService.instance.getUser(uid);
        viewers.add(StatusViewer(uid, user?.name ?? 'User', user?.photo, seenAt));
      }
      viewers.sort((a, b) => b.seenAt.compareTo(a.seenAt));
    }
    return viewers;
  }
}
