import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/countries.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../widgets/country_picker.dart';
import 'otp_verify_screen.dart';
import 'profile_setup_screen.dart';

/// "Enter your phone number" screen with a working country picker.
/// This is the onboarding root — there is no back navigation to Welcome.
class PhoneEntryScreen extends StatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  State<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends State<PhoneEntryScreen> {
  // Default to US, matching the Android CountryCodePicker default ("US").
  Country _country =
      kCountries.firstWhere((c) => c.iso2 == 'US', orElse: () => kCountries.first);

  final _phoneCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCountry() async {
    final picked = await CountryPicker.show(context);
    if (picked != null) setState(() => _country = picked);
  }

  void _onContinue() {
    // Match Android: validate non-empty and digits-only, else "Please enter a
    // correct number".
    final number = _phoneCtrl.text.trim();
    final digitsOnly = RegExp(r'^\d+$').hasMatch(number);
    if (number.isEmpty || !digitsOnly) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a correct number')),
      );
      return;
    }
    // Android builds the confirmation number as countryCodeWithPlus + number.
    final fullNumber = '${_country.dialCode}$number';
    showDialog(
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
              Text(
                'we will send you a SMS message to $fullNumber to verify your number',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: AppColors.textDesc, height: 1.4),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Edit',
                        style: TextStyle(
                            color: AppColors.textDesc, fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      _startVerification(fullNumber);
                    },
                    child: const Text('OK',
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
  }

  /// Sends the verification SMS via Firebase (with a local fallback), then
  /// routes to the OTP screen. Mirrors the Android verifyPhoneNumber flow.
  Future<void> _startVerification(String displayNumber) async {
    final e164 = _country.dialCode + _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    debugPrint('🔐 AUTH(UI): Continue confirmed → starting verification for $e164');
    setState(() => _loading = true);
    await AuthService.instance.verifyPhone(
      phoneNumber: e164,
      onCodeSent: () {
        if (!mounted) return;
        debugPrint('🔐 AUTH(UI): code sent → opening OTP screen');
        setState(() => _loading = false);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OtpVerifyScreen(phoneNumber: displayNumber),
          ),
        );
      },
      onAutoVerified: () {
        // Firebase auto-resolved the code (Android instant-verification).
        if (!mounted) return;
        setState(() => _loading = false);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
        );
      },
      onError: (message) {
        if (!mounted) return;
        debugPrint('🔐 AUTH(UI): verification error → $message');
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Block back navigation — the user cannot return to the Welcome screen.
    return PopScope(
      canPop: false,
      child: GradientScaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Enter your phone number',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  "Make sure this number can receive SMS and calls. You'll receive your activation code through it.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: AppColors.textDesc, height: 1.4),
                ),
                const SizedBox(height: 44),
                // Single phone field: [flag · initials · code ▾] | phone input
                UnderlineRow(
                  child: Row(
                    children: [
                      InkWell(
                        onTap: _pickCountry,
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_country.flag, style: const TextStyle(fontSize: 24)),
                              const SizedBox(width: 8),
                              Text(_country.iso2,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.white)),
                              const SizedBox(width: 6),
                              Text(_country.dialCode,
                                  style: const TextStyle(fontSize: 18, color: AppColors.white)),
                              const Icon(Icons.keyboard_arrow_down,
                                  color: AppColors.primary, size: 22),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 24,
                        color: AppColors.divider,
                        margin: const EdgeInsets.only(right: 12),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: const TextStyle(fontSize: 18, color: AppColors.white),
                          cursorColor: AppColors.primary,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: '123 123456',
                            hintStyle: TextStyle(fontSize: 18, color: AppColors.textDesc),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                else
                  PrimaryButton(
                    label: 'Continue',
                    onPressed: _onContinue,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
