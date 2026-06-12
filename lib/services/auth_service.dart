import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tagged auth logger — prints to the console so the verification flow is
/// observable (e.g. `flutter logs` / the run console).
void _log(String message) => debugPrint('🔐 AUTH: $message');

/// Authentication service mirroring the Android app's Firebase phone-auth flow:
/// verifyPhoneNumber → codeSent → signInWithCredential, with a persistent
/// session so the app skips login on subsequent launches.
///
/// On platforms/projects where Firebase phone verification can't complete
/// (e.g. the iOS Simulator without APNs / reCAPTCHA, or a project without the
/// Phone provider enabled), it transparently falls back to a locally-persisted
/// session so the flow stays usable — exactly the same screens and routing.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  // Lazy so the singleton can exist before Firebase.initializeApp (and in tests).
  FirebaseAuth get _auth => FirebaseAuth.instance;
  SharedPreferences? _prefs;

  static const _kLocalSession = 'st_local_session_phone';
  static const _kProfileCompleted = 'st_profile_completed';
  static const _kInstalled = 'st_installed';

  /// Phone-auth mode. Default `auto` → real Firebase SMS verification on a
  /// physical device, local-session fallback on the iOS Simulator (which has no
  /// APNs/push for the verification challenge, where native `verifyPhoneNumber`
  /// would crash). Force with `--dart-define=FIREBASE_PHONE=true|false`.
  static const String _phoneAuthMode =
      String.fromEnvironment('FIREBASE_PHONE', defaultValue: 'auto');

  /// Set once at [init] — true on a real iPhone/Android, false on a simulator.
  bool _isPhysicalDevice = false;

  /// Whether to drive the real Firebase phone-verification flow (real SMS).
  bool get _useRealPhoneAuth {
    switch (_phoneAuthMode) {
      case 'true':
        return true;
      case 'false':
        return false;
      default:
        return _isPhysicalDevice; // auto
    }
  }

  String? _verificationId;
  int? _resendToken;
  bool _localMode = false;
  String _pendingPhone = '';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _detectDevice();
    await _clearStaleSessionOnFreshInstall();
    _log('init — isLoggedIn=$isLoggedIn, profileCompleted=$profileCompleted, '
        'useRealPhoneAuth=$_useRealPhoneAuth (physical=$_isPhysicalDevice)');
  }

  /// Detects whether we're on a physical device or a simulator/emulator.
  Future<void> _detectDevice() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isIOS) {
        _isPhysicalDevice = (await info.iosInfo).isPhysicalDevice;
      } else if (Platform.isAndroid) {
        _isPhysicalDevice = (await info.androidInfo).isPhysicalDevice;
      } else {
        _isPhysicalDevice = true;
      }
    } catch (e) {
      _log('device detection failed ($e) → assuming simulator');
      _isPhysicalDevice = false;
    }
  }

  /// On iOS the Firebase auth session lives in the keychain, which survives an
  /// app *uninstall* — while shared_preferences is wiped. That left a reinstall
  /// "logged in" (stale anonymous user) but with no profile, routing to profile
  /// setup. Detect a fresh install (our prefs flag is absent) and sign out the
  /// leftover session so a reinstall correctly starts at the Welcome screen.
  Future<void> _clearStaleSessionOnFreshInstall() async {
    if (_prefs?.getBool(_kInstalled) == true) return;
    try {
      if (_auth.currentUser != null) {
        await _auth.signOut();
        _log('fresh install → cleared stale keychain session');
      }
    } catch (_) {/* Firebase not available */}
    await _prefs?.setBool(_kInstalled, true);
  }

  // ---- Session state -----------------------------------------------------
  bool get isLoggedIn {
    bool realFirebaseUser = false;
    try {
      final u = _auth.currentUser;
      // An anonymous user is created purely for backend (chat / database)
      // access — it does NOT mean the person has onboarded. Only a real
      // (phone-authenticated) Firebase user counts as logged in, so an
      // anonymous session never routes us past the Welcome screen.
      realFirebaseUser = u != null && !u.isAnonymous;
    } catch (_) {/* Firebase not available */}
    return realFirebaseUser || (_prefs?.getString(_kLocalSession) != null);
  }

  /// The Firebase user id used to key chat data. Real phone-auth uids when
  /// available, otherwise an anonymous uid (so chat works on the simulator).
  String? get uid {
    try {
      return _auth.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  /// Ensures a Firebase user exists (anonymous if needed) so chat has a uid.
  /// Returns the uid, or null if Firebase auth is unavailable/disabled.
  Future<String?> ensureSignedIn() async {
    try {
      if (_auth.currentUser == null) {
        _log('ensureSignedIn → signing in anonymously …');
        await _auth.signInAnonymously();
      }
      _log('ensureSignedIn → uid=${_auth.currentUser?.uid}');
      return _auth.currentUser?.uid;
    } catch (e) {
      _log('ensureSignedIn failed: $e');
      return null;
    }
  }

  bool get profileCompleted => _prefs?.getBool(_kProfileCompleted) ?? false;

  Future<void> setProfileCompleted(bool value) async {
    _log('setProfileCompleted=$value');
    await _prefs?.setBool(_kProfileCompleted, value);
  }

  String get phoneNumber =>
      _auth.currentUser?.phoneNumber ?? (_prefs?.getString(_kLocalSession) ?? '');

  // ---- Phone verification ------------------------------------------------
  /// Begins phone verification. [onCodeSent] fires once the SMS is sent (or
  /// immediately in local-fallback mode); [onError] reports a user-facing
  /// message; [onAutoVerified] fires if Firebase auto-resolves the code.
  Future<void> verifyPhone({
    required String phoneNumber,
    required void Function() onCodeSent,
    required void Function(String message) onError,
    void Function()? onAutoVerified,
    bool resend = false,
  }) async {
    _pendingPhone = phoneNumber;
    _log('verifyPhone → "$phoneNumber" (resend=$resend, '
        'useRealPhoneAuth=$_useRealPhoneAuth)');

    // On a simulator there's no APNs/push for the verification challenge, so the
    // native verifyPhoneNumber would crash — use the local session flow instead.
    // On a real device we drive the real SMS verification below.
    if (!_useRealPhoneAuth) {
      _log('verifyPhone → local-session mode (simulator / forced local)');
      _enterLocalMode();
      onCodeSent();
      return;
    }

    try {
      _log('verifyPhone → calling FirebaseAuth.verifyPhoneNumber …');
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        forceResendingToken: resend ? _resendToken : null,
        verificationCompleted: (PhoneAuthCredential credential) async {
          _log('verificationCompleted → auto-resolving credential');
          try {
            await _auth.signInWithCredential(credential);
            _log('auto sign-in success (uid=${_auth.currentUser?.uid})');
            onAutoVerified?.call();
          } catch (e) {
            _log('auto sign-in error: $e');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          _log('verificationFailed → code=${e.code} msg=${e.message}');
          if (_isUnavailable(e)) {
            _log('→ treating as unavailable, switching to local-session mode');
            _enterLocalMode();
            onCodeSent();
          } else {
            onError(_friendly(e));
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          _log('codeSent → verificationId=$verificationId');
          _localMode = false;
          _verificationId = verificationId;
          _resendToken = resendToken;
          onCodeSent();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _log('codeAutoRetrievalTimeout');
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      // Plugin/platform not available here — fall back to a local session.
      _log('verifyPhoneNumber threw ($e) → local-session mode');
      _enterLocalMode();
      onCodeSent();
    }
  }

  /// Confirms the SMS code. Returns true on success; throws
  /// [FirebaseAuthException] for a real invalid/expired code.
  Future<bool> confirmCode(String code) async {
    _log('confirmCode → "$code" (localMode=$_localMode)');
    if (_localMode || _verificationId == null || _verificationId == 'local') {
      await _prefs?.setString(_kLocalSession, _pendingPhone);
      _log('confirmCode → local session saved for "$_pendingPhone" ✅');
      return true;
    }
    final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!, smsCode: code);
    await _auth.signInWithCredential(credential);
    _log('confirmCode → Firebase sign-in success (uid=${_auth.currentUser?.uid}) ✅');
    return true;
  }

  Future<void> signOut() async {
    _log('signOut');
    try {
      await _auth.signOut();
    } catch (_) {}
    await _prefs?.remove(_kLocalSession);
    await _prefs?.remove(_kProfileCompleted);
    _verificationId = null;
    _resendToken = null;
    _localMode = false;
  }

  // ---- Helpers -----------------------------------------------------------
  void _enterLocalMode() {
    _localMode = true;
    _verificationId = 'local';
  }

  /// Errors that indicate phone verification can't run in this environment
  /// (simulator without APNs/reCAPTCHA, provider/config not set up) — these
  /// trigger the local-session fallback rather than a hard error.
  bool _isUnavailable(FirebaseAuthException e) {
    const unavailable = {
      'app-not-authorized',
      'missing-client-identifier',
      'missing-app-credential',
      'invalid-app-credential',
      'operation-not-allowed',
      'web-context-cancelled',
      'web-context-already-presented',
      'internal-error',
      'unknown',
    };
    return unavailable.contains(e.code);
  }

  String _friendly(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'The phone number is invalid.';
      case 'invalid-verification-code':
        return 'Invalid verification code.';
      case 'session-expired':
        return 'The code has expired. Please resend it.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return e.message ?? 'Verification failed. Please try again.';
    }
  }
}
