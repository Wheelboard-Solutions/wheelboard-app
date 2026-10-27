import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:iconsax/iconsax.dart';

import '../../../controllers/Professional/assigned_trip_controller.dart';
import '../../../controllers/Professional/trip_navigation_controller.dart';
import '../../../models/assigned_trip_model.dart';
import '../../../services/route_service.dart';
import '../../../theme/design_system.dart';
import '../../../utils/call_utils.dart';
import '../../../utils/map_navigation_utils.dart';
import '../../../widgets/custom_snackbar.dart';
import '../Navigation/PodCollectionScreen.dart';
import '../Navigation/TripCompletedScreen.dart';

/// Wheelboard Driver Navigation — a dedicated, full-screen fleet navigation
/// experience (Uber Driver / Rapido Captain class) built on top of Google Maps.
///
/// The map is the primary surface; a draggable bottom sheet holds trip details
/// and the per-step CTA, a compact live dashboard floats on top, and an
/// intelligent camera fits the route on every state change while never fighting
/// the driver's manual gestures (a Re-center control restores auto-follow).
///
/// IMPORTANT: this is a presentation layer only. The step machine, OTP flow,
/// LR confirm, POD hand-off, GPS + socket pinging and every backend call live in
/// [TripNavigationController] / [AssignedTripController] and are untouched —
/// 100% behavioural + API parity is preserved.
class TrackTripScreen extends StatefulWidget {
  final String tripId;
  const TrackTripScreen({super.key, required this.tripId});

  @override
  State<TrackTripScreen> createState() => _TrackTripScreenState();
}

