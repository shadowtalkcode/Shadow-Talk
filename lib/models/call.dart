/// Call direction / outcome — mirrors Android `FireCallDirection`.
enum CallDirection { outgoing, answered, missed, incoming }

/// Live phase of an in-flight call.
enum CallPhase { dialing, incoming, connecting, connected, ended, failed }

/// A persisted entry in the call history (Calls tab). Mirrors the relevant
/// fields of Android's `FireCall` Realm model, stored locally per-user.
class CallRecord {
  final String id; // callId
  final String peerUid;
  final String peerName;
  final String? peerPhoto;
  final bool isVideo;
  final CallDirection direction;
  final int ts; // millisecondsSinceEpoch
  final int durationSecs;

  const CallRecord({
    required this.id,
    required this.peerUid,
    required this.peerName,
    required this.peerPhoto,
    required this.isVideo,
    required this.direction,
    required this.ts,
    required this.durationSecs,
  });

  DateTime get time => DateTime.fromMillisecondsSinceEpoch(ts);
  bool get isMissed => direction == CallDirection.missed;

  Map<String, dynamic> toJson() => {
        'id': id,
        'peerUid': peerUid,
        'peerName': peerName,
        'peerPhoto': peerPhoto,
        'isVideo': isVideo,
        'direction': direction.index,
        'ts': ts,
        'durationSecs': durationSecs,
      };

  factory CallRecord.fromJson(Map<String, dynamic> j) => CallRecord(
        id: (j['id'] ?? '').toString(),
        peerUid: (j['peerUid'] ?? '').toString(),
        peerName: (j['peerName'] ?? 'User').toString(),
        peerPhoto: (j['peerPhoto'] == null || '${j['peerPhoto']}'.isEmpty)
            ? null
            : j['peerPhoto'].toString(),
        isVideo: j['isVideo'] == true,
        direction: CallDirection
            .values[(j['direction'] is int) ? j['direction'] as int : 0],
        ts: (j['ts'] is int) ? j['ts'] as int : 0,
        durationSecs: (j['durationSecs'] is int) ? j['durationSecs'] as int : 0,
      );
}

/// An in-flight call (outgoing or incoming) with mutable live state.
class ActiveCall {
  final String callId;
  final String channel;
  final String peerUid;
  final String peerName;
  final String? peerPhoto;
  final bool isVideo;
  final bool isIncoming;

  CallPhase phase;
  int? remoteUid;
  int durationSecs;

  ActiveCall({
    required this.callId,
    required this.channel,
    required this.peerUid,
    required this.peerName,
    required this.peerPhoto,
    required this.isVideo,
    required this.isIncoming,
    this.phase = CallPhase.dialing,
    this.remoteUid,
    this.durationSecs = 0,
  });
}
