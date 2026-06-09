import 'user.dart';

/// A status / story entry for the Status tab (display only).
class StatusUpdate {
  final String id;
  final User user;
  final DateTime time;
  final bool seen;
  final bool isText;
  final String? text;
  final String? imageAsset;

  const StatusUpdate({
    required this.id,
    required this.user,
    required this.time,
    this.seen = false,
    this.isText = false,
    this.text,
    this.imageAsset,
  });
}
