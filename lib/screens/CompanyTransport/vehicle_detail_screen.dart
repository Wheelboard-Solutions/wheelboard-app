import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:iconsax/iconsax.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/vehicle_gps_socket_service.dart';
import '../../controllers/Transport/fleet_controller.dart';
import '../../models/get_vehicle_model.dart';
import '../../services/verification_service.dart';
import '../../utils/map_navigation_utils.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/smart_image.dart';
import 'Lease/create_lease_wizard.dart';

const _primary = Color(0xFFF36969);
const _primaryLight = Color(0xFFFFF1F1);
const _bg = Color(0xFFF9FAFB);
const _card = Colors.white;
const _textDark = Color(0xFF111827);
const _textGrey = Color(0xFF6B7280);
const _border = Color(0xFFE5E7EB);

class VehicleDetailScreen extends StatefulWidget {
  final Vehicle vehicle;
  const VehicleDetailScreen({super.key, required this.vehicle});

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  final DriverController _ctrl = Get.find<DriverController>();

  Map<String, dynamic>? _detail;
  bool _loading = true;
  int _imageIndex = 0;

  /// Persisted RC verification, read from the vehicle payload the backend
  /// already returns. No provider call is made to render it.
  bool _rcVerifying = false;
  String? _rcMessage;
  Map<String, dynamic>? _rcOverride;
  final VehicleGpsSocketService _gpsSocket = VehicleGpsSocketService();
  final List<VehicleGpsPoint> _gpsPoints = [];
  bool _gpsLoading = false;
  bool _gpsSocketConnected = false;
  String? _gpsVehicleId;

  @override
  void initState() {
    super.initState();
    _gpsSocket.onConnectionChange = (connected) {
      if (!mounted) return;
      setState(() => _gpsSocketConnected = connected);
    };
    _gpsSocket.onPoint = (point) {
      if (!mounted) return;
      setState(() => _upsertGpsPoint(point));
    };
    _load();
  }

  @override
  void dispose() {
    if (_gpsVehicleId != null) {
      _gpsSocket.unsubscribe(_gpsVehicleId!);
    }
    _gpsSocket.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await _ctrl.fetchVehicleDetails(widget.vehicle.vehicleId);
    setState(() {
      _detail = result;
      _loading = false;
    });
    await _syncGpsTracking();
  }

  /// The vehicle's stored RC verification.
  ///
  /// Prefers a result from a Verify tap in this session, otherwise reads what
  /// the backend already included on the vehicle payload — so the correct
  /// status renders on first paint with no extra request of any kind.
  Map<String, dynamic>? get _rcVerification {
    if (_rcOverride != null) return _rcOverride;
    final raw = _detail?['rcVerification'];
    return raw is Map<String, dynamic> ? raw : null;
  }

  /// Verify this vehicle's RC. The ONLY thing on this screen that can reach the
  /// provider, and only on an explicit tap.
  ///
  /// The backend short-circuits when the RC is already verified, so even a
  /// mis-tap on a verified vehicle costs no provider quota.
  Future<void> _verifyRc() async {
    if (_rcVerifying) return;

    setState(() {
      _rcVerifying = true;
      _rcMessage = null;
    });

    RcVerifyResult result;
    try {
      result = await _ctrl.verifySavedVehicleRc(widget.vehicle.vehicleId);
    } finally {
      // Released whatever happens, so a failure never leaves a stuck spinner.
      if (mounted) setState(() => _rcVerifying = false);
    }
    if (!mounted) return;

    setState(() {
      // Only the backend's verdict updates the displayed state — never an
      // optimistic local guess.
      _rcOverride = {
        'status': switch (result.state) {
          VerificationState.verified => 'verified',
          VerificationState.pending => 'pending',
          VerificationState.rejected => 'rejected',
          _ => 'not_verified',
        },
        'rcStatus': result.rc?.rcStatus,
        'rcExpiryDate': result.rc?.rcExpiryDate,
        'insuranceUpto': result.rc?.insuranceUpto,
        'puccUpto': result.rc?.puccUpto,
      };
      // Backend-authored, always user-safe copy.
      _rcMessage = result.isVerified ? null : result.message;
    });
  }

