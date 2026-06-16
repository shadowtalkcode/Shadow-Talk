import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';

/// Shared styling + helpers for the offline-BTC screens, so every screen wears
/// the same Bitcoin-orange accent on the Shadow Talk dark palette.
class BtcUi {
  BtcUi._();

  /// Bitcoin brand orange (matches the Android `btcBgColor` accent usage).
  static const Color orange = Color(0xFFF7931A);
  static const Color cardBg = Color(0xFF221D34);
  static const Color cardBorder = Color(0xFF2E2A40);

  /// A full-page scaffold (used by the pushed sub-screens) with the app's
  /// background gradient and a titled app bar with a back button.
  static Widget pageScaffold({
    required String title,
    required Widget body,
    List<Widget>? actions,
  }) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.bgGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.white),
          title: Text(title,
              style: const TextStyle(
                  color: AppColors.white,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700)),
          actions: actions,
        ),
        body: SafeArea(top: false, child: body),
      ),
    );
  }

  /// Copy [text] to the clipboard and confirm with a snackbar.
  static Future<void> copy(
      BuildContext context, String? text, String label) async {
    if (text == null || text.isEmpty || text == 'N/A') {
      _snack(context, 'No $label to copy');
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) _snack(context, '$label copied');
  }

  static void snack(BuildContext context, String message) =>
      _snack(context, message);

  static void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: AppColors.cardBg,
        behavior: SnackBarBehavior.floating,
      ));
  }
}

/// A labelled, read-only field with a trailing copy button — used for the
/// address / mnemonic / private-key / hex rows across the BTC screens.
class BtcCopyField extends StatelessWidget {
  final String label;
  final String value;
  final int maxLines;
  final bool mono;

  const BtcCopyField({
    super.key,
    required this.label,
    required this.value,
    this.maxLines = 2,
    this.mono = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: AppColors.textDesc, fontSize: 13)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          decoration: BoxDecoration(
            color: BtcUi.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BtcUi.cardBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  value.isEmpty ? 'N/A' : value,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 14,
                    fontFamily: mono ? 'monospace' : null,
                    height: 1.3,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.copy, size: 18, color: BtcUi.orange),
                onPressed: () => BtcUi.copy(context, value, label),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
