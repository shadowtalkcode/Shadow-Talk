import 'package:flutter/material.dart';

import '../../services/btc/btc_wallet.dart';
import '../../theme/app_colors.dart';
import 'btc_common.dart';

/// Shows the wallet's address, 12-word mnemonic seed and WIF private key with
/// per-field and copy-all buttons. Port of the Android `WalletDetailsActivity`.
class WalletDetailsScreen extends StatelessWidget {
  final BtcWallet wallet;
  const WalletDetailsScreen({super.key, required this.wallet});

  @override
  Widget build(BuildContext context) {
    final address = wallet.address;
    final seed = wallet.mnemonicSeed;
    final wif = wallet.privateKeyWif;

    return BtcUi.pageScaffold(
      title: 'Wallet Details',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.red.withValues(alpha: 0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.red, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Keep this secure. Anyone with your seed or private key can '
                    'spend your funds.',
                    style: TextStyle(color: AppColors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          BtcCopyField(label: 'Receiving Address', value: address, maxLines: 2),
          const SizedBox(height: 18),
          BtcCopyField(
              label: 'Mnemonic Seed (12 words)',
              value: seed,
              maxLines: 3,
              mono: false),
          const SizedBox(height: 18),
          BtcCopyField(label: 'Private Key (WIF)', value: wif, maxLines: 2),
          const SizedBox(height: 28),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: BtcUi.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.copy_all),
              label: const Text('Copy All Details',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              onPressed: () => BtcUi.copy(
                context,
                'Bitcoin Wallet Details\n\n'
                'Network: ${BtcWallet.networkName}\n\n'
                'Receiving Address:\n$address\n\n'
                'Mnemonic Seed (12 words):\n$seed\n\n'
                'Private Key (WIF):\n$wif\n\n'
                'IMPORTANT: Keep this information secure! '
                'Do not share your seed or private key with anyone.',
                'All wallet details',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
