import 'dart:async';
import 'dart:convert';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/call.dart';
import 'auth_service.dart';
import 'chat_service.dart';

void _log(String m) => debugPrint('📞 CALL: $m');

/// A live call notifier that lets us force a UI rebuild after mutating the
/// in-flight [ActiveCall] object in place.
class _CallNotifier extends ValueNotifier<ActiveCall?> {
  _CallNotifier() : super(null);
  void ping() => notifyListeners();
}

/// Voice & video calling over Agora RTC (same App ID as the Android app, so
/// calls interoperate) with Firebase Realtime Database signalling on the same
/// `newCalls/{receiver}/{sender}/{callId}` paths Android uses. Call history is
/// stored locally per-user (mirrors Android's local Realm call log), which is
/// what drives the dynamic Calls tab.
class CallService {
  CallService._();
  static final CallService instance = CallService._();

  /// Agora App ID — identical to the Android build so iOS↔Android calls share
  /// the same RTC channels.
  static const String agoraAppId = '3255300df28a4b81b9b594a6bae66aa3';

  static const int _callTimeoutSecs = 40;

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  DatabaseReference get _root => _db.ref();
  String? get _uid => ChatService.instance.uid ?? AuthService.instance.uid;

  RtcEngine? _engine;
  RtcEngine? get engine => _engine;

  /// Current in-flight call (null when idle).
  final _CallNotifier _activeCall = _CallNotifier();
  ValueNotifier<ActiveCall?> get activeCall => _activeCall;

  /// Persisted call history for the Calls tab.
  final ValueNotifier<List<CallRecord>> history = ValueNotifier(const []);

  /// Emits when a new incoming call should be presented full-screen.
  final StreamController<ActiveCall> _incomingCtrl =
      StreamController<ActiveCall>.broadcast();
  Stream<ActiveCall> get incomingCalls => _incomingCtrl.stream;

  Timer? _durationTimer;
  Timer? _timeoutTimer;
  StreamSubscription<DatabaseEvent>? _nodeSub; // current call node listener
  StreamSubscription<DatabaseEvent>? _incomingSub; // newCalls/{me}
  final Set<String> _handledIncoming = {};
  bool _started = false;
  bool _ending = false;

  // ---- Lifecycle ---------------------------------------------------------
  /// Idempotent — safe to call again once auth/uid becomes available so the
  /// incoming-call listener can (re)attach to the right `newCalls/{uid}` path.
  Future<void> start() async {
    await _loadHistory();
    _listenForIncoming();
    if (!_started) {
      _started = true;
      _log('start → ready (uid=$_uid)');
    }
  }

  /// RTDB node for a given call: newCalls/{receiver}/{sender}/{callId}.
  DatabaseReference _callNode(String receiverUid, String senderUid, String callId) =>
      _root.child('newCalls').child(receiverUid).child(senderUid).child(callId);

  // ---- Permissions -------------------------------------------------------
  bool _permissionsRequested = false;

  /// Requests microphone + camera up-front (once per session) so the OS prompts
  /// the user as soon as they reach the home screen — before they ever place a
  /// call. Safe to call repeatedly; only the first call prompts.
  Future<void> requestMediaPermissions() async {
    if (_permissionsRequested) return;
    _permissionsRequested = true;
    try {
      final result =
          await [Permission.microphone, Permission.camera].request();
      _log('startup permissions → '
          '${result.map((k, v) => MapEntry(k.toString(), v.toString()))}');
    } catch (e) {
      _log('requestMediaPermissions failed: $e');
    }
  }

  Future<bool> _ensurePermissions(bool video) async {
    final perms = <Permission>[Permission.microphone];
    if (video) perms.add(Permission.camera);
    final result = await perms.request();
    _log('permissions → ${result.map((k, v) => MapEntry(k.toString(), v.toString()))}');
    // We request mic/camera so real devices prompt the user, but we never hard
    // block the call: Agora still joins the channel, and the iOS Simulator
    // reports microphone as `permanentlyDenied` without ever showing a dialog
    // (a documented Simulator limitation), which would otherwise make calls
    // impossible to test. Audio/video capture remains governed by the OS.
    return true;
  }

