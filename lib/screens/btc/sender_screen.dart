import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/btc/balance_manager.dart';
import '../../services/btc/btc_wallet.dart';
import '../../services/offline_chat_service.dart';
import '../../theme/app_colors.dart';
import 'btc_common.dart';

/// Build and sign a transaction **offline** from cached confirmed UTXOs and
/// emit its raw hex, to be handed to a connected device for broadcast.
/// Port of the Android `SenderActivity`.
class SenderScreen extends StatefulWidget {
  final BtcWallet wallet;
  const SenderScreen({super.key, required this.wallet});

  @override
  State<SenderScreen> createState() => _SenderScreenState();
}

class _SenderScreenState extends State<SenderScreen> {
  final BalanceManager _balance = BalanceManager.instance;
  final _recipientCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  String? _txHex;
  bool _generating = false;
  bool _meshSending = false;

  @override
  void initState() {
    super.initState();
    _balance.addListener(_onChange);
    // Make sure UTXOs are fresh/cached before the user tries to spend.
    _balance.fetch(widget.wallet);
  }

  @override
  void dispose() {
    _balance.removeListener(_onChange);
    _recipientCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _generate() async {
    final recipient = _recipientCtrl.text.trim();
    final amountStr = _amountCtrl.text.trim();
    if (recipient.isEmpty || amountStr.isEmpty) {
      BtcUi.snack(context, 'Please fill all fields');
      return;
    }
    final amountSats = BtcFormat.btcToSats(amountStr);
    if (amountSats == null) {
      BtcUi.snack(context, 'Invalid amount');
      return;
    }
    if (amountSats > _balance.totalSats) {
      BtcUi.snack(context,
          'Insufficient balance. Available: ${_balance.totalFormatted} BTC');
      return;
    }
    // Use all known UTXOs (confirmed + pending). If nothing is cached at all,
    // the wallet hasn't been refreshed online yet.
    final utxos = _balance.utxos;
    if (utxos.isEmpty) {
      BtcUi.snack(context,
          'No funds found yet. Connect to the internet and tap refresh.');
      return;
    }
    final usingUnconfirmed = _balance.spendableUtxos.isEmpty;

    setState(() => _generating = true);
    try {
      final hex = widget.wallet.buildSignedTransaction(
        recipientAddress: recipient,
        amountSats: amountSats,
        utxos: utxos,
        allowUnconfirmed: true, // let pending testnet funds be forwarded
      );
      setState(() => _txHex = hex);
      if (mounted) {
        BtcUi.snack(
            context,
            usingUnconfirmed
                ? 'Transaction generated (spending unconfirmed funds — broadcast may need the incoming tx to confirm)'
                : 'Transaction generated');
      }
    } on BtcTransactionException catch (e) {
      if (mounted) BtcUi.snack(context, e.message);
    } catch (e) {
      if (mounted) BtcUi.snack(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  /// Hand the signed transaction to the offline Bluetooth mesh. It hops
  /// device-to-device (no internet) until a peer that has connectivity can
  /// broadcast it to the Bitcoin network from their Broadcast screen.
  Future<void> _sendOverMesh() async {
    final hex = _txHex;
    if (hex == null) return;
    setState(() => _meshSending = true);
    try {
      final mesh = OfflineChatService.instance;
      if (!mesh.isReady) {
        // Lazily bring the mesh up (prompts for Bluetooth the first time).
        await mesh.init();
      }
      if (!mesh.isReady) {
        if (mounted) {
          BtcUi.snack(context,
              'Bluetooth is off or unavailable (the iOS Simulator has no BLE).');
        }
        return;
      }
      final delivered = await mesh.sendSignedTransaction(hex);
      if (!mounted) return;
      BtcUi.snack(
        context,
        delivered
            ? 'Sent over Bluetooth mesh — it will relay until a device online broadcasts it.'
            : 'No nearby peers yet. It will send when a device joins the mesh; keep this open.',
      );
    } catch (e) {
      if (mounted) BtcUi.snack(context, 'Mesh send failed: $e');
    } finally {
      if (mounted) setState(() => _meshSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BtcUi.pageScaffold(
      title: 'Send',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _balanceChip(),
          const SizedBox(height: 20),
          _field(
            controller: _recipientCtrl,
            label: 'Recipient Address',
            hint: 'tb1… or m/n…',
            paste: true,
          ),
          const SizedBox(height: 16),
          _field(
            controller: _amountCtrl,
            label: 'Amount (BTC)',
            hint: '0.00010000',
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: BtcUi.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _generating ? null : _generate,
              child: _generating
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : const Text('Generate Transaction',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16)),
            ),
          ),
          if (_txHex != null) ...[
            const SizedBox(height: 28),
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: QrImageView(
                  data: _txHex!,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20),
            BtcCopyField(
                label: 'Signed Transaction (hex)',
                value: _txHex!,
                maxLines: 6),
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: _meshSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: AppColors.primary))
                    : const Icon(Icons.bluetooth),
                label: const Text('Send via Bluetooth mesh',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                onPressed: _meshSending ? null : _sendOverMesh,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'No internet? Send it over the Bluetooth mesh — it relays phone to '
              'phone until a device online broadcasts it. Or hand the hex/QR to '
              'an online device and use the Broadcast screen.',
              style: TextStyle(color: AppColors.textDesc, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _balanceChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: BtcUi.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BtcUi.cardBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet,
              color: BtcUi.orange, size: 20),
          const SizedBox(width: 12),
          Text(
            _balance.isLoading
                ? 'Loading balance…'
                : 'Available: ${_balance.totalFormatted} BTC',
            style: const TextStyle(color: AppColors.white, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    bool paste = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: AppColors.textDesc, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: AppColors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: BtcUi.cardBg,
            // One-tap paste (e.g. paste a copied recipient address).
            suffixIcon: paste
                ? IconButton(
                    icon: const Icon(Icons.content_paste,
                        size: 20, color: BtcUi.orange),
                    tooltip: 'Paste',
                    onPressed: () =>
                        BtcUi.pasteInto(context, controller, label),
                  )
                : null,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: BtcUi.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: BtcUi.orange),
            ),
          ),
        ),
      ],
    );
  }
}
