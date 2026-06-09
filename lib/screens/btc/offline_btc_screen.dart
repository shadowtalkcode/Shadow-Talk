import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Offline BTC tab — wallet balance and Wallet/Send/Broadcast actions.
/// Display only (currency transfer is not implemented in this build).
class OfflineBtcScreen extends StatelessWidget {
  const OfflineBtcScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Title bar
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 14, 24, 8),
              child: Center(
                child: Text('Offline BTC',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                    )),
              ),
            ),
            const SizedBox(height: 16),
            // Balance card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                color: const Color(0xFF221D34),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF2E2A40)),
              ),
              child: Column(
                children: [
                  // Bitcoin badge
                  Container(
                    width: 92,
                    height: 92,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF7931A),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.currency_bitcoin, color: Colors.white, size: 56),
                  ),
                  const SizedBox(height: 20),
                  const Text('0.00000000 BTC',
                      style: TextStyle(
                          fontSize: 34, fontWeight: FontWeight.w700, color: AppColors.white)),
                  const SizedBox(height: 8),
                  const Text('Current Balance',
                      style: TextStyle(fontSize: 18, color: AppColors.textDesc)),
                  const SizedBox(height: 16),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppColors.primary, size: 28),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ActionButton(
                  icon: Icons.account_balance_wallet,
                  label: 'Wallet',
                  onTap: () => _notAvailable(context),
                ),
                _ActionButton(
                  icon: Icons.arrow_upward,
                  label: 'Send',
                  onTap: () => _notAvailable(context),
                ),
                _ActionButton(
                  icon: Icons.arrow_downward,
                  label: 'Broadcast',
                  onTap: () => _notAvailable(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _notAvailable(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Currency transfer is not available in this build')),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: const Color(0xFF2A2640),
          shape: CircleBorder(
            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 72,
              height: 72,
              child: Icon(icon, color: AppColors.primary, size: 30),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(fontSize: 16, color: AppColors.textDesc)),
      ],
    );
  }
}
