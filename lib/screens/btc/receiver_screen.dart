import 'package:flutter/material.dart';

import '../../services/btc/blockchain_api.dart';
import '../../services/offline_chat_service.dart';
import '../../theme/app_colors.dart';
import 'btc_common.dart';

/// Paste a signed transaction hex and broadcast it to the testnet network.
/// Port of the Android `ReceiverActivity` (verify → check existing → POST).
class ReceiverScreen extends StatefulWidget {
  const ReceiverScreen({super.key});

  @override
  State<ReceiverScreen> createState() => _ReceiverScreenState();
}

class _ReceiverScreenState extends State<ReceiverScreen> {
  final _hexCtrl = TextEditingController();
  bool _broadcasting = false;
  String? _status;
  bool _statusOk = false;

  @override
  void dispose() {
    _hexCtrl.dispose();
    super.dispose();
  }

  Future<void> _broadcast({String? meshHex}) async {
    final hex = (meshHex ?? _hexCtrl.text).trim();
    if (hex.isEmpty) {
      BtcUi.snack(context, 'Please enter transaction hex');
      return;
    }

    setState(() {
      _broadcasting = true;
      _statusOk = false;
      _status = 'Broadcasting…';
    });

    final result = await BlockchainApi.broadcast(hex);

    if (!mounted) return;
    setState(() {
      _broadcasting = false;
      final msg = result.message ?? '';
      if (result.success) {
        _statusOk = true;
        _status = 'Transaction broadcast successfully!\n\nTX ID:\n${result.txId}';
        if (meshHex == null) _hexCtrl.clear();
        // Once broadcast, drop it from the mesh inbox.
        OfflineChatService.instance.clearIncomingBtcTransaction(hex);
      } else if (msg.contains('already broadcast')) {
        // Already on the network — the goal is met, so this isn't a failure.
        _statusOk = true;
        _status = 'Transaction is already on the network.';
        if (meshHex == null) _hexCtrl.clear();
        OfflineChatService.instance.clearIncomingBtcTransaction(hex);
      } else {
        _statusOk = false;
        _status = 'Broadcast failed:\n$msg';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BtcUi.pageScaffold(
      title: 'Broadcast',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _meshInbox(),
          Row(
            children: [
              const Text('Signed Transaction (hex)',
                  style: TextStyle(color: AppColors.textDesc, fontSize: 13)),
              const Spacer(),
              TextButton.icon(
                onPressed: () =>
                    BtcUi.pasteInto(context, _hexCtrl, 'Transaction hex'),
                icon: const Icon(Icons.content_paste, size: 16, color: BtcUi.orange),
                label: const Text('Paste',
                    style: TextStyle(color: BtcUi.orange, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _hexCtrl,
            maxLines: 8,
            minLines: 5,
            style: const TextStyle(
                color: AppColors.white, fontFamily: 'monospace', fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Paste the signed transaction hex…',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: BtcUi.cardBg,
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
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: BtcUi.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _broadcasting ? null : _broadcast,
              child: _broadcasting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : const Text('Broadcast',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16)),
            ),
          ),
          if (_status != null) ...[
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (_statusOk ? AppColors.green : AppColors.red)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: (_statusOk ? AppColors.green : AppColors.red)
                        .withValues(alpha: 0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_statusOk ? Icons.check_circle : Icons.error_outline,
                      color: _statusOk ? AppColors.green : AppColors.red,
                      size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SelectableText(
                      _status!,
                      style: const TextStyle(
                          color: AppColors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Transactions that arrived over the offline Bluetooth mesh. Shown only when
  /// non-empty; tapping "Broadcast" pushes one to the Bitcoin network (this
  /// device is the online relay), or "Load" drops it into the field above.
  Widget _meshInbox() {
    return ValueListenableBuilder<List<String>>(
      valueListenable: OfflineChatService.instance.incomingBtcTransactions,
      builder: (context, txs, _) {
        if (txs.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bluetooth, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Text('Received over mesh (${txs.length})',
                      style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Signed transactions relayed from offline devices. Broadcast one '
                'to the network from here.',
                style: TextStyle(color: AppColors.textDesc, fontSize: 12),
              ),
              const SizedBox(height: 10),
              for (final tx in txs) _meshTxRow(tx),
            ],
          ),
        );
      },
    );
  }

  Widget _meshTxRow(String tx) {
    final short = tx.length <= 22 ? tx : '${tx.substring(0, 14)}…${tx.substring(tx.length - 6)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(short,
                style: const TextStyle(
                    color: AppColors.white,
                    fontFamily: 'monospace',
                    fontSize: 13)),
          ),
          TextButton(
            onPressed: _broadcasting
                ? null
                : () {
                    _hexCtrl.text = tx;
                    BtcUi.snack(context, 'Loaded into the field below');
                  },
            child: const Text('Load',
                style: TextStyle(color: AppColors.textDesc, fontSize: 13)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: BtcUi.orange,
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _broadcasting ? null : () => _broadcast(meshHex: tx),
            child: const Text('Broadcast', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
