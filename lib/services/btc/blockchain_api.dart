import 'dart:convert';

import 'package:http/http.dart' as http;

/// Thin client over the blockstream.info **testnet** Esplora API.
///
/// Direct port of the Android `BlockchainAPI`, `BroadcastAPI` and
/// `TransactionChecker` classes — same endpoints, same testnet network, so the
/// iOS wallet reads/writes the exact same chain as the Android app.
class BlockchainApi {
  BlockchainApi._();

  static const String baseUrl = 'https://blockstream.info/testnet/api';

  static const Duration _timeout = Duration(seconds: 15);

  // ---------------------------------------------------------------------------
  // UTXOs
  // ---------------------------------------------------------------------------

  /// All UTXOs for [address] (both confirmed and unconfirmed). Spending logic
  /// filters by [Utxo.confirmed] later — mirrors the Android behaviour.
  static Future<List<Utxo>> getUtxos(String address) async {
    final res = await http
        .get(Uri.parse('$baseUrl/address/$address/utxo'))
        .timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('UTXO fetch failed: HTTP ${res.statusCode}');
    }
    final List<dynamic> list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) => Utxo.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  // ---------------------------------------------------------------------------
  // Address balance (chain_stats + mempool_stats)
  // ---------------------------------------------------------------------------

  /// Accurate balance from the `/address` endpoint. `chain_stats` is more
  /// reliable than summing UTXOs (matches `BlockchainAPI.getAddressInfo`).
  static Future<AddressInfo> getAddressInfo(String address) async {
    final res =
        await http.get(Uri.parse('$baseUrl/address/$address')).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('Address info failed: HTTP ${res.statusCode}');
    }
    return AddressInfo.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  // ---------------------------------------------------------------------------
  // Fee estimate
  // ---------------------------------------------------------------------------

  /// Recommended fee rate in sat/vB. Doubles the 1-block estimate for high
  /// priority and clamps to a 10 sat/vB minimum — identical to Android.
  static Future<int> getRecommendedFeeRate() async {
    try {
      final res =
          await http.get(Uri.parse('$baseUrl/fee-estimates')).timeout(_timeout);
      if (res.statusCode == 200) {
        final Map<String, dynamic> json =
            jsonDecode(res.body) as Map<String, dynamic>;
        final dynamic one = json['1'];
        if (one is num) {
          final rate = (one.toDouble() * 2).ceil();
          return rate < 10 ? 10 : rate;
        }
      }
    } catch (_) {/* fall through to default */}
    return 10;
  }

  // ---------------------------------------------------------------------------
  // Broadcast
  // ---------------------------------------------------------------------------

  /// POST a raw signed transaction hex to the network.
  /// Returns the txid on success (port of `BroadcastAPI.broadcastTransaction`).
  static Future<BroadcastResult> broadcast(String txHex) async {
    // Signed hex pasted from chat / QR / the mesh inbox often carries stray
    // whitespace or newlines; the node rejects those, so strip them first.
    final cleanHex = txHex.replaceAll(RegExp(r'\s'), '');
    if (cleanHex.isEmpty) {
      return const BroadcastResult(
          success: false, message: 'No transaction hex to broadcast');
    }
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/tx'),
            headers: {'Content-Type': 'text/plain'},
            body: cleanHex,
          )
          .timeout(_timeout);

      if (res.statusCode == 200) {
        return BroadcastResult(success: true, txId: res.body.trim());
      }
      return BroadcastResult(success: false, message: _friendlyError(res.body));
    } catch (e) {
      return BroadcastResult(success: false, message: 'Network error: $e');
    }
  }

  /// Whether [txId] is already known to the network (confirmed or in mempool).
  /// Port of `TransactionChecker.existsOnBlockchain`.
  static Future<bool> transactionExists(String txId) async {
    if (txId.isEmpty) return false;
    try {
      final res =
          await http.get(Uri.parse('$baseUrl/tx/$txId')).timeout(_timeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static String _friendlyError(String raw) {
    if (raw.contains('Transaction already in block chain')) {
      return 'Transaction already broadcast';
    }
    if (raw.contains('bad-txns-inputs-missingorspent')) {
      return 'Transaction inputs already spent (double spend attempt)';
    }
    if (raw.contains('min relay fee not met')) return 'Transaction fee too low';
    if (raw.contains('insufficient fee')) return 'Insufficient transaction fee';
    if (raw.contains('dust')) return 'Output amount too small (below dust limit)';
    if (raw.contains('non-final')) return 'Transaction is non-final';
    return raw.isEmpty ? 'Unknown error' : raw;
  }
}

/// A single unspent output.
class Utxo {
  final String txid;
  final int vout;
  final int value; // satoshis
  final bool confirmed;
  final int blockHeight;

  const Utxo({
    required this.txid,
    required this.vout,
    required this.value,
    required this.confirmed,
    required this.blockHeight,
  });

  factory Utxo.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as Map<String, dynamic>?;
    return Utxo(
      txid: json['txid'] as String,
      vout: json['vout'] as int,
      value: (json['value'] as num).toInt(),
      confirmed: status?['confirmed'] == true,
      blockHeight: (status?['block_height'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'txid': txid,
        'vout': vout,
        'value': value,
        'status': {'confirmed': confirmed, 'block_height': blockHeight},
      };
}

/// Balance information derived from `chain_stats` and `mempool_stats`.
class AddressInfo {
  final int chainFunded;
  final int chainSpent;
  final int mempoolFunded;
  final int mempoolSpent;

  const AddressInfo({
    required this.chainFunded,
    required this.chainSpent,
    required this.mempoolFunded,
    required this.mempoolSpent,
  });

  factory AddressInfo.fromJson(Map<String, dynamic> json) {
    final chain = json['chain_stats'] as Map<String, dynamic>? ?? const {};
    final mem = json['mempool_stats'] as Map<String, dynamic>? ?? const {};
    int read(Map<String, dynamic> m, String k) => (m[k] as num?)?.toInt() ?? 0;
    return AddressInfo(
      chainFunded: read(chain, 'funded_txo_sum'),
      chainSpent: read(chain, 'spent_txo_sum'),
      mempoolFunded: read(mem, 'funded_txo_sum'),
      mempoolSpent: read(mem, 'spent_txo_sum'),
    );
  }

  /// Confirmed balance (on-chain only).
  int get confirmedBalance => chainFunded - chainSpent;

  /// Total = confirmed + unconfirmed received − unconfirmed sent.
  int get totalBalance =>
      confirmedBalance + (mempoolFunded - mempoolSpent);
}

/// Result of a broadcast attempt.
class BroadcastResult {
  final bool success;
  final String? txId;
  final String? message;

  const BroadcastResult({required this.success, this.txId, this.message});
}
