import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/material.dart';

import '../../services/offline_chat_service.dart';

/// Offline mesh chat — a faithful port of the Android "Offline Chat" (re-skinned
/// bitchat): monospace terminal aesthetic, `Shadow Talk/@nick` header with a
/// green peer-counter, an IRC-style `<@name> text [HH:mm:ss]` broadcast feed,
/// and a `type a message...` input with a green send button. Runs the Bluetooth
/// LE mesh in the background; on the simulator (no radio) it shows the
/// Bluetooth-required screen.
class OfflineChatScreen extends StatefulWidget {
  const OfflineChatScreen({super.key});

  @override
  State<OfflineChatScreen> createState() => _OfflineChatScreenState();
}

// bitchat (Shadow Talk re-skin) palette.
const _bg = Color(0xFF151122);
const _surface = Color(0xFF201C30);
const _surfaceVariant = Color(0xFF262236);
const _primary = Color(0xFF7E58FC);
const _green = Color(0xFF28A745);
const _onBg = Color(0xFFF8F9FA);
const _muted = Color(0xFF9B93B4);
const _error = Color(0xFFDC3545);
const _own = Color(0xFFFF9500);
const _mono = 'monospace';

class _OfflineChatScreenState extends State<OfflineChatScreen> {
  final _svc = OfflineChatService.instance;
  final _input = TextEditingController();
  final _nick = TextEditingController();
  final _scroll = ScrollController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _svc.init();
    _nick.text = _svc.nickname.value;
    _svc.nickname.addListener(_syncNick);
    _input.addListener(() {
      final has = _input.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  void _syncNick() {
    if (_nick.text != _svc.nickname.value) _nick.text = _svc.nickname.value;
  }

  @override
  void dispose() {
    _svc.nickname.removeListener(_syncNick);
    _input.dispose();
    _nick.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = _input.text.trim();
    if (t.isEmpty) return;
    _input.clear();
    await _svc.broadcast(t);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(0,
            duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
      }
    });
  }

  String _hms(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }

