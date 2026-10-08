import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../utils/location_service.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/tracking_socket_service.dart';
import '../../utils/call_utils.dart';
import '../../utils/app_logger.dart';

/// A single, role-aware live trip-tracking map shared by BOTH the company
/// (fleet owner / transporter) and the professional (driver). It mirrors the
/// web tracking page functionally:
///
///  * Loads the trip from `GET /trips/:id` and re-polls every few seconds.
///  * Plots pickup (green), destination (red) and the driver's LIVE position
///    (blue) — read from the latest `route.waypoints[]` entry the driver's GPS
///    pings persist (same source the web map consumes), with a fallback to
///    `currentLocation` / `lastLocation`.
///  * Draws the travelled path as a polyline so both users can see progress.
///  * When opened by the driver (`isDriver: true`) it also streams the device
///    GPS to `POST /trips/:id/location`, so the company sees the driver move in
///    near-real-time.
class LiveTripTrackingScreen extends StatefulWidget {
  /// Accepts either the Mongo/_id (tripRowId) or the human TRP id — the backend
  /// resolves both.
  final String tripId;

  /// True when the viewer is the assigned driver (enables GPS push).
  final bool isDriver;

  const LiveTripTrackingScreen({
    super.key,
    required this.tripId,
    this.isDriver = false,
  });

  @override
  State<LiveTripTrackingScreen> createState() => _LiveTripTrackingScreenState();
}

class _LiveTripTrackingScreenState extends State<LiveTripTrackingScreen> {
  // ── design tokens (match the app) ───────────────────────────────────────
  static const _primary = Color(0xFFF36969);
  static const _green = Color(0xFF22C55E);
  static const _blue = Color(0xFF3B82F6);
  static const _textDark = Color(0xFF111827);
  static const _textGrey = Color(0xFF6B7280);

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  Map<String, dynamic>? _trip;
  Map<String, dynamic>? _driverProfile;
  bool _loading = true;
  String? _error;

  Timer? _pollTimer;

  // realtime socket (mirrors web useRealtimeTracking)
  final TrackingSocketService _socket = TrackingSocketService();
  LatLng? _liveDriver; // last position pushed over the socket
  Map<String, dynamic>? _liveEta; // server-computed ETA from the socket
  bool _trackingStarted = false; // driver emitted tracking:start

  // driver GPS push
  StreamSubscription<Position>? _posStream;
  Timer? _pingTimer;
  Position? _lastPos;

