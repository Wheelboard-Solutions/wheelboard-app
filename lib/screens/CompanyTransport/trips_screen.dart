import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:wheelboard/screens/CompanyTransport/newtripscreen.dart';
import 'package:wheelboard/screens/CompanyTransport/schedulescreen.dart';
import 'package:wheelboard/screens/CompanyTransport/bids_screen.dart';
import 'package:wheelboard/screens/CompanyTransport/trip_details_screen.dart';
import 'package:wheelboard/controllers/Transport/add_trip_controller.dart';
import 'package:wheelboard/controllers/Transport/trip_page_controller.dart';
import 'package:wheelboard/models/add_new_trip_model.dart';
import '../../widgets/custom_loader.dart';
import '../shared/live_trip_tracking_screen.dart';
import 'pod/PodViewScreen.dart';
import 'share/share_navigation_sheet.dart';
import 'lr/lr_generate_screen.dart';
import 'recurring/recurring_trips_screen.dart';
import 'package:wheelboard/core/auth/auth_service.dart';

// ── Design tokens (exact match to Home & Fleet) ───────────────────────────────
const _primary    = Color(0xFFF36969);
const _primaryLt  = Color(0xFFFFF1F1);
const _bg         = Color(0xFFF9FAFB);
const _card       = Colors.white;
const _textDark   = Color(0xFF111827);
const _textMid    = Color(0xFF374151);
const _textGrey   = Color(0xFF6B7280);
const _border     = Color(0xFFE5E7EB);

// ── Status palette ────────────────────────────────────────────────────────────
const _upcomingColor    = Color(0xFFF59E0B);
const _upcomingBg       = Color(0xFFFFFBEB);
const _inProcessColor   = Color(0xFF3B82F6);
const _inProcessBg      = Color(0xFFEFF6FF);
const _completedColor   = Color(0xFF22C55E);
const _completedBg      = Color(0xFFF0FDF4);

// ── Safe avatar ───────────────────────────────────────────────────────────────
class _SafeAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  const _SafeAvatar({this.imageUrl, this.radius = 12});

  @override
  Widget build(BuildContext context) {
    final hasUrl = imageUrl != null && imageUrl!.isNotEmpty;
    final fallback = CircleAvatar(
      radius: radius, backgroundColor: Colors.grey.shade300,
      child: Icon(Icons.person, size: radius, color: Colors.grey.shade600));
    if (hasUrl) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        imageBuilder: (_, p) => CircleAvatar(radius: radius, backgroundImage: p),
        placeholder: (_, __) => CircleAvatar(radius: radius, backgroundColor: Colors.grey.shade200,
          child: SizedBox(width: radius, height: radius, child: const CircularProgressIndicator(strokeWidth: 1.5))),
        errorWidget: (_, __, ___) => fallback,
        width: radius * 2, height: radius * 2, fit: BoxFit.cover,
      );
    }
    return CircleAvatar(
      radius: radius, backgroundColor: Colors.grey.shade200,
      child: ClipOval(child: Image.asset('assets/driver.png',
        width: radius * 2, height: radius * 2, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback)));
  }
}

// ── TripPage ──────────────────────────────────────────────────────────────────
class TripPage extends StatefulWidget {
  final int initialTabIndex;
  const TripPage({super.key, this.initialTabIndex = 0});

  @override
  State<TripPage> createState() => _TripPageState();
}

