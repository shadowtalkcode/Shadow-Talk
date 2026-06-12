import 'dart:async';
import 'dart:convert';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bitchat/binary_protocol.dart';
import 'bitchat/bitchat_identity.dart';
import 'bitchat/identity_announcement.dart';
import 'profile_store.dart';

void _log(String m) => debugPrint('🔵 BLE: $m');

const int _ttl = 7; // mesh hops (Android MESSAGE_TTL_HOPS)
const int _announceIntervalSecs = 30; // Android ANNOUNCE_INTERVAL_MS
const int _stalePeerSecs = 180; // Android STALE_PEER_TIMEOUT_MS (3 min)

/// A message in the offline broadcast mesh.
class OfflineMessage {
  final String sender;
  final String text;
  final bool fromMe;
  final bool system;
  final int ts;
  OfflineMessage({
    required this.sender,
    required this.text,
    required this.fromMe,
    required this.system,
    required this.ts,
  });
}

/// A mesh peer (identified by its bitchat peerID), learned from a verified
/// ANNOUNCE — not tied to a single BLE link (peers can be multi-hop).
class _Peer {
  String nickname;
  bool verified;
  Uint8List? signingKey;
  int lastSeen;
  _Peer(this.nickname, this.verified, this.signingKey, this.lastSeen);
}

/// One direct Bluetooth link to a nearby device (a mesh edge).
class _Link {
  final String id; // peer uuid (peripheral.uuid or central.uuid)
  final bool weAreCentral;
  final Peripheral? peripheral;
  final GATTCharacteristic? characteristic;
  final Central? central;
  _Link({
    required this.id,
    required this.weAreCentral,
    this.peripheral,
    this.characteristic,
    this.central,
  });
}

/// Offline **broadcast mesh** chat over Bluetooth LE — a byte-compatible port of
/// the Android "Offline Chat" (bitchat). It speaks bitchat's exact wire format:
/// the same GATT service/characteristic UUIDs, the same binary packet layout
/// (`BinaryProtocol`), signed identity ANNOUNCEs (Ed25519) with TLV-encoded
/// public keys, broadcast MESSAGE packets, TTL relay and seen-packet dedup — so
/// a Flutter device meshes with an Android bitchat device in the public room.
///
/// (Private 1:1 messages use Noise encryption in bitchat; this port implements
/// the public broadcast room, which is unencrypted on the wire by design.)
/// Needs real Bluetooth hardware — the iOS Simulator reports `unsupported`.
class OfflineChatService {
  OfflineChatService._();
  static final OfflineChatService instance = OfflineChatService._();

  // EXACT bitchat identifiers (Android AppConstants).
  static final UUID serviceUuid =
      UUID.fromString('F47B5E2D-4A9E-4C5A-9B3F-8E1D2C3A4B5C');
  static final UUID messageCharUuid =
      UUID.fromString('A1B2C3D4-E5F6-4A5B-8C9D-0E1F2A3B4C5D');

  final CentralManager _central = CentralManager();
  final PeripheralManager _peripheral = PeripheralManager();
  final BitchatIdentity _identity = BitchatIdentity();

  // ---- Observable state ----
  final ValueNotifier<BluetoothLowEnergyState> state =
      ValueNotifier(BluetoothLowEnergyState.unknown);
  final ValueNotifier<List<OfflineMessage>> messages = ValueNotifier(const []);
  final ValueNotifier<List<String>> peers = ValueNotifier(const []);
  final ValueNotifier<String> nickname = ValueNotifier('');

  GATTCharacteristic? _localCharacteristic;
  final List<_Link> _links = [];
  final Map<String, _Peer> _peers = {}; // peerHex → peer
  final Set<String> _seen = {}; // packet dedup keys
  final Set<String> _connecting = {};
  bool _started = false;
  bool _identityReady = false;
  bool _scanning = false;
  bool _advertising = false;
  Timer? _announceTimer;
  final _subs = <StreamSubscription>[];

  bool get isReady => state.value == BluetoothLowEnergyState.poweredOn;
  int get peerCount => peers.value.length;

