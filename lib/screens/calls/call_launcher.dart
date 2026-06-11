import 'package:flutter/material.dart';

import '../../services/call_service.dart';
import 'call_screen.dart';

/// Starts an outgoing call and opens the full-screen call UI. Shared by every
/// call entry point (chat app bar, contact details, calls tab, new-call picker).
Future<void> startCall(
  BuildContext context, {
  required String peerUid,
  required String peerName,
  String? peerPhoto,
  required bool isVideo,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final ok = await CallService.instance.placeCall(
    peerUid: peerUid,
    peerName: peerName,
    peerPhoto: peerPhoto,
    isVideo: isVideo,
  );
  if (!ok) {
    messenger.showSnackBar(const SnackBar(
      content: Text('Could not start the call — check microphone/camera permission.'),
    ));
    return;
  }
  navigator.push(MaterialPageRoute(builder: (_) => const CallScreen()));
}