class _TripPageState extends State<TripPage>
    with TickerProviderStateMixin {
  final TripController tripController = Get.put(TripController());
  final TripPageTabController tabPageController =
      Get.put(TripPageTabController(), permanent: true);

  late TabController _tabController;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery    = '';
  String _destFilter     = '';
  String _bidsFilter     = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTabIndex);
    tabPageController.setTabController(_tabController);

    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchTrips();
      _fadeCtrl.forward();
    });

    ever(tabPageController.currentTabIndex, (int index) {
      if (_tabController.index != index && mounted) _tabController.animateTo(index);
    });

    _searchController.addListener(() => setState(() => _searchQuery = _searchController.text.toLowerCase()));
  }

  @override
  void didUpdateWidget(covariant TripPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTabIndex != oldWidget.initialTabIndex &&
        _tabController.index != widget.initialTabIndex) {
      _tabController.animateTo(widget.initialTabIndex);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchTrips() async {
    // Use AuthService (SecureStorage) — not the legacy SessionManager
    // which no longer holds 'userId' after the migration to SecureStorage.
    final userId = AuthService.to.userId;
    tripController.fetchTrips(userId.isNotEmpty ? userId : 'current');
  }

  List<Trip> _filterTrips(List<Trip> trips) {
    return trips.where((t) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery;
        if (!t.pickupLocation.toLowerCase().contains(q) &&
            !t.deliveryLocation.toLowerCase().contains(q) &&
            !t.tripCode.toLowerCase().contains(q) &&
            !(t.vehicleType?.toLowerCase().contains(q) ?? false)) { return false; }
      }
      if (_destFilter.isNotEmpty &&
          !t.deliveryLocation.toLowerCase().contains(_destFilter.toLowerCase())) { return false; }
      if (_bidsFilter == 'available' && t.totalBidCount == 0) { return false; }
      if (_bidsFilter == 'awaiting'  && t.totalBidCount > 0)  { return false; }
      return true;
    }).toList();
  }

  void _clearFilters() => setState(() {
    _searchController.clear();
    _searchQuery = _destFilter = _bidsFilter = '';
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: NestedScrollView(
            headerSliverBuilder: (_, __) => [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverPersistentHeader(
                pinned: true,
                delegate: _PinnedTabBar(child: _buildTabBar()),
              ),
            ],
            body: _TripsTabViews(
              tripController: tripController,
              tabController: _tabController,
              filterFn: _filterTrips,
            ),
          ),
        ),
        floatingActionButton: Obx(() {
          if (AuthService.to.isProfessional) return const SizedBox.shrink();
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _fab(label: 'Post Trip',  icon: Iconsax.add_circle, onTap: () => Get.to(() => const Newtripscreen())),
              const SizedBox(height: 8),
              _fab(label: 'Schedule',   icon: Iconsax.calendar_1,  onTap: () => Get.to(() => const ScheduleTripScreen())),
              const SizedBox(height: 8),
              _fab(label: 'Repeat',     icon: Iconsax.repeat,      onTap: () => Get.to(() => const RecurringTripsScreen())),
            ],
          );
        }),
      ),
    );
  }

  // ── header (search + stats) ──────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: _card,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(children: [
            Expanded(child: Text('Trips',
              style: GoogleFonts.poppins(
                fontSize: 22, fontWeight: FontWeight.w700,
                color: _textDark, letterSpacing: -0.3))),
            GestureDetector(
              onTap: () => _showFilterDialog(Get.context!),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _primaryLt,
                  borderRadius: BorderRadius.circular(12)),
                child: const Icon(Iconsax.setting_4, color: _primary, size: 20),
              ),
            ),
          ]),
          const SizedBox(height: 14),

          // Search bar
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Row(children: [
              const SizedBox(width: 12),
              const Icon(Iconsax.search_normal, color: _textGrey, size: 18),
              const SizedBox(width: 10),
              Expanded(child: TextField(
                controller: _searchController,
                style: GoogleFonts.poppins(fontSize: 13, color: _textDark),
                decoration: InputDecoration(
                  hintText: 'Search trips…',
                  hintStyle: GoogleFonts.poppins(fontSize: 13, color: _textGrey),
                  border: InputBorder.none,
                  isDense: true,
                ),
              )),
              if (_searchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () => _searchController.clear(),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: const Icon(Icons.close, size: 16, color: _textGrey))),
            ]),
          ),
          const SizedBox(height: 16),

          // Stats strip
          Obx(() {
            final all = tripController.trips;
            final upcoming   = all.where((t) => _isUpcoming(t.tripStatus)).length;
            final inProcess  = all.where((t) => _isInProcess(t.tripStatus)).length;
            final completed  = all.where((t) => _isCompleted(t.tripStatus)).length;
            final stats = [
              _StatDot(label: 'Total',       value: '${all.length}',  color: _primary,       bg: _primaryLt),
              _StatDot(label: 'Upcoming',    value: '$upcoming',       color: _upcomingColor,  bg: _upcomingBg),
              _StatDot(label: 'In Progress', value: '$inProcess',      color: _inProcessColor, bg: _inProcessBg),
              _StatDot(label: 'Completed',   value: '$completed',      color: _completedColor, bg: _completedBg),
            ];
            return Row(
              children: stats.map((s) => Expanded(child: Padding(
                padding: EdgeInsets.only(right: s == stats.last ? 0 : 8),
                child: _buildStatCard(s),
              ))).toList(),
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStatCard(_StatDot s) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(9)),
          child: Center(child: Text(s.value, style: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w700, color: s.color))),
        ),
        const SizedBox(height: 5),
        Text(s.label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w500, color: _textGrey)),
      ]),
    );
  }

  // ── tab bar ──────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: _card,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            indicatorColor: _primary,
            indicatorWeight: 2.5,
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: _primary,
            unselectedLabelColor: _textGrey,
            dividerColor: _border,
            labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
            tabs: const [
              Tab(text: 'Completed'),
              Tab(text: 'In Progress'),
              Tab(text: 'Upcoming'),
            ],
          ),
        ],
      ),
    );
  }

  // ── FAB ──────────────────────────────────────────────────────────────────
  Widget _fab({required String label, required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _primary,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFDFF5EB), width: 1.5),
          boxShadow: [BoxShadow(color: _primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.poppins(
            fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
        ]),
      ),
    );
  }

  // ── filter bottom sheet ──────────────────────────────────────────────────
  void _showFilterDialog(BuildContext context) {
    final destCtrl = TextEditingController(text: _destFilter);
    String tempBids = _bidsFilter;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: _card, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Filter Trips', style: GoogleFonts.poppins(
              fontSize: 18, fontWeight: FontWeight.w700, color: _primary)),
            const Spacer(),
            TextButton(
              onPressed: () { _clearFilters(); Navigator.pop(ctx); },
              child: Text('Clear All', style: GoogleFonts.poppins(
                fontSize: 13, color: _textGrey))),
          ]),
          const SizedBox(height: 20),
          Text('Destination', style: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w600, color: _textMid)),
          const SizedBox(height: 8),
          _filterInput(destCtrl, 'Enter destination city…', Iconsax.location),
          const SizedBox(height: 20),
          Text('Status', style: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w600, color: _textMid)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _chip('Completed',   () { Navigator.pop(ctx); _tabController.animateTo(0); }),
            _chip('In Progress', () { Navigator.pop(ctx); _tabController.animateTo(1); }),
            _chip('Upcoming',    () { Navigator.pop(ctx); _tabController.animateTo(2); }),
          ]),
          const SizedBox(height: 20),
          Text('Bids', style: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w600, color: _textMid)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            _toggleChip('Bids Available', tempBids == 'available', () => setModal(() => tempBids = tempBids == 'available' ? '' : 'available')),
            _toggleChip('Bids Awaiting',  tempBids == 'awaiting',  () => setModal(() => tempBids = tempBids == 'awaiting'  ? '' : 'awaiting')),
          ]),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () {
              setState(() { _destFilter = destCtrl.text.trim(); _bidsFilter = tempBids; });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0),
            child: Text('Apply Filters', style: GoogleFonts.poppins(
              fontSize: 15, fontWeight: FontWeight.w600)),
          )),
          const SizedBox(height: 8),
        ]),
      )),
    );
  }

  Widget _filterInput(TextEditingController ctrl, String hint, IconData icon) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: _bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
      child: Row(children: [
        const SizedBox(width: 12),
        Icon(icon, size: 18, color: _textGrey),
        const SizedBox(width: 8),
        Expanded(child: TextField(
          controller: ctrl,
          style: GoogleFonts.poppins(fontSize: 13, color: _textDark),
          decoration: InputDecoration(hintText: hint,
            hintStyle: GoogleFonts.poppins(fontSize: 13, color: _textGrey),
            border: InputBorder.none, isDense: true),
        )),
      ]),
    );
  }

  Widget _chip(String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _bg, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border)),
      child: Text(label, style: GoogleFonts.poppins(
        fontSize: 12, fontWeight: FontWeight.w500, color: _textMid)),
    ),
  );

  Widget _toggleChip(String label, bool active, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: active ? _primary : _bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? _primary : _border)),
      child: Text(label, style: GoogleFonts.poppins(
        fontSize: 12, fontWeight: FontWeight.w500,
        color: active ? Colors.white : _textMid)),
    ),
  );
}

