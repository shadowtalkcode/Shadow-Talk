import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'main_screen.dart';
import 'onboarding/profile_setup_screen.dart';
import 'onboarding/welcome_screen.dart';

/// Launch screen — just the logo centred on the dark background.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      // Auth gate, mirroring the Android SplashActivity routing:
      //  - not logged in        → onboarding (Welcome → phone login)
      //  - logged in, no profile → profile setup
      //  - logged in + profile   → home
      final auth = AuthService.instance;
      final Widget next;
      if (!auth.isLoggedIn) {
        next = const WelcomeScreen();
      } else if (!auth.profileCompleted) {
        next = const ProfileSetupScreen();
      } else {
        next = const MainScreen();
      }
      debugPrint('🔐 AUTH: splash gate → ${next.runtimeType} '
          '(isLoggedIn=${auth.isLoggedIn}, profileCompleted=${auth.profileCompleted})');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => next),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Image.asset(
          'assets/images/logo.png',
          width: 150,
          height: 150,
          errorBuilder: (context, error, stack) => const Icon(
            Icons.shield_moon_rounded,
            size: 120,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
