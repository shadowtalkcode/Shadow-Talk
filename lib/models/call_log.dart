import 'enums.dart';
import 'user.dart';

/// A call-history entry for the Calls tab (display only — no real calling).
class CallLog {
  final String id;
  final User user;
  final CallType type;
  final bool isVideo;
  final DateTime time;

  const CallLog({
    required this.id,
    required this.user,
    required this.type,
    required this.isVideo,
    required this.time,
  });
}
