import 'package:flutter/material.dart';

import '../../../theme/design_system.dart';

/// Quick-action utility card — clean white surface with subtle elevation,
/// brand-tinted icon chip, and high-legibility title label.
class QuickActionButtonWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const QuickActionButtonWidget({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.card,
        borderRadius: AppRadius.rXl,
        border: Border.all(
          color: AppPalette.border.withValues(alpha: 0.8),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.rXl,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.rXl,
          splashColor: AppPalette.primary.withValues(alpha: 0.1),
          highlightColor: AppPalette.primary.withValues(alpha: 0.05),
          child: Container(
            height: 108,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppPalette.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: AppPalette.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: AppText.caption
                        .weight(FontWeight.w600)
                        .on(AppPalette.textDark),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
