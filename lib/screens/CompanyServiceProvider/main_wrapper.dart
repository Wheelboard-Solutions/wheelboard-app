import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../controllers/Professional/feeds_controller.dart';
import '../../controllers/Transport/job_controller.dart';
import '../../controllers/Transport/notification_controller.dart';
import '../../controllers/Transport/user_profile_controller.dart';
import '../../utils/app_logger.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/wheelbot_button.dart';
import '../CompanyTransport/feed_screen.dart';
import 'add_service_screen.dart';
import 'home_screen.dart';
import 'my_listings_screen.dart';
import 'sp_job_screen.dart';
import 'sp_notification_screen.dart';
import 'sp_learning_screen.dart';

// Service provider nav items (5 tabs: Home, Listings, Feeds, Jobs, Notifications)
const _spNavItems = [
  AppNavItem(label: 'Home', icon: Iconsax.home, activeIcon: Iconsax.home_2),
  AppNavItem(
    label: 'Listings',
    icon: Iconsax.receipt,
    activeIcon: Iconsax.receipt_1,
  ),
  AppNavItem(
    label: 'Feeds',
    icon: Iconsax.document_text,
    activeIcon: Iconsax.document_text_1,
  ),
  AppNavItem(
    label: 'Jobs',
    icon: Iconsax.briefcase,
    activeIcon: Iconsax.briefcase1,
  ),
  AppNavItem(
    label: 'Alerts',
    icon: Iconsax.notification,
    activeIcon: Iconsax.notification_1,
  ),
];

class CompanyServiceProviderMainWrapper extends StatefulWidget {
  final int initialIndex;
  const CompanyServiceProviderMainWrapper({super.key, this.initialIndex = 0});

  @override
  State<CompanyServiceProviderMainWrapper> createState() =>
      _CompanyServiceProviderMainWrapperState();
}

class _CompanyServiceProviderMainWrapperState
    extends State<CompanyServiceProviderMainWrapper> {
  late int _currentIndex;

  // IndexedStack keeps every screen alive between tabs
  final List<Widget> _screens = [
    const ServiceProviderHomeScreen(),
    const MyListingsScreen(),
    const FeedScreen(),
    const SpJobScreen(),
    const SpNotificationScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    if (!Get.isRegistered<NotificationController>()) {
      Get.put(NotificationController(), permanent: true);
    }
    if (!Get.isRegistered<UserProfileController>()) {
      Get.put(UserProfileController(), permanent: true);
    }
    if (!Get.isRegistered<JobController>()) {
      Get.put(JobController(), permanent: true);
    }
    if (!Get.isRegistered<FeedsController>()) {
      Get.put(FeedsController(), permanent: true);
    }

    AppLogger.d('✅ Common controllers initialized in Service Provider wrapper');
  }

  // ── Learning is accessible from Home via profile menu ────────────────────
  void openLearning() => Get.to(() => const SpLearningScreen());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: _screens),
          if (_currentIndex == 0)
            const WheelbotFloatingButton(
              roleContext: 'serviceProvider',
              bottom: 100,
            ),
        ],
      ),
      floatingActionButton: (_currentIndex == 0 || _currentIndex == 1)
          ? FloatingActionButton.extended(
              onPressed: () => Get.to(() => const AddServiceScreen()),
              backgroundColor: const Color(0xFFF36969),
              icon: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 20,
              ),
              label: const Text(
                'Add Service',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: AppBottomNav(
        items: _spNavItems,
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}
