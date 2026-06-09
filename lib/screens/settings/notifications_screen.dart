import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/common.dart';

/// Notifications settings screen. Matches the provided design: a master
/// toggle, a ringtone row, a vibrate toggle, and a battery-optimization item.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _newMessage = true;
  bool _vibrate = false;
  String _ringtone = 'Default';

  void _pickRingtone() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF221D34),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Ringtone',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.white)),
              ),
            ),
            for (final r in ['Default', 'Note', 'Chime', 'Pulse', 'None'])
              ListTile(
                title: Text(r, style: const TextStyle(color: AppColors.white)),
                trailing: _ringtone == r
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _ringtone = r);
                  Navigator.pop(sheetContext);
                },
              ),
            const SizedBox(height: 8),
          ],
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
        title: const Text('Notifications',
            style: TextStyle(
                fontFamily: 'Inter', fontSize: 22, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            _ToggleRow(
              label: 'New message notifications',
              value: _newMessage,
              onChanged: (v) => setState(() => _newMessage = v),
            ),
            _TapRow(
              label: 'Ringtone',
              subtitle: _ringtone,
              onTap: _pickRingtone,
            ),
            _ToggleRow(
              label: 'Vibrate',
              value: _vibrate,
              onChanged: (v) => setState(() => _vibrate = v),
            ),
            const SizedBox(height: 20),
            _TapRow(
              label: 'Ignore Battery Optimization',
              labelBold: true,
              description:
                  'In order to make sure that all messages delivered correctly you have to disable Battery Optimizations',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

/// A row with a label on the left and a Material switch on the right.
class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 19, color: AppColors.white)),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.white,
              activeTrackColor: AppColors.primary,
              inactiveThumbColor: const Color(0xFFBDBDBD),
              inactiveTrackColor: const Color(0xFF4A4760),
              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tappable row with a bold/regular label and an optional subtitle/description.
class _TapRow extends StatelessWidget {
  final String label;
  final bool labelBold;
  final String? subtitle;
  final String? description;
  final VoidCallback onTap;

  const _TapRow({
    required this.label,
    required this.onTap,
    this.labelBold = false,
    this.subtitle,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: labelBold ? 21 : 19,
                    fontWeight: labelBold ? FontWeight.w700 : FontWeight.w400,
                    color: AppColors.white)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!,
                  style: const TextStyle(fontSize: 14, color: AppColors.textDesc)),
            ],
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(description!,
                  style: const TextStyle(fontSize: 15, color: AppColors.textDesc, height: 1.4)),
            ],
          ],
        ),
      ),
    );
  }
}