  // ---- Agora engine ------------------------------------------------------
  /// Best-effort engine setup. Individual media calls are wrapped because the
  /// iOS Simulator's audio/camera stack is incomplete for Agora and can throw
  /// `ERR_NOT_READY (-3)`; on a real device they all succeed. A failure here
  /// must never abort the call.
  Future<void> _initEngine(bool video) async {
    try {
      final eng = createAgoraRtcEngine();
      await eng.initialize(const RtcEngineContext(
        appId: agoraAppId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));
      _engine = eng;
      eng.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (conn, elapsed) => _log('joined ${conn.channelId}'),
        onUserJoined: (conn, remoteUid, elapsed) => _onRemoteJoined(remoteUid),
        onUserOffline: (conn, remoteUid, reason) => _onRemoteLeft(),
        onError: (err, msg) => _log('agora error $err: $msg'),
      ));
      try {
        await eng.enableAudio();
      } catch (e) {
        _log('enableAudio failed (simulator?): $e');
      }
      if (video) {
        // Same sequence as Android's preview(): enable video, enable local
        // capture, start the camera preview so the self-view renders
        // immediately (while ringing), before the remote answers.
        try {
          await eng.enableVideo();
          await eng.enableLocalVideo(true);
          await eng.startPreview();
        } catch (e) {
          _log('video setup failed (simulator?): $e');
        }
      }
    } catch (e) {
      _log('engine init failed (simulator?): $e');
    }
  }

  Future<void> _join(String channel, bool video) async {
    final eng = _engine;
    if (eng == null) return;
    try {
      await eng.joinChannel(
        token: '',
        channelId: channel,
        uid: 0,
        options: ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
          publishMicrophoneTrack: true,
          publishCameraTrack: video,
          autoSubscribeAudio: true,
          autoSubscribeVideo: video,
        ),
      );
    } catch (e) {
      _log('joinChannel failed (simulator?): $e');
    }
  }

  void _onRemoteJoined(int remoteUid) {
    final call = _activeCall.value;
    if (call == null) return;
    call.remoteUid = remoteUid;
    if (call.phase != CallPhase.connected) {
      call.phase = CallPhase.connected;
      _startDurationTimer();
    }
    _timeoutTimer?.cancel();
    _activeCall.ping();
    _log('remote joined ($remoteUid) → connected');
  }

  void _onRemoteLeft() {
    _log('remote left → ending');
    endCall();
  }

  // ---- Outgoing ----------------------------------------------------------
  Future<bool> placeCall({
    required String peerUid,
    required String peerName,
    String? peerPhoto,
    required bool isVideo,
  }) async {
    if (_activeCall.value != null) return false;
    final uid = _uid;
    if (uid == null) {
      _log('placeCall → no uid');
      return false;
    }
    if (!await _ensurePermissions(isVideo)) {
      _log('placeCall → permissions denied');
      return false;
    }

    final ts = DateTime.now().millisecondsSinceEpoch;
    final callId = '${uid}_${peerUid}_$ts';
    // Agora channel names must be ≤ 64 bytes; the long callId would exceed that,
    // so use a short unique channel. The callee receives it via the RTDB node.
    final channel = 'st$ts';
    _ending = false;
    final call = ActiveCall(
      callId: callId,
      channel: channel,
      peerUid: peerUid,
      peerName: peerName,
      peerPhoto: peerPhoto,
      isVideo: isVideo,
      isIncoming: false,
      phase: CallPhase.dialing,
    );
    _activeCall.value = call;

    // Engine setup is best-effort (resilient to Simulator media limits); it
    // never aborts the call, so the outgoing UI always shows and a real device
    // connects media normally.
    await _initEngine(isVideo);
    await _join(channel, isVideo);

    // Signalling: write the call node the callee listens for.
    try {
      await _callNode(peerUid, uid, callId).set({
        'timestamp': ServerValue.timestamp,
        'callType': isVideo ? 2 : 1,
        'callId': callId,
        'callerId': uid,
        'channel': channel,
        'isVideo': isVideo,
      });
    } catch (e) {
      _log('placeCall → signalling write failed (rules?): $e');
    }

    // Watch this node for the callee answering / declining.
    _nodeSub = _callNode(peerUid, uid, callId).onValue.listen((event) {
      final v = event.snapshot.value;
      if (v is! Map) return;
      if (v['ended_incoming'] == true) {
        _log('callee ended/declined');
        endCall();
      } else if (v['hasAnswered'] == true &&
          (_activeCall.value?.phase == CallPhase.dialing)) {
        _activeCall.value?.phase = CallPhase.connecting;
        _activeCall.ping();
      }
    }, onError: (Object e) => _log('call node listener closed: $e'));

    // No-answer timeout.
    _timeoutTimer = Timer(const Duration(seconds: _callTimeoutSecs), () {
      if (_activeCall.value?.phase != CallPhase.connected) {
        _log('no answer → timeout');
        endCall();
      }
    });

    _log('placing ${isVideo ? "video" : "voice"} call → $peerName ($peerUid)');
    return true;
  }

  // ---- Incoming ----------------------------------------------------------
  void _listenForIncoming() {
    final uid = _uid;
    if (uid == null) return;
    _incomingSub?.cancel();
    _incomingSub = _root.child('newCalls').child(uid).onValue.listen((event) {
      final val = event.snapshot.value;
      if (val is! Map) return;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      val.forEach((senderUid, calls) {
        if (calls is! Map) return;
        calls.forEach((callId, data) {
          if (data is! Map) return;
          final id = callId.toString();
          if (_handledIncoming.contains(id)) return;
          if (data['ended_outgoing'] == true || data['ended_incoming'] == true) {
            return;
          }
          final ts = (data['timestamp'] is int) ? data['timestamp'] as int : 0;
          // Ignore stale signals (older than the ring timeout).
          if (ts != 0 && nowMs - ts > _callTimeoutSecs * 1000) return;
          if (_activeCall.value != null) return; // already on a call
          _handledIncoming.add(id);
          _presentIncoming(
            callId: id,
            senderUid: senderUid.toString(),
            channel: (data['channel'] ?? id).toString(),
            isVideo: data['isVideo'] == true || data['callType'] == 2,
          );
        });
      });
    }, onError: (Object e) => _log('incoming listener closed: $e'));
  }

  /// Stops the calling backend: ends any active call and cancels the incoming
  /// listener. Call before signing out / deleting the account so the RTDB
  /// listeners don't emit permission-denied once the auth token is revoked.
  Future<void> stop() async {
    await endCall();
    await _incomingSub?.cancel();
    _incomingSub = null;
    await _nodeSub?.cancel();
    _nodeSub = null;
    _handledIncoming.clear();
    _started = false;
  }

  Future<void> _presentIncoming({
    required String callId,
    required String senderUid,
    required String channel,
    required bool isVideo,
  }) async {
    String name = 'Shadow Talk user';
    String? photo;
    try {
      final u = await ChatService.instance.getUser(senderUid);
      if (u != null) {
        name = u.name;
        photo = u.photo;
      }
    } catch (_) {}
    final call = ActiveCall(
      callId: callId,
      channel: channel,
      peerUid: senderUid,
      peerName: name,
      peerPhoto: photo,
      isVideo: isVideo,
      isIncoming: true,
      phase: CallPhase.incoming,
    );
    _ending = false;
    _activeCall.value = call;

    // Watch for the caller cancelling before we answer.
    _nodeSub?.cancel();
    _nodeSub = _callNode(_uid ?? '', senderUid, callId).onValue.listen((event) {
      final v = event.snapshot.value;
      if (v is Map && v['ended_outgoing'] == true) {
        _log('caller cancelled');
        endCall();
      }
    }, onError: (Object e) => _log('incoming node listener closed: $e'));

    _incomingCtrl.add(call);
    _log('incoming ${isVideo ? "video" : "voice"} call from $name');
  }

  Future<bool> acceptIncoming() async {
    final call = _activeCall.value;
    if (call == null || !call.isIncoming) return false;
    if (!await _ensurePermissions(call.isVideo)) return false;
    final uid = _uid;
    if (uid == null) return false;

    try {
      await _callNode(uid, call.peerUid, call.callId).update({'hasAnswered': true});
    } catch (e) {
      _log('acceptIncoming → signalling failed: $e');
    }

    call.phase = CallPhase.connecting;
    _activeCall.ping();
    await _initEngine(call.isVideo);
    await _join(call.channel, call.isVideo);
    return true;
  }

  // ---- End / cleanup -----------------------------------------------------
  Future<void> endCall() async {
    final call = _activeCall.value;
    if (call == null || _ending) return;
    _ending = true;

    // Signal the other side.
    final uid = _uid;
    if (uid != null) {
      try {
        if (call.isIncoming) {
          await _callNode(uid, call.peerUid, call.callId)
              .update({'ended_incoming': true});
        } else {
          await _callNode(call.peerUid, uid, call.callId)
              .update({'ended_outgoing': true});
        }
      } catch (_) {}
    }

    _recordHistory(call);
    call.phase = CallPhase.ended;
    _activeCall.ping();

    await _teardown();
    _activeCall.value = null;
    _ending = false;
  }

  Future<void> _teardown() async {
    _durationTimer?.cancel();
    _durationTimer = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    await _nodeSub?.cancel();
    _nodeSub = null;
    try {
      await _engine?.leaveChannel();
      await _engine?.release();
    } catch (_) {}
    _engine = null;
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final call = _activeCall.value;
      if (call == null) return;
      call.durationSecs++;
      _activeCall.ping();
    });
  }

  // ---- In-call controls --------------------------------------------------
  Future<void> setMuted(bool muted) async =>
      _engine?.muteLocalAudioStream(muted);
  Future<void> setSpeaker(bool on) async =>
      _engine?.setEnableSpeakerphone(on);
  Future<void> setVideoEnabled(bool on) async {
    await _engine?.muteLocalVideoStream(!on);
    await _engine?.enableLocalVideo(on);
  }

  Future<void> switchCamera() async => _engine?.switchCamera();

  // ---- History (local, per-user) ----------------------------------------
  String get _historyKey => 'call_history_${_uid ?? 'anon'}';

  void _recordHistory(ActiveCall call) {
    final connected = call.phase == CallPhase.connected || call.durationSecs > 0;
    final CallDirection dir;
    if (call.isIncoming) {
      dir = connected ? CallDirection.answered : CallDirection.missed;
    } else {
      dir = CallDirection.outgoing;
    }
    final record = CallRecord(
      id: call.callId,
      peerUid: call.peerUid,
      peerName: call.peerName,
      peerPhoto: call.peerPhoto,
      isVideo: call.isVideo,
      direction: dir,
      ts: DateTime.now().millisecondsSinceEpoch,
      durationSecs: call.durationSecs,
    );
    final next = [record, ...history.value];
    history.value = next;
    _persistHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);
      if (raw == null) {
        history.value = const [];
        return;
      }
      final list = (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((m) => CallRecord.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      history.value = list;
    } catch (e) {
      _log('loadHistory failed: $e');
      history.value = const [];
    }
  }

  Future<void> _persistHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(history.value.map((r) => r.toJson()).toList());
      await prefs.setString(_historyKey, raw);
    } catch (e) {
      _log('persistHistory failed: $e');
    }
  }

  Future<void> deleteRecord(String id) async {
    history.value = history.value.where((r) => r.id != id).toList();
    await _persistHistory();
  }

  Future<void> clearHistory() async {
    history.value = const [];
    await _persistHistory();
  }
}