  // Per-peer colour: djb2 hash → HSV (sat .5, val .85), avoiding orange hues.
  Color _peerColor(String name) {
    var hash = 5381;
    for (final c in name.codeUnits) {
      hash = ((hash << 5) + hash) + c;
    }
    var hue = (hash.abs() % 360).toDouble();
    if ((hue - 30).abs() < 20) hue = (hue + 60) % 360;
    return HSVColor.fromAHSV(1, hue, 0.5, 0.85).toColor();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      endDrawer: _sidebar(),
      body: SafeArea(
        bottom: false,
        child: ValueListenableBuilder<BluetoothLowEnergyState>(
          valueListenable: _svc.state,
          builder: (context, state, _) {
            if (state != BluetoothLowEnergyState.poweredOn) {
              return _bluetoothGate(state);
            }
            return Column(
              children: [
                _header(),
                Container(height: 1, color: const Color(0x4D322C4A)),
                Expanded(child: _messages()),
                _inputBar(),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---- Header: "Shadow Talk/@nick" + peer counter -----------------------
  Widget _header() {
    return SizedBox(
      height: 42,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.arrow_back, color: _primary, size: 20),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 8),
            const Text('Shadow Talk/',
                style: TextStyle(
                    fontFamily: _mono,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _primary)),
            const Text('@',
                style: TextStyle(
                    fontFamily: _mono, fontSize: 15, color: Color(0xCC7E58FC))),
            // Editable nickname
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: IntrinsicWidth(
                child: TextField(
                  controller: _nick,
                  style: const TextStyle(
                      fontFamily: _mono, fontSize: 15, color: _primary),
                  cursorColor: _primary,
                  maxLength: 15,
                  decoration: const InputDecoration(
                    counterText: '',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (v) => _svc.setNickname(v),
                  onTapOutside: (_) {
                    FocusScope.of(context).unfocus();
                    _svc.setNickname(_nick.text);
                  },
                ),
              ),
            ),
            const Spacer(),
            const Text('#mesh',
                style: TextStyle(fontFamily: _mono, fontSize: 14, color: _green)),
            const SizedBox(width: 10),
            // Peer counter
            ValueListenableBuilder<List<String>>(
              valueListenable: _svc.peers,
              builder: (context, peers, _) {
                final connected = peers.isNotEmpty;
                final color = connected ? _green : _muted;
                return GestureDetector(
                  onTap: () => Scaffold.of(context).openEndDrawer(),
                  child: Row(
                    children: [
                      Icon(Icons.group, size: 16, color: color),
                      const SizedBox(width: 4),
                      Text('${peers.length}',
                          style: TextStyle(
                              fontFamily: _mono,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: color)),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---- Message feed ------------------------------------------------------
  Widget _messages() {
    return ValueListenableBuilder<List<OfflineMessage>>(
      valueListenable: _svc.messages,
      builder: (context, msgs, _) {
        if (msgs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'nobody else is here yet.\nopen Offline Chat on a nearby device to start the mesh.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: _mono, fontSize: 13, color: _muted, height: 1.5),
              ),
            ),
          );
        }
        final reversed = msgs.reversed.toList();
        return ListView.builder(
          controller: _scroll,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: reversed.length,
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: SelectableText.rich(_row(reversed[i])),
          ),
        );
      },
    );
  }

  TextSpan _row(OfflineMessage m) {
    final time = ' [${_hms(m.ts)}]';
    if (m.system) {
      return TextSpan(children: [
        TextSpan(
            text: '* ${m.text} *',
            style: const TextStyle(
                fontFamily: _mono,
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: _muted)),
        TextSpan(
            text: time,
            style: TextStyle(
                fontFamily: _mono,
                fontSize: 11,
                color: _muted.withValues(alpha: 0.6))),
      ]);
    }
    final isMe = m.fromMe;
    final nameColor = isMe ? _own : _peerColor(m.sender);
    final bodyColor = isMe ? _own : _onBg;
    final bodyWeight = isMe ? FontWeight.bold : FontWeight.normal;
    return TextSpan(
      style: const TextStyle(fontFamily: _mono, fontSize: 15),
      children: [
        TextSpan(text: '<@', style: TextStyle(color: nameColor)),
        TextSpan(
            text: m.sender,
            style: TextStyle(color: nameColor, fontWeight: FontWeight.w600)),
        TextSpan(text: '> ', style: TextStyle(color: nameColor)),
        TextSpan(text: m.text, style: TextStyle(color: bodyColor, fontWeight: bodyWeight)),
        TextSpan(
            text: time,
            style: TextStyle(
                fontSize: 11, color: _muted.withValues(alpha: 0.7))),
      ],
    );
  }

  // ---- Input bar ---------------------------------------------------------
  Widget _inputBar() {
    return Material(
      color: _surface,
      elevation: 2,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  style: const TextStyle(fontFamily: _mono, fontSize: 15, color: _primary),
                  cursorColor: _primary,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'type a message...',
                    hintStyle: TextStyle(
                        fontFamily: _mono, fontSize: 15, color: Color(0x80F8F9FA)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _hasText ? _send : null,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _hasText
                        ? _green.withValues(alpha: 0.85)
                        : _onBg.withValues(alpha: 0.3),
                  ),
                  child: const Icon(Icons.arrow_upward, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Sidebar (NETWORK / PEOPLE) ---------------------------------------
  Widget _sidebar() {
    return Drawer(
      width: 280,
      backgroundColor: _surfaceVariant,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              height: 42,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('NETWORK',
                      style: TextStyle(
                          fontFamily: _mono,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _onBg)),
                ),
              ),
            ),
            Container(height: 1, color: const Color(0x4D322C4A)),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.group, size: 15, color: _muted),
                  SizedBox(width: 8),
                  Text('PEOPLE',
                      style: TextStyle(
                          fontFamily: _mono, fontSize: 12, color: _muted)),
                ],
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<List<String>>(
                valueListenable: _svc.peers,
                builder: (context, peers, _) {
                  if (peers.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('No one connected',
                          style: TextStyle(
                              fontFamily: _mono, fontSize: 13, color: _muted)),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      for (final p in peers)
                        Card(
                          color: _surface,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                const Icon(Icons.settings_input_antenna,
                                    size: 16, color: _green),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(p,
                                      style: TextStyle(
                                          fontFamily: _mono,
                                          fontSize: 14,
                                          color: _peerColor(p))),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Bluetooth gate (matches Android BluetoothCheckScreen) ------------
  Widget _bluetoothGate(BluetoothLowEnergyState state) {
    final notSupported = state == BluetoothLowEnergyState.unsupported;
    final unauthorized = state == BluetoothLowEnergyState.unauthorized;
    return Stack(
      children: [
        Positioned(
          top: 4,
          left: 4,
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: _primary),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('ShadowTalk',
                    style: TextStyle(
                        fontFamily: _mono,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _primary)),
                const SizedBox(height: 28),
                Icon(
                  notSupported ? Icons.error_outline : Icons.bluetooth,
                  size: 64,
                  color: notSupported ? _error : _primary,
                ),
                const SizedBox(height: 16),
                Text(
                  notSupported
                      ? 'Bluetooth Not Supported'
                      : unauthorized
                          ? 'Bluetooth Permission Needed'
                          : 'Bluetooth Required',
                  style: TextStyle(
                      fontFamily: _mono,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: notSupported ? _error : _primary),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: notSupported
                      ? const Text(
                          'This device doesn’t support Bluetooth Low Energy. '
                          'Offline Chat needs a real iPhone with Bluetooth to '
                          'reach nearby users without the internet.',
                          style: TextStyle(
                              fontFamily: _mono, fontSize: 13, color: _onBg, height: 1.5),
                        )
                      : const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Shadow Talk needs Bluetooth to:',
                                style: TextStyle(
                                    fontFamily: _mono,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: _onBg)),
                            SizedBox(height: 10),
                            _Bullet('Discover nearby users'),
                            _Bullet('Create mesh network connections'),
                            _Bullet('Send and receive messages'),
                            _Bullet('Work without internet or servers'),
                          ],
                        ),
                ),
                if (!notSupported) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _svc.openSettings(),
                      child: Text(
                        unauthorized ? 'Open Settings' : 'Enable Bluetooth',
                        style: const TextStyle(
                            fontFamily: _mono, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text('• $text',
          style: const TextStyle(fontFamily: _mono, fontSize: 13, color: _muted)),
    );
  }
}
