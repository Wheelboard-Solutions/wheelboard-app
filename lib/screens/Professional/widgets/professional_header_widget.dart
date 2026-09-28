import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../controllers/Transport/notification_controller.dart';
import '../../../core/auth/auth_service.dart';
import '../../../theme/design_system.dart';
import '../Notification1/Notification1Screen.dart';
import '../Search/professional_search_screen.dart';
import '../YourProfile/YourProfileScreen.dart';

/// Professional header — brand gradient bar with profile, search, notification bell
/// and an animated entrance (slide from left + smooth fade), 4s hold, bold welcome text,
/// and auto-disappearing top bar collapse.
class ProfessionalHeaderWidget extends StatefulWidget {
  const ProfessionalHeaderWidget({super.key});

  @override
  State<ProfessionalHeaderWidget> createState() =>
      _ProfessionalHeaderWidgetState();
}

class _ProfessionalHeaderWidgetState extends State<ProfessionalHeaderWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideIn;
  late Animation<double> _fadeOut;
  late Animation<double> _sizeFactor;

  String get _firstName {
    try {
      final user = AuthService.to.currentUser.value;
      final first = user?.profile['firstName']?.toString() ?? '';
      if (first.isNotEmpty) return first;
      final full = user?.fullName ?? '';
      if (full.isNotEmpty) return full.split(' ').first;
      return 'Driver';
    } catch (_) {
      return 'Driver';
    }
  }

  @override
  void initState() {
    super.initState();

    // Total duration: 5.5s (800ms enter, 4000ms hold, 700ms exit/collapse)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5500),
    );

    // 1. Left to right slide + smooth fade in (0ms to 800ms)
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.145, curve: Curves.easeOut),
      ),
    );

    _slideIn = Tween<Offset>(
      begin: const Offset(-0.6, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.145, curve: Curves.easeOutCubic),
      ),
    );

    // 2. Hold for 4 seconds (800ms to 4800ms)
    // 3. Fade out text (4800ms to 5300ms)
    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.872, 0.963, curve: Curves.easeIn),
      ),
    );

    // 4. Shrink top bar height smoothly (5000ms to 5500ms)
    _sizeFactor = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.909, 1.0, curve: Curves.easeInOutCubic),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _circleAction(
                      icon: Iconsax.menu_1,
                      onTap: () => Get.to(const YourProfileScreen()),
                    ),
                    const Spacer(),
                    Text(
                      'WHEELBOARD',
                      style: AppText.h2
                          .on(Colors.white)
                          .copyWith(letterSpacing: 1.4),
                    ),
                    const Spacer(),
                    _circleAction(
                      icon: Iconsax.search_normal_1,
                      onTap: () =>
                          Get.to(() => const ProfessionalSearchScreen()),
                    ),
                    AppSpacing.hGapSm,
                    Obx(() {
                      final ctrl =
                          Get.isRegistered<NotificationController>()
                              ? Get.find<NotificationController>()
                              : Get.put(NotificationController());
                      final unread = ctrl.unreadCount;
                      return _circleAction(
                        icon: Iconsax.notification,
                        badge: unread > 0
                            ? (unread > 99 ? '99+' : '$unread')
                            : null,
                        onTap: () => Get.to(() => const Notification1Screen()),
                      );
                    }),
                  ],
                ),
                SizeTransition(
                  sizeFactor: _sizeFactor,
                  axisAlignment: -1.0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppSpacing.vGapSm,
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          final opacity = (_fadeIn.value * _fadeOut.value)
                              .clamp(0.0, 1.0);
                          return Opacity(
                            opacity: opacity,
                            child: SlideTransition(
                              position: _slideIn,
                              child: child,
                            ),
                          );
                        },
                        child: Obx(() {
                          final name = _firstName;
                          return Text(
                            'Welcome back, $name'.tr,
                            style: AppText.bodySm
                                .on(Colors.white)
                                .weight(FontWeight.bold),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
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
