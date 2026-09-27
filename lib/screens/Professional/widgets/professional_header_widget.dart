import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../controllers/Transport/notification_controller.dart';
import '../../../theme/design_system.dart';
import '../Notification1/Notification1Screen.dart';
import '../Search/professional_search_screen.dart';
import '../YourProfile/YourProfileScreen.dart';

/// Professional header — brand gradient bar with profile, search and the
/// notification bell (now routing to the professional notifications screen,
/// which shows LR OTP — previously it wrongly opened the company screen).
class ProfessionalHeaderWidget extends StatelessWidget {
  const ProfessionalHeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Container(
        decoration: const BoxDecoration(
          gradient: AppPalette.brandGradient,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                _circleAction(
                  icon: Iconsax.menu_1,
                  onTap: () => Get.to(const YourProfileScreen()),
                ),
                const Spacer(),
                Text(
                  'WHEELBOARD',
                  style: AppText.h2.on(Colors.white).copyWith(letterSpacing: 1.4),
                ),
                const Spacer(),
                _circleAction(
                  icon: Iconsax.search_normal_1,
                  onTap: () => Get.to(() => const ProfessionalSearchScreen()),
                ),
                AppSpacing.hGapSm,
                Obx(() {
                  final ctrl = Get.isRegistered<NotificationController>()
                      ? Get.find<NotificationController>()
                      : Get.put(NotificationController());
                  final unread = ctrl.unreadCount;
                  return _circleAction(
                    icon: Iconsax.notification,
                    badge: unread > 0 ? (unread > 99 ? '99+' : '$unread') : null,
                    onTap: () => Get.to(() => const Notification1Screen()),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _circleAction({
    required IconData icon,
    required VoidCallback onTap,
    String? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 21),
          ),
          if (badge != null)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.all(3),
                constraints:
                    const BoxConstraints(minWidth: 18, minHeight: 18),
                decoration: BoxDecoration(
                  color: AppPalette.amber,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Center(
                  child: Text(badge,
                      style: AppText.micro.on(Colors.white).size(9)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
