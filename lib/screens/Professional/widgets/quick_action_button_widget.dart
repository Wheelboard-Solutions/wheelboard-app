import 'package:flutter/material.dart';

import '../../../theme/design_system.dart';

/// Quick-action tile — brand-tinted, flexible width (sizes to its parent, e.g.
/// an `Expanded` in a row). White icon chip + label on the brand gradient.
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
    final lines = title.split('\n');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 76,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          gradient: AppPalette.brandGradient,
          borderRadius: AppRadius.rLg,
          boxShadow: [
            BoxShadow(
              color: AppPalette.primary.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 5),
            ...lines.map(
              (line) => Text(
                line,
                // Six tiles share one row, so labels like "My Calendar" need
                // to wrap rather than truncate to "My Cal…".
                maxLines: lines.length == 1 ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppText.micro.on(Colors.white).size(10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
