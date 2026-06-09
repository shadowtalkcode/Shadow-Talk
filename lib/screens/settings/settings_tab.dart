import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

/// Settings tab. Matches the XD dark style: big title, profile header card,
/// and a list of settings rows.
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 12, 24, 8),
              child: Text('Settings',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: AppColors.white,
                  )),
            ),
            // Profile header card
            
            const SizedBox(height: 16),
          ListTile(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
            title: Text("Profile",
          style: TextStyle(color: AppColors.white, fontSize: 16))),
          ListTile(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
            },
            title: Text("Notifications",
          style: TextStyle(color: AppColors.white, fontSize: 16)),
          ),
          ListTile(
            title: Text("Delete account",
          style: TextStyle(color: AppColors.white, fontSize: 16)),
          )
          ],
        ),
      ),
    );
  }
}
