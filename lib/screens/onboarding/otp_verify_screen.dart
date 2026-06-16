import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../main_screen.dart';
import 'profile_setup_screen.dart';

/// "Verify your number" screen with underline PIN fields, a resend countdown,
/// the entered number in the subtitle, and a back-confirmation dialog.
class OtpVerifyScreen extends StatefulWidget {
  final String phoneNumber;
  const OtpVerifyScreen({super.key, this.phoneNumber = ''});

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  // Android's OTPEditText uses 6 digits, auto-submitting when the 6th is typed.
  static const int _otpLength = 6;
  final _controllers = List.generate(_otpLength, (_) => TextEditingController());
  final _nodes = List.generate(_otpLength, (_) => FocusNode());

  static const int _duration = 60; // 1:00 countdown (Android CountDownTimer)
  int _secondsLeft = _duration;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _duration);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  String get _timeText {
    // Android format: "%d:%02d" → minutes without leading zero (e.g. "1:00", "0:30").
    final m = _secondsLeft ~/ 60;
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool _verifying = false;
  bool _resending = false;

  void _onChanged(int i, String v) {
    if (v.isNotEmpty && i < _otpLength - 1) _nodes[i + 1].requestFocus();
    if (v.isEmpty && i > 0) _nodes[i - 1].requestFocus();
    final code = _controllers.map((c) => c.text).join();
    if (code.length == _otpLength && !_verifying) _submit(code);
  }

  Future<void> _submit(String code) async {
    debugPrint('🔐 AUTH(UI): OTP entered "$code" → verifying…');
    setState(() => _verifying = true);
    FocusScope.of(context).unfocus();
    try {
      // Keep the "Initializing" loader on screen long enough to be seen (the
      // Android app shows the spinning-gear setup screen during sign-in).
      await Future.delayed(const Duration(milliseconds: 2000));
      await AuthService.instance.confirmCode(code);
      if (!mounted) return;
      // Signed in. Route to profile setup (or home if already completed).
      final completed = AuthService.instance.profileCompleted;
      debugPrint('🔐 AUTH(UI): verified ✅ → ${completed ? 'MainScreen' : 'ProfileSetupScreen'}');
      final next = completed ? const MainScreen() : const ProfileSetupScreen();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => next),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      _onVerifyError(e.code == 'invalid-verification-code'
          ? 'Verification code is invalid'
          : (e.message ?? 'Verification failed. Please try again.'));
    } catch (_) {
      _onVerifyError('Verification failed. Please try again.');
    }
  }

  void _onVerifyError(String message) {
    if (!mounted) return;
    debugPrint('🔐 AUTH(UI): OTP verify error → $message');
    setState(() => _verifying = false);
    for (final c in _controllers) {
      c.clear();
    }
    _nodes.first.requestFocus();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _resend() async {
    debugPrint('🔐 AUTH(UI): resend requested');
    for (final c in _controllers) {
      c.clear();
    }
    setState(() => _resending = true);
    await AuthService.instance.verifyPhone(
      phoneNumber: widget.phoneNumber.replaceAll(RegExp(r'\s'), ''),
      resend: true,
      onCodeSent: () {
        if (!mounted) return;
        setState(() => _resending = false);
        _startTimer();
        _nodes.first.requestFocus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification code resent')),
        );
      },
      onError: (m) {
        if (!mounted) return;
        setState(() => _resending = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
      },
    );
  }

  Future<bool> _confirmBack() async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xFF221D34),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Are you sure you want to cancel the request to verify your phone number?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: AppColors.textDesc, height: 1.4),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('No',
                        style: TextStyle(
                            color: AppColors.textDesc, fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Yes',
                        style: TextStyle(
                            color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmBack()) navigator.pop();
      },
      child: Stack(
        children: [
          GradientScaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.white),
            onPressed: () async {
              final navigator = Navigator.of(context);
              if (await _confirmBack()) navigator.pop();
            },
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Verify your number',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  "We've sent an SMS to ${widget.phoneNumber.isEmpty ? 'your number' : widget.phoneNumber} with a 6-digit verification code",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: AppColors.textDesc, height: 1.4),
                ),
                const SizedBox(height: 48),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_otpLength, (i) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: _OtpField(
                        controller: _controllers[i],
                        node: _nodes[i],
                        enabled: !_verifying,
                        onChanged: (v) => _onChanged(i, v),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 32),
                if (_resending)
                  const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
                  )
                else if (_secondsLeft > 0)
                  Text(
                    'Try again after $_timeText',
                    style: const TextStyle(fontSize: 16, color: AppColors.textDesc),
                  )
                else
                  PrimaryButton(
                    label: 'Try Again',
                    width: 220,
                    onPressed: _resend,
                  ),
              ],
            ),
          ),
        ),
          ),
          // Verification loader (mirrors the Android progress bar shown while
          // the code is being checked).
          if (_verifying)
            const _VerifyingOverlay(),
        ],
      ),
    );
  }
}

/// A single underline-style OTP digit field.
class _OtpField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode node;
  final ValueChanged<String> onChanged;
  final bool enabled;

  const _OtpField({
    required this.controller,
    required this.node,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      child: TextField(
        controller: controller,
        focusNode: node,
        enabled: enabled,
        onChanged: onChanged,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.white),
        cursorColor: AppColors.primary,
        decoration: const InputDecoration(
          counterText: '',
          isDense: true,
          contentPadding: EdgeInsets.only(bottom: 8),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.divider, width: 2),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
      ),
    );
  }
}

/// Full-screen "Initializing" loader shown while the OTP code is being verified
/// — mirrors the Android `SetupUserActivity`: a spinning gear icon above
/// "Initializing" text whose trailing dots animate (. → .. → ...).
class _VerifyingOverlay extends StatefulWidget {
  const _VerifyingOverlay();

  @override
  State<_VerifyingOverlay> createState() => _VerifyingOverlayState();
}

class _VerifyingOverlayState extends State<_VerifyingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;
  Timer? _dotTimer;
  int _dotCount = 1;

  @override
  void initState() {
    super.initState();
    // Gear spins 360° every 2s, forever (matches Android's RotateAnimation).
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    // Dots cycle 1 → 2 → 3 every 500ms.
    _dotTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      setState(() => _dotCount = (_dotCount % 3) + 1);
    });
  }

  @override
  void dispose() {
    _spin.dispose();
    _dotTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AbsorbPointer(
        // Wrapped in a (transparent) Material because this overlay is a direct
        // child of the screen's top-level Stack — without a Material ancestor
        // Flutter paints the yellow "missing Material" underline under the text.
        child: Material(
          type: MaterialType.transparency,
          child: Container(
          decoration: const BoxDecoration(gradient: AppColors.bgGradient),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RotationTransition(
                turns: _spin,
                child: const Icon(Icons.settings, size: 80, color: AppColors.white),
              ),
              const SizedBox(height: 32),
              Text(
                'Initializing${'.' * _dotCount}',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'OpenSans',
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}
