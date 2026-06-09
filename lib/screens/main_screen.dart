import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'btc/offline_btc_screen.dart';
import 'calls/calls_tab.dart';
import 'chats/chats_tab.dart';
import 'settings/settings_tab.dart';

/// Hosts the four bottom-navigation destinations from the XD design:
/// Chats · Calls · Groups · Settings.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;

  final _tabs = const [
    ChatsTab(),
    CallsTab(),
    OfflineBtcScreen(),
    SettingsTab(),
  ];

  static const _items = [
    (Icons.forum_rounded, 'Chats'),
    (Icons.call, 'Calls'),
    (Icons.currency_bitcoin, 'Bitcoin'),
    (Icons.settings, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.bgGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: IndexedStack(index: _index, children: _tabs),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF211C33),
            border: Border(top: BorderSide(color: Color(0xFF2A2640))),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(
                children: List.generate(_items.length, (i) {
                  final active = i == _index;
                  final (icon, label) = _items[i];
                  return Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _index = i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon,
                              size: 26,
                              color: active ? AppColors.primary : AppColors.textDesc),
                          const SizedBox(height: 4),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              color: active ? AppColors.primary : AppColors.textDesc,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
