import 'package:flutter/material.dart';

import '../../data/chat_repository.dart';
import '../../models/chat.dart';
import '../../models/enums.dart';
import '../../models/message.dart';
import '../../theme/app_colors.dart';
import '../../utils/time_format.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';
import '../status/add_tale_screen.dart';
import '../status/tale_list_screen.dart';
import 'chat_screen.dart';
import 'new_chat_screen.dart';

/// Chats tab. Matches XD reference 06: large "Chats" title, +/search square
/// buttons, a "My tale" status row, then the chat list and an Invite row.
class ChatsTab extends StatefulWidget {
  const ChatsTab({super.key});

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> {
  final _repo = ChatRepository.instance;

  void _openChat(Chat chat) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatScreen(chatId: chat.chatId)),
    );
  }

  Future<void> _newChat() async {
    final chat = await Navigator.of(context).push<Chat>(
      MaterialPageRoute(builder: (_) => const NewChatScreen()),
    );
    if (chat != null && mounted) _openChat(chat);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: _repo,
          builder: (context, _) {
            final chats = _repo.chats;
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
                        SquareIconButton(
                            icon: Icons.search,
                            onTap: () => showSearch(
                                context: context,
                                delegate: _ChatSearchDelegate(_repo))),
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
                // Chats
                SliverList.builder(
                  itemCount: chats.length,
                  itemBuilder: (context, i) => _ChatRow(
                    chat: chats[i],
                    onTap: () => _openChat(chats[i]),
                  ),
                ),
                // Invite friends
                SliverToBoxAdapter(child: _InviteRow()),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TalesStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tales = ChatRepository.instance.statuses;
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
        children: [
          // My tale
          _TaleItem(
            label: 'My tale',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddTaleScreen()),
            ),
            ring: false,
            child: Stack(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  child: const Icon(Icons.photo_camera, color: Color(0xFF6B6880), size: 22),
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
          for (final s in tales)
            _TaleItem(
              label: s.user.userName,
              ring: true,
              seen: s.seen,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TaleListScreen()),
              ),
              child: Avatar(user: s.user, size: 60, showBorder: false),
            ),
        ],
      ),
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

class _ChatRow extends StatelessWidget {
  final Chat chat;
  final VoidCallback onTap;
  const _ChatRow({required this.chat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final last = chat.lastMessage;
    final unread = chat.unreadCount;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Avatar(user: chat.user, size: 56, showBorder: false),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    chat.user.userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (chat.isTyping)
                        const Expanded(
                          child: Text('typing…',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 15, color: AppColors.primary)),
                        )
                      else
                        Expanded(
                          child: Text(
                            _preview(last),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, color: AppColors.textDesc),
                          ),
                        ),
                    ],
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
                  last == null ? '' : TimeFormat.shortStamp(last.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: unread > 0 ? AppColors.primary : AppColors.textDesc,
                  ),
                ),
                const SizedBox(height: 8),
                if (unread > 0)
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text('$unread',
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
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

  String _preview(Message? m) {
    if (m == null) return 'Tap to start chatting';
    switch (m.kind) {
      case MessageKind.text:
        return m.content;
      case MessageKind.image:
        return '📷 Photo';
      case MessageKind.voice:
        return '🎤 Voice message';
      case MessageKind.audio:
        return '🎵 Audio';
      case MessageKind.file:
        return '📄 ${m.fileName ?? 'Document'}';
      case MessageKind.location:
        return '📍 Location';
      case MessageKind.contact:
        return '👤 ${m.contactName ?? 'Contact'}';
      default:
        return '';
    }
  }
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
                  child: const Text('Note Now',
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

class _InviteRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showInviteDialog(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_add_alt_1, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Invite Friends',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.white)),
                  SizedBox(height: 4),
                  Text('More friends, more fun',
                      style: TextStyle(fontSize: 15, color: AppColors.textDesc)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

/// Search delegate styled for the dark theme.
class _ChatSearchDelegate extends SearchDelegate<void> {
  final ChatRepository repo;
  _ChatSearchDelegate(this.repo);

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(backgroundColor: AppColors.background),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: AppColors.textDesc),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: AppColors.white, fontSize: 18),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) =>
      [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];

  @override
  Widget buildLeading(BuildContext context) =>
      IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final chats = repo.searchChats(query);
    return Container(
      color: AppColors.background,
      child: ListView(
        children: [
          for (final c in chats)
            ListTile(
              leading: Avatar(user: c.user, size: 48, showBorder: false),
              title: Text(c.user.userName, style: const TextStyle(color: AppColors.white)),
              subtitle: Text(c.lastMessage?.content ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textDesc)),
              onTap: () {
                close(context, null);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ChatScreen(chatId: c.chatId)),
                );
              },
            ),
        ],
      ),
    );
  }
}
