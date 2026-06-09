import 'package:flutter/material.dart';

import '../models/user.dart';
import '../theme/app_colors.dart';

/// Circular avatar that shows the user's photo asset, or coloured initials
/// when no photo is available (e.g. contacts not in the gallery).
class Avatar extends StatelessWidget {
  final User user;
  final double size;
  final bool showBorder;

  const Avatar({
    super.key,
    required this.user,
    this.size = 60,
    this.showBorder = true,
  });

  static const _palette = [
    Color(0xFF7E58FC),
    Color(0xFF28A745),
    Color(0xFFE9844A),
    Color(0xFF4A90E2),
    Color(0xFFD64A7A),
    Color(0xFF11998E),
  ];

  Color get _bg {
    final h = user.uid.codeUnits.fold(0, (a, b) => a + b);
    return _palette[h % _palette.length];
  }

  String get _initials {
    final parts = user.userName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final border = showBorder
        ? Border.all(color: const Color(0xFFBDBDBD), width: 1)
        : null;

    Widget inner;
    if (user.isGroup && user.localPhoto == null) {
      inner = Container(
        color: AppColors.surface,
        alignment: Alignment.center,
        child: Icon(Icons.groups_rounded, size: size * 0.55, color: AppColors.iconTint),
      );
    } else if (user.localPhoto != null) {
      inner = Image.asset(
        user.localPhoto!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => _initialsAvatar(),
      );
    } else {
      inner = _initialsAvatar();
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, border: border),
      child: ClipOval(child: SizedBox(width: size, height: size, child: inner)),
    );
  }

  Widget _initialsAvatar() {
    return Container(
      color: _bg,
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
