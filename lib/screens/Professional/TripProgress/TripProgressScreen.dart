import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import '../../../utils/constants.dart';
import '../../../controllers/Professional/track_trip_controller.dart';
import '../../../models/assigned_trip_model.dart';
import '../TrackTrip/TrackTripScreen.dart';
import '../../../utils/call_utils.dart';

// ── Design tokens (match Home & Fleet) ────────────────────────────────────────
const _primary   = Color(0xFFF36969);
const _bg        = Color(0xFFF9FAFB);
const _card      = Colors.white;
const _textDark  = Color(0xFF111827);
const _textMid   = Color(0xFF374151);
const _textGrey  = Color(0xFF6B7280);
const _border    = Color(0xFFE5E7EB);

class TripProgressScreen extends StatefulWidget {
  final AssignedTrip trip;
  const TripProgressScreen({super.key, required this.trip});

  @override
  State<TripProgressScreen> createState() => _TripProgressScreenState();
}

class _TripProgressScreenState extends State<TripProgressScreen>
    with SingleTickerProviderStateMixin {
  late TrackTripController _trackCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _trackCtrl = Get.put(TrackTripController());
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fadeCtrl.forward());
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  AssignedTrip get t => widget.trip;

  bool get _isInProgress {
    final s = t.tripStatus.toLowerCase();
    return s == 'in progress' || s == 'in-progress' || s == 'active' ||
        s == 'ongoing' || s == 'en route';
  }

  bool get _isCompleted {
    final s = t.tripStatus.toLowerCase();
    return s == 'completed' || s == 'done' || s == 'finished';
  }

  Color get _statusColor {
    if (_isCompleted)  return const Color(0xFF22C55E);
    if (_isInProgress) return const Color(0xFF3B82F6);
    return _primary;
  }

  String get _statusLabel {
    if (_isCompleted)  return 'Finished';
    if (_isInProgress) return 'In Progress';
    return 'Assigned';
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(children: [
                  _buildHero(),
                  const SizedBox(height: 20),
                  _buildInfoGrid(),
                  const SizedBox(height: 16),
                  if (t.specialInstructions.isNotEmpty) ...[
                    _buildInstructions(),
                    const SizedBox(height: 16),
                  ],
                  _buildActions(),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      color: _card,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: _textMid),
          onPressed: Get.back,
        ),
        Expanded(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.tripCode.isNotEmpty ? t.tripCode : t.tripId,
              textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w700, color: _textDark)),
            Container(
              margin: const EdgeInsets.only(top: 3),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
              child: Text(_statusLabel,
                style: GoogleFonts.poppins(
                  fontSize: 10, fontWeight: FontWeight.w600, color: _statusColor))),
          ],
        )),
        // Call company button
        if (t.companyMobileNo?.isNotEmpty ?? false)
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10)),
              child: const Icon(Iconsax.call, size: 18, color: Color(0xFF3B82F6))),
            onPressed: () => CallUtils.makeCall(t.companyMobileNo!),
          )
        else
          const SizedBox(width: 48),
      ]),
    );
  }

  // ── hero section ──────────────────────────────────────────────────────────
  Widget _buildHero() {
    return Stack(children: [
      // background image with gradient overlay
      ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28)),
        child: SizedBox(
          height: 200, width: double.infinity,
          child: Stack(fit: StackFit.expand, children: [
            Image.asset(AppImages.trip, fit: BoxFit.cover),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.55),
                  ])),
            ),
          ]),
        ),
      ),

      // badges
      Positioned(top: 16, left: 20,
        child: Row(children: [
          _heroBadge(_statusLabel, _statusColor),
          if (!_isCompleted && !_isInProgress) ...[
            const SizedBox(width: 8),
            _heroBadge('Pending Start', const Color(0xFF3B82F6)),
          ],
        ])),

      // CTA button overlaid on hero
      Positioned(right: 20, bottom: 20,
        child: Obx(() => AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: ElevatedButton(
            key: ValueKey(_isCompleted),
            onPressed: (_trackCtrl.isLoading.value || _isCompleted) ? null : () {
              if (_isInProgress) {
                Get.to(() => TrackTripScreen(tripId: t.tripId));
              } else {
                _trackCtrl.startTrip(t.tripId);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _isCompleted
                  ? Colors.grey[400]
                  : (_isInProgress ? const Color(0xFF3B82F6) : _primary),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 8,
              shadowColor: (_isInProgress
                  ? const Color(0xFF3B82F6) : _primary).withValues(alpha: 0.45),
            ),
            child: _trackCtrl.isLoading.value
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(
                    _isCompleted ? 'Trip Finished'
                      : (_isInProgress ? 'Track Trip' : 'Start Trip'),
                    style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ))),
    ]);
  }

  Widget _heroBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: GoogleFonts.poppins(
        fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)));
  }

  // ── info grid ─────────────────────────────────────────────────────────────
  Widget _buildInfoGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _card, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(children: [
          // route
          _routeRow('Origin', t.pickupLocation, const Color(0xFF22C55E)),
          Padding(
            padding: const EdgeInsets.only(left: 15, top: 4, bottom: 4),
            child: Container(width: 1.5, height: 18, color: _border)),
          _routeRow('Destination', t.deliveryLocation, _primary),
          const SizedBox(height: 20),
          const Divider(color: _border, height: 1),
          const SizedBox(height: 16),

          // 2×2 info cards
          GridView.count(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 2.2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              _infoTile(Iconsax.building, 'Company',
                t.companyName ?? 'N/A'),
              _infoTile(Iconsax.tag, 'Status',
                t.tripStatus.isEmpty ? 'N/A' : t.tripStatus),
              _infoTile(Iconsax.hashtag_1, 'Trip ID',
                t.tripCode.isNotEmpty ? t.tripCode : t.tripId),
              _infoTile(Iconsax.calendar_1, 'Date',
                '${t.pickupDate.day}/${t.pickupDate.month}/${t.pickupDate.year}'),
              if (t.vehicleNumber.isNotEmpty)
                _infoTile(Iconsax.truck, 'Vehicle', t.vehicleNumber),
              if (t.distance?.isNotEmpty ?? false)
                _infoTile(Iconsax.routing, 'Distance', t.distance!),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _routeRow(String label, String address, Color color) {
    return Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(Iconsax.location, color: color, size: 16)),
      const SizedBox(width: 14),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.poppins(
            fontSize: 10, color: _textGrey, fontWeight: FontWeight.w500)),
          Text(address.isEmpty ? 'N/A' : address,
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w700, color: _textDark)),
        ],
      )),
    ]);
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _bg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border)),
      child: Row(children: [
        Icon(icon, size: 16, color: _textGrey),
        const SizedBox(width: 8),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: GoogleFonts.poppins(
              fontSize: 9, color: _textGrey, fontWeight: FontWeight.w500)),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 11, fontWeight: FontWeight.w700, color: _textDark)),
          ],
        )),
      ]),
    );
  }

  // ── special instructions ──────────────────────────────────────────────────
  Widget _buildInstructions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFDE68A))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Iconsax.info_circle, size: 18, color: Color(0xFFF59E0B)),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Special Instructions', style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: const Color(0xFF92400E))),
              const SizedBox(height: 4),
              Text(t.specialInstructions, style: GoogleFonts.poppins(
                fontSize: 12, color: const Color(0xFF92400E))),
            ],
          )),
        ]),
      ),
    );
  }

  // ── bottom action buttons ─────────────────────────────────────────────────
  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        // primary action
        if (!_isCompleted)
          Obx(() => SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _trackCtrl.isLoading.value ? null : () {
                if (_isInProgress) {
                  Get.to(() => TrackTripScreen(tripId: t.tripId));
                } else {
                  _trackCtrl.startTrip(t.tripId);
                }
              },
              icon: _trackCtrl.isLoading.value
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Icon(_isInProgress ? Iconsax.location_tick : Iconsax.play_circle,
                      size: 20),
              label: Text(
                _trackCtrl.isLoading.value ? 'Loading…'
                  : (_isInProgress ? 'Track Live Trip' : 'Start Trip'),
                style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isInProgress
                    ? const Color(0xFF3B82F6) : _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          )),

        if (!_isCompleted) const SizedBox(height: 10),

        // call button
        if (t.companyMobileNo?.isNotEmpty ?? false)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => CallUtils.makeCall(t.companyMobileNo!),
              icon: const Icon(Iconsax.call, size: 18),
              label: Text('Call Company',
                style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _textMid,
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: _border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
      ]),
    );
  }
}
