import 'dart:async';

import 'package:flutter/material.dart';

import '../../main.dart';
import '../../models/call.dart';
import '../../services/call_service.dart';
import 'call_screen.dart';

/// Wraps the whole app (via MaterialApp.builder) and presents the full-screen
/// [CallScreen] whenever an incoming call arrives — the foreground equivalent
/// of Android's incoming-call notification.
class IncomingCallHost extends StatefulWidget {
  final Widget child;
  const IncomingCallHost({super.key, required this.child});

  @override
  State<IncomingCallHost> createState() => _IncomingCallHostState();
}

class _IncomingCallHostState extends State<IncomingCallHost> {
  StreamSubscription<ActiveCall>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = CallService.instance.incomingCalls.listen((_) {
      final nav = rootNavigatorKey.currentState;
      if (nav == null) return;
      nav.push(MaterialPageRoute(builder: (_) => const CallScreen()));
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
