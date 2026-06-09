import 'package:flutter/material.dart';

import '../../data/chat_repository.dart';
import '../../models/status_update.dart';
import '../../theme/app_colors.dart';
import '../../utils/time_format.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';

/// Tale (status/stories) list. Matches the XD dark style.
class TaleListScreen extends StatelessWidget {
  const TaleListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = ChatRepository.instance;
    final tales = repo.statuses;
    final unseen = tales.where((t) => !t.seen).toList();
    final seen = tales.where((t) => t.seen).toList();

    return GradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppColors.white),
        title: const Text('Tales',
            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        children: [
          // My tale
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            leading: Stack(
              children: [
                Avatar(user: repo.me, size: 56, showBorder: false),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 22,
                    height: 22,
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
            title: const Text('My tale',
                style: TextStyle(color: AppColors.white, fontSize: 17)),
            subtitle: const Text('Tap to add tale update',
                style: TextStyle(color: AppColors.textDesc, fontSize: 13)),
          ),
          if (unseen.isNotEmpty) const _Header('Recent updates'),
          for (final t in unseen) _TaleRow(tale: t),
          if (seen.isNotEmpty) const _Header('Viewed updates'),
          for (final t in seen) _TaleRow(tale: t),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String label;
  const _Header(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(label, style: const TextStyle(color: AppColors.textDesc, fontSize: 13)),
    );
  }
}

class _TaleRow extends StatelessWidget {
  final StatusUpdate tale;
  const _TaleRow({required this.tale});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: tale.seen ? AppColors.grey : AppColors.primary,
            width: 2.5,
          ),
        ),
        child: Avatar(user: tale.user, size: 48, showBorder: false),
      ),
      title: Text(tale.user.userName,
          style: const TextStyle(color: AppColors.white, fontSize: 17)),
      subtitle: Text(TimeFormat.shortStamp(tale.time),
          style: const TextStyle(color: AppColors.textDesc, fontSize: 13)),
    );
  }
}
