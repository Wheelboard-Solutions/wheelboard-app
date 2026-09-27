import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/Professional/assigned_trip_controller.dart';
import '../../controllers/Professional/professional_tab_controller.dart';
import '../../core/auth/auth_service.dart';
import '../../utils/app_logger.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/wheelbot_button.dart';
import 'FeedsProfessional/FeedsProfessionalScreen.dart';
import 'FindJobs/FindJobsScreen.dart';
import 'Search/professional_search_screen.dart';
import 'ProfessionalHomePage/ProfessionalHomePageScreen.dart';
import 'Trips/ProfessionalTripsScreen.dart';

class ProfessionalMainWrapper extends StatefulWidget {
  final int initialIndex;
  const ProfessionalMainWrapper({super.key, this.initialIndex = 0});

  @override
  State<ProfessionalMainWrapper> createState() =>
      _ProfessionalMainWrapperState();
}

class _ProfessionalMainWrapperState extends State<ProfessionalMainWrapper>
    with WidgetsBindingObserver {
  late final ProfessionalTabController _tab;

  // IndexedStack keeps every screen alive — no rebuild on tab switch.
  // Order/labels mirror the web BottomNav: Home · Find(search) · Trips · Feeds · Jobs(board).
  final List<Widget> _screens = const [
    ProfessionalHomePageScreen(),
    ProfessionalSearchScreen(embedded: true),
    ProfessionalTripsScreen(),
    FeedsProfessionalScreen(),
    FindJobsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _tab = Get.isRegistered<ProfessionalTabController>()
        ? Get.find<ProfessionalTabController>()
        : Get.put(ProfessionalTabController(), permanent: true);
    _tab.currentIndex.value = widget.initialIndex;
    WidgetsBinding.instance.addObserver(this);

    if (!Get.isRegistered<AssignedTripController>()) {
      Get.put(AssignedTripController(), permanent: true);
      AppLogger.d(
        '✅ AssignedTripController initialized in Professional wrapper',
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await AuthService.to.refreshLoginStatus();
        final tripCtrl = Get.find<AssignedTripController>();
        await tripCtrl.fetchAssignedTrips();
        AppLogger.d('✅ Auth + trips refreshed in Professional wrapper');
      } catch (e) {
        AppLogger.d('⚠️ Could not refresh on startup: $e');
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Resyncing on resume drops any trips a company deleted while the app was
    // backgrounded — the Professional never sees stale, un-openable trips.
    if (state == AppLifecycleState.resumed) {
      try {
        Get.find<AssignedTripController>().fetchAssignedTrips();
      } catch (_) {}
    }
  }

  void _onTabTapped(int index) {
    _tab.currentIndex.value = index;

    // Refresh trips when switching to Home or Trips tab
    if (index == ProfessionalTabController.home ||
        index == ProfessionalTabController.trips) {
      try {
        Get.find<AssignedTripController>().fetchAssignedTrips();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(
        () => Stack(
          children: [
            IndexedStack(index: _tab.currentIndex.value, children: _screens),
            if (_tab.currentIndex.value == 0)
              const WheelbotFloatingButton(
                roleContext: 'professional',
                bottom: 94,
              ),
          ],
        ),
      ),
      bottomNavigationBar: Obx(
        () => AppBottomNav(
          items: professionalNavItems,
          currentIndex: _tab.currentIndex.value,
          onTap: _onTabTapped,
        ),
      ),
    );
  }
}
