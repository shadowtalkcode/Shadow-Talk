import 'package:flutter/material.dart';

/// Color palette extracted directly from the Shadow Talk Adobe XD design.
class AppColors {
  AppColors._();

  // Core
  static const Color primary = Color(0xFF7E58FC); // #7E58FC
  static const Color primaryDark = Color(0xFF4B26BF); // gradient end
  static const Color background = Color(0xFF1C182A); // #1C182A
  static const Color cardBg = Color(0xFF262236); // cards / bubbles / inputs
  static const Color surface = Color(0xFF262236); // #262236
  static const Color surfaceAlt = Color(0xFF404360); // muted slate (waveform/inactive)
  static const Color btcBg = Color(0xFF151122);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF); // headings/body
  static const Color textDesc = Color(0xFFB4B5BA); // secondary text #B4B5BA
  static const Color textMuted = Color(0xFFBBBCBD);
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  // Lines / dividers
  static const Color divider = Color(0xFF2E2A40);
  static const Color thinDivider = Color(0xFF262236);

  // States / accents
  static const Color green = Color(0xFF80EA4E); // online dot #80EA4E
  static const Color red = Color(0xFFEA5659); // block/destructive #EA5659
  static const Color blue = Color(0xFF3AA0FF); // verified badge #3AA0FF
  static const Color pink = Color(0xFFFF95C9); // pink accent #FF95C9
  static const Color readState = Color(0xFF7E58FC);
  static const Color sentState = Color(0xFF80EA4E);
  static const Color typing = Color(0xFFB4B5BA);

  // Chat bubbles
  static const Color sentBubble = Color(0xFF7E58FC);
  static const Color receivedBubble = Color(0xFF262236);
  static const Color sentMessageText = Color(0xFFFFFFFF);
  static const Color receivedMessageText = Color(0xFFFFFFFF);
  static const Color messageTime = Color(0xFFB4B5BA);
  static const Color linkColor = Color(0xFF8498FC);

  // Badges
  static const Color unreadBadgeBg = Color(0xFF7E58FC);
  static const Color unreadBadgeText = Color(0xFFFFFFFF);

  // Icons
  static const Color iconTint = Color(0xFFB4B5BA);
  static const Color iconTintSuperLight = Color(0xFFE9ECEF);
  static const Color grey = Color(0xFF6C757D);

  // Misc
  static const Color dayText = Color(0xFF6F7680);
  static const Color hint = Color(0xFFB4B5BA);

  /// Subtle vertical background gradient seen on most artboards
  /// (slightly lighter toward the bottom).
  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1C182A), Color(0xFF211C32)],
  );

  /// Primary button / accent gradient.
  static const LinearGradient purpleGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF8A66FF), Color(0xFF7E58FC)],
  );
}