  // ---- Lifecycle ---------------------------------------------------------
  Future<void> init() async {
    if (_started) return;
    _started = true;

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('offline_nick');
    final base = (stored == null || stored.isEmpty)
        ? (ProfileStore.instance.name.isEmpty ? 'anon' : ProfileStore.instance.name)
        : stored;
    nickname.value = base.length > 15 ? base.substring(0, 15) : base;

    try {
      await _identity.init();
      _identityReady = true;
      _log('identity ready peerID=${_identity.peerIDHex}');
    } catch (e) {
      _log('identity init failed: $e');
    }

    state.value = _central.state;
    _subs.add(_central.stateChanged.listen((e) {
      state.value = e.state;
      _log('state → ${e.state}');
      if (e.state == BluetoothLowEnergyState.poweredOn) _startAll();
    }));

    // Central role
    _subs.add(_central.discovered.listen(_onDiscovered));
    _subs.add(_central.characteristicNotified.listen((e) {
      final link = _links.firstWhere(
        (l) => l.weAreCentral && l.peripheral?.uuid == e.peripheral.uuid,
        orElse: () => _noLink,
      );
      _onReceive(e.value, link == _noLink ? null : link);
    }));
    _subs.add(_central.connectionStateChanged.listen((e) {
      if (e.state == ConnectionState.disconnected) {
        _removeLink(e.peripheral.uuid.toString());
      }
    }));

    // Peripheral role
    _subs.add(_peripheral.characteristicWriteRequested.listen((e) async {
      try {
        await _peripheral.respondWriteRequest(e.request);
      } catch (_) {}
      final link = _ensureCentralLink(e.central);
      _onReceive(e.request.value, link);
    }));
    _subs.add(_peripheral.characteristicNotifyStateChanged.listen((e) {
      if (e.state) _ensureCentralLink(e.central);
    }));

    try {
      await _central.authorize();
      await _peripheral.authorize();
    } catch (e) {
      _log('authorize failed: $e');
    }
    state.value = _central.state;
    if (isReady) await _startAll();
  }

  final _Link _noLink = _Link(id: '', weAreCentral: true);

  Future<void> _startAll() async {
    await _setupPeripheral();
    await _startScan();
    _announceTimer?.cancel();
    _announceTimer = Timer.periodic(
        const Duration(seconds: _announceIntervalSecs), (_) {
      _sendAnnounce(null);
      _pruneStalePeers();
    });
  }

  Future<void> setNickname(String value) async {
    var v = value.trim();
    if (v.isEmpty) return;
    if (v.length > 15) v = v.substring(0, 15);
    nickname.value = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('offline_nick', v);
    if (isReady) {
      try {
        await _peripheral.stopAdvertising();
        await _peripheral.startAdvertising(
            Advertisement(name: v, serviceUUIDs: [serviceUuid]));
      } catch (_) {}
      // Re-announce so peers pick up the new nickname immediately.
      _sendAnnounce(null);
    }
  }

  // ---- Peripheral (be discoverable) -------------------------------------
  Future<void> _setupPeripheral() async {
    if (!isReady || _advertising) return;
    try {
      _localCharacteristic = GATTCharacteristic.mutable(
        uuid: messageCharUuid,
        properties: [
          GATTCharacteristicProperty.read,
          GATTCharacteristicProperty.write,
          GATTCharacteristicProperty.writeWithoutResponse,
          GATTCharacteristicProperty.notify,
        ],
        permissions: [
          GATTCharacteristicPermission.read,
          GATTCharacteristicPermission.write,
        ],
        descriptors: [],
      );
      final service = GATTService(
        uuid: serviceUuid,
        isPrimary: true,
        includedServices: [],
        characteristics: [_localCharacteristic!],
      );
      await _peripheral.removeAllServices();
      await _peripheral.addService(service);
      await _peripheral.startAdvertising(
          Advertisement(name: nickname.value, serviceUUIDs: [serviceUuid]));
      _advertising = true;
      _log('advertising service $serviceUuid');
    } catch (e) {
      _log('setupPeripheral failed: $e');
    }
  }

  // ---- Central (scan + auto-connect into the mesh) ----------------------
  Future<void> _startScan() async {
    if (!isReady || _scanning) return;
    try {
      await _central.startDiscovery(serviceUUIDs: [serviceUuid]);
      _scanning = true;
      _log('scanning…');
    } catch (e) {
      _log('startScan failed: $e');
    }
  }

  void _onDiscovered(DiscoveredEventArgs e) {
    final id = e.peripheral.uuid.toString();
    if (_connecting.contains(id)) return;
    if (_links.any((l) => l.weAreCentral && l.id == id)) return;
    _connecting.add(id);
    _connectToMesh(e.peripheral).whenComplete(() => _connecting.remove(id));
  }

