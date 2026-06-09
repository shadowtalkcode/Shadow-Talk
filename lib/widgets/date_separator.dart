import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Centred date pill between message groups. Ported from row_day.xml.
class DateSeparator extends StatelessWidget {
  final String label;
  const DateSeparator({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.dayText,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
