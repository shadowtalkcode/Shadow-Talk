import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/user.dart';
import '../../services/chat_service.dart';
import '../../services/status_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/time_format.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';
import 'live_chat_screen.dart';
import '../status/story_viewer.dart';
import '../status/text_status_composer.dart';
import 'new_chat_screen.dart';

/// Chats tab. Matches XD reference 06: large "Chats" title, +/search square
/// buttons, a "My tale" status row, then the chat list and an Invite row.
class ChatsTab extends StatefulWidget {
  const ChatsTab({super.key});

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> {
  final _chat = ChatService.instance;
  Stream<List<ChatSummary>>? _chatsStream;

  @override
  void initState() {
    super.initState();
    _ensureStarted();
  }

  Future<void> _ensureStarted() async {
    if (!_chat.isReady) await _chat.start();
    if (mounted) setState(() => _chatsStream = _chat.chatsList());
  }

  void _openLive(ChatSummary s) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveChatScreen(
          peerUid: s.peerUid,
          peerName: s.peerName,
          peerPhoto: s.peerPhoto,
        ),
      ),
    );
  }

  Future<void> _newChat() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NewChatScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Builder(
          builder: (context) {
            return CustomScrollView(
              slivers: [
                // Header
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        const Text(
                          'Chats',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: AppColors.white,
                          ),
                        ),
                        const Spacer(),
                        SquareIconButton(icon: Icons.add, onTap: _newChat),
                        const SizedBox(width: 12),
                        SquareIconButton(icon: Icons.search, onTap: _newChat),
                      ],
                    ),
                  ),
                ),
                // Tales strip (My tale + friends' stories)
                SliverToBoxAdapter(child: _TalesStrip()),
                const SliverToBoxAdapter(
                  child: Divider(color: Color(0xFF2A2640), height: 1, indent: 24, endIndent: 24),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                // Live chats from Realtime Database
                SliverToBoxAdapter(
                  child: StreamBuilder<List<ChatSummary>>(
                    stream: _chatsStream,
                    builder: (context, snap) {
                      final chats = snap.data ?? const <ChatSummary>[];
                      if (chats.isEmpty) {
                        return _EmptyChats(onStart: _newChat);
                      }
                      return Column(
                        children: [
                          for (final c in chats)
                            _LiveChatRow(summary: c, onTap: () => _openLive(c)),
                        ],
                      );
                    },
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TalesStrip extends StatefulWidget {
  @override
  State<_TalesStrip> createState() => _TalesStripState();
}

class _TalesStripState extends State<_TalesStrip> {
  final _picker = ImagePicker();
  Future<List<UserTale>>? _future;

  @override
  void initState() {
    super.initState();
    _future = StatusService.instance.loadTales();
  }

  void _reload() {
    if (!mounted) return;
    final f = StatusService.instance.loadTales();
    setState(() {
      _future = f;
    });
  }

  void _showPosted() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 3),
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Status uploaded',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
  }

  Future<void> _addMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF221D34),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Add to my tale',
                    style: TextStyle(
                        color: AppColors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.text_fields, color: AppColors.primary),
              title: const Text('Text', style: TextStyle(color: AppColors.white)),
              onTap: () => Navigator.pop(sheet, 'text'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Photo', style: TextStyle(color: AppColors.white)),
              onTap: () => Navigator.pop(sheet, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera, color: AppColors.primary),
              title: const Text('Camera', style: TextStyle(color: AppColors.white)),
              onTap: () => Navigator.pop(sheet, 'camera'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'text') {
      final posted = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const TextStatusComposer()),
      );
      if (posted == true) {
        _reload();
        _showPosted();
      }
    } else {
      await _pickImage(choice == 'camera' ? ImageSource.camera : ImageSource.gallery);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await _picker.pickImage(
          source: source, maxWidth: 1280, maxHeight: 1280, imageQuality: 80);
      if (file == null) return;
      messenger.showSnackBar(const SnackBar(content: Text('Posting status…')));
      await StatusService.instance.postImageStatus(File(file.path));
      if (mounted) {
        _reload();
        _showPosted();
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Couldn't post photo: $e")));
    }
  }

  Future<void> _onMyTale(UserTale myTale) async {
    if (myTale.items.isEmpty) {
      await _addMenu();
      return;
    }
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF221D34),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility, color: AppColors.primary),
              title: const Text('View my tale', style: TextStyle(color: AppColors.white)),
              onTap: () => Navigator.pop(sheet, 'view'),
            ),
            ListTile(
              leading: const Icon(Icons.add, color: AppColors.primary),
              title: const Text('Add to my tale', style: TextStyle(color: AppColors.white)),
              onTap: () => Navigator.pop(sheet, 'add'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'view') {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => StoryViewer(tale: myTale)),
      );
      _reload();
    } else if (choice == 'add') {
      await _addMenu();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 108,
      child: FutureBuilder<List<UserTale>>(
        future: _future,
        builder: (context, snap) {
          final tales = snap.data ?? const <UserTale>[];
          final myTale = tales.isNotEmpty && tales.first.isMine
              ? tales.first
              : UserTale(uid: '', name: 'My tale', photo: null, items: const [], isMine: true);
          final friends = tales.where((t) => !t.isMine).toList();
          return ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
            children: [
              _TaleItem(
                label: 'My tale',
                onTap: () => _onMyTale(myTale),
                ring: myTale.items.isNotEmpty,
                seen: false,
                child: Stack(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surface,
                        border: myTale.items.isEmpty
                            ? Border.all(color: AppColors.primary, width: 2)
                            : null,
                        image: (myTale.photo != null && File(myTale.photo!).existsSync())
                            ? DecorationImage(image: FileImage(File(myTale.photo!)), fit: BoxFit.cover)
                            : null,
                      ),
                      child: (myTale.photo == null)
                          ? const Icon(Icons.photo_camera, color: Color(0xFF6B6880), size: 22)
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.background, width: 2),
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 12),
                      ),
                    ),
                  ],
                ),
              ),
              for (final t in friends)
                _TaleItem(
                  label: t.name,
                  ring: true,
                  seen: t.allSeen,
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => StoryViewer(tale: t)),
                    );
                    _reload();
                  },
                  child: _TaleAvatar(tale: t),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Circular avatar for a friend's tale (network photo / initial).