  Future<void> _connectToMesh(Peripheral peripheral) async {
    try {
      await _central.connect(peripheral);
      try {
        // bitchat fragments only above 512 bytes; a high MTU keeps short
        // messages/announces single-packet.
        await _central.requestMTU(peripheral, mtu: 517);
      } catch (_) {}
      final services = await _central.discoverGATT(peripheral);
      final service = services.firstWhere((s) => s.uuid == serviceUuid,
          orElse: () => services.first);
      final ch =
          service.characteristics.firstWhere((c) => c.uuid == messageCharUuid);
      await _central.setCharacteristicNotifyState(peripheral, ch, state: true);
      final link = _Link(
        id: peripheral.uuid.toString(),
        weAreCentral: true,
        peripheral: peripheral,
        characteristic: ch,
      );
      _links.add(link);
      // Announce ourselves so the peer learns + verifies our identity.
      await _sendAnnounce(link);
      _log('linked to ${peripheral.uuid}');
    } catch (e) {
      _log('connectToMesh failed: $e');
    }
  }

  _Link _ensureCentralLink(Central central) {
    final id = central.uuid.toString();
    final existing = _links.where((l) => !l.weAreCentral && l.id == id).toList();
    if (existing.isNotEmpty) return existing.first;
    final link = _Link(id: id, weAreCentral: false, central: central);
    _links.add(link);
    // Announce to the freshly-connected central too.
    _sendAnnounce(link);
    return link;
  }

  void _removeLink(String id) {
    _links.removeWhere((l) => l.id == id);
    // If we've lost all direct links, the mesh is gone — drop peers.
    if (_links.isEmpty && _peers.isNotEmpty) {
      for (final p in _peers.values) {
        _appendSystem('${p.nickname} left the mesh');
      }
      _peers.clear();
      _refreshPeers();
    }
  }

  // ---- Outgoing packets --------------------------------------------------
  Future<void> _sendAnnounce(_Link? only) async {
    if (!_identityReady) return;
    final tlv = IdentityAnnouncement(
            nickname.value, _identity.noisePublicKey, _identity.signingPublicKey)
        .encode();
    if (tlv == null) return;
    final packet = BitchatPacket(
      type: MessageType.announce,
      senderID: _identity.senderID,
      timestamp: _now,
      payload: tlv,
      ttl: _ttl,
    );
    packet.signature = await _identity.sign(packet.toBinaryDataForSigning()!);
    final bytes = BinaryProtocol.encode(packet);
    if (bytes == null) return;
    if (only != null) {
      await _sendTo(only, bytes);
    } else {
      await _sendToAll(bytes, null);
    }
  }

  Future<void> broadcast(String text) async {
    final t = text.trim();
    if (t.isEmpty || !_identityReady) return;
    final packet = BitchatPacket(
      type: MessageType.message,
      senderID: _identity.senderID,
      recipientID: kBroadcastRecipient,
      timestamp: _now,
      payload: Uint8List.fromList(utf8.encode(t)),
      ttl: _ttl,
    );
    packet.signature = await _identity.sign(packet.toBinaryDataForSigning()!);
    _seen.add(_dedupKey(packet));
    _append(OfflineMessage(
        sender: nickname.value, text: t, fromMe: true, system: false, ts: _now));
    final bytes = BinaryProtocol.encode(packet);
    if (bytes != null) await _sendToAll(bytes, null);
  }

  // ---- Incoming packets --------------------------------------------------
  Future<void> _onReceive(List<int> raw, _Link? from) async {
    final packet = BinaryProtocol.decode(Uint8List.fromList(raw));
    if (packet == null) return;
    final senderHex = BitchatIdentity.bytesToPeerHex(packet.senderID);
    if (senderHex == _identity.peerIDHex) return; // our own packet, ignore

    final key = _dedupKey(packet);
    if (_seen.contains(key)) return;
    _seen.add(key);
    if (_seen.length > 5000) _seen.clear();

    switch (packet.type) {
      case MessageType.announce:
        await _handleAnnounce(packet, senderHex);
        break;
      case MessageType.message:
        _handleMessage(packet, senderHex);
        break;
      case MessageType.leave:
        _handleLeave(senderHex);
        break;
      default:
        break; // NOISE_*/FRAGMENT/etc. not handled in the public room
    }

    // Relay onward (TTL decremented). Signature stays valid (signed at TTL=0).
    if (packet.ttl > 0) {
      packet.ttl -= 1;
      final relay = BinaryProtocol.encode(packet);
      if (relay != null) await _sendToAll(relay, from?.id);
    }
  }

