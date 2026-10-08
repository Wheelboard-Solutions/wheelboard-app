import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../controllers/Professional/assigned_trip_controller.dart';
import '../../../models/assigned_trip_model.dart';
import '../../../theme/design_system.dart';
import '../../../utils/trip_status.dart';
import '../TrackTrip/TrackTripScreen.dart';

/// Modern "My Trips" list for professionals — Uber/Rapido-style.
///
/// Mirrors the web `/professional/trips` page exactly in behaviour: a stats
/// header, the `All / Assigned / In-Process / Completed` filter tabs, and a list
/// of route cards. Tapping a card opens the trip navigation step machine
/// ([TrackTripScreen]) — the same target the web card uses (`/navigate`).
///
/// State comes entirely from [AssignedTripController] (the single source of
/// truth registered permanently in the Professional wrapper) — this screen never
/// fetches trips itself.
class ProfessionalTripsScreen extends StatelessWidget {
  const ProfessionalTripsScreen({super.key});

  static const _filters = ['All', 'Assigned', 'In-Process', 'Completed'];

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AssignedTripController>();

    return Scaffold(
      backgroundColor: AppPalette.bg,
      body: SafeArea(
        bottom: false,
        child: Obx(() {
          // First-load: full-screen loading / error before we have any data.
          if (ctrl.isLoading.value && ctrl.assignedTrips.isEmpty) {
            return const AppLoading(message: 'Loading your trips…');
          }
          if (ctrl.hasError.value && ctrl.assignedTrips.isEmpty) {
            return AppErrorState(
              message: ctrl.errorMessage.value.isEmpty
                  ? 'Failed to load trips'
                  : ctrl.errorMessage.value,
              onRetry: ctrl.fetchAssignedTrips,
            );
          }

          final trips = ctrl.visibleTrips;

          return RefreshIndicator(
            color: AppPalette.primary,
            onRefresh: ctrl.fetchAssignedTrips,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _Header()),
                SliverToBoxAdapter(child: _StatsGrid(ctrl: ctrl)),
                SliverToBoxAdapter(child: _FilterTabs(ctrl: ctrl)),
                if (trips.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyTrips(filter: ctrl.selectedFilter.value),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                    sliver: SliverList.separated(
                      itemCount: trips.length,
                      separatorBuilder: (_, __) => AppSpacing.vGapLg,
                      itemBuilder: (_, i) => _AnimatedIn(
                        index: i,
                        child: _TripCard(
                          trip: trips[i],
                          bucket: ctrl.bucketOf(trips[i]),
                          earnings: ctrl.earningsOf(trips[i]),
                          onTap: () => Get.to(
                            () => TrackTripScreen(tripId: trips[i].tripId),
                            transition: Transition.cupertino,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: AppPalette.brandGradient,
              borderRadius: AppRadius.rLg,
              boxShadow: [
                BoxShadow(
                  color: AppPalette.primary.withValues(alpha: 0.30),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Iconsax.truck_fast, color: Colors.white, size: 24),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('My Trips', style: AppText.h1),
                Text('Track and manage your journeys', style: AppText.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats grid (2×2) — Completed · Earnings · Rating · Active & Assigned
// ─────────────────────────────────────────────────────────────────────────────
class _StatsGrid extends StatelessWidget {
  final AssignedTripController ctrl;
  const _StatsGrid({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          Row(children: [
            Expanded(
              child: _StatCard(
                icon: Iconsax.tick_circle,
                color: AppPalette.blue,
                value: '${ctrl.completedCount}',
                label: 'Completed Trips',
              ),
            ),
            AppSpacing.hGapMd,
            Expanded(
              child: _StatCard(
                icon: Iconsax.money_recive,
                color: AppPalette.green,
                value: _formatMoney(ctrl.totalEarnings),
                label: 'Total Earnings',
              ),
            ),
          ]),
          AppSpacing.vGapMd,
          Row(children: [
            Expanded(
              child: _StatCard(
                icon: Iconsax.star1,
                color: AppPalette.amber,
                value: ctrl.rating?.toStringAsFixed(1) ?? '—',
                label: 'Average Rating',
                trailing: _StarRow(rating: ctrl.rating ?? 0),
              ),
            ),
            AppSpacing.hGapMd,
            Expanded(
              child: _StatCard(
                icon: Iconsax.activity,
                color: AppPalette.primary,
                value: '${ctrl.activeAndAssignedCount}',
                label: 'Active & Assigned',
                trailing: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(spacing: 6, runSpacing: 4, children: [
                    _MiniChip(
                        text: '${ctrl.assignedCount} assigned',
                        color: AppPalette.amber,
                        bg: AppPalette.amberBg),
                    _MiniChip(
                        text: '${ctrl.inProcessCount} active',
                        color: AppPalette.blue,
                        bg: AppPalette.blueBg),
                  ]),
                ),
              ),
            ),
          ]),
          AppSpacing.vGapMd,
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final Widget? trailing;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
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
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadius.rMd,
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          AppSpacing.vGapSm,
          Text(value, style: AppText.h1.size(22)),
          const SizedBox(height: 2),
          Text(label, style: AppText.caption),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  final double rating;
  const _StarRow({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: List.generate(5, (i) {
          final filled = i < rating.floor();
          return Icon(
            filled ? Iconsax.star1 : Iconsax.star,
            size: 13,
            color: filled ? AppPalette.amber : AppPalette.border,
          );
        }),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String text;
  final Color color;
  final Color bg;
  const _MiniChip({required this.text, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.rPill),
      child: Text(text, style: AppText.micro.on(color).size(10)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter tabs
// ─────────────────────────────────────────────────────────────────────────────
class _FilterTabs extends StatelessWidget {
  final AssignedTripController ctrl;
  const _FilterTabs({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
        itemCount: ProfessionalTripsScreen._filters.length,
        separatorBuilder: (_, __) => AppSpacing.hGapSm,
        itemBuilder: (_, i) {
          final f = ProfessionalTripsScreen._filters[i];
          final selected = ctrl.selectedFilter.value == f;
          return GestureDetector(
            onTap: () => ctrl.selectedFilter.value = f,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                gradient: selected ? AppPalette.brandGradient : null,
                color: selected ? null : AppPalette.card,
                borderRadius: AppRadius.rPill,
                border: Border.all(
                    color: selected ? Colors.transparent : AppPalette.border),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppPalette.primary.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                f,
                style: AppText.subtitle
                    .on(selected ? Colors.white : AppPalette.textMid)
                    .size(13),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trip card
// ─────────────────────────────────────────────────────────────────────────────
class _TripCard extends StatelessWidget {
  final AssignedTrip trip;
  final TripBucket bucket;
  final double earnings;
  final VoidCallback onTap;

  const _TripCard({
    required this.trip,
    required this.bucket,
    required this.earnings,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progress = TripStatusMapper.progressOf(trip.tripStatus);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppPalette.card,
          borderRadius: AppRadius.rXl,
          border: Border.all(color: AppPalette.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            _cardHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.lg),
              child: Column(
                children: [
                  _route(),
                  AppSpacing.vGapLg,
                  _infoGrid(),
                  if (bucket == TripBucket.inProcess) ...[
                    AppSpacing.vGapLg,
                    _progressBar(progress),
                  ],
                  AppSpacing.vGapLg,
                  _viewDetailsButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardHeader() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            gradient: bucket.gradient,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: AppRadius.rMd,
                ),
                child: const Icon(Iconsax.truck, color: Colors.white, size: 19),
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Trip ID',
                        style: AppText.micro.on(Colors.white.withValues(alpha: 0.85))),
                    Text(
                      trip.tripCode.isNotEmpty ? trip.tripCode : trip.tripId,
                      style: AppText.subtitle.on(Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: AppRadius.rPill,
                ),
                child: Text(
                  bucket.label.toUpperCase(),
                  style: AppText.micro.on(Colors.white).size(9),
                ),
              ),
            ],
          ),
        ),
        // Earnings badge floating over the header bottom edge.
        Positioned(
          right: AppSpacing.lg,
          bottom: -16,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppPalette.card,
              borderRadius: AppRadius.rMd,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Iconsax.money_recive,
                  size: 15, color: AppPalette.green),
              const SizedBox(width: 4),
              Text(_formatMoney(earnings),
                  style: AppText.title.on(AppPalette.green).size(15)),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _route() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
                color: AppPalette.greenBg, shape: BoxShape.circle),
            child: const Center(
              child: CircleAvatar(radius: 4, backgroundColor: AppPalette.green),
            ),
          ),
          Container(
            width: 2,
            height: 30,
            margin: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppPalette.green, AppPalette.danger],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: AppRadius.rPill,
            ),
          ),
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
                color: AppPalette.dangerBg, shape: BoxShape.circle),
            child: const Center(
              child:
                  CircleAvatar(radius: 4, backgroundColor: AppPalette.danger),
            ),
          ),
        ]),
        AppSpacing.hGapMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('FROM', style: AppText.micro.size(10)),
              Text(
                trip.pickupLocation.isEmpty ? 'Unknown' : trip.pickupLocation,
                style: AppText.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),
              Text('TO', style: AppText.micro.size(10)),
              Text(
                trip.deliveryLocation.isEmpty
                    ? 'Unknown'
                    : trip.deliveryLocation,
                style: AppText.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoGrid() {
    return Row(children: [
      Expanded(
        child: _infoTile(
            Iconsax.calendar_1, _formatDate(trip.pickupDate), 'Date'),
      ),
      AppSpacing.hGapSm,
      Expanded(
        child: _infoTile(Iconsax.routing, _formatDistance(trip.distance),
            'Distance'),
      ),
      AppSpacing.hGapSm,
      Expanded(
        child: _infoTile(
            Iconsax.clock, trip.estimatedEta ?? 'N/A', 'Duration'),
      ),
    ]);
  }

  Widget _infoTile(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppPalette.bg,
        borderRadius: AppRadius.rMd,
      ),
      child: Column(children: [
        Icon(icon, size: 16, color: AppPalette.textFaint),
        const SizedBox(height: 4),
        Text(value,
            style: AppText.label.on(AppPalette.textDark).weight(FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        Text(label, style: AppText.micro.size(9)),
      ]),
    );
  }

  Widget _progressBar(int progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Trip Progress', style: AppText.caption),
          Text('$progress%',
              style: AppText.caption.on(AppPalette.blue).weight(FontWeight.w700)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: AppRadius.rPill,
          child: LinearProgressIndicator(
            value: progress / 100,
            minHeight: 7,
            backgroundColor: AppPalette.border,
            valueColor: const AlwaysStoppedAnimation(AppPalette.blue),
          ),
        ),
      ],
    );
  }

  Widget _viewDetailsButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: onTap,
        icon: const Icon(Iconsax.eye, size: 17),
        label: Text('View Details', style: AppText.subtitle.on(AppPalette.textMid)),
        style: TextButton.styleFrom(
          backgroundColor: AppPalette.bg,
          foregroundColor: AppPalette.textMid,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyTrips extends StatelessWidget {
  final String filter;
  const _EmptyTrips({required this.filter});

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Iconsax.box,
      title: 'No trips found',
      subtitle: filter == 'All'
          ? "You don't have any trips yet."
          : "You don't have any ${filter.toLowerCase()} trips yet.",
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lightweight staggered entrance animation
// ─────────────────────────────────────────────────────────────────────────────
class _AnimatedIn extends StatelessWidget {
  final int index;
  final Widget child;
  const _AnimatedIn({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index.clamp(0, 6) * 60)),
      curve: Curves.easeOut,
      builder: (_, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 16), child: c),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Formatting helpers
// ─────────────────────────────────────────────────────────────────────────────
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String _formatDate(DateTime d) {
  final local = d.toLocal();
  return '${local.day} ${_months[local.month - 1]}';
}

String _formatDistance(String? raw) {
  if (raw == null || raw.isEmpty) return 'N/A';
  final n = double.tryParse(raw);
  if (n == null) return raw;
  return '${n.round()} km';
}

String _formatMoney(double amount) {
  if (amount >= 1000) {
    final k = amount / 1000;
    return '₹${k.toStringAsFixed(k % 1 == 0 ? 0 : 1)}k';
  }
  return '₹${amount.round()}';
}
