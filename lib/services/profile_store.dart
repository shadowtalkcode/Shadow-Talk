import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's profile (entered during onboarding setup and editable
/// from Settings → Profile) using shared_preferences.
class ProfileStore extends ChangeNotifier {
  ProfileStore._();
  static final ProfileStore instance = ProfileStore._();

  SharedPreferences? _prefs;

  static const _kName = 'st_profile_name';
  static const _kAbout = 'st_profile_about';
  static const _kPhoto = 'st_profile_photo';
  static const _kPhone = 'st_profile_phone';

  static const defaultAbout = 'Hey there! I am using Shadow Talk.';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String get name => _prefs?.getString(_kName) ?? '';
  String get about {
    final v = _prefs?.getString(_kAbout);
    return (v == null || v.isEmpty) ? defaultAbout : v;
  }

  String? get photoPath => _prefs?.getString(_kPhoto);
  String get phone => _prefs?.getString(_kPhone) ?? '';

  Future<void> save({
    String? name,
    String? about,
    String? photoPath,
    String? phone,
  }) async {
    if (name != null) await _prefs?.setString(_kName, name);
    if (about != null) await _prefs?.setString(_kAbout, about);
    if (photoPath != null) await _prefs?.setString(_kPhoto, photoPath);
    if (phone != null) await _prefs?.setString(_kPhone, phone);
    notifyListeners();
  }

  Future<void> clearPhoto() async {
    await _prefs?.remove(_kPhoto);
    notifyListeners();
  }

  /// Wipes the profile (used on logout / delete account).
  Future<void> clear() async {
    await _prefs?.remove(_kName);
    await _prefs?.remove(_kAbout);
    await _prefs?.remove(_kPhoto);
    await _prefs?.remove(_kPhone);
    notifyListeners();
  }
}
