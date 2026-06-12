import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the Notifications settings, mirroring the Android
/// `pref_notification.xml`:
///   - New message notifications (master switch)  → default **true**
///   - Ringtone (child of the master switch)       → default "Default"
///   - Vibrate (child of the master switch)        → default **false**
///
/// Backed by shared_preferences so every choice is saved and restored across
/// launches (same singleton pattern as [ProfileStore]).
class NotificationSettings extends ChangeNotifier {
  NotificationSettings._();
  static final NotificationSettings instance = NotificationSettings._();

  SharedPreferences? _prefs;

  static const _kNewMessage = 'notif_new_message';
  static const _kVibrate = 'notif_vibrate';
  static const _kRingtone = 'notif_ringtone';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  bool get newMessage => _prefs?.getBool(_kNewMessage) ?? true;
  bool get vibrate => _prefs?.getBool(_kVibrate) ?? false;
  String get ringtone => _prefs?.getString(_kRingtone) ?? 'Default';

  Future<void> setNewMessage(bool v) async {
    await _prefs?.setBool(_kNewMessage, v);
    notifyListeners();
  }

  Future<void> setVibrate(bool v) async {
    await _prefs?.setBool(_kVibrate, v);
    notifyListeners();
  }

  Future<void> setRingtone(String v) async {
    await _prefs?.setString(_kRingtone, v);
    notifyListeners();
  }
}
