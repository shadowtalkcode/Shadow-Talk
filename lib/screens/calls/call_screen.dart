import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../chats/add_people_screen.dart';

/// Voice/video call screen (display only). Matches XD references 10-12.
class CallScreen extends StatelessWidget {
  final User user;
  final bool isVideo;
  const CallScreen({super.key, required this.user, this.isVideo = false});

  @override
  Widget build(BuildContext context) {
    return isVideo ? _video(context) : _voice(context);
  }

  Widget _voice(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: AppColors.white),
        title: const Text('End-to-end encrypted',
            style: TextStyle(fontSize: 14, color: AppColors.textDesc)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF221D34),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surface,
                          image: user.localPhoto != null
                              ? DecorationImage(
                                  image: AssetImage(user.localPhoto!), fit: BoxFit.cover)
                              : null,
                        ),
                        child: user.localPhoto == null
                            ? const Icon(Icons.person, size: 90, color: AppColors.iconTint)
                            : null,
                      ),
                      const SizedBox(height: 24),
                      Text(user.userName,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.white)),
                      const SizedBox(height: 8),
                      const Text('Ringing...',
                          style: TextStyle(fontSize: 17, color: AppColors.textDesc)),
                    ],
                  ),
                ),
              ),
            ),
            _controls(context),
          ],
        ),
      ),
    );
  }

  Widget _video(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (user.localPhoto != null)
            Image.asset(user.localPhoto!, fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(color: AppColors.surface))
          else
            Container(color: AppColors.surface),
          Container(color: Colors.black.withValues(alpha: 0.25)),
          SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    const BackButton(color: Colors.white),
                    const Spacer(),
                    const Text('End-to-end encrypted',
                        style: TextStyle(fontSize: 14, color: Colors.white70)),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
                const Spacer(),
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam, color: Colors.white),
                      const SizedBox(width: 12),
                      Text('Sending video request to ${user.userName}',
                          style: const TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
                ),
                _controls(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _controls(BuildContext context) {
    Widget btn(IconData icon, {Color? bg, Color? fg, double size = 56}) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bg ?? AppColors.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(icon, color: fg ?? AppColors.white, size: 26),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          btn(Icons.volume_up),
          btn(Icons.videocam),
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: btn(Icons.call_end, bg: AppColors.red, size: 62),
          ),
          btn(Icons.mic, bg: AppColors.primary),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddPeopleScreen()),
            ),
            child: btn(Icons.person_add_alt_1),
          ),
        ],
      ),
    );
  }
}