// ── Status helpers ────────────────────────────────────────────────────────────
// All delegate to the single web-parity [tripStatusBucket] (add_trip_controller)
// so tab counts, badges and colours stay perfectly in sync with the web
// company Trips screen.
bool _isUpcoming(String s)  => tripStatusBucket(s) == 'upcoming';
bool _isInProcess(String s) => tripStatusBucket(s) == 'in-process';
bool _isCompleted(String s) => tripStatusBucket(s) == 'completed';

Color _statusColor(String s) {
  if (_isCompleted(s))  return _completedColor;
  if (_isInProcess(s))  return _inProcessColor;
  return _upcomingColor;
}
Color _statusBg(String s) {
  if (_isCompleted(s))  return _completedBg;
  if (_isInProcess(s))  return _inProcessBg;
  return _upcomingBg;
}
String _statusLabel(String s) {
  if (_isCompleted(s))  return 'Completed';
  if (_isInProcess(s))  return 'In Progress';
  return 'Upcoming';
}

// ── Pinned tab header ─────────────────────────────────────────────────────────
class _PinnedTabBar extends SliverPersistentHeaderDelegate {
  final Widget child;
  const _PinnedTabBar({required this.child});
  @override double get minExtent => 52;
  @override double get maxExtent => 52;
  @override Widget build(_, __, ___) => child;
  @override bool shouldRebuild(_) => false;
}

