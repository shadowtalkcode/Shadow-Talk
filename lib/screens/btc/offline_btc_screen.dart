import 'package:flutter/material.dart';

import '../../services/btc/balance_manager.dart';
import '../../services/btc/btc_wallet.dart';
import '../../theme/app_colors.dart';
import 'btc_common.dart';
import 'receiver_screen.dart';
import 'sender_screen.dart';
import 'wallet_screen.dart';

/// Offline BTC tab — testnet wallet balance plus Wallet / Send / Broadcast
/// actions. Direct port of the Android `OfflineBtcMainActivity`.
class OfflineBtcScreen extends StatefulWidget {
  const OfflineBtcScreen({super.key});

  @override
  State<OfflineBtcScreen> createState() => _OfflineBtcScreenState();
}

class _OfflineBtcScreenState extends State<OfflineBtcScreen> {
  final BalanceManager _balance = BalanceManager.instance;
  BtcWallet? _wallet;

  @override
  void initState() {
    super.initState();
    _balance.addListener(_onBalance);
    _init();
  }

  @override
  void dispose() {
    _balance.removeListener(_onBalance);
    super.dispose();
  }

  void _onBalance() {
    if (mounted) setState(() {});
  }

  Future<void> _init() async {
    // A testnet wallet is generated on first visit so the tab always has an
    // address to show (the Android Wallet screen does the same on open).
    final wallet = await BtcWallet.loadOrCreate();
    if (!mounted) return;
    setState(() => _wallet = wallet);
    _balance.fetch(wallet);
  }

  void _refresh() {
    if (_wallet != null) _balance.fetch(_wallet!);
  }

  Future<void> _push(Widget screen) async {
    if (_wallet == null) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    // Returning from Send/Broadcast may have changed the balance.
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final loading = _balance.isLoading;
    final balanceText = _wallet == null
        ? '—'
        : (_balance.error != null && _balance.totalSats == 0
            ? 'Error'
            : '${_balance.totalFormatted} BTC');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
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
                color: BtcUi.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: BtcUi.cardBorder),
              ),
              child: Column(
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: const BoxDecoration(
                      color: BtcUi.orange,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.currency_bitcoin,
                        color: Colors.white, size: 56),
                  ),
                  const SizedBox(height: 20),
                  Text(loading ? 'Loading…' : balanceText,
                      style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white)),
                  const SizedBox(height: 8),
                  Text(
                    _balance.pendingSats != 0
                        ? 'Pending ${_balance.pendingFormatted} BTC'
                        : 'Current Balance',
                    style: const TextStyle(fontSize: 16, color: AppColors.textDesc),
                  ),
                  const SizedBox(height: 8),
                  Text('TestNet',
                      style: TextStyle(
                          fontSize: 12,
                          color: BtcUi.orange.withValues(alpha: 0.9))),
                  const SizedBox(height: 8),
                  IconButton(
                    icon: loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: AppColors.primary),
                          )
                        : const Icon(Icons.refresh,
                            color: AppColors.primary, size: 28),
                    onPressed: loading ? null : _refresh,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ActionButton(
                  icon: Icons.account_balance_wallet,
                  label: 'Wallet',
                  onTap: () => _push(WalletScreen(wallet: _wallet!)),
                ),
                _ActionButton(
                  icon: Icons.arrow_upward,
                  label: 'Send',
                  onTap: () => _push(SenderScreen(wallet: _wallet!)),
                ),
                _ActionButton(
                  icon: Icons.arrow_downward,
                  label: 'Broadcast',
                  onTap: () => _push(const ReceiverScreen()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: const Color(0xFF2A2640),
          shape: CircleBorder(
            side: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
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