class _TrackTripScreenState extends State<TrackTripScreen>
    with TickerProviderStateMixin {
  // Collapsed bottom-sheet fraction (keeps the map dominant).
  static const double _collapsedFrac = 0.32;

  final Set<Marker> _markers = {};
  LatLng? _destination;
  GoogleMapController? _mapController;

  late TripNavigationController _navController;
  late DraggableScrollableController _sheetController;

  // OTP / reason controllers
  final _startOtpController = TextEditingController();
  final _lrOtpController = TextEditingController();
  final _completionReasonController = TextEditingController();

  // ── custom map assets ──────────────────────────────────────────────────────
  BitmapDescriptor? _truckMarker;
  BitmapDescriptor? _pickupMarker;
  BitmapDescriptor? _destMarkerIcon;

  // ── route & live data ──────────────────────────────────────────────────────
  LatLng? _pickup;
  final Set<Polyline> _polylines = {};
  double _speedKmh = 0;
  bool _gpsEnabled = true;
  bool _online = true;
  bool _nearDestination = false;
  Timer? _connTimer;

  // ── road routing (Google Directions) ──────────────────────────────────────
  RouteResult? _currentRoute;
  LatLng? _lastRoutedFrom;
  bool _isFetchingRoute = false;

  // ── smooth marker animation ────────────────────────────────────────────────
  AnimationController? _truckCtrl;
  LatLng? _truckLatLng;
  LatLng _animFrom = const LatLng(0, 0);
  LatLng _animTo = const LatLng(0, 0);
  double _animHeading = 0;

  // ── intelligent camera ─────────────────────────────────────────────────────
  bool _autoFollow = true;
  bool _expectProgrammaticMove = false;
  bool _followZoomApplied = false;
  bool _hasFitInitial = false;
  Timer? _resumeFollowTimer;

  bool get _canUseGoogleMap =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// Resilient access: the previous `Get.find<AssignedTripController>()` threw
  /// (→ "Failed to load trip") whenever this screen was opened from a route
  /// that hadn't already registered the controller (e.g. Trip Details). Put it
  /// on demand instead.
  AssignedTripController get _assignedCtrl {
    if (!Get.isRegistered<AssignedTripController>()) {
      return Get.put(AssignedTripController());
    }
    return Get.find<AssignedTripController>();
  }

  @override
  void initState() {
    super.initState();
    _navController = Get.put(TripNavigationController());
    _sheetController = DraggableScrollableController();

    _truckCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addListener(_onTruckTick);

    final assignedCtrl = _assignedCtrl;
    _initFromTrip(assignedCtrl);

    // If the assigned-trips list hasn't been loaded yet (e.g. deep link or
    // opened from Trip Details), fetch it then initialise — instead of failing.
    if (assignedCtrl.assignedTrips.isEmpty) {
      assignedCtrl.fetchAssignedTrips().then((_) {
        if (mounted) _initFromTrip(assignedCtrl);
      });
    }

    // Live GPS → animate the truck + recompute metrics + (optionally) follow.
    ever(_navController.currentPosition, (Position? pos) {
      if (pos != null && mounted) _updateMapForPosition(pos);
    });

    // Re-fit the camera intelligently whenever the trip phase changes.
    ever(_navController.currentStep, (TripStep step) => _onStepChanged(step));

    _initCustomMarkers();
    _checkGpsStatus();
    _initConnectivity();
  }

  bool _initialised = false;

  /// Locate this trip in the assigned list and initialise the step machine,
  /// destination marker and (for active trips) live GPS. Safe to call again
  /// after the list loads.
  void _initFromTrip(AssignedTripController assignedCtrl) {
    final trip = assignedCtrl.assignedTrips.firstWhereOrNull(
      (t) => t.tripId == widget.tripId,
    );
    if (trip == null || _initialised) return;
    _initialised = true;

    _navController.initFromStatus(trip.tripStatus);

    if (trip.latitude != null &&
        trip.latitude != 0 &&
        trip.longitude != null &&
        trip.longitude != 0) {
      _setDestMarker(LatLng(trip.latitude!, trip.longitude!));
    } else {
      _geocodeDestination(trip.deliveryLocation);
    }
    // Also geocode the pickup so we can draw the full route polyline.
    if (trip.pickupLocation.isNotEmpty) {
      _geocodePickup(trip.pickupLocation);
    }

    final step = _navController.currentStep.value;
    if (step == TripStep.inTransit ||
        step == TripStep.navigatingToPickup ||
        step == TripStep.atPickup) {
      _navController.startTrackingForTrip(widget.tripId);
    }

    // Web parity: when the trip is awaiting LR confirmation, auto-open the
    // "Confirm Trip" OTP modal on entry (the web does `setShowOtpModal(true)`).
    if (step == TripStep.confirmOtp && !_lrModalAutoShown) {
      _lrModalAutoShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onConfirmLr(trip);
      });
    }
  }

  bool _lrModalAutoShown = false;

  void _setDestMarker(LatLng pos) {
    if (!mounted) return;
    setState(() {
      _destination = pos;
      _markers.removeWhere((m) => m.markerId.value == 'destination');
      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: pos,
          infoWindow: const InfoWindow(title: 'Destination'),
          icon:
              _destMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
      _rebuildPolyline();
    });
    _maybeFitInitial();
    _triggerRouteFetch();
  }

  void _setPickupMarker(LatLng pos) {
    if (!mounted) return;
    setState(() {
      _pickup = pos;
      _markers.removeWhere((m) => m.markerId.value == 'pickup');
      _markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: pos,
          infoWindow: const InfoWindow(title: 'Pickup'),
          icon:
              _pickupMarker ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
      _rebuildPolyline();
    });
    _maybeFitInitial();
    _triggerRouteFetch();
  }

  Future<void> _geocodeDestination(String address) async {
    if (address.isEmpty) return;
    try {
      final locs = await geo.locationFromAddress(address);
      if (locs.isNotEmpty) {
        _setDestMarker(LatLng(locs.first.latitude, locs.first.longitude));
      }
    } catch (_) {}
  }

  Future<void> _geocodePickup(String address) async {
    if (address.isEmpty) return;
    try {
      final locs = await geo.locationFromAddress(address);
      if (locs.isNotEmpty) {
        _setPickupMarker(LatLng(locs.first.latitude, locs.first.longitude));
      }
    } catch (_) {}
  }

  // ── custom marker creation ────────────────────────────────────────────────
  Future<void> _initCustomMarkers() async {
    try {
      final results = await Future.wait([
        _buildMarkerBitmap(
          bgColor: AppPalette.primary,
          icon: Icons.local_shipping,
          size: 110,
          pin: false,
        ),
        _buildMarkerBitmap(
          bgColor: AppPalette.green,
          icon: Icons.trip_origin,
          size: 96,
          pin: true,
        ),
        _buildMarkerBitmap(
          bgColor: AppPalette.danger,
          icon: Icons.flag,
          size: 96,
          pin: true,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _truckMarker = results[0];
        _pickupMarker = results[1];
        _destMarkerIcon = results[2];
        // Re-place existing markers with custom icons.
        if (_destination != null) _setDestMarker(_destination!);
        if (_pickup != null) _setPickupMarker(_pickup!);
        final p = _truckLatLng;
        if (p != null) _placeTruckMarker(p, _animHeading);
      });
    } catch (_) {
      // Marker painting failed — fall back to default coloured markers silently.
    }
  }

  /// Paints a branded marker. [pin] draws a tapered location-pin tail (for
  /// pickup/destination); otherwise a flat rounded disc (for the vehicle).
  static Future<BitmapDescriptor> _buildMarkerBitmap({
    required Color bgColor,
    required IconData icon,
    double size = 96,
    bool pin = false,
  }) async {
    final recorder = ui.PictureRecorder();
    final h = pin ? size * 1.3 : size;
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, h));
    final cx = size / 2;
    final cy = size / 2;
    final r = size / 2 - 6;

    // Drop shadow.
    canvas.drawCircle(
      Offset(cx, cy + 3),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Pin tail (only for location pins).
    if (pin) {
      final tail = Path()
        ..moveTo(cx - r * 0.42, cy + r * 0.55)
        ..lineTo(cx, h - 4)
        ..lineTo(cx + r * 0.42, cy + r * 0.55)
        ..close();
      canvas.drawPath(tail, Paint()..color = bgColor);
    }

    // Filled background circle + white ring.
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = bgColor);
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );

    // Icon in the centre.
    final tp = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size * 0.4,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.white,
        ),
      )
      ..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), h.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  // ── live position handler ─────────────────────────────────────────────────
  void _updateMapForPosition(Position pos) {
    final to = LatLng(pos.latitude, pos.longitude);
    _speedKmh = pos.speed > 0 ? pos.speed * 3.6 : 0;

    // Smoothly animate the vehicle marker from its previous spot to the new one.
    _animateTruckTo(to, pos.heading);

    // Reroute when driver deviates > 200 m from the last routed origin.
    final lastRouted = _lastRoutedFrom;
    if (lastRouted != null) {
      final deviationKm = _haversineKm(
        pos.latitude,
        pos.longitude,
        lastRouted.latitude,
        lastRouted.longitude,
      );
      if (deviationKm > 0.2) {
        _triggerRouteFetch();
      }
    } else {
      // No route yet — try to fetch one now that we have a live position.
      _triggerRouteFetch();
    }

    // Live ETA / distance / progress.
    final route = _currentRoute;
    final navDest = _routeDestinationForStep(_navController.currentStep.value);

    if (navDest != null) {
      double distKm;
      int? routeEtaMin;

      if (route != null && route.points.length > 1) {
        // Use remaining road distance from the nearest route point.
        final nearIdx = _nearestIndex(route.points, to);
        double roadDist = 0;
        for (int i = nearIdx; i < route.points.length - 1; i++) {
          roadDist += _haversineKm(
            route.points[i].latitude,
            route.points[i].longitude,
            route.points[i + 1].latitude,
            route.points[i + 1].longitude,
          );
        }
        distKm = roadDist;
        routeEtaMin = route.durationMinutes;
      } else {
        distKm = _haversineKm(
          pos.latitude,
          pos.longitude,
          navDest.latitude,
          navDest.longitude,
        );
      }

      final speedKmh = pos.speed > 0.5 ? pos.speed * 3.6 : 40.0;
      final etaMin = routeEtaMin ?? (distKm / speedKmh * 60).round();

      _navController.distanceRemaining.value = distKm >= 1.0
          ? '${distKm.toStringAsFixed(1)} km'
          : '${(distKm * 1000).toStringAsFixed(0)} m';
      _navController.eta.value = etaMin > 60
          ? '${etaMin ~/ 60}h ${etaMin % 60}m'
          : '$etaMin min';

      // "Arriving now" proximity check — always Haversine to final destination.
      if (_destination != null) {
        final toDestKm = _haversineKm(
          pos.latitude,
          pos.longitude,
          _destination!.latitude,
          _destination!.longitude,
        );
        final near = toDestKm < 0.12;
        if (near != _nearDestination && mounted) {
          setState(() => _nearDestination = near);
        }
      }

      // Progress along the trip (pickup → destination).
      if (_pickup != null && _destination != null) {
        final totalKm = _haversineKm(
          _pickup!.latitude,
          _pickup!.longitude,
          _destination!.latitude,
          _destination!.longitude,
        );
        final toDestKm = _haversineKm(
          pos.latitude,
          pos.longitude,
          _destination!.latitude,
          _destination!.longitude,
        );
        if (totalKm > 0) {
          _navController.progress.value = ((totalKm - toDestKm) / totalKm)
              .clamp(0.0, 1.0);
        }
      }
    }

    // Follow the vehicle during active transit (respecting manual pan).
    if (_navController.currentStep.value == TripStep.inTransit && _autoFollow) {
      _followVehicle(to);
    }
  }

  // ── smooth marker interpolation ────────────────────────────────────────────
  void _animateTruckTo(LatLng to, double heading) {
    _animFrom = _truckLatLng ?? to;
    _animTo = to;
    _animHeading = heading;
    if (_truckCtrl == null) {
      _placeTruckMarker(to, heading);
      return;
    }
    _truckCtrl!
      ..reset()
      ..forward();
  }

  void _onTruckTick() {
    final t = _truckCtrl?.value ?? 1.0;
    final p = LatLng(
      ui.lerpDouble(_animFrom.latitude, _animTo.latitude, t)!,
      ui.lerpDouble(_animFrom.longitude, _animTo.longitude, t)!,
    );
    _truckLatLng = p;
    if (mounted) _placeTruckMarker(p, _animHeading);
  }

  void _placeTruckMarker(LatLng p, double heading) {
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'truck');
      _markers.add(
        Marker(
          markerId: const MarkerId('truck'),
          position: p,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          rotation: heading,
          zIndexInt: 10,
          icon:
              _truckMarker ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
      _rebuildPolyline();
    });
  }

  // ── road routing ─────────────────────────────────────────────────────────

  /// Returns the destination LatLng the driver should navigate toward for the
  /// given trip step. Before/at pickup → go to pickup; after pickup → go to
  /// the drop-off destination. Returns null when no navigation is needed.
  LatLng? _routeDestinationForStep(TripStep step) {
    switch (step) {
      case TripStep.readyToStart:
      case TripStep.navigatingToPickup:
      case TripStep.atPickup:
        return _pickup;
      case TripStep.inTransit:
      case TripStep.atDestination:
      case TripStep.podUpload:
        return _destination;
      case TripStep.confirmOtp:
      case TripStep.completed:
        return null;
    }
  }

  /// Fetches a real road route from Google Directions API, stores the result,
  /// and redraws the polylines. Safe to call from any async context.
  Future<void> _fetchAndSetRoute(LatLng origin, LatLng destination) async {
    if (_isFetchingRoute) return;
    _isFetchingRoute = true;
    try {
      final result = await routeService.getRoute(
        origin: origin,
        destination: destination,
      );
      if (!mounted) return;
      setState(() {
        _currentRoute = result;
        _lastRoutedFrom = origin;
        _rebuildPolyline();
      });
      // Fit camera to the full route extent on first load.
      if (result != null && result.points.length > 1) {
        _fitCameraToRoutePoints(result.points);
      }
    } finally {
      _isFetchingRoute = false;
    }
  }

  /// Triggers a route fetch for the current step, using the driver's live
  /// position as origin. No-op when we don't yet have both endpoints.
  void _triggerRouteFetch() {
    final step = _navController.currentStep.value;
    final dest = _routeDestinationForStep(step);
    final driver = _driverLatLng;
    if (dest == null || driver == null) return;
    _fetchAndSetRoute(driver, dest);
  }

  /// Fits the camera to bounds of all route points (more accurate than the
  /// two-point bounds used for initial fit).
  void _fitCameraToRoutePoints(List<LatLng> pts) {
    if (pts.isEmpty || _mapController == null) return;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted || _mapController == null) return;
      try {
        _programmaticAnimate(
          CameraUpdate.newLatLngBounds(_boundsFromPoints(pts), 72),
        );
      } catch (_) {}
    });
  }

  /// Index of the point in [pts] nearest to [pos] (for completed/remaining split).
  int _nearestIndex(List<LatLng> pts, LatLng pos) {
    int best = 0;
    double bestDist = double.infinity;
    for (int i = 0; i < pts.length; i++) {
      final d = _haversineKm(
        pos.latitude,
        pos.longitude,
        pts[i].latitude,
        pts[i].longitude,
      );
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }

  void _rebuildPolyline() {
    _polylines.clear();

    final route = _currentRoute;
    final currentLL =
        _truckLatLng ??
        (_navController.currentPosition.value != null
            ? LatLng(
                _navController.currentPosition.value!.latitude,
                _navController.currentPosition.value!.longitude,
              )
            : null);

    if (route != null && route.points.length > 1) {
      // Real road route — split into completed (grey) and remaining (brand red).
      final pts = route.points;
      final splitIdx = currentLL != null ? _nearestIndex(pts, currentLL) : 0;

      final completed = pts.sublist(0, splitIdx + 1);
      final remaining = pts.sublist(splitIdx);

      if (completed.length > 1) {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('travelled'),
            points: completed,
            color: AppPalette.textFaint,
            width: 4,
            patterns: [PatternItem.dot, PatternItem.gap(14)],
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        );
      }

      if (remaining.length > 1) {
        // Casing shadow for depth.
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('remaining_casing'),
            points: remaining,
            color: AppPalette.primary.withValues(alpha: 0.22),
            width: 12,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        );
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('remaining'),
            points: remaining,
            color: AppPalette.primary,
            width: 6,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        );
      }
    } else if (_destination != null) {
      // Fallback: straight line while route is loading.
      final origin = currentLL ?? _pickup;
      if (origin != null) {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('remaining_casing'),
            points: [origin, _destination!],
            color: AppPalette.primary.withValues(alpha: 0.22),
            width: 12,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        );
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('remaining'),
            points: [origin, _destination!],
            color: AppPalette.primary,
            width: 6,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        );
      }
    }
  }

  // ── intelligent camera management ───────────────────────────────────────────
  LatLng? get _driverLatLng {
    if (_truckLatLng != null) return _truckLatLng;
    final p = _navController.currentPosition.value;
    return p != null ? LatLng(p.latitude, p.longitude) : null;
  }

  /// Fit the camera to the points relevant to the current trip phase.
  ///  • before pickup → driver + pickup + destination (whole route)
  ///  • after pickup  → driver + destination (remaining route)
  void _fitCameraForStep(TripStep step) {
    final pts = <LatLng>[];
    final driver = _driverLatLng;
    switch (step) {
      case TripStep.inTransit:
      case TripStep.atDestination:
      case TripStep.podUpload:
        if (driver != null) pts.add(driver);
        if (_destination != null) pts.add(_destination!);
        break;
      case TripStep.confirmOtp:
      case TripStep.readyToStart:
      case TripStep.navigatingToPickup:
      case TripStep.atPickup:
      case TripStep.completed:
        if (driver != null) pts.add(driver);
        if (_pickup != null) pts.add(_pickup!);
        if (_destination != null) pts.add(_destination!);
        break;
    }
    if (pts.isEmpty || _mapController == null) return;

    // Defer slightly so the platform view has laid out (avoids bounds throw).
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted || _mapController == null) return;
      try {
        if (pts.length == 1) {
          _programmaticAnimate(CameraUpdate.newLatLngZoom(pts.first, 15));
        } else {
          _programmaticAnimate(
            CameraUpdate.newLatLngBounds(_boundsFromPoints(pts), 80),
          );
        }
      } catch (_) {
        /* map not ready yet — ignore */
      }
    });
  }

  LatLngBounds _boundsFromPoints(List<LatLng> pts) {
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    // Pad a touch so markers aren't flush against the edge.
    const pad = 0.0025;
    return LatLngBounds(
      southwest: LatLng(minLat - pad, minLng - pad),
      northeast: LatLng(maxLat + pad, maxLng + pad),
    );
  }

  void _followVehicle(LatLng to) {
    if (_mapController == null) return;
    if (!_followZoomApplied) {
      _programmaticAnimate(
        CameraUpdate.newCameraPosition(CameraPosition(target: to, zoom: 16.5)),
      );
      _followZoomApplied = true;
    } else {
      _programmaticAnimate(CameraUpdate.newLatLng(to));
    }
  }

  void _programmaticAnimate(CameraUpdate update) {
    _expectProgrammaticMove = true;
    _mapController?.animateCamera(update);
  }

  void _maybeFitInitial() {
    if (_hasFitInitial || _mapController == null) return;
    if (_pickup == null && _destination == null) return;
    _hasFitInitial = true;
    _fitCameraForStep(_navController.currentStep.value);
  }

  void _onStepChanged(TripStep step) {
    _followZoomApplied = false;
    _autoFollow = true;
    _resumeFollowTimer?.cancel();
    // Clear the previous route so we immediately show the straight-line
    // fallback while the new road route loads.
    setState(() {
      _currentRoute = null;
      _lastRoutedFrom = null;
      _rebuildPolyline();
    });
    _fitCameraForStep(step);
    _triggerRouteFetch();
  }

  void _onCameraMoveStarted() {
    // Programmatic moves we initiated are not user gestures.
    if (_expectProgrammaticMove) return;
    if (_autoFollow && mounted) setState(() => _autoFollow = false);
    // Resume auto-follow after a period of inactivity.
    _resumeFollowTimer?.cancel();
    _resumeFollowTimer = Timer(const Duration(seconds: 15), _resumeAutoFollow);
  }

  void _onCameraIdle() => _expectProgrammaticMove = false;

  void _resumeAutoFollow() {
    if (!mounted) return;
    setState(() {
      _autoFollow = true;
      _followZoomApplied = false;
    });
    final step = _navController.currentStep.value;
    final driver = _driverLatLng;
    if (step == TripStep.inTransit && driver != null) {
      _followVehicle(driver);
    } else {
      _fitCameraForStep(step);
    }
  }

  void _recenter() {
    _resumeFollowTimer?.cancel();
    HapticFeedback.selectionClick();
    _resumeAutoFollow();
  }

  Future<void> _openExternalNavigation(AssignedTrip trip) async {
    final dest = _routeDestinationForStep(_navController.currentStep.value);
    if (dest == null) {
      SnackBarHelper.error('Navigation is not available for this trip step.');
      return;
    }
    final ok = await MapNavigationUtils.openDirections(
      origin: _driverLatLng,
      destination: dest,
      destinationLabel: dest == _pickup
          ? trip.pickupLocation
          : trip.deliveryLocation,
    );
    if (!ok) {
      SnackBarHelper.error('Could not open maps on this device.');
    }
  }

  // Haversine great-circle distance in km.
  static double _haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  // ── GPS + connectivity status ───────────────────────────────────────────────
  Future<void> _checkGpsStatus() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (mounted) setState(() => _gpsEnabled = enabled);
  }

  void _initConnectivity() {
    _checkConnectivity();
    _connTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _checkConnectivity(),
    );
  }

  Future<void> _checkConnectivity() async {
    bool ok;
    try {
      final res = await InternetAddress.lookup(
        'one.one.one.one',
      ).timeout(const Duration(seconds: 4));
      ok = res.isNotEmpty && res.first.rawAddress.isNotEmpty;
    } catch (_) {
      ok = false;
    }
    // Also re-check GPS while we're polling.
    final gps = await Geolocator.isLocationServiceEnabled();
    if (mounted && (ok != _online || gps != _gpsEnabled)) {
      setState(() {
        _online = ok;
        _gpsEnabled = gps;
      });
    }
  }

  @override
  void dispose() {
    _navController.stopTracking();
    _truckCtrl?.dispose();
    _sheetController.dispose();
    _resumeFollowTimer?.cancel();
    _connTimer?.cancel();
    _startOtpController.dispose();
    _lrOtpController.dispose();
    _completionReasonController.dispose();
    super.dispose();
  }

  // ── step → label / headline / colour ──────────────────────────────────────
  String _stepLabel(TripStep step) {
    switch (step) {
      case TripStep.confirmOtp:
        return 'Awaiting Confirmation';
      case TripStep.readyToStart:
        return 'Ready to Start';
      case TripStep.navigatingToPickup:
        return 'En Route to Pickup';
      case TripStep.atPickup:
        return 'At Pickup';
      case TripStep.inTransit:
        return 'In Transit';
      case TripStep.atDestination:
        return 'At Destination';
      case TripStep.podUpload:
        return 'Upload POD';
      case TripStep.completed:
        return 'Completed';
    }
  }

  String _stepHeadline(TripStep step) {
    switch (step) {
      case TripStep.confirmOtp:
        return 'Confirm your Lorry Receipt';
      case TripStep.readyToStart:
        return 'Ready to start';
      case TripStep.navigatingToPickup:
        return 'Heading to pickup';
      case TripStep.atPickup:
        return 'At the pickup point';
      case TripStep.inTransit:
        return 'On the way';
      case TripStep.atDestination:
      case TripStep.podUpload:
        return 'Arrived at destination';
      case TripStep.completed:
        return 'Trip completed';
    }
  }

  Color _stepColor(TripStep step) {
    switch (step) {
      case TripStep.confirmOtp:
        return AppPalette.amber;
      case TripStep.readyToStart:
        return AppPalette.blue;
      case TripStep.navigatingToPickup:
        return AppPalette.purple;
      case TripStep.atPickup:
        return const Color(0xFF06B6D4);
      case TripStep.inTransit:
        return AppPalette.green;
      case TripStep.atDestination:
      case TripStep.podUpload:
        return AppPalette.primary;
      case TripStep.completed:
        return AppPalette.green;
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final assignedCtrl = _assignedCtrl;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppPalette.bg,
      body: Obx(() {
        final trip =
            assignedCtrl.assignedTrips.firstWhereOrNull(
              (t) => t.tripId == widget.tripId,
            ) ??
            AssignedTrip(
              tripId: widget.tripId,
              userId: '',
              vehicleId: '',
              vehicleNumber: '',
              vehicleModel: '',
              vehicleType: '',
              driverId: '',
              driverName: 'Loading...',
              driverContact: '',
              pickupLocation: '',
              deliveryLocation: '',
              pickupDate: DateTime.now(),
              pickupTime: '',
              specialInstructions: '',
              payRange: '',
              tripCode: '',
              tripStatus: 'scheduled',
              createdDate: DateTime.now(),
              totalBidCount: 0,
            );

        final step = _navController.currentStep.value;

        return Stack(
          children: [
            Positioned.fill(
              child: _canUseGoogleMap
                  ? GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target:
                            _destination ?? const LatLng(28.5581811, 77.344654),
                        zoom: 13,
                      ),
                      onMapCreated: (c) {
                        _mapController = c;
                        _maybeFitInitial();
                      },
                      onCameraMoveStarted: _onCameraMoveStarted,
                      onCameraIdle: _onCameraIdle,
                      markers: _markers,
                      polylines: _polylines,
                      myLocationEnabled: false,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      compassEnabled: false,
                      mapToolbarEnabled: false,
                      rotateGesturesEnabled: true,
                      tiltGesturesEnabled: true,
                      mapType: MapType.normal,
                      style: _mapStyle,
                      padding: EdgeInsets.only(
                        top: 96,
                        bottom: size.height * _collapsedFrac + 8,
                      ),
                    )
                  : _desktopNavigationFallback(trip),
            ),

            // Compact live dashboard on top.
            SafeArea(child: _topDashboard(step)),

            // Re-center control (only when the driver has taken manual control).
            if (_canUseGoogleMap && !_autoFollow)
              Positioned(
                right: AppSpacing.lg,
                bottom: size.height * _collapsedFrac + 16,
                child: _recenterButton(),
              ),

            // Draggable bottom sheet (collapsed = essentials, expanded = detail).
            DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: _collapsedFrac,
              minChildSize: 0.16,
              maxChildSize: 0.9,
              snap: true,
              // Min (0.16) and max (0.9) are implicit snap points; only the
              // interior "collapsed" rest position needs listing here.
              snapSizes: const [_collapsedFrac],
              builder: (ctx, scrollCtrl) =>
                  _bottomSheet(trip, step, scrollCtrl),
            ),
          ],
        );
      }),
    );
  }

  Widget _desktopNavigationFallback(AssignedTrip trip) {
    return Container(
      color: AppPalette.bg,
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 104, AppSpacing.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.map_outlined, color: AppPalette.primary, size: 48),
          AppSpacing.vGapMd,
          Text('Map preview unavailable on macOS', style: AppText.h2),
          AppSpacing.vGapSm,
          Text(
            'Run on iPhone, Android, or web to use live Google Maps navigation.',
            style: AppText.body.on(AppPalette.textGrey),
          ),
          AppSpacing.vGapLg,
          _desktopRouteItem('Pickup', trip.pickupLocation, AppPalette.green),
          AppSpacing.vGapMd,
          _desktopRouteItem(
            'Delivery Destination',
            trip.deliveryLocation,
            AppPalette.danger,
          ),
        ],
      ),
    );
  }

  Widget _desktopRouteItem(String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(top: 5),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        AppSpacing.hGapSm,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppText.caption.on(AppPalette.textGrey)),
              Text(
                value.isNotEmpty ? value : 'Not available',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppText.label.weight(FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── top live dashboard ──────────────────────────────────────────────────────
  Widget _topDashboard(TripStep step) {
    final color = _stepColor(step);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Row(
        children: [
          _circleBtn(Iconsax.arrow_left_2, () => Get.back()),
          AppSpacing.hGapMd,
          Expanded(
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppPalette.card,
                borderRadius: AppRadius.rPill,
                boxShadow: _softShadow,
              ),
              child: Row(
                children: [
                  // Pulsing status dot.
                  _PulseDot(color: _nearDestination ? AppPalette.amber : color),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      _nearDestination ? 'Arriving now' : _stepLabel(step),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.label
                          .on(_nearDestination ? AppPalette.amber : color)
                          .weight(FontWeight.w700),
                    ),
                  ),
                  if (_speedKmh > 2) ...[
                    _statusGlyph(Iconsax.speedometer, AppPalette.blue),
                    const SizedBox(width: 3),
                    Text(
                      _speedKmh.toStringAsFixed(0),
                      style: AppText.micro
                          .on(AppPalette.blue)
                          .weight(FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // GPS + internet health.
                  _statusGlyph(
                    _gpsEnabled ? Iconsax.gps : Iconsax.location_slash,
                    _gpsEnabled ? AppPalette.green : AppPalette.danger,
                  ),
                  const SizedBox(width: 6),
                  _statusGlyph(
                    _online ? Iconsax.wifi : Iconsax.wifi_square,
                    _online ? AppPalette.green : AppPalette.danger,
                  ),
                ],
              ),
            ),
          ),
          AppSpacing.hGapMd,
          _circleBtn(
            Iconsax.refresh,
            () => _navController.startTrackingForTrip(widget.tripId),
          ),
        ],
      ),
    );
  }

  Widget _statusGlyph(IconData icon, Color color) =>
      Icon(icon, size: 15, color: color);

  Widget _recenterButton() {
    return Material(
      color: AppPalette.card,
      borderRadius: AppRadius.rPill,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      child: InkWell(
        onTap: _recenter,
        borderRadius: AppRadius.rPill,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Iconsax.gps, size: 17, color: AppPalette.primary),
              const SizedBox(width: 7),
              Text(
                'Re-center',
                style: AppText.label
                    .on(AppPalette.primary)
                    .weight(FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color: AppPalette.card,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Icon(icon, color: AppPalette.textDark, size: 21),
        ),
      ),
    );
  }

  // ── bottom action sheet ─────────────────────────────────────────────────────
  Widget _bottomSheet(
    AssignedTrip trip,
    TripStep step,
    ScrollController scrollCtrl,
  ) {
    final showProgress =
        step != TripStep.confirmOtp &&
        step != TripStep.readyToStart &&
        step != TripStep.completed;

    return Container(
      decoration: BoxDecoration(
        color: AppPalette.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 22,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ListView(
        controller: scrollCtrl,
        padding: EdgeInsets.zero,
        children: [
          // Drag handle.
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppPalette.border,
                borderRadius: AppRadius.rPill,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Collapsed essentials: headline + live metrics + CTA ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_stepHeadline(step), style: AppText.h2),
                          if (!kIsWeb &&
                              defaultTargetPlatform == TargetPlatform.iOS &&
                              (step == TripStep.navigatingToPickup ||
                                  step == TripStep.atPickup ||
                                  step == TripStep.inTransit))
                            Text(
                              'Location updates while Wheelboard is open',
                              style: AppText.caption,
                            ),
                          if (trip.vehicleNumber.isNotEmpty)
                            Text(
                              '${trip.vehicleNumber}${trip.vehicleModel.isNotEmpty ? " • ${trip.vehicleModel}" : ""}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.caption
                                  .on(AppPalette.primary)
                                  .weight(FontWeight.w600),
                            ),
                        ],
                      ),
                    ),
                    _statusPill(step),
                  ],
                ),
                AppSpacing.vGapMd,

                // Live metrics row — ETA / Distance / Progress.
                Row(
                  children: [
                    Expanded(
                      child: Obx(
                        () => _metricTile(
                          'ETA',
                          _navController.eta.value,
                          Iconsax.timer_1,
                          AppPalette.blue,
                        ),
                      ),
                    ),
                    AppSpacing.hGapSm,
                    Expanded(
                      child: Obx(
                        () => _metricTile(
                          'Distance',
                          _navController.distanceRemaining.value,
                          Iconsax.routing,
                          AppPalette.primary,
                        ),
                      ),
                    ),
                    AppSpacing.hGapSm,
                    Expanded(
                      child: Obx(
                        () => _metricTile(
                          'Progress',
                          '${(_navController.progress.value * 100).toStringAsFixed(0)}%',
                          Iconsax.chart_2,
                          AppPalette.green,
                        ),
                      ),
                    ),
                  ],
                ),

                if (showProgress) ...[
                  AppSpacing.vGapMd,
                  Obx(
                    () => ClipRRect(
                      borderRadius: AppRadius.rPill,
                      child: LinearProgressIndicator(
                        value: _navController.progress.value,
                        backgroundColor: AppPalette.border,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _stepColor(_navController.currentStep.value),
                        ),
                        minHeight: 7,
                      ),
                    ),
                  ),
                ],
                AppSpacing.vGapLg,

                // Primary per-step action.
                _stepActions(trip, step),

                // ── Expanded detail ──
                AppSpacing.vGapLg,
                const Divider(height: 1, color: AppPalette.border),
                AppSpacing.vGapLg,

                Text('TRIP ROUTE', style: AppText.micro.size(10)),
                AppSpacing.vGapSm,
                _routeItem(
                  'Pickup Location',
                  trip.pickupLocation,
                  AppPalette.green,
                  isStart: true,
                ),
                AppSpacing.vGapMd,
                _routeItem(
                  'Delivery Destination',
                  trip.deliveryLocation,
                  AppPalette.danger,
                  isStart: false,
                ),
                AppSpacing.vGapLg,

                // Company + contact.
                _contactCard(trip),

                if (trip.specialInstructions.isNotEmpty) ...[
                  AppSpacing.vGapLg,
                  Text('INSTRUCTIONS', style: AppText.micro.size(10)),
                  AppSpacing.vGapSm,
                  AppBanner(
                    text: trip.specialInstructions,
                    icon: Iconsax.info_circle,
                    color: AppPalette.amber,
                    background: AppPalette.amberBg,
                    borderColor: const Color(0x33F59E0B),
                  ),
                ],

                // Trip metadata.
                AppSpacing.vGapLg,
                Text('TRIP DETAILS', style: AppText.micro.size(10)),
                AppSpacing.vGapSm,
                _metaGrid(trip),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(TripStep step) {
    final color = _stepColor(step);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.rPill,
      ),
      child: Text(
        _stepLabel(step),
        style: AppText.caption.on(color).weight(FontWeight.w700),
      ),
    );
  }

  Widget _metricTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: AppPalette.bg,
        borderRadius: AppRadius.rLg,
        border: Border.all(color: AppPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              Text(label, style: AppText.micro.size(9)),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.subtitle.on(AppPalette.textDark).size(14),
          ),
        ],
      ),
    );
  }

  Widget _contactCard(AssignedTrip trip) {
    final phone = trip.companyMobileNo ?? trip.driverContact;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppPalette.bg,
        borderRadius: AppRadius.rLg,
        border: Border.all(color: AppPalette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppPalette.primaryLight,
              borderRadius: AppRadius.rMd,
            ),
            child: const Icon(
              Iconsax.building_4,
              color: AppPalette.primary,
              size: 20,
            ),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.companyName ?? 'Transport Co.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.subtitle,
                ),
                if (phone.isNotEmpty) Text(phone, style: AppText.caption),
              ],
            ),
          ),
          if (phone.isNotEmpty)
            Material(
              color: AppPalette.green,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => CallUtils.makeCall(phone),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Iconsax.call, color: Colors.white, size: 18),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _metaGrid(AssignedTrip trip) {
    final items = <List<dynamic>>[
      [
        Iconsax.box,
        'Trip ID',
        trip.tripCode.isNotEmpty ? trip.tripCode : trip.tripId,
      ],
      [
        Iconsax.truck,
        'Vehicle',
        trip.vehicleNumber.isNotEmpty ? trip.vehicleNumber : '—',
      ],
      [Iconsax.calendar, 'Pickup', _fmtDate(trip.pickupDate, trip.pickupTime)],
      [Iconsax.money, 'Pay', trip.payRange.isNotEmpty ? trip.payRange : '—'],
    ];
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: items.map((it) {
        return SizedBox(
          width: (MediaQuery.of(context).size.width - 40 - AppSpacing.sm) / 2,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppPalette.bg,
              borderRadius: AppRadius.rLg,
              border: Border.all(color: AppPalette.border),
            ),
            child: Row(
              children: [
                Icon(it[0] as IconData, size: 16, color: AppPalette.textGrey),
                AppSpacing.hGapSm,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(it[1] as String, style: AppText.micro.size(9)),
                      Text(
                        it[2] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.label.on(AppPalette.textDark),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _fmtDate(DateTime d, String time) {
    final ds =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    return time.isNotEmpty ? '$ds • $time' : ds;
  }

  // ── step action bar (UNCHANGED behaviour) ───────────────────────────────────
  Widget _stepActions(AssignedTrip trip, TripStep step) {
    switch (step) {
      case TripStep.confirmOtp:
        return _primaryButton(
          icon: Iconsax.tick_circle,
          label: 'Confirm Trip with OTP',
          color: AppPalette.amber,
          onTap: () => _onConfirmLr(trip),
        );

      case TripStep.readyToStart:
        return _primaryButton(
          icon: Iconsax.play_circle,
          label: 'Start Trip',
          color: AppPalette.green,
          onTap: () => _showStartTripModal(trip),
        );

      case TripStep.navigatingToPickup:
        return Row(
          children: [
            Expanded(
              flex: 2,
              child: _outlineButton(
                icon: Iconsax.routing_2,
                label: 'Navigate',
                onTap: () => _openExternalNavigation(trip),
              ),
            ),
            AppSpacing.hGapMd,
            Expanded(
              flex: 3,
              child: _primaryButton(
                icon: Iconsax.location,
                label: 'Arrived at Pickup',
                color: AppPalette.purple,
                onTap: () => _navController.arriveAtPickup(trip.tripId),
              ),
            ),
          ],
        );

      case TripStep.atPickup:
        return Row(
          children: [
            Expanded(
              flex: 2,
              child: _outlineButton(
                icon: Iconsax.routing_2,
                label: 'Navigate',
                onTap: () => _openExternalNavigation(trip),
              ),
            ),
            AppSpacing.hGapMd,
            Expanded(
              flex: 3,
              child: _primaryButton(
                icon: Iconsax.truck,
                label: 'Start Trip',
                color: AppPalette.green,
                onTap: () => _showStartTripModal(trip),
              ),
            ),
          ],
        );

      case TripStep.inTransit:
        return Row(
          children: [
            Expanded(
              flex: 2,
              child: _outlineButton(
                icon: Iconsax.routing_2,
                label: 'Navigate',
                onTap: () => _openExternalNavigation(trip),
              ),
            ),
            AppSpacing.hGapMd,
            Expanded(
              flex: 3,
              child: Obx(
                () => AppPrimaryButton(
                  label: 'Arrived at Drop-off',
                  icon: Iconsax.flag,
                  loading: _navController.isLoading.value,
                  onPressed: () => _showArrivalConfirmDialog(trip),
                ),
              ),
            ),
          ],
        );

      case TripStep.atDestination:
      case TripStep.podUpload:
        return _primaryButton(
          icon: Iconsax.document_upload,
          label: 'Upload Proof of Delivery',
          color: AppPalette.purple,
          onTap: () =>
              Get.to(
                () => PodCollectionScreen(tripId: trip.tripId),
                transition: Transition.rightToLeft,
              )?.then((_) {
                // Refresh status after returning from POD screen
                final step2 = _navController.currentStep.value;
                if (step2 == TripStep.completed) {
                  _goToCompletedScreen(trip);
                }
              }),
        );

      case TripStep.completed:
        return _primaryButton(
          icon: Iconsax.tick_circle,
          label: 'View Trip Summary',
          color: AppPalette.green,
          onTap: () => _goToCompletedScreen(trip),
        );
    }
  }

  void _goToCompletedScreen(AssignedTrip trip) {
    Get.off(
      () => TripCompletedScreen(tripId: trip.tripId),
      transition: Transition.rightToLeft,
    );
  }

  // ── LR confirmation (web parity) ─────────────────────────────────────────────
  /// Confirms the Lorry Receipt the same way the web does: a simple modal that
  /// takes the 6-digit OTP the company already sent to the driver's
  /// notifications and posts it to `/trips/:id/confirm-otp`. There is no
  /// "send OTP" / "simple confirmation" / "reject LR" flow — that older, broken
  /// path (which surfaced an "Internal server error") has been removed.
  void _onConfirmLr(AssignedTrip trip) {
    _lrOtpController.clear();
    _navController.lrOtpError.value = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _OtpSheet(
          title: 'Confirm Trip',
          subtitle:
              'Enter the 6-digit OTP from your notification to confirm the Lorry Receipt.',
          controller: _lrOtpController,
          isLoading: _navController.isConfirmingLr,
          error: _navController.lrOtpError,
          onConfirm: () async {
            final nav = Navigator.of(ctx);
            final ok = await _navController.confirmLrWithOtp(
              trip.tripId,
              _lrOtpController.text.trim(),
            );
            if (ok) {
              nav.pop();
              // Resync so the card/step reflect the new `scheduled` status.
              await Get.find<AssignedTripController>().fetchAssignedTrips();
            }
          },
          onCancel: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  void _showStartTripModal(AssignedTrip trip) {
    _startOtpController.clear();
    _navController.startTripOtpError.value = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _OtpSheet(
          title: 'Start Trip',
          subtitle: 'Enter the 6-digit OTP to confirm trip start.',
          controller: _startOtpController,
          isLoading: _navController.isStartingTrip,
          error: _navController.startTripOtpError,
          onConfirm: () async {
            final nav = Navigator.of(ctx);
            final pos = _navController.currentPosition.value;
            final ok = await _navController.startTrip(
              trip.tripId,
              _startOtpController.text.trim(),
              lat: pos?.latitude,
              lng: pos?.longitude,
            );
            if (ok) nav.pop();
          },
          onCancel: () => Navigator.of(ctx).pop(),
          // Allow skipping OTP — some backend versions don't require it
          extraAction: TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final pos = _navController.currentPosition.value;
              await _navController.startTripDirect(
                trip.tripId,
                lat: pos?.latitude,
                lng: pos?.longitude,
              );
            },
            child: Text('Skip OTP (start without OTP)', style: AppText.caption),
          ),
        ),
      ),
    );
  }

  void _showArrivalConfirmDialog(AssignedTrip trip) {
    _completionReasonController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppPalette.border,
                  borderRadius: AppRadius.rPill,
                ),
              ),
              AppSpacing.vGapXl,
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppPalette.primaryLight,
                  borderRadius: AppRadius.rXl,
                ),
                child: const Icon(
                  Iconsax.location_tick,
                  size: 30,
                  color: AppPalette.primary,
                ),
              ),
              AppSpacing.vGapMd,
              Text('Arrived at Destination?', style: AppText.h2),
              const SizedBox(height: 6),
              Text(
                'Confirm that you have reached the drop-off location and are ready to collect proof of delivery.',
                textAlign: TextAlign.center,
                style: AppText.bodySm,
              ),
              AppSpacing.vGapLg,
              TextField(
                controller: _completionReasonController,
                maxLines: 2,
                style: AppText.bodySm,
                decoration: InputDecoration(
                  hintText:
                      'e.g. Delivered successfully, customer received goods',
                  hintStyle: AppText.caption,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.rLg,
                    borderSide: const BorderSide(color: AppPalette.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadius.rLg,
                    borderSide: const BorderSide(color: AppPalette.primary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              AppSpacing.vGapLg,
              Row(
                children: [
                  Expanded(
                    child: AppSecondaryButton(
                      label: 'Cancel',
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                  AppSpacing.hGapMd,
                  Expanded(
                    flex: 2,
                    child: Obx(
                      () => AppPrimaryButton(
                        label: "Yes, I've Arrived",
                        loading: _navController.isLoading.value,
                        onPressed: () async {
                          final nav = Navigator.of(ctx);
                          final pos = _navController.currentPosition.value;
                          await _navController.arriveAtDestination(
                            trip.tripId,
                            lat: pos?.latitude,
                            lng: pos?.longitude,
                            reason: _completionReasonController.text.trim(),
                          );
                          nav.pop();
                          Get.to(
                            () => PodCollectionScreen(tripId: trip.tripId),
                            transition: Transition.rightToLeft,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  // ── small helpers ─────────────────────────────────────────────────────────
  Widget _primaryButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return AppPrimaryButton(
      label: label,
      icon: icon,
      color: color,
      onPressed: onTap,
    );
  }

  Widget _outlineButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return AppSecondaryButton(
      label: label,
      icon: icon,
      color: AppPalette.textMid,
      onPressed: onTap,
    );
  }

  Widget _routeItem(
    String label,
    String address,
    Color color, {
    required bool isStart,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withValues(alpha: 0.2),
                  width: 4,
                ),
              ),
            ),
            if (isStart)
              Container(width: 2, height: 30, color: AppPalette.border),
          ],
        ),
        AppSpacing.hGapMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppText.micro.size(10)),
              Text(
                address.isEmpty ? 'N/A' : address,
                style: AppText.subtitle.size(13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Driver-optimised map style: clean road focus, no POI clutter.
  static const String _mapStyle = '''[
    {"featureType":"administrative","elementType":"geometry","stylers":[{"visibility":"off"}]},
    {"featureType":"poi","stylers":[{"visibility":"off"}]},
    {"featureType":"road","elementType":"labels.icon","stylers":[{"visibility":"off"}]},
    {"featureType":"transit","stylers":[{"visibility":"off"}]},
    {"featureType":"landscape","elementType":"geometry","stylers":[{"color":"#f5f5f5"}]},
    {"featureType":"water","elementType":"geometry","stylers":[{"color":"#c9e8f7"}]},
    {"featureType":"road.highway","elementType":"geometry.fill","stylers":[{"color":"#ffffff"}]},
    {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#e0e0e0"}]},
    {"featureType":"road.arterial","elementType":"geometry.fill","stylers":[{"color":"#ffffff"}]},
    {"featureType":"road.local","elementType":"geometry.fill","stylers":[{"color":"#fbfbfb"}]},
    {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#555555"}]},
    {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#333333"}]}
  ]''';

  static final _softShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.10),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
  ];
}

// ── pulsing status dot ────────────────────────────────────────────────────────
class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.5 * (1 - _c.value)),
              blurRadius: 2 + 5 * _c.value,
              spreadRadius: 1 + 2 * _c.value,
            ),
          ],
        ),
      ),
    );
  }
}

