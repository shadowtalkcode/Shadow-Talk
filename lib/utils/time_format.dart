/// Lightweight date/time formatting (no intl dependency).
class TimeFormat {
  TimeFormat._();

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  /// "13.06" — 24-hour with a period separator, as used in the XD chat design.
  static String clock24(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h.$m';
  }

  /// "12:20 AM"
  static String clock(DateTime t) {
    final h24 = t.hour;
    final ampm = h24 < 12 ? 'AM' : 'PM';
    var h = h24 % 12;
    if (h == 0) h = 12;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m $ampm';
  }

  /// Relative label used in the chat list / calls / status time column.
  static String shortStamp(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(t.year, t.month, t.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return clock(t);
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return _weekdays[t.weekday - 1];
    return '${t.day}/${t.month}/${t.year % 100}';
  }

  /// Date-separator label inside a chat ("TODAY", "YESTERDAY", "12 June 2026").
  static String daySeparator(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(t.year, t.month, t.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'YESTERDAY';
    return '${t.day} ${_months[t.month - 1]} ${t.year}';
  }

  static String dayKey(DateTime t) => '${t.year}-${t.month}-${t.day}';
}