// ── Tab views ─────────────────────────────────────────────────────────────────
class _TripsTabViews extends StatelessWidget {
  final TripController tripController;
  final TabController tabController;
  final List<Trip> Function(List<Trip>) filterFn;
  const _TripsTabViews({required this.tripController, required this.tabController, required this.filterFn});

  String _loc(String full) => full.isEmpty ? 'Unknown' : full.split(',').first.trim();

  String _fmtDate(DateTime? d, String t) {
    if (d == null) return t;
    final ms = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final ts = t.length > 5 ? t.substring(0, 5) : t;
    return '${ms[d.month-1]} ${d.day.toString().padLeft(2,'0')}, ${d.year}${ts.isNotEmpty ? ' · $ts' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      controller: tabController,
      children: [
        _tripList(context, 'completed'),
        _tripList(context, 'in-process'),
        _tripList(context, 'upcoming'),
      ],
    );
  }

  Future<void> _hardRefresh() {
    // Pull-to-refresh = full re-fetch from the backend (token-auth; userId is
    // only used for logging). Mirrors the web which refetches the trip list.
    final userId = AuthService.to.userId;
    return tripController.fetchTrips(userId.isNotEmpty ? userId : 'current');
  }

  Widget _tripList(BuildContext context, String tab) {
    return Obx(() {
      if (tripController.isTripsLoading.value && tripController.trips.isEmpty) {
        return const Center(child: CustomLoader(message: 'Loading trips…'));
      }
      final all = tripController.getTripsByStatus(
        tab == 'upcoming' ? 'Upcoming' : tab == 'in-process' ? 'In-Process' : 'Completed');
      final filtered = filterFn(all);

      // Always wrap in a RefreshIndicator + an always-scrollable list so the
      // pull-down gesture works even when the tab is empty.
      if (filtered.isEmpty) {
        return RefreshIndicator(
          color: _primary,
          onRefresh: _hardRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.5, child: _empty(tab)),
            ],
          ),
        );
      }

      return RefreshIndicator(
        color: _primary,
        onRefresh: _hardRefresh,
        child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: filtered.length,
        itemBuilder: (_, i) {
          final trip = filtered[i];
          return _AnimatedCard(
            index: i,
            child: tab == 'upcoming'
                ? _UpcomingTripCard(
                    trip: trip,
                    onViewBids:    () => Get.to(() => BidsScreen(tripId: trip.tripId)),
                    onDetails:     () => Get.to(() => TripDetailsScreen(trip: trip)),
                    onShare:       () => _shareTrip(trip),
                    onGenerateLr:  () => _openLrForm(trip, LrFormMode.generate),
                    onUpdateLr:    () => _openLrForm(trip, LrFormMode.update),
                    date: _fmtDate(trip.pickupDate, trip.pickupTime),
                    from: _loc(trip.pickupLocation),
                    to:   _loc(trip.deliveryLocation),
                  )
                : _TripTile(
                    trip: trip,
                    date: _fmtDate(trip.pickupDate, trip.pickupTime),
                    from: _loc(trip.pickupLocation),
                    to:   _loc(trip.deliveryLocation),
                    // Tapping any tile opens full details (edit/delete/share),
                    // matching the web where View Details is available on every
                    // tab — not just Upcoming.
                    onDetails:      () => Get.to(() => TripDetailsScreen(trip: trip)),
                    onComplete:     tab == 'in-process' ? () => tripController.completeTrip(trip.tripId, trip.userId) : null,
                    onTrack:        tab == 'in-process' ? () => Get.to(() => LiveTripTrackingScreen(tripId: trip.id.isNotEmpty ? trip.id : trip.tripId, isDriver: false)) : null,
                    onViewPod:      tab == 'completed'  ? () => Get.to(() => PodViewScreen(tripId: trip.tripId)) : null,
                  ),
          );
        },
      ),
      );
    });
  }

  Widget _empty(String tab) {
    final labels = {'upcoming': 'No upcoming trips', 'in-process': 'No active trips', 'completed': 'No completed trips'};
    final icons  = {'upcoming': Iconsax.calendar_1, 'in-process': Iconsax.routing, 'completed': Iconsax.tick_circle};
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(color: _primaryLt, borderRadius: BorderRadius.circular(20)),
        child: Icon(icons[tab] ?? Iconsax.routing, color: _primary, size: 32)),
      const SizedBox(height: 16),
      Text(labels[tab] ?? 'No trips', style: GoogleFonts.poppins(
        fontSize: 16, fontWeight: FontWeight.w600, color: _textMid)),
      const SizedBox(height: 6),
      Text('Pull to refresh or create a new trip', style: GoogleFonts.poppins(
        fontSize: 12, color: _textGrey)),
    ]));
  }

  void _shareTrip(Trip trip) {
    // Generate a live navigation share link (OTP + URL) exactly like the web
    // ShareNavigationModal — instead of a static message.
    final ctx = Get.context;
    if (ctx == null) return;
    // Web passes the Mongo _id (trip.id) to /share-navigation/generate, not the
    // human-readable tripId code. Fall back to tripId only if _id is missing.
    final shareId = trip.id.isNotEmpty ? trip.id : trip.tripId;
    ShareNavigationSheet.show(
      ctx,
      tripId: shareId,
      from: trip.pickupLocation,
      to: trip.deliveryLocation,
      vehicleNumber: trip.vehicleNumber,
    );
  }

  Future<void> _openLrForm(Trip trip, LrFormMode mode) async {
    // Backend loadTripContext resolves by Mongo _id first, then human tripId.
    final tripId = trip.id.isNotEmpty ? trip.id : trip.tripId;
    final res = await Get.to(() => LrGenerateScreen(tripId: tripId, mode: mode));
    if (res == true) {
      final userId = AuthService.to.userId;
      tripController.fetchTrips(userId.isNotEmpty ? userId : 'current');
    }
  }
}

