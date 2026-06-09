import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// "Add Tale" screen. Matches XD reference 14: Text/Camera buttons + a gallery
/// grid (display only).
class AddTaleScreen extends StatelessWidget {
  const AddTaleScreen({super.key});

  static const _gallery = [
    'image1.png', 'image2.png', 'image3.png', 'lady.png', 'dua.jpg',
    'taylor.jpg', 'angelina.jpg', 'image4.png', 'profile_pic.png',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 16, 8),
              child: Row(
                children: [
                  const Text('Add Tale',
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.white)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  _typeButton(Icons.title, 'Text', filled: false),
                  const SizedBox(width: 16),
                  _typeButton(Icons.photo_camera, 'Camera', filled: true),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text('Gallery',
                  style: TextStyle(
                      color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(width: 60, child: Divider(color: AppColors.primary, thickness: 2)),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.count(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                crossAxisCount: 3,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
                children: [
                  for (final g in _gallery)
                    Image.asset('assets/images/$g', fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) =>
                            Container(color: AppColors.surface)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeButton(IconData icon, String label, {required bool filled}) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 64,
          decoration: BoxDecoration(
            color: filled ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary, width: 1.5),
          ),
          child: Icon(icon, color: filled ? Colors.white : AppColors.primary, size: 28),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: AppColors.textDesc, fontSize: 13)),
      ],
    );
  }
}
