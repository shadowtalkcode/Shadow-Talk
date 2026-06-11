import 'package:flutter/material.dart';

import '../../services/chat_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import 'live_chat_screen.dart';

/// "Select Contact" screen — opened from the + button on Chats. Its search
/// finds a real Shadow Talk user by phone number and opens a live chat.
class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  bool _searching = false;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _findAndOpen() async {
    final phone = _searchCtrl.text.trim();
    if (phone.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (!ChatService.instance.isReady) {
      await ChatService.instance.start();
    }
    final user = await ChatService.instance.findUserByPhone(phone);
    if (!mounted) return;
    if (user == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No Shadow Talk user with that number')),
      );
      return;
    }
    if (user.uid == ChatService.instance.uid) {
      messenger.showSnackBar(const SnackBar(content: Text("That's your own number")));
      return;
    }
    navigator.pushReplacement(
      MaterialPageRoute(
        builder: (_) => LiveChatScreen(
          peerUid: user.uid,
          peerName: user.name,
          peerPhoto: user.photo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppColors.white),
        titleSpacing: 0,
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: AppColors.white, fontSize: 18),
                cursorColor: AppColors.primary,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _findAndOpen(),
                decoration: const InputDecoration(
                  hintText: 'Enter phone number…',
                  hintStyle: TextStyle(color: AppColors.textDesc),
                  border: InputBorder.none,
                ),
              )
            : const Text('Select Contact',
                style: TextStyle(
                    fontFamily: 'Inter', fontSize: 22, fontWeight: FontWeight.w700)),
        actions: [
          if (_searching)
            IconButton(
              icon: const Icon(Icons.arrow_forward, color: AppColors.primary),
              onPressed: _findAndOpen,
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.white),
              onPressed: () => setState(() {}),
            ),
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search, color: AppColors.white),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _searchCtrl.clear();
            }),
          ),
          if (!_searching)
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
              ],
              onSelected: (_) => _invite(),
            ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person, size: 200, color: Color(0xFF4A4F5C)),
            const SizedBox(height: 8),
            const Text('No Shadow Talk Contacts',
                style: TextStyle(
                    color: AppColors.white, fontSize: 19, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text('Tap search to start a chat by phone number',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textDesc, fontSize: 14)),
            ),
            const SizedBox(height: 24),
            Material(
              color: AppColors.primary,
              child: InkWell(
                onTap: (){
                  _showInviteDialog(context);
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                  child: Text('INVITE FRIENDS',
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

  void _showInviteDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: const Color(0xFF221D34),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Invite Friends',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.white)),
            const SizedBox(height: 12),
            const Text(
              'Shadow Talk is more fun to use with friends. Would you like to invite them?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: AppColors.textDesc, height: 1.4),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Not Now',
                      style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Invite', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

  void _invite() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite link copied — share it with friends!')),
    );
  }
}
