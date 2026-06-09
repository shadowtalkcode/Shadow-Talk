import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import 'phone_entry_screen.dart';

/// "Welcome to Shadow Talk" intro screen. Matches XD reference 02.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 3),
              Image.asset(
                'assets/images/logo.png',
                width: 120,
                height: 120,
                errorBuilder: (context, error, stack) => const Icon(
                  Icons.shield_moon_rounded,
                  size: 140,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Welcome to Shadow Talk',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Free messages and calls with end-to-end encryption',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textDesc),
              ),
              const Spacer(flex: 4),
              const Text.rich(
                TextSpan(
                  text: 'Read our ',
                  children: [
                    TextSpan(
                      text: 'Privacy Policy',
                      style: TextStyle(decoration: TextDecoration.underline),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textDesc),
              ),
              const SizedBox(height: 6),
              const Text.rich(
                TextSpan(
                  text: 'By tapping "Start Now" you agree to our ',
                  children: [
                    TextSpan(
                      text: 'Terms & Policy',
                      style: TextStyle(decoration: TextDecoration.underline),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textDesc),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Start Now',
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const PhoneEntryScreen()),
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}
