import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// One of the attachment options the user can pick.
enum AttachmentOption { file, camera, gallery, audio, location, contact }

/// Grid of attachment options. Ported from attachments_items.xml (two rows of
/// three coloured circular icons).
class AttachmentSheet extends StatelessWidget {
  const AttachmentSheet({super.key});

  static Future<AttachmentOption?> show(BuildContext context) {
    return showModalBottomSheet<AttachmentOption>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const AttachmentSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = <_Item>[
      _Item(AttachmentOption.file, Icons.insert_drive_file, 'File', const Color(0xFF7E58FC)),
      _Item(AttachmentOption.camera, Icons.photo_camera, 'Camera', const Color(0xFFE0457B)),
      _Item(AttachmentOption.gallery, Icons.photo, 'Gallery', const Color(0xFFA347E0)),
      _Item(AttachmentOption.audio, Icons.headset, 'Audio', const Color(0xFFE9844A)),
      _Item(AttachmentOption.location, Icons.location_on, 'Location', const Color(0xFF28A745)),
      _Item(AttachmentOption.contact, Icons.person, 'Contact', const Color(0xFF4A90E2)),
    ];

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 20,
          children: [
            for (final item in items)
              InkWell(
                onTap: () => Navigator.pop(context, item.option),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
                      child: Icon(item.icon, color: Colors.white, size: 26),
                    ),
                    const SizedBox(height: 8),
                    Text(item.label,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Item {
  final AttachmentOption option;
  final IconData icon;
  final String label;
  final Color color;
  _Item(this.option, this.icon, this.label, this.color);
}
