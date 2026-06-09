import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../theme/app_colors.dart';

/// Contact / group info screen. Matches XD reference 08: full-bleed photo
/// header, dark info sheet, About Me / Phone cards, Block button and media tabs.
class ContactDetailsScreen extends StatelessWidget {
  final User user;
  const ContactDetailsScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.background,
            pinned: true,
            stretch: true,
            expandedHeight: 360,
            leading: const BackButton(color: Colors.white),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: IconButton(
                    icon: const Icon(Icons.search, color: Colors.white, size: 20),
                    onPressed: () {},
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _photoHeader(),
            ),
          ),
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -28),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.userName,
                                  style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.white)),
                              const SizedBox(height: 4),
                              Text(user.isGroup ? user.status : 'Active Now',
                                  style: const TextStyle(fontSize: 15, color: AppColors.textDesc)),
                            ],
                          ),
                        ),
                        const Icon(Icons.videocam, color: AppColors.white, size: 26),
                        const SizedBox(width: 18),
                        const Icon(Icons.call, color: AppColors.white, size: 24),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Text('About Me',
                                  style: TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.white)),
                              Spacer(),
                              Text('2 Aug a...',
                                  style: TextStyle(fontSize: 12, color: AppColors.textDesc)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(user.status,
                              style: const TextStyle(fontSize: 14, color: AppColors.textDesc, height: 1.4)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Card(
                      child: Row(
                        children: [
                          const Text('Phone number',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.white)),
                          const Spacer(),
                          Text(user.phone.isEmpty ? '+31 812 6666 6666' : user.phone,
                              style: const TextStyle(fontSize: 15, color: AppColors.primary)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Block user
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.red,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      alignment: Alignment.center,
                      child: Text(user.isBlocked ? 'Unblock user' : 'Block user',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                    const SizedBox(height: 24),
                    _MediaTabs(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoHeader() {
    if (user.localPhoto != null) {
      return Image.asset(user.localPhoto!, fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => Container(color: AppColors.surface));
    }
    return Container(
      color: AppColors.surface,
      alignment: Alignment.center,
      child: Icon(user.isGroup ? Icons.groups_rounded : Icons.person,
          size: 120, color: AppColors.iconTint),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class _MediaTabs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const tabs = ['Media', 'Links', 'Docs', 'Groups'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < tabs.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 24),
                child: Column(
                  children: [
                    Text(tabs[i],
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w400,
                            color: i == 0 ? AppColors.primary : AppColors.textDesc)),
                    const SizedBox(height: 4),
                    if (i == 0)
                      Container(width: 22, height: 2, color: AppColors.primary),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (final img in ['image1.png', 'image2.png', 'image3.png', 'lady.png', 'dua.jpg', 'taylor.jpg'])
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset('assets/images/$img', fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Container(color: AppColors.surface)),
              ),
          ],
        ),
      ],
    );
  }
}
