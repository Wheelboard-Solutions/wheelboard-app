import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/design_system.dart';
import '../CompanyTransport/banner_carousel.dart';
import 'complete_profile_screen.dart';
import 'profile_screen.dart';
import 'earnings_screen.dart';
import 'add_service_screen.dart';
import 'my_listings_screen.dart';
import 'service_details_screen.dart';
import 'booking_list_screen.dart';
import 'leads/leads_screen.dart';
import 'sp_learning_screen.dart';
import 'sp_notification_screen.dart';
import '../CompanyTransport/job_screen.dart';
import '../CompanyTransport/feed_screen.dart';
import '../CompanyTransport/fleet_userprofile.dart';
import '../../controllers/Transport/notification_controller.dart';
import '../../controllers/Transport/user_profile_controller.dart';
import '../../controllers/Professional/feeds_controller.dart';
import '../../controllers/Transport/post_controller.dart';
import '../../models/service_model.dart';
import '../../utils/share_service.dart';
import '../../utils/constants.dart';
import '../../utils/media_url.dart';
import '../../controllers/ServiceProvider/service_provider_home_controller.dart';

/// Service-provider Home dashboard — rebuilt on the Wheelboard design system
/// (`theme/design_system.dart`). Replaces the legacy `AppColors` + ad-hoc
/// styling. All data/actions are preserved: stats (services/leads/conversion),
/// quick actions (earnings/hire/bookings/learning), My Services (edit/publish),
/// and Popular Feeds. KPIs now come from the real lead stats (see P1).
class ServiceProviderHomeScreen extends StatefulWidget {
  const ServiceProviderHomeScreen({super.key});

  @override
  State<ServiceProviderHomeScreen> createState() =>
      _ServiceProviderHomeScreenState();
}

class _ServiceProviderHomeScreenState extends State<ServiceProviderHomeScreen> {
  final notificationController = Get.put(NotificationController());
  final userProfileController = Get.put(UserProfileController());
  final feedsController = Get.put(FeedsController());
  late final ServiceProviderHomeController _homeController;