  bool get _canUseGoogleMap =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    _loadTrip(initial: true);
    _initSocket();
    // REST poll is a resilient fallback (and seeds the route/markers); the live
    // marker is driven by the socket `location:update` when connected. Slower
    // interval since the socket carries the realtime stream.
    _pollTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => _loadTrip());
    if (widget.isDriver) _startDriverGps();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _posStream?.cancel();
    _pingTimer?.cancel();
    if (widget.isDriver && _trackingStarted) {
      _socket.stopTracking(widget.tripId);
    }
    _socket.unsubscribeTrip(widget.tripId);
    _socket.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ── realtime socket (web parity: useRealtimeTracking) ──────────────────────
  Future<void> _initSocket() async {
    _socket.onConnectionChange = (connected) {
      if (!connected) return;
      // Viewer subscribes to the trip room; driver (re)starts its session.
      _socket.subscribeTrip(widget.tripId);
      if (widget.isDriver) _ensureDriverTrackingStarted();
    };
    _socket.onLocation = (lat, lng, eta) {
      if (!mounted) return;
      setState(() {
        _liveDriver = LatLng(lat, lng);
        if (eta != null) _liveEta = eta;
      });
      _rebuildMapItems();
    };
    await _socket.connect();
  }

  /// Emit `tracking:start` once with a minimal route so the server will accept
  /// and broadcast our `gps:ping`s to the company viewer. Needs the trip route
  /// to be loaded; called again after the first load if not yet started.
  void _ensureDriverTrackingStarted() {
    if (_trackingStarted || !_socket.isConnected) return;
    final dest = _destination;
    if (dest == null) return;
    final pickup = _pickup ?? dest;
    final distKm =
        (_trip?['route']?['plannedDistance'] as num?)?.toDouble() ?? 0;
    final durS = (_trip?['route']?['plannedDuration'] as num?)?.toInt() ?? 0;
    _socket.startTracking(
      tripId: widget.tripId,
      route: TrackingSocketService.buildStoredRoute(
        startLat: pickup.latitude,
        startLng: pickup.longitude,
        endLat: dest.latitude,
        endLng: dest.longitude,
        distanceMeters: distKm * 1000,
        durationSeconds: durS,
      ),
      destination: {
        'latitude': dest.latitude,
        'longitude': dest.longitude,
        'formattedAddress': _to(),
      },
    );
    _trackingStarted = true;
  }

  // ── data loading ────────────────────────────────────────────────────────
  Map<String, dynamic>? _extractTrip(dynamic body) {
    if (body is Map<String, dynamic>) {
      if (body['route'] != null ||
          body['status'] != null ||
          body['tripId'] != null) {
        return body;
      }
      if (body['data'] is Map<String, dynamic>) return body['data'];
      if (body['trip'] is Map<String, dynamic>) return body['trip'];
      return body;
    }
    if (body is Map) return Map<String, dynamic>.from(body);
    return null;
  }

  Future<void> _loadTrip({bool initial = false}) async {
    try {
      // NOTE: ApiClient.get already returns the decoded JSON body (response.data)
      // — calling `.data` on it again is what previously threw and produced the
      // "Failed to load trip" error.
      final body = await ApiClient.instance
          .get<dynamic>(ApiEndpoints.trips.details(widget.tripId));
      final trip = _extractTrip(body);
      if (!mounted) return;
      if (trip == null) {
        setState(() {
          _loading = false;
          _error = 'Trip data unavailable. Pull to retry.';
        });
        return;
      }
      setState(() {
        _trip = trip;
        _loading = false;
        _error = null;
      });
      _rebuildMapItems(animate: initial);
      _maybeFetchDriverProfile();
      // Route is now known — start the driver's socket session if the socket
      // connected before the first trip load completed.
      if (widget.isDriver) _ensureDriverTrackingStarted();
    } catch (e) {
      AppLogger.e('LiveTripTracking load failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_trip == null) _error = 'Failed to load trip. Pull to retry.';
      });
    }
  }

  Future<void> _maybeFetchDriverProfile() async {
    if (_driverProfile != null) return;
    final d = _trip?['driverId'];
    String? id;
    if (d is String && d.isNotEmpty) {
      id = d;
    } else if (d is Map) {
      id = (d['_id'] ?? d['id'] ?? d['userId'])?.toString();
    }
    if (id == null || id.isEmpty) return;
    try {
      final res = await ApiClient.instance
          .get<dynamic>(ApiEndpoints.users.publicProfile(id));
      final map = res is Map<String, dynamic>
          ? (res['data'] is Map<String, dynamic> ? res['data'] : res)
          : null;
      if (map != null && mounted) setState(() => _driverProfile = map);
    } catch (_) {
      // best-effort enrichment only
    }
  }

  // ── geometry helpers ──────────────────────────────────────────────────────
  LatLng? _coordToLatLng(dynamic coords) {
    if (coords is List && coords.length >= 2) {
      final lng = (coords[0] as num?)?.toDouble();
      final lat = (coords[1] as num?)?.toDouble();
      if (lat != null && lng != null && (lat != 0 || lng != 0)) {
        return LatLng(lat, lng);
      }
    }
    return null;
  }

  LatLng? get _pickup =>
      _coordToLatLng(_trip?['route']?['startLocation']?['coordinates']);
  LatLng? get _destination =>
      _coordToLatLng(_trip?['route']?['endLocation']?['coordinates']);

  List<LatLng> get _waypoints {
    final raw = _trip?['route']?['waypoints'];
    if (raw is! List) return [];
    final pts = <LatLng>[];
    for (final w in raw) {
      final ll = _coordToLatLng((w as Map?)?['coordinates']);
      if (ll != null) pts.add(ll);
    }
    return pts;
  }

  /// The driver's current position. Priority:
  ///   1. live socket `location:update` (realtime, same as web),
  ///   2. latest persisted GPS waypoint,
  ///   3. explicit current/last location fields.
  LatLng? get _driverLatLng {
    if (_liveDriver != null) return _liveDriver;
    final wps = _waypoints;
    if (wps.isNotEmpty) return wps.last;
    return _coordToLatLng(_trip?['currentLocation']?['coordinates']) ??
        _coordToLatLng(_trip?['lastLocation']?['coordinates']);
  }

  void _rebuildMapItems({bool animate = false}) {
    final markers = <Marker>{};
    final pickup = _pickup;
    final dest = _destination;
    final driver = _driverLatLng;

    if (pickup != null) {
      markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: pickup,
        infoWindow: const InfoWindow(title: 'Pickup'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
    }
    if (dest != null) {
      markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: dest,
        infoWindow: const InfoWindow(title: 'Destination'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    }
    if (driver != null) {
      markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: driver,
        infoWindow: InfoWindow(title: _driverName(), snippet: _statusLabel()),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ));
    }

    // Travelled path: pickup → all GPS waypoints → (driver) ; plus a faint
    // remaining leg to the destination.
    final path = <LatLng>[
      if (pickup != null) pickup,
      ..._waypoints,
    ];
    final polylines = <Polyline>{};
    if (path.length >= 2) {
      polylines.add(Polyline(
        polylineId: const PolylineId('travelled'),
        points: path,
        color: _blue,
        width: 4,
      ));
    }
    final remainingFrom = driver ?? (path.isNotEmpty ? path.last : pickup);
    if (remainingFrom != null && dest != null) {
      polylines.add(Polyline(
        polylineId: const PolylineId('remaining'),
        points: [remainingFrom, dest],
        color: _primary.withValues(alpha: 0.5),
        width: 3,
        patterns: [PatternItem.dash(20), PatternItem.gap(12)],
      ));
    }

    setState(() {
      _markers
        ..clear()
        ..addAll(markers);
      _polylines
        ..clear()
        ..addAll(polylines);
    });

    // Keep the camera on the driver as they move; on first load fit the route.
    if (driver != null && !animate) {
      _mapController?.animateCamera(CameraUpdate.newLatLng(driver));
    } else {
      _fitBounds([pickup, dest, driver].whereType<LatLng>().toList());
    }
  }

  void _fitBounds(List<LatLng> pts) {
    if (_mapController == null || pts.isEmpty) return;
    if (pts.length == 1) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(pts.first, 13));
      return;
    }
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      minLat = p.latitude < minLat ? p.latitude : minLat;
      maxLat = p.latitude > maxLat ? p.latitude : maxLat;
      minLng = p.longitude < minLng ? p.longitude : minLng;
      maxLng = p.longitude > maxLng ? p.longitude : maxLng;
    }
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        60,
      ),
    );
  }

  // ── driver GPS push (driver role only) ─────────────────────────────────────
  Future<void> _startDriverGps() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      _posStream = Geolocator.getPositionStream(
        locationSettings: LocationService.trackingSettings(),
      ).listen((pos) {
        _lastPos = pos;
        _pingLocation(pos);
      });
      _pingTimer = Timer.periodic(const Duration(seconds: 12), (_) {
        if (_lastPos != null) _pingLocation(_lastPos!);
      });
    } catch (e) {
      AppLogger.e('Driver GPS start failed: $e');
    }
  }

  Future<void> _pingLocation(Position pos) async {
    // 1) Realtime broadcast to viewers over the socket (web parity).
    if (_socket.isConnected && _trackingStarted) {
      _socket.sendPing(
        tripId: widget.tripId,
        ping: {
          'latitude': pos.latitude,
          'longitude': pos.longitude,
          'accuracy': pos.accuracy,
          'speed': pos.speed,
          'heading': pos.heading,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
    }
    // 2) Persist to the trip waypoints over REST (history + polling fallback).
    try {
      await ApiClient.instance.post(
        ApiEndpoints.trips.updateLocation(widget.tripId),
        data: {
          'coordinates': [pos.longitude, pos.latitude],
          'speed': pos.speed,
          'accuracy': pos.accuracy,
          'heading': pos.heading,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        },
      );
    } catch (_) {
      // best-effort
    }
  }

  // ── presentation helpers ──────────────────────────────────────────────────
  String _driverName() {
    final p = _driverProfile?['profile'] as Map<String, dynamic>? ??
        _driverProfile;
    final fn = (p?['firstName'] ?? '').toString();
    final ln = (p?['lastName'] ?? '').toString();
    final joined = '$fn $ln'.trim();
    if (joined.isNotEmpty) return joined;
    final n = (_trip?['driver_name'] ?? '').toString();
    return n.isNotEmpty ? n : (widget.isDriver ? 'You' : 'Driver');
  }

  String _driverPhone() {
    final p = _driverProfile?['profile'] as Map<String, dynamic>? ??
        _driverProfile;
    return (p?['phoneNumber'] ?? _trip?['driver_phone'] ?? '').toString();
  }

  String _vehicleName() {
    final v = _trip?['vehicleId'];
    if (v is Map) {
      final name = (v['name'] ?? v['model'] ?? '').toString();
      final reg = (v['registrationNumber'] ?? '').toString();
      return [name, reg].where((s) => s.isNotEmpty).join(' • ');
    }
    return '';
  }

  String _from() =>
      (_trip?['route']?['startLocation']?['address'] ?? '').toString();
  String _to() =>
      (_trip?['route']?['endLocation']?['address'] ?? '').toString();

  String _rawStatus() => (_trip?['status'] ?? '').toString();
  String _statusLabel() =>
      _rawStatus().replaceAll('-', ' ').toUpperCase();

  Color _statusColor() {
    final s = _rawStatus();
    if (s == 'completed') return _green;
    if (s == 'cancelled') return _textGrey;
    if (s.contains('progress') ||
        s.contains('route') ||
        s.contains('pickup') ||
        s.contains('pod') ||
        s.contains('arrived')) {
      return _blue;
    }
    return _primary;
  }

  String _eta() {
    // Prefer the server-computed live ETA from the socket; fall back to the
    // trip's planned duration.
    final secs = (_liveEta?['durationSeconds'] as num?)?.toInt() ??
        (_trip?['route']?['plannedDuration'] as num?)?.toInt();
    if (secs == null || secs <= 0) return 'N/A';
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    if (h >= 24) return '${h ~/ 24}d ${h % 24}h';
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  String _distance() {
    final km = (_trip?['route']?['plannedDistance'] as num?)?.toDouble();
    if (km == null || km <= 0) return 'N/A';
    return '${km.round()} km';
  }

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            if (_loading)
              const Expanded(
                child: Center(
                    child: CircularProgressIndicator(color: _primary)))
            else if (_error != null && _trip == null)
              Expanded(child: _errorView())
            else ...[
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.45,
                child: _canUseGoogleMap ? _mapPanel() : _desktopMapFallback(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _details(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    final code = (_trip?['tripId'] ?? widget.tripId).toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)
      ]),
      child: Row(children: [
        IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back_ios_new, color: _primary, size: 20),
        ),
        Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Track Trip',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _textDark)),
            Text(code.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500])),
          ]),
        ),
        IconButton(
          onPressed: () => _loadTrip(),
          icon: const Icon(Icons.refresh, color: _primary, size: 20),
        ),
      ]),
    );
  }

  Widget _mapPanel() {
    return Stack(children: [
      GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(20.5937, 78.9629),
          zoom: 4,
        ),
        onMapCreated: (c) {
          _mapController = c;
          _rebuildMapItems(animate: true);
        },
        markers: _markers,
        polylines: _polylines,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
      ),
      Positioned(
        right: 12,
        bottom: 12,
        child: FloatingActionButton.small(
          heroTag: 'recenter',
          backgroundColor: Colors.white,
          onPressed: () {
            final d = _driverLatLng;
            if (d != null) {
              _mapController?.animateCamera(CameraUpdate.newLatLngZoom(d, 14));
            } else {
              _fitBounds([_pickup, _destination].whereType<LatLng>().toList());
            }
          },
          child: const Icon(Icons.my_location, color: _primary),
        ),
      ),
      if (_driverLatLng == null)
        Positioned(
          left: 12,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Waiting for driver location...',
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.white),
            ),
          ),
        ),
    ]);
  }

  Widget _desktopMapFallback() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.map_outlined, color: _primary, size: 42),
          const SizedBox(height: 12),
          Text(
            'Map preview unavailable on macOS',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Run on iPhone, Android, or web to see the live Google Map.',
            style: GoogleFonts.poppins(fontSize: 13, color: _textGrey),
          ),
          const SizedBox(height: 18),
          _desktopRouteLine('Pickup', _from(), _green),
          const SizedBox(height: 10),
          _desktopRouteLine('Destination', _to(), _primary),
          if (_driverLatLng == null) ...[
            const SizedBox(height: 14),
            Text(
              'Waiting for driver location...',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _textGrey,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _desktopRouteLine(String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 5),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.poppins(fontSize: 11, color: _textGrey)),
              Text(
                value.isNotEmpty ? value : 'Not available',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text(_error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style:
                  GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600])),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              setState(() => _loading = true);
              _loadTrip(initial: true);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
                backgroundColor: _primary, foregroundColor: Colors.white),
          ),
        ]),
      ),
    );
  }

  Widget _details() {
    final phone = _driverPhone();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _statusColor().withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _statusColor().withValues(alpha: 0.4)),
          ),
          child: Text(_statusLabel(),
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _statusColor())),
        ),
        const Spacer(),
        if (!widget.isDriver && phone.isNotEmpty)
          GestureDetector(
            onTap: () => CallUtils.makeCall(phone),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.phone, color: Color(0xFF27AE60), size: 16),
                const SizedBox(width: 6),
                Text('Call Driver',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF27AE60))),
              ]),
            ),
          ),
      ]),
      const SizedBox(height: 16),

      // distance + ETA
      Row(children: [
        Expanded(child: _stat(Icons.straighten, 'Distance', _distance())),
        const SizedBox(width: 12),
        Expanded(child: _stat(Icons.schedule, 'Est. Duration', _eta())),
      ]),
      const SizedBox(height: 12),

      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _row(Icons.person, widget.isDriver ? 'You (Driver)' : 'Driver',
            _driverName()),
        if (_vehicleName().isNotEmpty) ...[
          const Divider(height: 20),
          _row(Icons.local_shipping, 'Vehicle', _vehicleName()),
        ],
      ])),
      const SizedBox(height: 12),

      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _routePoint('Pickup', _from(), _green, line: true),
        const SizedBox(height: 4),
        _routePoint('Destination', _to(), _primary, line: false),
      ])),
      const SizedBox(height: 24),
    ]);
  }

  Widget _stat(IconData icon, String label, String value) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: _primary),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 10, color: _textGrey)),
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _textDark)),
          ]),
        ]),
      );

  Widget _card(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEFEFEF)),
        ),
        child: child,
      );

  Widget _row(IconData icon, String label, String value) => Row(children: [
        Icon(icon, size: 16, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: GoogleFonts.poppins(fontSize: 10, color: _textGrey)),
            Text(value.isEmpty ? 'N/A' : value,
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _textDark)),
          ]),
        ),
      ]);

  Widget _routePoint(String label, String addr, Color color,
          {required bool line}) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border:
                    Border.all(color: color.withValues(alpha: 0.25), width: 4)),
          ),
          if (line) Container(width: 2, height: 28, color: Colors.grey[200]),
        ]),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: GoogleFonts.poppins(fontSize: 10, color: _textGrey)),
          Text(addr.isEmpty ? 'N/A' : addr,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _textDark)),
        ])),
      ]);
}