// ── Animated card wrapper (stagger fade + slide) ──────────────────────────────
class _AnimatedCard extends StatefulWidget {
  final int index;
  final Widget child;
  const _AnimatedCard({required this.index, required this.child});
  @override State<_AnimatedCard> createState() => _AnimatedCardState();
}
class _AnimatedCardState extends State<_AnimatedCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _fade;
  late Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: widget.index * 60), () {
      if (mounted) _ctrl.forward();
    });
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) => FadeTransition(opacity: _fade,
    child: SlideTransition(position: _slide, child: widget.child));
}

// ── Upcoming Trip Card ────────────────────────────────────────────────────────
class _UpcomingTripCard extends StatelessWidget {
  final Trip trip;
  final String date, from, to;
  final VoidCallback? onViewBids, onDetails, onShare, onGenerateLr, onUpdateLr;

  const _UpcomingTripCard({
    required this.trip, required this.date, required this.from, required this.to,
    this.onViewBids, this.onDetails, this.onShare, this.onGenerateLr, this.onUpdateLr,
  });

  bool get _hasDriver => trip.driverId.isNotEmpty && (trip.driverName?.isNotEmpty ?? false) && trip.driverName != 'Not assigned';

  @override
  Widget build(BuildContext context) {
    final sc = _statusColor(trip.tripStatus);
    final sb = _statusBg(trip.tripStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── icon header ───────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: trip.isScheduledTrip ? const Color(0xFFF3E8FF) : const Color(0xFFFFF1F1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
                ),
                child: Icon(
                  trip.isScheduledTrip ? Iconsax.calendar_tick : Iconsax.truck_fast, 
                  color: trip.isScheduledTrip ? const Color(0xFF9333EA) : _primary, 
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.tripId, 
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: _textDark),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      trip.isScheduledTrip ? 'Scheduled Trip' : 'New Assignment', 
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: _textGrey),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _badge(_statusLabel(trip.tripStatus), sc, bg: sb, darkText: true),
                ],
              ),
            ],
          ),
        ),

        // ── body ──────────────────────────────────────────────────
        Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // route
            Row(children: [
              const SizedBox(width: 4),
              Expanded(child: Column(children: [
                _locRow(from, isStart: true),
                Padding(padding: const EdgeInsets.only(left: 5),
                  child: Container(width: 1, height: 16, color: _border)),
                _locRow(to, isStart: false),
              ])),
            ]),
            const SizedBox(height: 12),
            const Divider(color: _border, height: 1),
            const SizedBox(height: 12),

            // meta row
            Wrap(spacing: 16, runSpacing: 6, children: [
              _metaChip(Iconsax.calendar_1, date),
              if (trip.vehicleNumber?.isNotEmpty ?? false)
                _metaChip(Iconsax.truck, trip.vehicleNumber!),
              if (trip.payRange.isNotEmpty)
                _metaChip(Iconsax.money, trip.payRange),
            ]),
            const SizedBox(height: 12),

            // assigned driver / bids
            if (_hasDriver)
              Row(children: [
                _SafeAvatar(imageUrl: trip.driverImagePath, radius: 14),
                const SizedBox(width: 8),
                Expanded(child: Text(trip.driverName ?? '',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: _textMid),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              ])
            else if (trip.totalBidCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: _inProcessBg, borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Iconsax.people, size: 14, color: _inProcessColor),
                  const SizedBox(width: 6),
                  Text('${trip.totalBidCount} bid${trip.totalBidCount == 1 ? '' : 's'} received',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: _inProcessColor)),
                ])),

            const SizedBox(height: 14),

            // action buttons — status-aware, mirrors web /company/trips:
            //   draft                   → Generate LR
            //   lr-rejected             → Update LR (+ rejection note)
            //   pending-lr-confirmation → Awaiting LR (driver must confirm)
            //   scheduled trip          → Share (navigation link + OTP)
            //   created trip            → View Bids
            _buildActions(),
          ],
        )),
      ]),
    );
  }

  Widget _locRow(String label, {required bool isStart}) {
    return Row(children: [
      Container(
        width: 10, height: 10,
        decoration: BoxDecoration(
          color: isStart ? _completedColor : _primary,
          shape: BoxShape.circle,
          border: Border.all(color: isStart ? _completedColor.withValues(alpha: 0.3) : _primaryLt, width: 3)),
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: _textDark))),
    ]);
  }

  Widget _buildActions() {
    final Widget primary;
    if (trip.isScheduledTrip) {
      primary = _filledBtn(icon: Iconsax.share, label: 'Share', onTap: onShare);
    } else {
      primary = _filledBtn(icon: Iconsax.people, label: 'View Bids', onTap: onViewBids);
    }

    return Row(children: [
      Expanded(child: primary),
      const SizedBox(width: 8),
      Expanded(child: _outlineBtn(icon: Iconsax.eye, label: 'Details', onTap: onDetails)),
    ]);
  }
}

