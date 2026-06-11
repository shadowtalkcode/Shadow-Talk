import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';

import '../../models/call.dart';
import '../../services/call_service.dart';
import '../../theme/app_colors.dart';

/// Full-screen call UI (outgoing · incoming · in-call), voice & video — mirrors
/// the Android `CallingActivity`: full-bleed avatar/video background, the
/// "Shadow Talk Voice/Video Call" label, Android status strings, and a local
/// self-view (full-screen while ringing, PIP once connected). Reads the live
/// [CallService.activeCall] and closes itself when the call ends.
class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _svc = CallService.instance;
  bool _muted = false;
  bool _speaker = false;
  bool _videoOn = true;

  @override
  void initState() {
    super.initState();
    _svc.activeCall.addListener(_onCallChanged);
    final call = _svc.activeCall.value;
    _videoOn = call?.isVideo ?? true;
    _speaker = call?.isVideo ?? false; // video defaults to speaker
  }

  @override
  void dispose() {
    _svc.activeCall.removeListener(_onCallChanged);
    super.dispose();
  }

  void _onCallChanged() {
    if (!mounted) return;
    if (_svc.activeCall.value == null) {
      Navigator.of(context).maybePop();
    } else {
      setState(() {});
    }
  }

  String _fmt(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }

  // Android's "Shadow Talk Voice Call" / "Shadow Talk Video Call".
  String _callTypeLabel(ActiveCall call) =>
      call.isVideo ? 'Shadow Talk Video Call' : 'Shadow Talk Voice Call';

  // Android status strings (Initiating / Connecting / Waiting for answer / …).
  String _statusText(ActiveCall call) {
    switch (call.phase) {
      case CallPhase.incoming:
        return call.isVideo ? 'Incoming video call' : 'Incoming voice call';
      case CallPhase.dialing:
        return 'Waiting for answer';
      case CallPhase.connecting:
        return 'Connecting';
      case CallPhase.connected:
        return _fmt(call.durationSecs);
      case CallPhase.ended:
        return 'Call ended';
      case CallPhase.failed:
        return 'Failed';
    }
  }

  @override
  Widget build(BuildContext context) {
    final call = _svc.activeCall.value;
    if (call == null) {
      return const Scaffold(backgroundColor: AppColors.background);
    }

    final engineReady = _svc.engine != null;
    final remoteUp = call.remoteUid != null && call.phase == CallPhase.connected;
    // Like Android: the remote video fills the screen once connected; until then
    // the callee's avatar fills it. The sender's own camera is always shown as a
    // small PIP in the top-right corner during a video call (both while ringing
    // and once connected).
    final showRemoteFull = call.isVideo && engineReady && remoteUp;
    final showLocalPip = call.isVideo && engineReady && _videoOn;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ---- Background ----
          if (showRemoteFull)
            _remoteVideo(call)
          else
            _photoOrGradient(call),

          if (showRemoteFull)
            Container(color: Colors.black.withValues(alpha: 0.18)),

          // Avatar + name until the remote video arrives.
          if (!showRemoteFull) _avatarLayer(call),

          // ---- Local self-view PIP (sender's own camera), top-right ----
          if (showLocalPip)
            Positioned(
              top: MediaQuery.of(context).padding.top + 56,
              right: 12,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 110,
                  height: 160,
                  color: Colors.black54,
                  child: _localVideo(),
                ),
              ),
            ),

          // ---- Top info (logo + call type + name + status) ----
          SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    const BackButton(color: Colors.white),
                    const Spacer(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(call.isVideo ? Icons.videocam : Icons.lock,
                            size: 14, color: Colors.white70),
                        const SizedBox(width: 6),
                        const Text('End-to-end encrypted',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
                // When the remote video fills the background, show name/status
                // as an overlay near the top (matches Android's top info bar).
                if (showRemoteFull) ...[
                  const SizedBox(height: 6),
                  Text(_callTypeLabel(call),
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(call.peerName,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(_statusText(call),
                      style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ],
                const Spacer(),
                _controls(call),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoOrGradient(ActiveCall call) {
    final p = call.peerPhoto;
    if (p != null && p.isNotEmpty) {
      final img = p.startsWith('http') ? NetworkImage(p) : AssetImage(p) as ImageProvider;
      return Image(
        image: img,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) =>
            Container(decoration: const BoxDecoration(gradient: AppColors.bgGradient)),
      );
    }
    return Container(decoration: const BoxDecoration(gradient: AppColors.bgGradient));
  }

  Widget _remoteVideo(ActiveCall call) {
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: _svc.engine!,
        canvas: VideoCanvas(uid: call.remoteUid),
        connection: RtcConnection(channelId: call.channel),
      ),
    );
  }

  Widget _localVideo() {
    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: _svc.engine!,
        canvas: const VideoCanvas(uid: 0),
      ),
    );
  }

  Widget _avatarLayer(ActiveCall call) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _BigAvatar(name: call.peerName, photo: call.peerPhoto),
          const SizedBox(height: 28),
          Text(call.peerName,
              style: const TextStyle(
                  color: AppColors.white, fontSize: 26, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(_callTypeLabel(call),
              style: const TextStyle(color: AppColors.textDesc, fontSize: 14)),
          const SizedBox(height: 6),
          Text(_statusText(call),
              style: const TextStyle(color: AppColors.textDesc, fontSize: 17)),
        ],
      ),
    );
  }

  // ---- Control bars ------------------------------------------------------
  Widget _controls(ActiveCall call) {
    if (call.phase == CallPhase.incoming) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _RoundBtn(
              icon: Icons.call_end,
              bg: AppColors.red,
              size: 70,
              label: 'Decline',
              onTap: () => _svc.endCall(),
            ),
            _RoundBtn(
              icon: Icons.call,
              bg: AppColors.green,
              size: 70,
              label: 'Accept',
              onTap: () => _svc.acceptIncoming(),
            ),
          ],
        ),
      );
    }

    // Outgoing / connecting / connected controls.
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _RoundBtn(
            icon: _muted ? Icons.mic_off : Icons.mic,
            bg: _muted ? AppColors.primary : Colors.white24,
            size: 56,
            onTap: () {
              setState(() => _muted = !_muted);
              _svc.setMuted(_muted);
            },
          ),
          if (call.isVideo)
            _RoundBtn(
              icon: Icons.cameraswitch,
              bg: Colors.white24,
              size: 56,
              onTap: () => _svc.switchCamera(),
            )
          else
            _RoundBtn(
              icon: _speaker ? Icons.volume_up : Icons.volume_down,
              bg: _speaker ? AppColors.primary : Colors.white24,
              size: 56,
              onTap: () {
                setState(() => _speaker = !_speaker);
                _svc.setSpeaker(_speaker);
              },
            ),
          if (call.isVideo)
            _RoundBtn(
              icon: _videoOn ? Icons.videocam : Icons.videocam_off,
              bg: _videoOn ? Colors.white24 : AppColors.primary,
              size: 56,
              onTap: () {
                setState(() => _videoOn = !_videoOn);
                _svc.setVideoEnabled(_videoOn);
              },
            ),
          _RoundBtn(
            icon: Icons.call_end,
            bg: AppColors.red,
            size: 64,
            onTap: () => _svc.endCall(),
          ),
        ],
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final double size;
  final String? label;
  final VoidCallback onTap;

  const _RoundBtn({
    required this.icon,
    required this.bg,
    required this.size,
    required this.onTap,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: size * 0.42),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 8),
          Text(label!, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ],
    );
  }
}

/// Large circular avatar with photo (asset or network) or coloured initials.
class _BigAvatar extends StatelessWidget {
  final String name;
  final String? photo;
  const _BigAvatar({required this.name, this.photo});

  static const _palette = [
    Color(0xFF7E58FC),
    Color(0xFF28A745),
    Color(0xFFE9844A),
    Color(0xFF4A90E2),
    Color(0xFFD64A7A),
    Color(0xFF11998E),
  ];

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    const size = 200.0;
    ImageProvider? img;
    final p = photo;
    if (p != null && p.isNotEmpty) {
      img = p.startsWith('http') ? NetworkImage(p) : AssetImage(p) as ImageProvider;
    }
    final bg = _palette[name.codeUnits.fold(0, (a, b) => a + b) % _palette.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        image: img != null ? DecorationImage(image: img, fit: BoxFit.cover) : null,
      ),
      alignment: Alignment.center,
      child: img == null
          ? Text(_initials,
              style: const TextStyle(
                  color: Colors.white, fontSize: 72, fontWeight: FontWeight.w600))
          : null,
    );
  }
}