  @override
  void initState() {
    super.initState();
    _homeController = Get.put(ServiceProviderHomeController());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notificationController.fetchNotifications();
      userProfileController.fetchCurrentUserProfile();
    });
  }

  Future<void> _refresh() async {
    await Future.wait([
      _homeController.fetchMyServices(),
      _homeController.fetchBookings(),
    ]);
    notificationController.fetchNotifications();
    userProfileController.fetchCurrentUserProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.bg,
      body: RefreshIndicator(
        color: AppPalette.primary,
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              AppSpacing.vGapLg,
              _profileNudge(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: BannerCarousel(),
              ),
              AppSpacing.vGapLg,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _statsRow(),
              ),
              AppSpacing.vGapMd,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _quickActions(),
              ),
              AppSpacing.vGapXl,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _servicesSection(),
              ),
              AppSpacing.vGapXl,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _sectionHeader(
                  'Popular Feeds',
                  viewLabel: 'View more',
                  onView: () => Get.to(() => const FeedScreen()),
                ),
              ),
              AppSpacing.vGapMd,
              _feedsList(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header (brand gradient) ────────────────────────────────────────────────
  Widget _header() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppPalette.brandGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Obx(() {
                final profile = userProfileController.userProfile.value;
                final logo = profile?.businessLogoPath;
                final hasLogo = logo != null && logo.isNotEmpty;
                return GestureDetector(
                  onTap: () =>
                      Get.to(() => const ServiceProviderProfileScreen()),
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    backgroundImage: hasLogo ? NetworkImage(logo) : null,
                    child: hasLogo
                        ? null
                        : const Icon(Icons.storefront,
                            color: Colors.white, size: 24),
                  ),
                );
              }),
              AppSpacing.hGapMd,
              Expanded(
                child: Obx(() {
                  final profile = userProfileController.userProfile.value;
                  final name = profile?.businessName ??
                      profile?.displayName ??
                      'Welcome';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Welcome back'.tr,
                          style: AppText.caption.on(Colors.white70)),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.h2.on(Colors.white),
                      ),
                    ],
                  );
                }),
              ),
              Obx(() {
                final unread = notificationController.unreadCount;
                return GestureDetector(
                  onTap: () => Get.to(() => const SpNotificationScreen()),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: AppRadius.rMd,
                        ),
                        child: const Icon(Iconsax.notification,
                            color: Colors.white, size: 22),
                      ),
                      if (unread > 0)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppPalette.amber,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            constraints: const BoxConstraints(
                                minWidth: 18, minHeight: 18),
                            child: Center(
                              child: Text(
                                unread > 99 ? '99+' : '$unread',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  /// "Complete your profile" banner (mirrors web /business/home): shown when
  /// the business profile is missing type/address/city. Tap → complete-profile.
  Widget _profileNudge() {
    return Obx(() {
      final p = userProfileController.userProfile.value;
      if (p == null) return const SizedBox.shrink();
      final complete = (p.businessType ?? '').isNotEmpty &&
          (p.address ?? '').isNotEmpty &&
          (p.city ?? '').isNotEmpty;
      if (complete) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: GestureDetector(
          onTap: () => Get.to(() => const ServiceProviderCompleteProfileScreen()),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppPalette.amberBg,
              borderRadius: AppRadius.rLg,
              border: Border.all(color: const Color(0x33F59E0B)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppPalette.amber.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Iconsax.info_circle,
                      size: 18, color: AppPalette.amber),
                ),
                AppSpacing.hGapMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Complete your profile'.tr,
                          style: AppText.subtitle.on(const Color(0xFF92400E))),
                      Text(
                        'Add business details to get better visibility and leads.',
                        style: AppText.caption.on(const Color(0xFF92400E)),
                      ),
                    ],
                  ),
                ),
                const Icon(Iconsax.arrow_right_3,
                    size: 16, color: AppPalette.amber),
              ],
            ),
          ),
        ),
      );
    });
  }

  // ── Stats ──────────────────────────────────────────────────────────────────
  Widget _statsRow() {
    return Obx(() {
      final stats = _homeController.leadStats.value;
      final conv = stats?.conversionRate ?? 0;
      return Row(
        children: [
          Expanded(
            child: _statCard(
              Iconsax.briefcase,
              AppPalette.amber,
              'Services',
              '${_homeController.services.length}',
              () => Get.to(() => const MyListingsScreen()),
            ),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: _statCard(
              Iconsax.calendar_1,
              AppPalette.green,
              'Bookings',
              '${_homeController.totalBookings}',
              () => Get.to(() =>
                  BookingListScreen(serviceIds: _homeController.allServiceIds)),
            ),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: _statCard(
              Icons.percent,
              AppPalette.blue,
              'Conv.',
              '${conv.toStringAsFixed(0)}%',
              () => Get.to(() => const LeadsScreen()),
            ),
          ),
        ],
      );
    });
  }

  Widget _statCard(IconData icon, Color color, String label, String value,
      VoidCallback onTap) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadius.rSm,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          AppSpacing.vGapSm,
          Text(value, style: AppText.h2),
          Text(label.tr,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
        ],
      ),
    );
  }

  // ── Quick actions ────────────────────────────────────────────────────────
  Widget _quickActions() {
    return Row(
      children: [
        _qa(Iconsax.money_recive, 'Earnings',
            () => Get.to(() => const EarningsScreen())),
        AppSpacing.hGapSm,
        _qa(Iconsax.people, 'Hire', () => Get.to(() => const JobsScreen())),
        AppSpacing.hGapSm,
        _qa(
          Iconsax.chart_2,
          'Leads',
          () => Get.to(() => const LeadsScreen()),
        ),
        AppSpacing.hGapSm,
        _qa(Icons.school_outlined, 'Learning',
            () => Get.to(() => const SpLearningScreen())),
      ],
    );
  }

  Widget _qa(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          decoration: BoxDecoration(
            color: AppPalette.card,
            borderRadius: AppRadius.rLg,
            border: Border.all(color: AppPalette.border),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppPalette.primaryLight,
                  borderRadius: AppRadius.rMd,
                ),
                child: Icon(icon, color: AppPalette.primary, size: 20),
              ),
              AppSpacing.vGapSm,
              Text(
                label.tr,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption.weight(FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── My Services ──────────────────────────────────────────────────────────
  Widget _servicesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('My Services',
            onView: () => Get.to(() => const MyListingsScreen())),
        AppSpacing.vGapMd,
        Obx(() {
          if (_homeController.isLoadingServices.value) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: AppLoading(),
            );
          }
          final services = _homeController.services;
          if (services.isEmpty) {
            return AppCard(
              child: AppEmptyState(
                icon: Iconsax.box,
                title: 'No services yet'.tr,
                subtitle: 'Create your first service to get started.',
              ),
            );
          }
          final shown = services.take(2).toList();
          return Column(
            children: [
              for (final s in shown)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _serviceCard(s),
                ),
            ],
          );
        }),
      ],
    );
  }

  Widget _serviceCard(ServiceModel service) {
    final img = _homeController.serviceImages[service.serviceId] ?? '';
    final title = service.serviceTitle.isNotEmpty
        ? service.serviceTitle
        : 'Untitled Service';
    final tag = service.categoryList.isNotEmpty
        ? service.categoryList.first
        : (service.businessType.isNotEmpty
            ? service.businessType
            : (service.city.isNotEmpty ? service.city : 'Service'));
    final desc = service.description ?? 'No description available';
    final published = service.isAvailable;

    return AppCard(
      onTap: () =>
          Get.to(() => ServiceDetailsScreen(serviceId: service.serviceId)),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: AppRadius.rMd,
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: img.isEmpty
                      ? Image.asset(AppImages.service, fit: BoxFit.cover)
                      : Image.network(
                          img,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Image.asset(AppImages.service, fit: BoxFit.cover),
                        ),
                ),
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.subtitle),
                        ),
                        AppSpacing.hGapSm,
                        _chip(tag),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption),
                  ],
                ),
              ),
            ],
          ),
          AppSpacing.vGapMd,
          Row(
            children: [
              Expanded(
                child: AppSecondaryButton(
                  label: 'Edit'.tr,
                  icon: Icons.edit_outlined,
                  onPressed: () =>
                      Get.to(() => AddServiceScreen(service: service)),
                ),
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: AppSecondaryButton(
                  label: published ? 'Unpublish'.tr : 'Publish'.tr,
                  icon: published
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: published ? AppPalette.textGrey : AppPalette.blue,
                  onPressed: () =>
                      _homeController.togglePublishStatus(service.serviceId),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppPalette.greenBg,
        borderRadius: AppRadius.rPill,
      ),
      child: Text(text, style: AppText.micro.on(AppPalette.green)),
    );
  }

  Widget _sectionHeader(String title,
      {VoidCallback? onView, String viewLabel = 'View All'}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title.tr, style: AppText.h3),
        if (onView != null)
          GestureDetector(
            onTap: onView,
            child: Text(viewLabel.tr, style: AppText.subtitle.on(AppPalette.primary)),
          ),
      ],
    );
  }

  // ── Popular Feeds ────────────────────────────────────────────────────────
  Widget _feedsList() {
    return Obx(() {
      if (feedsController.isLoading.isTrue) {
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: AppLoading(message: 'Loading feeds…'),
        );
      }
      if (feedsController.feeds.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AppEmptyState(
            icon: Iconsax.document_text,
            title: 'No popular feeds'.tr,
          ),
        );
      }
      final popularFeeds = feedsController.feeds.take(3).toList();
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: popularFeeds.length,
        itemBuilder: (context, index) {
          final feed = popularFeeds[index];
          return Padding(
            padding: EdgeInsets.only(
                bottom: index < popularFeeds.length - 1 ? 12 : 0),
            child: _buildFeedPostCard(context, feed),
          );
        },
      );
    });
  }

  /// Feed post card — ported from the previous implementation (renders real
  /// feed data: author, content, image, like/share/view, status, time).
  Widget _buildFeedPostCard(BuildContext context, Post post) {
    final companyLogoUrl =
        post.companyLogo != null && post.companyLogo!.isNotEmpty
            ? post.companyLogo!
            : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.card,
        borderRadius: AppRadius.rXl,
        border: Border.all(color: AppPalette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => Get.to(FleetUserprofile(companyId: post.companyId)),
            borderRadius: BorderRadius.circular(50),
            child: Row(
              children: [
                companyLogoUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.network(
                          _formatImageUrl(companyLogoUrl),
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _avatarFallback(post),
                        ),
                      )
                    : _avatarFallback(post),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.userName.isNotEmpty ? post.userName : 'User',
                        style: AppText.subtitle,
                      ),
                      Text(post.category, style: AppText.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (post.content.isNotEmpty)
            Text(post.content, style: AppText.bodySm),
          if (post.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: AppRadius.rLg,
              child: Image.network(
                _formatImageUrl(post.imageUrls[0]),
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 200,
                  color: AppPalette.bg,
                  child: const Center(
                    child: Icon(Icons.image_not_supported,
                        size: 48, color: AppPalette.textFaint),
                  ),
                ),
              ),
            ),
          ],
          if (post.content.isEmpty && post.imageUrls.isEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: AppRadius.rLg,
              child: Image.asset('assets/truck.png',
                  height: 150, width: double.infinity, fit: BoxFit.cover),
            ),
          ],
          const SizedBox(height: 10),
          Obx(() {
            final isLiked = feedsController.isLiked(post.postId);
            return Row(
              children: [
                GestureDetector(
                  onTap: () => feedsController.toggleLike(post.postId),
                  child: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    size: 26,
                    color: isLiked ? AppPalette.primary : AppPalette.textFaint,
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => ShareService.sharePost(
                    postId: post.postId,
                    content: post.content,
                    userName: post.userName,
                    category: post.category,
                  ),
                  child: SvgPicture.asset('assets/share.svg',
                      width: 24, height: 24),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => Get.to(() => const FeedScreen()),
                  child:
                      SvgPicture.asset('assets/eye.svg', width: 24, height: 24),
                ),
                const Spacer(),
                _feedStatusBadge(post.status),
              ],
            );
          }),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(post.timeAgo, style: AppText.caption),
              if (post.content.length > 100)
                Text('Read More', style: AppText.caption.on(AppPalette.blue)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(Post post) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: AppPalette.primaryLight,
      child: Text(
        post.userName.isNotEmpty ? post.userName[0].toUpperCase() : 'U',
        style: AppText.subtitle.on(AppPalette.primary),
      ),
    );
  }

  Widget _feedStatusBadge(String status) {
    final pending = status == 'Pending';
    final color = pending ? AppPalette.amber : AppPalette.green;
    final bg = pending ? AppPalette.amberBg : AppPalette.greenBg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.rPill),
      child: Text(status, style: AppText.micro.on(color)),
    );
  }

  String _formatImageUrl(String url) => MediaUrl.resolve(url);
}