// ── Completed / In-Process Trip Tile ─────────────────────────────────────────
class _TripTile extends StatelessWidget {
  final Trip trip;
  final String date, from, to;
  final VoidCallback? onComplete, onTrack, onViewPod, onDetails;

  const _TripTile({
    required this.trip, required this.date, required this.from, required this.to,
    this.onComplete, this.onTrack, this.onViewPod, this.onDetails,
  });

  Future<void> _call(String n) async {
    final uri = Uri.parse('tel:$n');
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final sc = _statusColor(trip.tripStatus);
    final sb = _statusBg(trip.tripStatus);
    final inProcess = _isInProcess(trip.tripStatus);
    final completed = _isCompleted(trip.tripStatus);

    return GestureDetector(
      onTap: onDetails,
      child: Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // status + date
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: sb, borderRadius: BorderRadius.circular(20)),
              child: Text(_statusLabel(trip.tripStatus),
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: sc))),
            const Spacer(),
            Text(date, style: GoogleFonts.poppins(fontSize: 11, color: _textGrey)),
          ]),
          const SizedBox(height: 12),

          // route visualization
          Row(children: [
            Column(children: [
              _dot(_completedColor),
              Container(width: 1.5, height: 24, color: _border),
              _dot(_primary),
            ]),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(from, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: _textDark),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 14),
                Text(to, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: _textDark),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            )),
          ]),
          const SizedBox(height: 12),

          // vehicle + driver chips
          Wrap(spacing: 8, runSpacing: 6, children: [
            if (trip.vehicleNumber?.isNotEmpty ?? false)
              _infoChip(Iconsax.truck, trip.vehicleNumber!),
            if (trip.vehicleType?.isNotEmpty ?? false)
              _infoChip(Iconsax.category, trip.vehicleType!),
            if (trip.driverName?.isNotEmpty ?? false)
              _infoChip(Iconsax.user, trip.driverName!),
          ]),

          const SizedBox(height: 14),
          const Divider(color: _border, height: 1),
          const SizedBox(height: 12),

          // action buttons
          if (inProcess) Row(children: [
            Expanded(child: _outlineBtn(icon: Iconsax.location_tick, label: 'Track', onTap: onTrack)),
            const SizedBox(width: 8),
            if (trip.driverContact?.isNotEmpty ?? false)
              _iconBtn(icon: Iconsax.call, onTap: () => _call(trip.driverContact!)),
            if (trip.driverContact?.isNotEmpty ?? false) const SizedBox(width: 8),
            Expanded(child: _filledBtn(
              icon: Iconsax.tick_circle, label: 'Complete',
              onTap: () => Get.dialog(AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Text('Complete Trip', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                content: Text('Are you sure you want to end this trip?', style: GoogleFonts.poppins(fontSize: 14)),
                actions: [
                  TextButton(onPressed: Get.back, child: const Text('Cancel')),
                  ElevatedButton(
                    onPressed: () { Get.back(); if (onComplete != null) onComplete!(); },
                    style: ElevatedButton.styleFrom(backgroundColor: _completedColor, elevation: 0),
                    child: const Text('Confirm', style: TextStyle(color: Colors.white))),
                ],
              ))
            )),
          ])
          // Completed trips show only View POD — the Expenses button was
          // removed from the card at product request.
          else if (completed) Row(children: [
            Expanded(child: _filledBtn(icon: Iconsax.document_text, label: 'View POD', onTap: onViewPod, color: _completedColor)),
          ]),
        ],
      )),
    ),
    );
  }

  Widget _dot(Color c) => Container(
    width: 10, height: 10,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle,
      border: Border.all(color: c.withValues(alpha: 0.3), width: 3)));
}