// ── reusable OTP bottom sheet ───────────────────────────────────────────────
class _OtpSheet extends StatelessWidget {
  final String title;
  final String subtitle;
  final TextEditingController controller;
  final RxBool isLoading;
  final RxnString error;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final Widget? extraAction;

  const _OtpSheet({
    required this.title,
    required this.subtitle,
    required this.controller,
    required this.isLoading,
    required this.error,
    required this.onConfirm,
    required this.onCancel,
    this.extraAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: AppPalette.border,
              borderRadius: AppRadius.rPill,
            ),
          ),
          AppSpacing.vGapXl,
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppPalette.primaryLight,
              borderRadius: AppRadius.rXl,
            ),
            child: const Icon(
              Iconsax.lock_1,
              size: 30,
              color: AppPalette.primary,
            ),
          ),
          AppSpacing.vGapMd,
          Text(title, style: AppText.h2),
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center, style: AppText.bodySm),
          AppSpacing.vGapLg,
          TextField(
            controller: controller,
            maxLength: 6,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: AppText.h1.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 12,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '------',
              hintStyle: AppText.h1.copyWith(
                fontSize: 24,
                color: AppPalette.border,
                letterSpacing: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: AppRadius.rLg,
                borderSide: const BorderSide(color: AppPalette.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.rLg,
                borderSide: const BorderSide(
                  color: AppPalette.primary,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
          Obx(
            () => error.value != null
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      error.value!,
                      style: AppText.caption.on(AppPalette.danger),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          AppSpacing.vGapLg,
          Row(
            children: [
              Expanded(
                child: AppSecondaryButton(
                  label: 'Cancel',
                  color: AppPalette.textMid,
                  onPressed: onCancel,
                ),
              ),
              AppSpacing.hGapMd,
              Expanded(
                flex: 2,
                child: Obx(
                  () => AppPrimaryButton(
                    label: 'Confirm',
                    loading: isLoading.value,
                    onPressed: onConfirm,
                  ),
                ),
              ),
            ],
          ),
          if (extraAction != null) ...[const SizedBox(height: 8), extraAction!],
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