  Future<void> _syncGpsTracking() async {
    final v = _displayVehicle;
    if (v.gpsLastKnown == null || v.vehicleId.isEmpty) return;
    if (_gpsVehicleId == v.vehicleId && _gpsPoints.isNotEmpty) return;

    _gpsVehicleId = v.vehicleId;
    setState(() => _gpsLoading = true);
    final history = await _ctrl.fetchVehicleGpsHistory(v.vehicleId, limit: 500);
    if (mounted) {
      setState(() {
        _gpsPoints
          ..clear()
          ..addAll(history);
        _gpsLoading = false;
      });
    }
    await _gpsSocket.connectAndSubscribe(v.vehicleId);
  }

  void _upsertGpsPoint(VehicleGpsPoint point) {
    final index = _gpsPoints.indexWhere((item) => item.stableKey == point.stableKey);
    if (index >= 0) {
      _gpsPoints[index] = point;
    } else {
      _gpsPoints.add(point);
    }
    _gpsPoints.sort((a, b) {
      final aTime = DateTime.tryParse(a.recordedAt)?.millisecondsSinceEpoch ?? 0;
      final bTime = DateTime.tryParse(b.recordedAt)?.millisecondsSinceEpoch ?? 0;
      return aTime.compareTo(bTime);
    });
    if (_gpsPoints.length > 500) {
      _gpsPoints.removeRange(0, _gpsPoints.length - 500);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove ${widget.vehicle.vehicleModel}?',
            style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        content: const Text('This will permanently remove the vehicle from your fleet.',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel', style: TextStyle(color: _textGrey, fontFamily: 'Poppins')),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Remove', style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final ok = await _ctrl.deleteVehicle(widget.vehicle.vehicleId);
      if (ok) Get.back();
    }
  }

  Future<void> _callDriver(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  // ── Data helpers ──────────────────────────────────────────────────────────
  /// The driver assigned to this vehicle.
  ///
  /// `GET /fleet/vehicles/:id` returns this as `assignedDriver`; the screen used
  /// to read `driverInfo`, a key the backend never sends, so the Assigned
  /// Driver card never rendered. `driverInfo` is still accepted so an older
  /// backend keeps working, and both spellings of each field are tolerated.
  Map<String, dynamic>? get _driver {
    final raw = _detail?['assignedDriver'] ?? _detail?['driverInfo'];
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final name = (map['name'] ?? map['driverName'] ?? '').toString();
    if (name.trim().isEmpty) return null;
    return {
      ...map,
      'driverName': name,
      'driverMobile':
          (map['phoneNumber'] ?? map['driverMobile'] ?? '').toString(),
      'driverImage': (map['image'] ?? map['driverImage'] ?? '').toString(),
    };
  }
  Map<String, dynamic>? get _metrics => _detail?['metrics'] as Map<String, dynamic>?;
  List get _recentTrips => (_detail?['recentTrips'] as List?) ?? [];
  int get _totalTrips => (_detail?['totalTrips'] as num?)?.toInt() ?? 0;

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'available': return const Color(0xFF22C55E);
      case 'in-transit': case 'in transit': return const Color(0xFF3B82F6);
      case 'assigned': return const Color(0xFFF59E0B);
      case 'maintenance': return const Color(0xFFEF4444);
      default: return _textGrey;
    }
  }

  /// Vehicle to display. Prefer the freshly-fetched detail (same endpoint the
  /// web Vehicle Details uses via getVehicleById) so the header image and all
  /// other fields match the web exactly. The list-supplied `widget.vehicle` is
  /// only a fallback while the detail is still loading — it often lacks the
  /// uploaded image, which is why the header showed the placeholder icon.
  Vehicle get _displayVehicle {
    final d = _detail;
    if (d != null && d.isNotEmpty) {
      try {
        return Vehicle.fromJson(d);
      } catch (_) {
        // Fall through to the list item on any shape mismatch.
      }
    }
    return widget.vehicle;
  }

