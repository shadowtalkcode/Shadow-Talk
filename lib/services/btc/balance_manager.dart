import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:path_provider/path_provider.dart';

import 'blockchain_api.dart';
import 'btc_wallet.dart';

/// App-wide balance + UTXO state, the Dart equivalent of the Android
/// `BalanceManager` singleton (backed by `UTXOStore` for offline caching).
///
/// Exposes confirmed / pending / total balances and the cached UTXO set used
/// by the offline transaction builder. UI listens via [ChangeNotifier];
/// [fetch] tries the network and silently falls back to the on-disk cache when
/// offline (mirroring the Android online/offline split).
class BalanceManager extends ChangeNotifier {
  BalanceManager._();
  static final BalanceManager instance = BalanceManager._();

  static const String _cacheFileName = 'utxo_cache.json';

  int _confirmed = 0;
  int _pending = 0;
  int _total = 0;
  bool _loading = false;
  String? _error;
  List<Utxo> _utxos = const [];

  int get confirmedSats => _confirmed;
  int get pendingSats => _pending;
  int get totalSats => _total;
  bool get isLoading => _loading;
  String? get error => _error;
  List<Utxo> get utxos => _utxos;

  String get totalFormatted => BtcFormat.satsToBtc(_total);
  String get confirmedFormatted => BtcFormat.satsToBtc(_confirmed);
  String get pendingFormatted => BtcFormat.satsToBtc(_pending);

  /// Fetch balance + UTXOs for [wallet]. On network failure, loads the cached
  /// snapshot so the wallet still works offline.
  Future<void> fetch(BtcWallet wallet) async {
    if (_loading) return;
    _loading = true;
    _error = null;
    _safeNotify();

    final address = wallet.address;
    try {
      final info = await BlockchainApi.getAddressInfo(address);
      final utxos = await BlockchainApi.getUtxos(address);

      _confirmed = info.confirmedBalance;
      _total = info.totalBalance;
      _pending = _total - _confirmed;
      _utxos = utxos;
      _error = null;

      await _saveCache(address);
    } catch (e) {
      // Offline / API error → use cache if we have it for this address.
      final restored = await _loadCache(address);
      if (!restored) {
        _error = 'Offline: no cached data';
      }
    } finally {
      _loading = false;
      _safeNotify();
    }
  }

  /// Notify listeners without crashing when the call happens mid-build.
  ///
  /// Screens call [fetch] from their `initState`, which runs while the route is
  /// being built; the synchronous `_loading = true` notify would otherwise make
  /// an already-mounted listener (e.g. the BTC tab) `setState` during build and
  /// throw. If we're inside the build/layout phase, defer to after the frame.
  void _safeNotify() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    } else {
      notifyListeners();
    }
  }

  /// Confirmed UTXOs only — what the offline sender is allowed to spend.
  List<Utxo> get spendableUtxos =>
      _utxos.where((u) => u.confirmed).toList(growable: false);

  // ---------------------------------------------------------------------------
  // Offline cache (UTXOStore)
  // ---------------------------------------------------------------------------

  Future<File> _cacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_cacheFileName');
  }

  Future<void> _saveCache(String address) async {
    try {
      final file = await _cacheFile();
      await file.writeAsString(jsonEncode({
        'address': address,
        'confirmed': _confirmed,
        'pending': _pending,
        'total': _total,
        'utxos': _utxos.map((u) => u.toJson()).toList(),
      }));
    } catch (_) {/* caching is best-effort */}
  }

  Future<bool> _loadCache(String address) async {
    try {
      final file = await _cacheFile();
      if (!await file.exists()) return false;
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      if (json['address'] != address) return false;
      _confirmed = (json['confirmed'] as num?)?.toInt() ?? 0;
      _pending = (json['pending'] as num?)?.toInt() ?? 0;
      _total = (json['total'] as num?)?.toInt() ?? _confirmed;
      _utxos = ((json['utxos'] as List<dynamic>?) ?? const [])
          .map((e) => Utxo.fromJson(e as Map<String, dynamic>))
          .toList();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Reset in-memory state (e.g. on sign-out). Does not delete the cache file.
  void reset() {
    _confirmed = 0;
    _pending = 0;
    _total = 0;
    _utxos = const [];
    _error = null;
    _safeNotify();
  }
}
