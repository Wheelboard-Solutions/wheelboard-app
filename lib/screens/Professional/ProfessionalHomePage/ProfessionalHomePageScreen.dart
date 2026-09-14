import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../controllers/Professional/assigned_trip_controller.dart';
import '../../../controllers/Professional/feeds_controller.dart';
import '../../../controllers/Professional/open_jobs_controller.dart';
import '../../../controllers/Professional/professional_tab_controller.dart';
import '../../../controllers/Transport/notification_controller.dart';
import '../../../models/feed_model.dart';
import '../../../theme/design_system.dart';
import '../../../utils/trip_status.dart';
import '../../../widgets/custom_snackbar.dart';
import '../Calendar/CalendarScreen.dart';
import '../EarningSummary/EarningSummaryScreen.dart';
import '../Expenses/professional_expenses_screen.dart';
import '../MyLearning/my_learning_screen.dart';
import '../SOS/SOSScreen.dart';
import '../TrackTrip/TrackTripScreen.dart';
import '../../shared/subscription_screen.dart';
import '../widgets/banner_header_widget.dart';
import '../widgets/job_card_widget.dart';
import '../widgets/professional_header_widget.dart';
import '../widgets/quick_action_button_widget.dart';
import '../widgets/trip_card_widget.dart';

/// Professional home — modern, brand-consistent, robust flow layout.
///
/// Mirrors the web `/professional/home` composition (hero, quick actions, next
/// scheduled trip, job listings) and keeps every action + API: calendar, live
/// tracking, earnings, expenses, learning, job apply/save, SOS, search,
/// notifications. Trip routing goes through [TripStatusMapper] → [TrackTripScreen]
/// (the same target as the My Trips list), replacing the old brittle
/// hardcoded-status routing.
class ProfessionalHomePageScreen extends StatelessWidget {
  const ProfessionalHomePageScreen({super.key});

  String _formatDate(DateTime? date, String time) {
    if (date == null) return time;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dateStr =
        '${months[date.month - 1]} ${date.day.toString().padLeft(2, '0')}, ${date.year}';
    final timeStr = time.isNotEmpty
        ? ' – ${time.substring(0, time.length > 5 ? 5 : time.length)}'
        : '';
    return '$dateStr$timeStr';
  }

