import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/call_service.dart';
import '../../services/chat_service.dart';
import '../../services/profile_store.dart';
import '../../theme/app_colors.dart';
import '../onboarding/welcome_screen.dart';
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
            onTap: () => _confirmSignOut(context, deleteAccount: true),
            title: const Text("Delete account",
                style: TextStyle(color: AppColors.white, fontSize: 16)),
          )
          ],
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context, {required bool deleteAccount}) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xFF221D34),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Are you sure you want to delete your account?',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: AppColors.textDesc, height: 1.4),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel', style: TextStyle(color: AppColors.textDesc)),
                  ),
                  TextButton(
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      Navigator.pop(dialogContext);
                      // Tear down live listeners BEFORE revoking the auth token
                      // so RTDB streams don't throw permission-denied.
                      await CallService.instance.stop();
                      await ChatService.instance.stop();
                      await AuthService.instance.signOut();
                      await ProfileStore.instance.clear();
                      navigator.pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                        (route) => false,
                      );
                    },
                    child: Text('Delete',
                        style: const TextStyle(color: AppColors.red,fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
