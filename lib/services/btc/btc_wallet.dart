import 'dart:convert';
import 'dart:io';

import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:path_provider/path_provider.dart';

import 'blockchain_api.dart';

/// Deterministic **testnet** Bitcoin wallet — the Dart counterpart of the
/// Android `WalletHelper`.
///
/// bitcoinj on Android creates a deterministic P2PKH wallet and persists it to
/// a file. Here the BIP39 mnemonic *is* the wallet: we persist just the
/// mnemonic and re-derive the (single) legacy receive key on demand along the
/// standard testnet path `m/44'/1'/0'/0/0`. Same network, same address format,
/// same blockstream API — so it behaves identically to the Android build.
class BtcWallet {
  BtcWallet._(this.mnemonic);

  final String mnemonic;

  static const BitcoinNetwork network = BitcoinNetwork.testnet;
  static const String _derivationPath = "m/44'/1'/0'/0/0";
  static const String _walletFileName = 'bitcoin_wallet.json';

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  static Future<File> _walletFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_walletFileName');
  }

  /// Whether a wallet has already been created on this device.
  static Future<bool> exists() async => (await _walletFile()).exists();

  /// Create a fresh 12-word wallet and persist it. Mirrors
  /// `WalletHelper.createWallet`.
  static Future<BtcWallet> create() async {
    final mnemonic = Bip39MnemonicGenerator()
        .fromWordsNumber(Bip39WordsNum.wordsNum12)
        .toStr();
    final wallet = BtcWallet._(mnemonic);
    await wallet._save();
    return wallet;
  }

  /// Load the persisted wallet, or `null` if none exists
  /// (`WalletHelper.loadWallet`).
  static Future<BtcWallet?> load() async {
    final file = await _walletFile();
    if (!await file.exists()) return null;
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final mnemonic = json['mnemonic'] as String?;
      if (mnemonic == null || mnemonic.isEmpty) return null;
      return BtcWallet._(mnemonic);
    } catch (_) {
      return null;
    }
  }

  /// Load the existing wallet or create one if absent.
  static Future<BtcWallet> loadOrCreate() async =>
      (await load()) ?? (await create());

  Future<void> _save() async {
    final file = await _walletFile();
    await file.writeAsString(jsonEncode({'mnemonic': mnemonic}));
  }

  // ---------------------------------------------------------------------------
  // Key derivation
  // ---------------------------------------------------------------------------

  ECPrivate get _privateKey {
    final seed = Bip39SeedGenerator(Mnemonic.fromString(mnemonic)).generate();
    final node = Bip32Slip10Secp256k1.fromSeed(seed).derivePath(_derivationPath);
    return ECPrivate.fromBytes(node.privateKey.raw);
  }

  P2pkhAddress get _p2pkh => _privateKey.getPublic().toAddress();

  /// The wallet's receiving address (`WalletHelper.getReceivingAddress`).
  String get address => _p2pkh.toAddress(network);

  /// Private key in WIF format (`WalletHelper.getPrivateKeyWIF`).
  String get privateKeyWif => _privateKey.toWif(network: network);

  /// 12-word mnemonic seed (`WalletHelper.getMnemonicSeed`).
  String get mnemonicSeed => mnemonic;

  static String get networkName => 'TestNet';

  // ---------------------------------------------------------------------------
  // Offline transaction building & signing (port of SenderActivity)
  // ---------------------------------------------------------------------------

  /// Build and sign a raw transaction entirely offline, from cached confirmed
  /// UTXOs, and return its hex. The recipient may be legacy (`m/n…`) or
  /// segwit (`tb1…`); change returns to this wallet's address.
  ///
  /// Throws [BtcTransactionException] with a user-facing message on any
  /// validation failure — matching the Toasts the Android sender shows.
  String buildSignedTransaction({
    required String recipientAddress,
    required int amountSats,
    required List<Utxo> utxos,
    int feeRate = 10,
    bool allowUnconfirmed = false,
  }) {
    // Prefer confirmed UTXOs; when [allowUnconfirmed] is set, also spend pending
    // (0-conf) funds — useful on testnet where waiting for confirmations is slow
    // and the user wants to forward funds they just received.
    final confirmed = utxos.where((u) => u.confirmed).toList();
    final spendable = <Utxo>[
      ...confirmed,
      if (allowUnconfirmed) ...utxos.where((u) => !u.confirmed),
    ];
    if (spendable.isEmpty) {
      throw const BtcTransactionException(
          'No spendable funds yet. Connect to the internet and refresh.');
    }

    final BasedUtxoNetwork net = network;
    final senderScript = _p2pkh.toScriptPubKey();

    final Script recipientScript;
    try {
      recipientScript =
          BitcoinAddress(recipientAddress, network: network).baseAddress.toScriptPubKey();
    } catch (_) {
      throw const BtcTransactionException('Invalid recipient address');
    }

    // Select inputs until we cover amount + a small fee buffer.
    final List<TxInput> inputs = [];
    final List<Utxo> used = [];
    int inputSum = 0;
    for (final u in spendable) {
      inputs.add(TxInput(txId: u.txid, txIndex: u.vout));
      used.add(u);
      inputSum += u.value;
      if (inputSum >= amountSats + 1000) break;
    }

    if (inputSum < amountSats) {
      throw const BtcTransactionException(
          'Insufficient balance for that amount plus the network fee');
    }

    // Outputs: recipient first, then (optionally) change.
    final outputs = <TxOutput>[
      TxOutput(amount: BigInt.from(amountSats), scriptPubKey: recipientScript),
    ];

    // Fee estimate ≈ 10 + inputs·148 + outputs·34 vbytes (P2PKH), then × rate.
    final estimatedSize = 10 + inputs.length * 148 + (outputs.length + 1) * 34;
    final fee = (estimatedSize * feeRate).clamp(1000, 1 << 30);
    final change = inputSum - amountSats - fee;

    if (change > 546) {
      outputs.add(TxOutput(amount: BigInt.from(change), scriptPubKey: senderScript));
    } else if (change < 0) {
      throw BtcTransactionException(
          'Insufficient balance to cover amount + network fee '
          '(${BtcFormat.satsToBtc(fee)} BTC)');
    }

    final tx = BtcTransaction(inputs: inputs, outputs: outputs);

    // Sign every input (legacy P2PKH, SIGHASH_ALL).
    final pubHex = _privateKey.getPublic().toHex();
    for (int i = 0; i < inputs.length; i++) {
      final digest = tx.getTransactionDigest(txInIndex: i, script: senderScript);
      final signature = _privateKey.signECDSA(digest);
      inputs[i].scriptSig = Script(script: [signature, pubHex]);
    }

    // Keep `net` referenced for callers that inspect the network constant.
    assert(net == network);
    return tx.serialize();
  }
}

/// Raised when a transaction cannot be built/validated; [message] is safe to
/// surface directly to the user.
class BtcTransactionException implements Exception {
  final String message;
  const BtcTransactionException(this.message);
  @override
  String toString() => message;
}

/// Satoshi/BTC formatting helpers (port of `WalletHelper.formatSatoshisToBTC`).
class BtcFormat {
  BtcFormat._();

  static const int satsPerBtc = 100000000;

  /// `123456` → `"0.00123456"` (always 8 decimals, like the Android UI).
  static String satsToBtc(int sats) =>
      (sats / satsPerBtc).toStringAsFixed(8);

  /// Parse a user-entered BTC amount string into satoshis. Returns `null` if
  /// the input isn't a valid positive number.
  static int? btcToSats(String btc) {
    final value = double.tryParse(btc.trim());
    if (value == null || value <= 0) return null;
    return (value * satsPerBtc).round();
  }
}
