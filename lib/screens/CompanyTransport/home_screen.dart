import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../controllers/Professional/feeds_controller.dart';
import '../../controllers/Transport/dashboard_controller.dart';
import '../../controllers/Transport/job_controller.dart';
import '../../controllers/Transport/post_controller.dart';
import '../../models/job_model.dart';
import '../../controllers/Transport/notification_controller.dart';
import '../../controllers/Transport/user_profile_controller.dart';
import '../../core/auth/auth_service.dart';
import '../../utils/media_url.dart';
import '../../utils/share_service.dart';
import '../../widgets/wheelbot_button.dart';
import '../Professional/Expenses/professional_expenses_screen.dart';
import '../shared/subscription_screen.dart';
import 'banner_carousel.dart';
import 'companyuser_profile_screen.dart';
import 'dashboard.dart';
import 'feed_screen.dart';
import 'fleet_screen.dart';
import 'fleet_userprofile.dart';
import 'job_form_screen.dart';
import 'job_screen.dart';
import 'notification_screen.dart';
import 'hired_professionals_screen.dart';
import 'services_screen.dart';

// ─── Design tokens ─────────────────────────────────────────────────────────

const _primary = Color(0xFFF36969);
const _primaryLight = Color(0xFFFFF1F1);
const _bg = Colors.white;
const _cardBg = Color(0xFFF9FAFB);
const _textDark = Color(0xFF111827);
const _textMid = Color(0xFF374151);
const _textGrey = Color(0xFF6B7280);
const _border = Color(0xFFE5E7EB);