// ── Shared action widgets ─────────────────────────────────────────────────────
Widget _badge(String label, Color color, {Color? bg, bool darkText = false}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bg ?? color.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: GoogleFonts.poppins(
      fontSize: 11, fontWeight: FontWeight.w700,
      color: darkText ? color : Colors.white)));
}

Widget _metaChip(IconData icon, String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFF9FAFB),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _border),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: _textGrey),
      const SizedBox(width: 6),
      Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: _textMid)),
    ]),
  );
}

Widget _infoChip(IconData icon, String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _border),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: _textMid),
      const SizedBox(width: 6),
      Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: _textDark),
        maxLines: 1),
    ]));
}

Widget _filledBtn({required IconData icon, required String label,
    VoidCallback? onTap, Color color = _primary}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      height: 38,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 14, color: Colors.white),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.poppins(
          fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
      ]),
    ),
  );
}

Widget _outlineBtn({required IconData icon, required String label, VoidCallback? onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      height: 38,
      decoration: BoxDecoration(
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 14, color: _textMid),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.poppins(
          fontSize: 12, fontWeight: FontWeight.w600, color: _textMid)),
      ]),
    ),
  );
}

Widget _iconBtn({required IconData icon, required VoidCallback onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38, height: 38,
      decoration: BoxDecoration(border: Border.all(color: _border), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, size: 16, color: _textMid)));
}

// ── Data models ───────────────────────────────────────────────────────────────
class _StatDot {
  final String label, value;
  final Color color, bg;
  const _StatDot({required this.label, required this.value, required this.color, required this.bg});
}