  @override
  Widget build(BuildContext context) {
    final v = _displayVehicle;

    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        slivers: [
          _buildSliverHeader(v),
          SliverToBoxAdapter(
            child: _loading
                // Shaped like the real detail layout, so the page does not
                // jump when the vehicle lands.
                ? const SkeletonDetailView()
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatusRow(v),
                        const SizedBox(height: 16),
                        _buildQuickStats(v),
                        const SizedBox(height: 16),
                        _buildInfoCard(v),
                        const SizedBox(height: 16),
                        _buildRcCard(v),
                        const SizedBox(height: 16),
                        _buildGpsCard(v),
                        const SizedBox(height: 16),
                        if (_driver != null && (_driver!['driverName']?.toString().isNotEmpty == true)) ...[
                          _buildDriverCard(),
                          const SizedBox(height: 16),
                        ],
                        _buildMetricsCard(),
                        const SizedBox(height: 16),
                        if (_recentTrips.isNotEmpty) ...[
                          _buildRecentTrips(),
                          const SizedBox(height: 16),
                        ],
                        _buildActionsCard(v),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverHeader(Vehicle v) {
    final images = v.imageUrls;

    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      backgroundColor: _card,
      elevation: 0,
      leading: GestureDetector(
        onTap: () => Get.back(),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6)],
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: _textDark),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6)],
          ),
          child: IconButton(
            icon: const Icon(Iconsax.refresh, size: 18, color: _textDark),
            onPressed: _load,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Real vehicle photo, with the icon shown ONLY when no image exists.
            //
            // Must be SmartImage, not raw Image.network: this app persists
            // vehicle images as base64 `data:` URIs, which Image.network cannot
            // decode — it failed and fell through to the placeholder icon, which
            // is why the detail header showed a truck while the Fleet card
            // (already using SmartImage) rendered the photo correctly.
            SmartImage(
              source: images.isNotEmpty ? images[_imageIndex] : null,
              fit: BoxFit.cover,
              placeholder: _imgPlaceholder(),
            ),

            // Gradient overlay at bottom
            const Positioned(
              bottom: 0, left: 0, right: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0x99000000)],
                  ),
                ),
                child: SizedBox(height: 80),
              ),
            ),

            // Image dots
            if (images.length > 1)
              Positioned(
                bottom: 12,
                left: 0, right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(images.length, (i) => GestureDetector(
                    onTap: () => setState(() => _imageIndex = i),
                    child: Container(
                      width: i == _imageIndex ? 18 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i == _imageIndex ? Colors.white : Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  )),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(Vehicle v) {
    final sc = _statusColor(v.status);
    return Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sc.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sc.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: sc, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(v.status.isEmpty ? 'Unknown' : v.status,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sc, fontFamily: 'Poppins')),
        ]),
      ),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(v.ownershipType.isEmpty ? 'Owned' : v.ownershipType,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF3B82F6), fontFamily: 'Poppins')),
      ),
      if (v.vehicleType.isNotEmpty) ...[
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(v.vehicleType,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8B5CF6), fontFamily: 'Poppins')),
        ),
      ],
    ]);
  }

  Widget _buildQuickStats(Vehicle v) {
    return Row(children: [
      _statCard('$_totalTrips', 'Total Trips', Iconsax.routing, _primary),
      const SizedBox(width: 10),
      _statCard(v.manufacturingYear > 0 ? '${v.manufacturingYear}' : '—', 'Year', Iconsax.calendar, const Color(0xFF3B82F6)),
      const SizedBox(width: 10),
      _statCard(v.vehicleType.isNotEmpty ? v.vehicleType : '—', 'Category', Iconsax.truck, const Color(0xFF8B5CF6)),
    ]);
  }

  Widget _statCard(String val, String label, IconData icon, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 5),
            Text(val,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color, fontFamily: 'Poppins'),
                maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
            Text(label, style: const TextStyle(fontSize: 10, color: _textGrey, fontFamily: 'Poppins'), textAlign: TextAlign.center),
          ]),
        ),
      );

  Widget _buildInfoCard(Vehicle v) {
    return _sectionCard('Vehicle Information', [
      _infoRow(Iconsax.truck, 'Model', v.vehicleModel),
      _infoRow(Iconsax.receipt_text, 'Registration', v.vehicleNumber),
      if (v.manufacturingYear > 0)
        _infoRow(Iconsax.calendar, 'Year', '${v.manufacturingYear}'),
      if (v.ownershipType.isNotEmpty)
        _infoRow(Iconsax.building, 'Ownership', v.ownershipType),
      if (v.vehicleType.isNotEmpty)
        _infoRow(Iconsax.category, 'Category', v.vehicleType),
      if (v.description.isNotEmpty)
        _infoRow(Iconsax.note_text, 'Description', v.description, multiline: true),
    ]);
  }

  VehicleGpsPoint? _latestGpsPoint(Vehicle v) {
    if (_gpsPoints.isNotEmpty) return _gpsPoints.last;
    final gps = v.gpsLastKnown;
    if (gps?.latitude == null || gps?.longitude == null) return null;
    return VehicleGpsPoint(
      telemetryId: '',
      vehicleId: v.vehicleId,
      connectionId: '',
      providerDeviceId: gps!.providerDeviceId,
      latitude: gps.latitude!,
      longitude: gps.longitude!,
      speedKph: gps.speedKph,
      heading: null,
      ignition: gps.ignition,
      fuelLevel: null,
      odometer: null,
      recordedAt: gps.lastSeenAt ?? DateTime.now().toUtc().toIso8601String(),
      receivedAt: gps.syncedAt,
    );
  }

  /// RC verification status.
  ///
  /// Rendered entirely from Wheelboard's PERSISTED state — opening this screen
  /// never calls the KYC provider. That keeps a verified vehicle showing as
  /// verified tomorrow, during a provider outage, and without spending quota.
  /// The Verify action below is the only thing that contacts the provider, and
  /// only when the owner taps it.
  Widget _buildRcCard(Vehicle v) {
    final rc = _rcVerification;
    final status = rc?['status']?.toString() ?? 'not_verified';
    final verified = status == 'verified';
    final pending = status == 'pending';
    final rejected = status == 'rejected';

    final Color accent = verified
        ? const Color(0xFF16A34A)
        : pending
        ? const Color(0xFFF59E0B)
        : rejected
        ? const Color(0xFFDC2626)
        : _textGrey;

    final IconData icon = verified
        ? Iconsax.tick_circle
        : pending
        ? Iconsax.clock
        : rejected
        ? Iconsax.close_circle
        : Iconsax.shield_cross;

    final String label = verified
        ? 'RC Verified'
        : pending
        ? 'Verification Pending'
        : rejected
        ? 'Verification Rejected'
        : 'RC Not Verified';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              if (!verified && !pending)
                GestureDetector(
                  onTap: _rcVerifying ? null : _verifyRc,
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _rcVerifying
                          ? _border
                          : _primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: _primary.withValues(alpha: 0.3)),
                    ),
                    child: _rcVerifying
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _primary,
                            ),
                          )
                        : Text(
                            rejected ? 'Re-verify' : 'Verify RC',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: _primary,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Poppins',
                            ),
                          ),
                  ),
                ),
            ],
          ),
          if (_rcMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _rcMessage!,
              style: const TextStyle(
                fontSize: 12,
                color: _textGrey,
                fontFamily: 'Poppins',
              ),
            ),
          ],
          if (verified) ...[
            const SizedBox(height: 10),
            _rcDetail('Registration', v.vehicleNumber),
            if (rc?['rcStatus'] != null)
              _rcDetail('RC status', rc!['rcStatus'].toString()),
            if (rc?['rcExpiryDate'] != null)
              _rcDetail('RC valid until', rc!['rcExpiryDate'].toString()),
            if (rc?['insuranceUpto'] != null)
              _rcDetail('Insurance until', rc!['insuranceUpto'].toString()),
            if (rc?['puccUpto'] != null)
              _rcDetail('PUCC until', rc!['puccUpto'].toString()),
          ],
          if (rejected && rc?['rejectionReason'] != null) ...[
            const SizedBox(height: 6),
            Text(
              rc!['rejectionReason'].toString(),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFDC2626),
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _rcDetail(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: _textGrey,
              fontFamily: 'Poppins',
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _textDark,
              fontFamily: 'Poppins',
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildGpsCard(Vehicle v) {
    final gps = v.gpsLastKnown;
    if (gps == null) {
      return _sectionCard('GPS Tracking', [
        _infoRow(Iconsax.gps_slash, 'Status', 'Not connected'),
      ]);
    }

    final latest = _latestGpsPoint(v);
    final status = gps.stale ? 'Stale' : 'Live';
    final statusColor = gps.stale ? const Color(0xFFF59E0B) : const Color(0xFF22C55E);
    final lastSeen = latest?.recordedAt == null
        ? 'Waiting for ping'
        : DateTime.tryParse(latest!.recordedAt)?.toLocal().toString() ?? latest.recordedAt;
    final hasLocation = latest != null;

    return _sectionCard('GPS Tracking', [
      _infoRow(Iconsax.gps, 'Status', status),
      _infoRow(
        Iconsax.wifi,
        'Socket',
        _gpsSocketConnected ? 'Connected' : 'Idle',
      ),
      _infoRow(Iconsax.link, 'Provider', gps.providerName.isNotEmpty ? gps.providerName : 'Connected'),
      _infoRow(Iconsax.clock, 'Last Seen', lastSeen),
      _infoRow(
        Iconsax.speedometer,
        'Speed',
        latest?.speedKph != null ? '${latest!.speedKph!.toStringAsFixed(1)} km/h' : 'N/A',
      ),
      _infoRow(
        Iconsax.flash,
        'Ignition',
        latest?.ignition == null ? 'N/A' : (latest!.ignition! ? 'On' : 'Off'),
      ),
      _infoRow(
        Iconsax.routing,
        'Route Points',
        _gpsLoading ? 'Loading...' : '${_gpsPoints.length}',
      ),
      if (hasLocation)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Column(
            children: [
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openGpsLocation(latest),
                    icon: Icon(Iconsax.location, size: 16, color: statusColor),
                    label: Text(
                      'View',
                      style: TextStyle(
                        color: statusColor,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: statusColor),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _navigateToVehicle(v, latest),
                    icon: const Icon(Iconsax.routing,
                        size: 16, color: Colors.white),
                    label: const Text(
                      'Navigate',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _shareLocation(v, latest, gps.stale),
                  icon: const Icon(Iconsax.send_2, size: 16, color: _primary),
                  label: Text(
                    _driverPhone.isEmpty
                        ? 'Share Location'
                        : 'Send to ${_driver!['driverName']}',
                    style: const TextStyle(
                      color: _primary,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      if (_gpsPoints.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recent GPS Points',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _textDark,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 8),
              ..._gpsPoints.reversed.take(5).map((point) {
                final time = DateTime.tryParse(point.recordedAt)
                        ?.toLocal()
                        .toString() ??
                    point.recordedAt;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Iconsax.location_tick, size: 14, color: _primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _textDark,
                            fontFamily: 'Poppins',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 10,
                          color: _textGrey,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
    ]);
  }

  Future<void> _openGpsLocation(VehicleGpsPoint gps) async {
    final uri = Uri.parse(
      'https://www.google.com/maps?q=${gps.latitude},${gps.longitude}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// The assigned driver's number, digits only. Empty when no driver is
  /// assigned or the record carries no contact number.
  String get _driverPhone => (_driver?['driverMobile']?.toString() ?? '')
      .replaceAll(RegExp(r'[^0-9]'), '');

  /// Turn-by-turn directions to the vehicle, through the app's existing map
  /// launcher (native Maps first, browser last) rather than a second map SDK.
  Future<void> _navigateToVehicle(Vehicle v, VehicleGpsPoint point) async {
    final opened = await MapNavigationUtils.openDirections(
      destination: LatLng(point.latitude, point.longitude),
      destinationLabel: v.vehicleNumber,
    );
    if (!opened) {
      SnackBarHelper.error('No maps app could open this location.');
    }
  }

  /// Send the vehicle's position to the driver on it.
  ///
  /// Straight to the driver over WhatsApp when a number is on file — the same
  /// `wa.me` deep link the service screens use — and otherwise out through the
  /// system share sheet so the owner can still pass it to whoever is driving.
  ///
  /// A fix that has gone quiet is labelled "last known" with its timestamp: a
  /// driver acting on a stale position needs to know it is stale.
  Future<void> _shareLocation(
    Vehicle v,
    VehicleGpsPoint point,
    bool stale,
  ) async {
    final recordedAt = DateTime.tryParse(point.recordedAt)?.toLocal();
    final when = recordedAt == null
        ? ''
        : ' (${recordedAt.day}/${recordedAt.month} '
            '${recordedAt.hour.toString().padLeft(2, '0')}:'
            '${recordedAt.minute.toString().padLeft(2, '0')})';
    final label = stale ? 'last known location' : 'current location';
    final message = '${v.vehicleNumber} — $label$when: '
        'https://www.google.com/maps?q=${point.latitude},${point.longitude}';

    final phone = _driverPhone;
    if (phone.isNotEmpty) {
      final uri = Uri.parse(
        'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
      SnackBarHelper.error(
        'WhatsApp is not available — opening share instead.',
      );
    }

    await Share.share(message, subject: '${v.vehicleNumber} location');
  }

  Widget _buildDriverCard() {
    final d = _driver!;
    final name = d['driverName']?.toString() ?? '';
    final phone = d['driverMobile']?.toString() ?? '';
    final img = d['driverImage']?.toString();

    return _sectionCard('Assigned Driver', [
      Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 54, height: 54,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _primaryLight, width: 2)),
            child: ClipOval(
              child: img != null && img.isNotEmpty
                  ? Image.network(img, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _driverInitials(name))
                  : _driverInitials(name),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _textDark, fontFamily: 'Poppins')),
              if (phone.isNotEmpty)
                Text(phone, style: const TextStyle(fontSize: 12, color: _textGrey, fontFamily: 'Poppins')),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('On Duty', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF22C55E), fontFamily: 'Poppins')),
              ),
            ]),
          ),
          if (phone.isNotEmpty)
            GestureDetector(
              onTap: () => _callDriver(phone),
              child: Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: const Color(0xFF22C55E).withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Iconsax.call, size: 18, color: Color(0xFF22C55E)),
              ),
            ),
        ]),
      ),
    ]);
  }

  Widget _driverInitials(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'D';
    return Container(
      color: _primaryLight,
      alignment: Alignment.center,
      child: Text(initial, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _primary, fontFamily: 'Poppins')),
    );
  }

  Widget _buildMetricsCard() {
    final m = _metrics ?? const <String, dynamic>{};
    // Null is preserved as "unknown" rather than coerced to 0: the backend
    // returns null when a vehicle has no completed trips or no recorded
    // distance, which is not the same as a measured zero.
    // `costPerKm` is the explicit canonical name; `tripEfficiency` is the
    // backward-compatible alias carrying the identical ₹/km value.
    final costPerKm = (m['costPerKm'] as num?)?.toDouble() ??
        (m['tripEfficiency'] as num?)?.toDouble();
    final monthlyUsage = (m['monthlyUsage'] as num?)?.toDouble();

    // Odometer reading mirrors how wheelboard-fe shows it for the company user
    // (the "Mileage" field on the vehicle info card). Numeric values get a "km"
    // suffix; free-form strings are shown as-is; empty falls back to "N/A".
    final odoStr = _detail?['mileage']?.toString().trim() ?? '';
    final isNumericOdo = RegExp(r'^[0-9]+(\.[0-9]+)?$').hasMatch(odoStr);
    final odometerText = odoStr.isEmpty
        ? 'N/A'
        : (isNumericOdo ? '$odoStr km' : odoStr);

    return _sectionCard('Vehicle Metrics', [
      _metricRow('Odometer', odometerText, Iconsax.speedometer, const Color(0xFF22C55E)),
      // ₹/km is a COST metric. Labelled "Cost per km" so it cannot be confused
      // with fuel mileage (km/L) or the 0-100 driver performance score, both of
      // which were also called "Trip Efficiency" elsewhere in the platform.
      _metricRow(
        'Cost per km',
        costPerKm != null ? '₹${costPerKm.toStringAsFixed(2)}/km' : 'N/A',
        Iconsax.trend_up,
        _primary,
      ),
      _metricRow(
        'Monthly Usage',
        monthlyUsage != null ? '${monthlyUsage.toStringAsFixed(1)} km' : 'N/A',
        Iconsax.chart_square,
        const Color(0xFF3B82F6),
      ),
    ]);
  }

  Widget _metricRow(String label, String value, IconData icon, Color color) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: _textGrey, fontFamily: 'Poppins'))),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color, fontFamily: 'Poppins')),
        ]),
      );

  Widget _buildRecentTrips() {
    return _sectionCard('Recent Trips', [
      ..._recentTrips.take(3).map((t) {
        final trip = t as Map<String, dynamic>;
        final code = trip['tripCode']?.toString() ?? trip['_id']?.toString() ?? '—';
        final from = trip['pickupCity']?.toString() ?? trip['from']?.toString() ?? '';
        final to = trip['dropCity']?.toString() ?? trip['to']?.toString() ?? '';
        final status = trip['status']?.toString() ?? '';
        final sc = _tripStatusColor(status);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: sc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(Iconsax.routing, size: 18, color: sc),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(code,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textDark, fontFamily: 'Poppins')),
                if (from.isNotEmpty || to.isNotEmpty)
                  Text('$from → $to',
                      style: const TextStyle(fontSize: 11, color: _textGrey, fontFamily: 'Poppins'),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            if (status.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: sc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(status,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: sc, fontFamily: 'Poppins')),
              ),
          ]),
        );
      }),
    ]);
  }

  Color _tripStatusColor(String s) {
    switch (s.toLowerCase()) {
      case 'completed': return const Color(0xFF22C55E);
      case 'in-transit': case 'in transit': return const Color(0xFF3B82F6);
      case 'assigned': return const Color(0xFFF59E0B);
      case 'cancelled': return const Color(0xFFEF4444);
      default: return _textGrey;
    }
  }

  Widget _buildActionsCard(Vehicle v) {
    return Column(children: [
      // List for lease
      if (v.status.toLowerCase() == 'available')
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Get.to(() => const CreateLeaseWizard()),
              icon: const Icon(Iconsax.receipt_text, size: 16),
              label: const Text('List for Lease', style: TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
            ),
          ),
        ),

      // Delete
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _confirmDelete,
          icon: const Icon(Iconsax.trash, size: 16, color: Color(0xFFEF4444)),
          label: const Text('Remove Vehicle', style: TextStyle(color: Color(0xFFEF4444), fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFEF4444)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    ]);
  }

  Widget _infoRow(IconData icon, String label, String value, {bool multiline = false}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: _textGrey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: const TextStyle(fontSize: 11, color: _textGrey, fontFamily: 'Poppins')),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textDark, fontFamily: 'Poppins'),
                    maxLines: multiline ? null : 1,
                    overflow: multiline ? null : TextOverflow.ellipsis),
              ]),
            ),
          ],
        ),
      );

  Widget _sectionCard(String title, List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Text(title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _textDark, fontFamily: 'Poppins')),
            ),
            const Divider(color: _border, height: 1),
            ...children.expand((w) => [w, const Divider(color: _border, height: 1)]).toList()..removeLast(),
            const SizedBox(height: 4),
          ],
        ),
      );

  Widget _imgPlaceholder() => Container(
        color: const Color(0xFFF3F4F6),
        child: const Center(child: Icon(Iconsax.truck, size: 64, color: _textGrey)),
      );
}
