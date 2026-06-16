import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/btc/balance_manager.dart';
import '../../services/btc/btc_wallet.dart';
import '../../theme/app_colors.dart';
import 'btc_common.dart';
import 'receiver_screen.dart';
import 'sender_screen.dart';
import 'wallet_details_screen.dart';

/// Wallet overview — receiving address (with QR), live balance, and entry
/// points to details / send / broadcast. Port of the Android `WalletActivity`.
class WalletScreen extends StatefulWidget {
  final BtcWallet wallet;
  const WalletScreen({super.key, required this.wallet});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final BalanceManager _balance = BalanceManager.instance;

  @override
  void initState() {
    super.initState();
    _balance.addListener(_onChange);
    _balance.fetch(widget.wallet);
  }

  @override
  void dispose() {
    _balance.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final address = widget.wallet.address;
    final loading = _balance.isLoading;

    return BtcUi.pageScaffold(
      title: 'Wallet',
      actions: [
        IconButton(
          icon: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: AppColors.primary))
              : const Icon(Icons.refresh, color: AppColors.primary),
          onPressed: loading ? null : () => _balance.fetch(widget.wallet),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // Balance
          Container(
            padding: const EdgeInsets.symmetric(vertical: 22),
            decoration: BoxDecoration(
              color: BtcUi.cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: BtcUi.cardBorder),
            ),
            child: Column(
              children: [
                Text(loading ? 'Loading…' : '${_balance.totalFormatted} BTC',
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white)),
                const SizedBox(height: 4),
                const Text('Balance · TestNet',
                    style: TextStyle(color: AppColors.textDesc, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // QR of the receiving address
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: QrImageView(
                data: address,
                version: QrVersions.auto,
                size: 180,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 24),
          BtcCopyField(label: 'Receiving Address', value: address, maxLines: 2),
          const SizedBox(height: 24),
          _navButton(
            icon: Icons.vpn_key,
            label: 'Wallet Details (seed & private key)',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => WalletDetailsScreen(wallet: widget.wallet))),
          ),
          const SizedBox(height: 12),
          _navButton(
            icon: Icons.arrow_upward,
            label: 'Send (generate signed transaction)',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SenderScreen(wallet: widget.wallet))),
          ),
          const SizedBox(height: 12),
          _navButton(
            icon: Icons.arrow_downward,
            label: 'Broadcast received transaction',
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReceiverScreen())),
          ),
        ],
      ),
    );
  }

  Widget _navButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: BtcUi.cardBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: BtcUi.cardBorder),
          ),
          child: Row(
            children: [
              Icon(icon, color: BtcUi.orange, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        color: AppColors.white, fontSize: 15)),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textDesc),
            ],
          ),
        ),
      ),
    );
  }
}
