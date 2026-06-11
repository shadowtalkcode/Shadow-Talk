import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../services/chat_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';
import 'call_launcher.dart';

/// "Select Contact" for placing a call — mirrors Android `NewCallActivity`.
/// Lists Shadow Talk contacts (chat partners) with a voice and a video call
/// button on each row.
class NewCallScreen extends StatefulWidget {
  const NewCallScreen({super.key});

  @override
  State<NewCallScreen> createState() => _NewCallScreenState();
}

class _NewCallScreenState extends State<NewCallScreen> {
  bool _searching = false;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _callByPhone(bool isVideo) async {
    final phone = _searchCtrl.text.trim();
    if (phone.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
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
    await startCall(context,
        peerUid: user.uid, peerName: user.name, peerPhoto: user.photo, isVideo: isVideo);
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
                onSubmitted: (_) => _callByPhone(false),
                decoration: const InputDecoration(
                  hintText: 'Call a phone number…',
                  hintStyle: TextStyle(color: AppColors.textDesc),
                  border: InputBorder.none,
                ),
              )
            : const Text('Select Contact',
                style: TextStyle(
                    fontFamily: 'Inter', fontSize: 22, fontWeight: FontWeight.w700)),
        actions: [
          if (_searching) ...[
            IconButton(
              icon: const Icon(Icons.call, color: AppColors.green),
              onPressed: () => _callByPhone(false),
            ),
            IconButton(
              icon: const Icon(Icons.videocam, color: AppColors.blue),
              onPressed: () => _callByPhone(true),
            ),
          ],
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search, color: AppColors.white),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _searchCtrl.clear();
            }),
          ),
        ],
      ),
      body: StreamBuilder<List<ChatSummary>>(
        stream: ChatService.instance.chatsList(),
        builder: (context, snap) {
          final contacts = snap.data ?? const <ChatSummary>[];
          if (contacts.isEmpty) {
            return _empty();
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: contacts.length,
            itemBuilder: (context, i) => _ContactRow(summary: contacts[i]),
          );
        },
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.contacts_outlined, size: 110, color: Color(0xFF4A4F5C)),
          const SizedBox(height: 12),
          const Text('No Shadow Talk Contacts',
              style: TextStyle(
                  color: AppColors.white, fontSize: 19, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text('Tap search to call by phone number',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textDesc, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final ChatSummary summary;
  const _ContactRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    final user = User(
      uid: summary.peerUid,
      userName: summary.peerName,
      localPhoto: summary.peerPhoto,
    );
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Avatar(user: user, size: 50, showBorder: false),
      title: Text(summary.peerName,
          style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.white)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.call, color: AppColors.green),
            onPressed: () => startCall(context,
                peerUid: summary.peerUid,
                peerName: summary.peerName,
                peerPhoto: summary.peerPhoto,
                isVideo: false),
          ),
          IconButton(
            icon: const Icon(Icons.videocam, color: AppColors.blue),
            onPressed: () => startCall(context,
                peerUid: summary.peerUid,
                peerName: summary.peerName,
                peerPhoto: summary.peerPhoto,
                isVideo: true),
          ),
        ],
      ),
    );
  }
}