// ─── HomeScreen ────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  bool _toolsOpen = false;

  late UserProfileController _profileCtrl;
  late JobController _jobCtrl;
  late FeedsController _feedsCtrl;
  late NotificationController _notifCtrl;
  late DashboardController _dashCtrl;

  static const _menuItems = [
    _MenuItem('Vehicles', Iconsax.truck, Icons.directions_car_rounded),
    _MenuItem('Professionals', Iconsax.people, Icons.people_outline_rounded),
    _MenuItem(
      'Expenses',
      Iconsax.wallet_3,
      Icons.account_balance_wallet_outlined,
    ),
    _MenuItem('Hire', Iconsax.briefcase, Icons.work_outline_rounded),
    _MenuItem('Services', Iconsax.setting_2, Icons.build_circle_outlined),
    _MenuItem('Dashboard', Iconsax.chart_2, Icons.bar_chart_rounded),
    _MenuItem('Subscription', Iconsax.crown, Icons.workspace_premium_rounded),
  ];

  static const _menuColors = [
    Color(0xFFEFF6FF), // Vehicles - blue
    Color(0xFFF0FDF4), // Professionals - green
    Color(0xFFFFFBEB), // Expenses - amber
    Color(0xFFFFF1F1), // Hire - red
    Color(0xFFF5F3FF), // Services - purple
    Color(0xFFF0F9FF), // Dashboard - sky
    Color(0xFFFFF7ED), // Subscription - orange
  ];

  static const _menuIconColors = [
    Color(0xFF3B82F6),
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
    Color(0xFFF36969),
    Color(0xFF8B5CF6),
    Color(0xFF0EA5E9),
    Color(0xFFF97316),
  ];

  @override
  void initState() {
    super.initState();
    _profileCtrl = Get.put(UserProfileController());
    _jobCtrl = Get.put(JobController());
    _feedsCtrl = Get.put(FeedsController());
    _notifCtrl = Get.put(NotificationController());
    _dashCtrl = Get.put(DashboardController());

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _profileCtrl.fetchCurrentUserProfile();
      _notifCtrl.refreshNotifications();
      _fadeCtrl.forward();
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Image helpers (secure) ───────────────────────────────────────────────

  String _imageUrl(String path) => MediaUrl.resolve(path);

  Map<String, String> get _authHeaders {
    final token = AuthService.to.currentToken;
    if (token.isEmpty) return {};
    return {'Authorization': 'Bearer $token', 'Accept': '*/*'};
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildSliverHeader(),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _buildBanner(),
                  const SizedBox(height: 16),
                  _buildStatsStrip(),
                  const SizedBox(height: 24),
                  _buildQuickActions(),
                  const SizedBox(height: 28),
                  _buildRecentJobs(),
                  const SizedBox(height: 28),
                  _buildPopularFeeds(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFABs(),
    );
  }

  // ── Sliver header ────────────────────────────────────────────────────────

  Widget _buildSliverHeader() {
    return SliverAppBar(
      expandedHeight: 0,
      pinned: true,
      backgroundColor: _bg,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: _border,
      automaticallyImplyLeading: false,
      flexibleSpace: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Obx(() {
            final profile = _profileCtrl.userProfile.value;
            final name = profile?.displayName ?? 'My Company';
            final initials = _initials(name);
            final imgPath = profile?.profileImage ?? '';
            final imgUrl = imgPath.isNotEmpty ? _imageUrl(imgPath) : '';

            return Row(
              children: [
                // Avatar
                GestureDetector(
                  onTap: () => Get.to(() => CompanyProfileScreen()),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _primaryLight,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _primary.withValues(alpha: 0.25),
                        width: 2,
                      ),
                    ),
                    child: imgUrl.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              imgUrl,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              headers: _authHeaders,
                              errorBuilder: (_, __, ___) =>
                                  _initialsWidget(initials, 44),
                            ),
                          )
                        : _initialsWidget(initials, 44),
                  ),
                ),
                const SizedBox(width: 12),

                // Greeting
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _greeting(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: _textGrey,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _textDark,
                          fontFamily: 'Poppins',
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Notification bell
                Obx(() {
                  final count = _notifCtrl.unreadCount;
                  return GestureDetector(
                    onTap: () => Get.to(() => const NotificationScreen()),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _primaryLight,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.notifications_outlined,
                            color: _primary,
                            size: 22,
                          ),
                        ),
                        if (count > 0)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: _primary,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              child: Center(
                                child: Text(
                                  count > 99 ? '99+' : '$count',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
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
            );
          }),
        ),
      ),
    );
  }

  // ── Banner ───────────────────────────────────────────────────────────────

  Widget _buildBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BannerCarousel(),
      ),
    );
  }

  // ── Stats strip ──────────────────────────────────────────────────────────

  Widget _buildStatsStrip() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Obx(() {
        final d = _dashCtrl.dashboardData.value;
        final loading = _dashCtrl.isLoading.value && d == null;

        final stats = [
          _StatCell(
            icon: Iconsax.routing_2,
            color: const Color(0xFF3B82F6),
            bg: const Color(0xFFEFF6FF),
            label: 'Total Trips',
            value: loading ? '—' : '${d?.tripSummary.totalTrips ?? 0}',
          ),
          _StatCell(
            icon: Iconsax.truck,
            color: const Color(0xFF22C55E),
            bg: const Color(0xFFF0FDF4),
            label: 'Active Vehicles',
            value: loading ? '—' : '${d?.activeVehicles.activeVehicles ?? 0}',
          ),
          _StatCell(
            icon: Iconsax.briefcase,
            color: const Color(0xFF8B5CF6),
            bg: const Color(0xFFF5F3FF),
            label: 'Active Jobs',
            value: loading ? '—' : '${d?.jobsSummary.activeJobs ?? 0}',
          ),
          _StatCell(
            icon: Iconsax.wallet_3,
            color: const Color(0xFFF59E0B),
            bg: const Color(0xFFFFFBEB),
            label: 'This Month',
            value: loading
                ? '—'
                : '₹${_formatSalary(d?.monthlyExpenses.totalExpenses ?? 0)}',
          ),
        ];

        return Row(
          children: stats
              .map(
                (s) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: s == stats.last ? 0 : 8),
                    child: _buildStatCard(s),
                  ),
                ),
              )
              .toList(),
        );
      }),
    );
  }

  Widget _buildStatCard(_StatCell s) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: s.bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(s.icon, size: 18, color: s.color),
          ),
          const SizedBox(height: 8),
          Text(
            s.value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _textDark,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            s.label.tr,
            style: const TextStyle(
              fontSize: 9,
              color: _textGrey,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── Quick actions ────────────────────────────────────────────────────────

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions'.tr,
            style: const TextStyle(

              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _textDark,
              fontFamily: 'Poppins',
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _menuItems.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (context, i) => _buildActionCard(i),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(int i) {
    final item = _menuItems[i];
    final bg = _menuColors[i];
    final iconColor = _menuIconColors[i];

    return GestureDetector(
      onTap: () => _handleMenuTap(i),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(child: Icon(item.icon, color: iconColor, size: 24)),
            ),
            const SizedBox(height: 8),
            Text(
              item.label.tr,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _textMid,
                fontFamily: 'Poppins',
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

          ],
        ),
      ),
    );
  }

  void _handleMenuTap(int i) {
    switch (i) {
      case 0:
        Get.to(() => FleetVehiclesScreen());
      case 1:
        Get.to(() => const HiredProfessionalsScreen());
      case 2:
        Get.to(() => const ProfessionalExpensesScreen(isProfessional: false));
      case 3:
        Get.to(() => PostJobScreen());
      case 4:
        Get.to(() => const ServicesScreen());
      case 5:
        Get.to(() => DashboardScreen());
      case 6:
        Get.to(() => const SubscriptionScreen(category: 'fleet_owner'));
    }
  }

  // ── Recent Jobs ──────────────────────────────────────────────────────────

  Widget _buildRecentJobs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            'Recent Jobs',
            onTap: () => Get.to(() => const JobsScreen()),
          ),
          const SizedBox(height: 14),
          Obx(() {
            if (_jobCtrl.isLoading.isTrue) return _shimmerList(3);
            if (_jobCtrl.jobs.isEmpty) {
              return _emptyState(
                'No jobs posted yet.',
                Icons.work_outline_rounded,
              );
            }
            return Column(
              children: _jobCtrl.jobs.take(5).map(_buildJobCard).toList(),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildJobCard(JobModel job) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Job icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.work_outline_rounded,
                    color: _primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.role,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _textDark,
                          fontFamily: 'Poppins',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          _chip(
                            job.jobType,
                            const Color(0xFFEFF6FF),
                            const Color(0xFF3B82F6),
                          ),
                          const SizedBox(width: 6),
                          if (job.city.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 12,
                                  color: _textGrey,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  job.city,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _textGrey,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Salary
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      job.salary.isNotEmpty ? job.salary : '—',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _primary,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: _border, height: 1),
            const SizedBox(height: 12),

            // Stats + actions
            Row(
              children: [
                _statBadge(
                  Icons.people_outline_rounded,
                  '${job.openings} positions',
                ),
                const SizedBox(width: 12),
                _statBadge(
                  Icons.description_outlined,
                  '${job.applications.length} applicants',
                ),
                const Spacer(),
                _actionBtn(
                  'Share',
                  Icons.share_outlined,
                  const Color(0xFF3B82F6),
                  () => ShareService.shareJob(
                    jobId: job.jobId,
                    jobTitle: job.role,
                    city: job.city,
                    jobType: job.jobType,
                    jobDuration: job.jobDuration,
                    openings: job.openings,
                    salary: job.salary,
                    description: job.description,
                  ),
                ),
                const SizedBox(width: 8),
                _actionBtn(
                  'Edit',
                  Icons.edit_outlined,
                  _primary,
                  () => Get.to(() => PostJobScreen(jobToEdit: job)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Popular Feeds ────────────────────────────────────────────────────────

  Widget _buildPopularFeeds() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            'Popular Feeds',
            onTap: () => Get.to(() => const FeedScreen()),
          ),
          const SizedBox(height: 14),
          Obx(() {
            if (_feedsCtrl.isLoading.isTrue) return _shimmerList(3);
            if (_feedsCtrl.feeds.isEmpty) {
              return _emptyState('No posts yet.', Icons.dynamic_feed_outlined);
            }
            return Column(
              children: _feedsCtrl.feeds.take(5).map(_buildFeedCard).toList(),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFeedCard(Post post) {
    final logo = post.companyLogo?.isNotEmpty == true
        ? _imageUrl(post.companyLogo!)
        : '';
    final initial = post.userName.isNotEmpty
        ? post.userName[0].toUpperCase()
        : 'U';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author row
            InkWell(
              onTap: () =>
                  Get.to(() => FleetUserprofile(companyId: post.companyId)),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  logo.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            logo,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            headers: _authHeaders,
                            errorBuilder: (_, __, ___) =>
                                _initialsWidget(initial, 40, radius: 10),
                          ),
                        )
                      : _initialsWidget(initial, 40, radius: 10),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.userName.isNotEmpty ? post.userName : 'User',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _textDark,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        if (post.category.isNotEmpty)
                          Text(
                            post.category,
                            style: const TextStyle(
                              fontSize: 11,
                              color: _textGrey,
                              fontFamily: 'Poppins',
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Status badge
                  _chip(
                    post.status,
                    post.status.toLowerCase() == 'pending'
                        ? const Color(0xFFFFFBEB)
                        : const Color(0xFFF0FDF4),
                    post.status.toLowerCase() == 'pending'
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF22C55E),
                  ),
                ],
              ),
            ),

            // Content
            if (post.content.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                post.content,
                style: const TextStyle(
                  fontSize: 13,
                  color: _textMid,
                  fontFamily: 'Poppins',
                  height: 1.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // Images
            if (post.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: post.imageUrls.length == 1
                    ? Image.network(
                        _imageUrl(post.imageUrls[0]),
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                        headers: _authHeaders,
                        errorBuilder: (_, __, ___) => _imagePlaceholder(),
                      )
                    : SizedBox(
                        height: 120,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: post.imageUrls.take(4).length,
                          separatorBuilder: (_, __) => const SizedBox(width: 6),
                          itemBuilder: (_, i) => ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _imageUrl(post.imageUrls[i]),
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              headers: _authHeaders,
                              errorBuilder: (_, __, ___) =>
                                  _imagePlaceholder(width: 120),
                            ),
                          ),
                        ),
                      ),
              ),
            ],

            const SizedBox(height: 12),
            const Divider(color: _border, height: 1),
            const SizedBox(height: 10),

            // Reaction row
            Row(
              children: [
                Obx(() {
                  final liked = _feedsCtrl.isLiked(post.postId);
                  return GestureDetector(
                    onTap: () => _feedsCtrl.toggleLike(post.postId),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          liked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 20,
                          color: liked ? _primary : _textGrey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          liked ? 'Liked' : 'Like',
                          style: TextStyle(
                            fontSize: 12,
                            color: liked ? _primary : _textGrey,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => ShareService.sharePost(
                    postId: post.postId,
                    content: post.content,
                    userName: post.userName,
                    category: post.category,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.share_outlined, size: 18, color: _textGrey),
                      SizedBox(width: 4),
                      Text(
                        'Share',
                        style: TextStyle(
                          fontSize: 12,
                          color: _textGrey,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  post.timeAgo,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _textGrey,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── FABs ─────────────────────────────────────────────────────────────────

  Widget _buildFABs() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: animation,
                alignment: Alignment.bottomRight,
                child: child,
              ),
            );
          },
          child: _toolsOpen
              ? Column(
                  key: const ValueKey('company-tools-open'),
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _toolAction(
                      heroTag: 'tool-services',
                      icon: Icons.build_circle_outlined,
                      label: 'Services',
                      onPressed: () => Get.to(() => ServicesScreen()),
                    ),
                    const SizedBox(height: 10),
                    _toolAction(
                      heroTag: 'tool-wheelbot',
                      icon: Icons.smart_toy_rounded,
                      label: 'WheelBot',
                      onPressed: () =>
                          WheelbotSheet.show(context, roleContext: 'company'),
                    ),
                    const SizedBox(height: 10),
                    _toolAction(
                      heroTag: 'tool-postjob',
                      icon: Icons.add_rounded,
                      label: 'Post Job',
                      onPressed: () => Get.to(() => PostJobScreen()),
                    ),
                    const SizedBox(height: 10),
                  ],
                )
              : const SizedBox.shrink(key: ValueKey('company-tools-closed')),
        ),
        FloatingActionButton.extended(
          heroTag: 'company-tools-toggle',
          onPressed: () => setState(() => _toolsOpen = !_toolsOpen),
          backgroundColor: _primary,
          elevation: 4,
          icon: Icon(
            _toolsOpen ? Icons.close_rounded : Icons.widgets_rounded,
            color: Colors.white,
            size: 20,
          ),
          label: Text(
            _toolsOpen ? 'Close' : 'Tools',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontFamily: 'Poppins',
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _toolAction({
    required String heroTag,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return FloatingActionButton.extended(
      heroTag: heroTag,
      onPressed: () {
        setState(() => _toolsOpen = false);
        onPressed();
      },
      backgroundColor: _primary,
      elevation: 3,
      icon: Icon(icon, color: Colors.white, size: 20),
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
          fontSize: 14,
        ),
      ),
    );
  }

  // ── Shared helpers ───────────────────────────────────────────────────────

  Widget _sectionHeader(String title, {VoidCallback? onTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title.tr,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _textDark,
            fontFamily: 'Poppins',
            letterSpacing: -0.2,
          ),
        ),
        if (onTap != null)
          GestureDetector(
            onTap: onTap,
            child: Text(
              'View all'.tr,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _primary,
                fontFamily: 'Poppins',
              ),
            ),
          ),

      ],
    );
  }

  Widget _chip(String label, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: text,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }

  Widget _statBadge(IconData icon, String label, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color ?? _textGrey),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color ?? _textGrey,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }

  Widget _actionBtn(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _initialsWidget(String initials, double size, {double radius = 100}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _primaryLight,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: _primary,
            fontSize: size * 0.35,
            fontFamily: 'Poppins',
          ),
        ),
      ),
    );
  }

  Widget _imagePlaceholder({double width = double.infinity}) {
    return Container(
      width: width,
      height: 120,
      color: _cardBg,
      child: const Center(
        child: Icon(Icons.image_outlined, color: _textGrey, size: 32),
      ),
    );
  }

  Widget _emptyState(String msg, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: _textGrey),
          const SizedBox(height: 10),
          Text(
            msg,
            style: const TextStyle(
              color: _textGrey,
              fontSize: 13,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _shimmerList(int count) {
    return Column(
      children: List.generate(count, (_) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 100,
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
        );
      }),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return 'W';
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  String _formatSalary(num salary) {
    // Keep 1-decimal precision so this matches the Dashboard's "This Month"
    // figure exactly (both read monthlyExpenses.totalExpenses). Rounding to a
    // whole 'K' previously showed 5K here while the Dashboard showed 4.7k.
    if (salary >= 10000000) {
      return '${(salary / 10000000).toStringAsFixed(2)}Cr';
    }
    if (salary >= 100000) return '${(salary / 100000).toStringAsFixed(1)}L';
    if (salary >= 1000) return '${(salary / 1000).toStringAsFixed(1)}K';
    return salary.toStringAsFixed(0);
  }
}

// ─── Data class for menu items ───────────────────────────────────────────

class _MenuItem {
  final String label;
  final IconData icon;
  final IconData fallbackIcon;

  const _MenuItem(this.label, this.icon, this.fallbackIcon);
}

// ─── Data class for stats strip ──────────────────────────────────────────

class _StatCell {
  final IconData icon;
  final Color color;
  final Color bg;
  final String label;
  final String value;

  const _StatCell({
    required this.icon,
    required this.color,
    required this.bg,
    required this.label,
    required this.value,
  });
}