  /// Open the professional's current trip — prefer an in-process trip, else any
  /// non-completed one — using the shared status mapper.
  Future<void> _openCurrentTrip(AssignedTripController c) async {
    await c.fetchAssignedTrips();
    final trips = c.assignedTrips;
    if (trips.isEmpty) {
      SnackBarHelper.info('No trips assigned to you yet.');
      return;
    }
    final target =
        trips.firstWhereOrNull((t) => c.bucketOf(t) == TripBucket.inProcess) ??
            trips.firstWhereOrNull((t) => c.bucketOf(t) != TripBucket.completed);
    if (target != null) {
      Get.to(() => TrackTripScreen(tripId: target.tripId),
          transition: Transition.cupertino);
    } else {
      SnackBarHelper.info('No active or scheduled trips found.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final assignedTripController = Get.find<AssignedTripController>();
    final notificationController = Get.isRegistered<NotificationController>()
        ? Get.find<NotificationController>()
        : Get.put(NotificationController());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      notificationController.fetchNotifications();
    });

    final bottomInset = MediaQuery.of(context).padding.bottom + 76;

    return Scaffold(
      backgroundColor: AppPalette.bg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ProfessionalHeaderWidget(),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg,
                        AppSpacing.lg, AppSpacing.md),
                    child: BannerHeaderWidget(),
                  ),
                  _quickActions(assignedTripController),
                  AppSpacing.vGapLg,
                  _nextTripSection(assignedTripController),
                  AppSpacing.vGapLg,
                  _jobsSection(),
                  AppSpacing.vGapLg,
                  _popularFeedsSection(),
                  SizedBox(height: bottomInset + 90),
                ],
              ),
            ),
            Positioned(
              right: AppSpacing.lg,
              bottom: bottomInset - 40,
              child: _sosButton(),
            ),
          ],
        ),
      ),
    );
  }

  // ── quick actions ─────────────────────────────────────────────────────────
  Widget _quickActions(AssignedTripController c) {
    Widget action(IconData icon, String title, VoidCallback onTap) => Expanded(
          child: QuickActionButtonWidget(icon: icon, title: title, onTap: onTap),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          action(Iconsax.calendar_1, 'My Calendar'.tr,
              () => Get.to(const CalendarScreen())),
          AppSpacing.hGapSm,
          action(Iconsax.location, 'Track My Trip'.tr, () => _openCurrentTrip(c)),
          AppSpacing.hGapSm,
          action(Iconsax.money_recive, 'Earning'.tr,
              () => Get.to(const EarningSummaryScreen())),
          AppSpacing.hGapSm,
          action(Iconsax.receipt_text, 'Expenses'.tr,
              () => Get.to(() => const ProfessionalExpensesScreen())),
          AppSpacing.hGapSm,
          action(Iconsax.teacher, 'My Learning'.tr,
              () => Get.to(const MyLearningScreen())),
          AppSpacing.hGapSm,
          action(Iconsax.card, 'My Plans'.tr,
              () => Get.to(() =>
                  const SubscriptionScreen(category: 'professional'))),
        ],
      ),
    );
  }

  // ── next scheduled trip ─────────────────────────────────────────────────────
  Widget _nextTripSection(AssignedTripController c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Next Trip'.tr, style: AppText.h3),

          AppSpacing.vGapMd,
          Obx(() {
            if (c.isLoading.value && c.assignedTrips.isEmpty) {
              return _shimmerCard();
            }
            final active = c.assignedTrips
                .where((t) => c.bucketOf(t) != TripBucket.completed)
                .toList();
            if (active.isEmpty) {
              return TripCardWidget(
                pickupAddress: 'No trips available',
                destinationAddress: 'No trip found',
                dateTime: '',
                tags: const [],
                onTap: () => SnackBarHelper.info('No trips available right now.'),
              );
            }
            final trip = active.first;
            final tags = [TripStatusMapper.prettyStatus(trip.tripStatus)]
                .where((t) => t.isNotEmpty)
                .toList();
            return TripCardWidget(
              pickupAddress: trip.pickupLocation,
              destinationAddress: trip.deliveryLocation,
              dateTime: _formatDate(trip.pickupDate, trip.pickupTime),
              tags: tags,
              distance: trip.calculatedDistance != null
                  ? '${trip.calculatedDistance!.toStringAsFixed(1)} km'
                  : null,
              eta: trip.estimatedEta,
              tripDistance: trip.distance,
              onTap: () => _openCurrentTrip(c),
            );
          }),
        ],
      ),
    );
  }

  Widget _shimmerCard() => Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppPalette.card,
          borderRadius: AppRadius.rXl,
          border: Border.all(color: AppPalette.border),
        ),
        child: const AppLoading(),
      );

  // ── jobs ─────────────────────────────────────────────────────────────────
  Widget _jobsSection() {
    final jobsController = Get.put(OpenJobsController());
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Jobs for you'.tr, style: AppText.h3),
              GestureDetector(
                onTap: () => jobsController.refreshOpenJobs(),
                child: Text('Refresh'.tr,
                    style: AppText.label
                        .on(AppPalette.primary)
                        .weight(FontWeight.w600)),
              ),
            ],
          ),
          AppSpacing.vGapMd,
          Obx(() {
            if (jobsController.isLoading.value) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: AppLoading(message: 'Loading jobs…'),
              );
            }
            if (jobsController.openJobs.isEmpty) {
              return const AppEmptyState(
                icon: Iconsax.briefcase,
                title: 'No jobs available',
                subtitle: 'Check back later for new opportunities.',
              );
            }
            return Column(
              children: jobsController.openJobs.asMap().entries.map((entry) {
                final index = entry.key;
                final job = entry.value;
                final displayCompanyName =
                    (job.companyName != null && job.companyName!.isNotEmpty)
                        ? job.companyName!
                        : (job.role.isNotEmpty ? job.role : 'Company');
                return Padding(
                  padding: EdgeInsets.only(
                      bottom:
                          index < jobsController.openJobs.length - 1 ? 12 : 0),
                  child: JobCardWidget(
                    companyName: displayCompanyName,
                    role: job.role,
                    city: job.city,
                    jobId: job.jobId,
                    applicants: job.openings,
                    isApplying: jobsController.isApplying(job.jobId),
                    isApplied: job.isApplied,
                    isSaved: job.isSaved,
                    onSaveToggle: () async {
                      if (job.jobId.isNotEmpty) {
                        await jobsController.toggleSave(job.jobId);
                      }
                    },
                    onApplyNow: () async {
                      if (job.jobId.isNotEmpty && !job.isApplied) {
                        final success =
                            await jobsController.applyForJob(job.jobId);
                        if (success) await jobsController.refreshOpenJobs();
                      }
                    },
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }

  // ── Popular Feeds preview ───────────────────────────────────────────────
  // Mirrors the web professional home `<PopularFeeds />` section: a 4-item
  // preview of community feeds with a "View All" → Feeds tab.

  void _openFeedsTab() {
    if (Get.isRegistered<ProfessionalTabController>()) {
      Get.find<ProfessionalTabController>()
          .goTo(ProfessionalTabController.feeds);
    }
  }

  Widget _popularFeedsSection() {
    final feedsCtrl = Get.put(FeedsController());
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Popular Feeds'.tr, style: AppText.h3),
              GestureDetector(
                onTap: _openFeedsTab,
                child: Row(children: [
                  Text('View All'.tr,
                      style: AppText.subtitle.on(AppPalette.primary)),
                  const Icon(Iconsax.arrow_right_3,
                      size: 16, color: AppPalette.primary),
                ]),
              ),
            ],
          ),
          AppSpacing.vGapMd,
          Obx(() {
            if (feedsCtrl.isLoading.value && feedsCtrl.feeds.isEmpty) {
              return _shimmerCard();
            }
            final items = feedsCtrl.feeds.take(4).toList();
            if (items.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: BoxDecoration(
                  color: AppPalette.card,
                  borderRadius: AppRadius.rLg,
                  border: Border.all(color: AppPalette.border),
                ),
                child: Center(
                  child: Text('No feeds available yet.'.tr,
                      style: AppText.bodySm.on(AppPalette.textGrey)),
                ),
              );
            }
            return Column(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  _feedPreviewCard(items[i]),
                  if (i < items.length - 1) AppSpacing.vGapMd,
                ],
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _feedPreviewCard(Post post) {
    return GestureDetector(
      onTap: _openFeedsTab,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppPalette.card,
          borderRadius: AppRadius.rLg,
          border: Border.all(color: AppPalette.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppPalette.brandGradient,
                borderRadius: AppRadius.rMd,
              ),
              child: Text(
                post.author.initials.isNotEmpty ? post.author.initials : 'U',
                style: AppText.subtitle.on(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          post.author.name.isNotEmpty
                              ? post.author.name
                              : 'Wheelboard',
                          style: AppText.subtitle.on(AppPalette.textDark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (post.serverTimeAgo.isNotEmpty)
                        Text(post.serverTimeAgo,
                            style: AppText.caption.on(AppPalette.textGrey)),
                    ],
                  ),
                  if (post.category.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(post.category,
                        style: AppText.caption.on(AppPalette.primary)),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    post.content,
                    style: AppText.bodySm.on(AppPalette.textMid),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── SOS ─────────────────────────────────────────────────────────────────
  Widget _sosButton() {
    return GestureDetector(
      onTap: () => Get.to(const SOSScreen()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          color: AppPalette.danger,
          borderRadius: AppRadius.rLg,
          boxShadow: [
            BoxShadow(
              color: AppPalette.danger.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Iconsax.danger, color: Colors.white, size: 18),
          AppSpacing.hGapSm,
          Text('SOS',
              style: AppText.subtitle
                  .on(Colors.white)
                  .copyWith(letterSpacing: 0.5)),
        ]),
      ),
    );
  }
}