  Future<void> _handleAnnounce(BitchatPacket packet, String senderHex) async {
    final ann = IdentityAnnouncement.decode(packet.payload);
    if (ann == null) return;
    var verified = false;
    if (packet.signature != null) {
      verified = await BitchatIdentity.verify(
          packet.signature!, packet.toBinaryDataForSigning()!, ann.signingPublicKey);
    }
    final existing = _peers[senderHex];
    if (existing == null) {
      _peers[senderHex] =
          _Peer(ann.nickname, verified, ann.signingPublicKey, _now);
      if (verified) _appendSystem('${ann.nickname} joined the mesh');
    } else {
      existing.nickname = ann.nickname;
      existing.verified = existing.verified || verified;
      existing.signingKey = ann.signingPublicKey;
      existing.lastSeen = _now;
    }
    _refreshPeers();
  }

  void _handleMessage(BitchatPacket packet, String senderHex) {
    // Only broadcast messages are shown in the public room.
    final isBroadcast = packet.recipientID == null ||
        _eq(packet.recipientID!, kBroadcastRecipient);
    if (!isBroadcast) return;
    // Android drops public messages from unverified/unknown peers — mirror that.
    final peer = _peers[senderHex];
    if (peer == null || !peer.verified) {
      _log('dropping message from unverified peer $senderHex');
      return;
    }
    peer.lastSeen = _now;
    final text = utf8.decode(packet.payload, allowMalformed: true);
    _append(OfflineMessage(
        sender: peer.nickname,
        text: text,
        fromMe: false,
        system: false,
        ts: packet.timestamp == 0 ? _now : packet.timestamp));
  }

  void _handleLeave(String senderHex) {
    final peer = _peers.remove(senderHex);
    if (peer != null) {
      _appendSystem('${peer.nickname} left the mesh');
      _refreshPeers();
    }
  }

  void _pruneStalePeers() {
    final cutoff = _now - _stalePeerSecs * 1000;
    final stale = _peers.entries.where((e) => e.value.lastSeen < cutoff).toList();
    if (stale.isEmpty) return;
    for (final e in stale) {
      _peers.remove(e.key);
      _appendSystem('${e.value.nickname} left the mesh');
    }
    _refreshPeers();
  }

  // ---- BLE send ----------------------------------------------------------
  Future<void> _sendToAll(Uint8List bytes, String? exceptId) async {
    for (final link in [..._links]) {
      if (exceptId != null && link.id == exceptId) continue;
      await _sendTo(link, bytes);
    }
  }

  Future<void> _sendTo(_Link link, Uint8List value) async {
    try {
      if (link.weAreCentral) {
        await _central.writeCharacteristic(
          link.peripheral!,
          link.characteristic!,
          value: value,
          type: GATTCharacteristicWriteType.withResponse,
        );
      } else if (link.central != null && _localCharacteristic != null) {
        await _peripheral.notifyCharacteristic(link.central!, _localCharacteristic!,
            value: value);
      }
    } catch (e) {
      _log('send failed: $e');
    }
  }

  // ---- Helpers -----------------------------------------------------------
  /// Per-packet dedup key — type + sender + timestamp uniquely identifies a
  /// message across relays (its TTL/signature differ but these don't).
  String _dedupKey(BitchatPacket p) =>
      '${p.type}:${BitchatIdentity.bytesToPeerHex(p.senderID)}:${p.timestamp}';

  void _append(OfflineMessage m) => messages.value = [...messages.value, m];

  void _appendSystem(String text) => _append(OfflineMessage(
      sender: 'system', text: text, fromMe: false, system: true, ts: _now));

  void _refreshPeers() {
    final names = _peers.values.where((p) => p.verified).map((p) => p.nickname).toSet();
    peers.value = names.toList()..sort();
  }

  bool _eq(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  int get _now => DateTime.now().millisecondsSinceEpoch;

  Future<void> openSettings() async {
    try {
      await _central.showAppSettings();
    } catch (_) {}
  }
}
