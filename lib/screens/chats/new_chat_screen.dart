import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/common.dart';

/// "Select Contact" screen — opened from the + button on Chats. Matches the
/// provided design: AppBar (back · title · refresh · search · ⋮) and an empty
/// state with a person icon, a message, and an INVITE button.
class NewChatScreen extends StatelessWidget {
  const NewChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppColors.white),
        titleSpacing: 0,
        title: const Text('Select Contact',
            style: TextStyle(
                fontFamily: 'Inter', fontSize: 22, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.white),
            onPressed: () {},
          ),
          PopupMenuButton<String>(
            color: AppColors.cardBg,
            icon: const Icon(Icons.more_vert, color: AppColors.white),
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'group',
                  child: Text('New group', style: TextStyle(color: AppColors.white))),
              PopupMenuItem(
                  value: 'invite',
                  child: Text('Invite a friend', style: TextStyle(color: AppColors.white))),
              PopupMenuItem(
                  value: 'help',
                  child: Text('Contacts help', style: TextStyle(color: AppColors.white))),
            ],
            onSelected: (_) => _invite(context),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person, size: 220, color: Color(0xFF4A4F5C)),
            const SizedBox(height: 8),
            const Text('No Shadow Talk Contacts',
                style: TextStyle(
                    color: AppColors.white, fontSize: 19, fontWeight: FontWeight.w500)),
            const SizedBox(height: 24),
            Material(
              color: AppColors.primary,
              child: InkWell(
                onTap: () => _invite(context),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  child: Text('INVITE',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _invite(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite link copied — share it with friends!')),
    );
  }
}
