import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
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
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
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
