import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:share_plus/share_plus.dart';

import '../../../theme/design_system.dart';

/// Compact job card used on the professional home — brand design system.
class JobCardWidget extends StatelessWidget {
  final String companyName;
  final String? role;
  final String? city;
  final String? jobId;
  final int applicants;
  final bool isApplying;
  final bool isApplied;
  final bool isSaved;
  final VoidCallback? onApplyNow;
  final VoidCallback? onSaveToggle;

  const JobCardWidget({
    super.key,
    required this.companyName,
    this.role,
    this.city,
    this.jobId,
    this.applicants = 0,
    this.isApplying = false,
    this.isApplied = false,
    this.isSaved = false,
    this.onApplyNow,
    this.onSaveToggle,
  });

  void _share() {
    const url = 'https://wheelboard.app';
    final text = '🚛 Job Opening at $companyName!\n\n'
        '${(role ?? '').isNotEmpty ? '📋 Role: $role\n' : ''}'
        '${(city ?? '').isNotEmpty ? '📍 Location: $city\n' : ''}'
        '👥 Openings: $applicants\n\n'
        'Apply now on WheelBoard:\n$url';
    Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: AppPalette.primaryLight, borderRadius: AppRadius.rMd),
              child: const Icon(Iconsax.building_4,
                  color: AppPalette.primary, size: 19),
            ),
            AppSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(companyName,
                      style: AppText.subtitle.on(AppPalette.primary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if ((role ?? '').isNotEmpty)
                    Text(role!,
                        style: AppText.bodySm,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            GestureDetector(
              onTap: onSaveToggle,
              child: Icon(
                isSaved ? Iconsax.archive_tick5 : Iconsax.archive_1,
                size: 22,
                color: isSaved ? AppPalette.primary : AppPalette.textFaint,
              ),
            ),
          ]),
          if ((city ?? '').isNotEmpty || applicants > 0) ...[
            AppSpacing.vGapMd,
            Wrap(spacing: 8, runSpacing: 8, children: [
              if ((city ?? '').isNotEmpty) _chip(Iconsax.location, city!),
              if (applicants > 0)
                _chip(Iconsax.people, '$applicants openings'),
            ]),
          ],
          AppSpacing.vGapMd,
          Row(children: [
            Expanded(
              child: AppSecondaryButton(
                label: 'Share',
                icon: Iconsax.share,
                color: AppPalette.textMid,
                onPressed: _share,
              ),
            ),
            AppSpacing.hGapMd,
            Expanded(
              child: AppPrimaryButton(
                label: isApplied ? 'Applied' : 'Apply now',
                icon: isApplied ? Iconsax.tick_circle : Iconsax.send_2,
                loading: isApplying,
                color: isApplied ? AppPalette.textFaint : AppPalette.primary,
                onPressed: isApplied ? null : onApplyNow,
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration:
          BoxDecoration(color: AppPalette.bg, borderRadius: AppRadius.rPill),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: AppPalette.textGrey),
        const SizedBox(width: 5),
        Text(text, style: AppText.caption.on(AppPalette.textMid)),
      ]),
    );
  }
}