class _TaleAvatar extends StatelessWidget {
  final UserTale tale;
  const _TaleAvatar({required this.tale});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = tale.photo != null && tale.photo!.startsWith('http');
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
        image: hasPhoto
            ? DecorationImage(image: NetworkImage(tale.photo!), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: hasPhoto
          ? null
          : Text(tale.name.isNotEmpty ? tale.name[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600)),
    );
  }
}

class _TaleItem extends StatelessWidget {
  final String label;
  final Widget child;
  final bool ring;
  final bool seen;
  final VoidCallback onTap;
  const _TaleItem({
    required this.label,
    required this.child,
    required this.onTap,
    this.ring = true,
    this.seen = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        margin: const EdgeInsets.only(right: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: ring
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: seen ? AppColors.grey : AppColors.primary,
                        width: 2,
                      ),
                    )
                  : null,
              child: child,
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textDesc, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveChatRow extends StatelessWidget {
  final ChatSummary summary;
  final VoidCallback onTap;
  const _LiveChatRow({required this.summary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final peer = User(uid: summary.peerUid, userName: summary.peerName, localPhoto: summary.peerPhoto);
    final unread = summary.unread;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Avatar(user: peer, size: 56, showBorder: false),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(summary.peerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.white)),
                  const SizedBox(height: 4),
                  Text(
                    (summary.lastFromMe ? 'You: ' : '') + summary.lastText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, color: AppColors.textDesc),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  summary.lastTs == 0
                      ? ''
                      : TimeFormat.shortStamp(
                          DateTime.fromMillisecondsSinceEpoch(summary.lastTs)),
                  style: TextStyle(
                      fontSize: 12,
                      color: unread > 0 ? AppColors.primary : AppColors.textDesc),
                ),
                const SizedBox(height: 8),
                if (unread > 0)
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text('$unread',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                  )
                else
                  const SizedBox(height: 22),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChats extends StatelessWidget {
  final VoidCallback onStart;
  const _EmptyChats({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 70, 32, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.25),
                  AppColors.primary.withValues(alpha: 0.08),
                ],
              ),
            ),
            child: const Icon(Icons.forum_rounded, size: 52, color: AppColors.primary),
          ),
          const SizedBox(height: 22),
          const Text(
            'No conversations yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start a new conversation by searching for\na friend\u2019s phone number.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textDesc, fontSize: 15, height: 1.45),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onStart,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                gradient: AppColors.purpleGradient,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_comment_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text('Start a chat',
                      style: TextStyle(
                          color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
