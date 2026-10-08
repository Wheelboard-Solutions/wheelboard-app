import 'dart:async';

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wheelboard/models/assigned_trip_model.dart';
import 'package:wheelboard/core/network/api_client.dart';
import 'package:wheelboard/core/network/api_endpoints.dart';
import 'package:wheelboard/core/network/api_exception.dart';
import 'package:wheelboard/core/auth/auth_service.dart';
import 'package:wheelboard/utils/location_service.dart';
import 'package:wheelboard/utils/trip_status.dart';
import '../../utils/app_logger.dart';

class AssignedTripController extends GetxController {
  final AuthService _authService = Get.find<AuthService>();

  var assignedTrips = <AssignedTrip>[].obs;
  var isLoading = true.obs;

  /// Whether the last fetch failed (drives the retry/error state in the UI).
  final hasError = false.obs;
  final errorMessage = ''.obs;

  /// Local UI filter for the My Trips list, mirroring the web filter tabs:
  /// 'All' | 'Assigned' | 'In-Process' | 'Completed'.
  final selectedFilter = 'All'.obs;

  // ── derived classification (single source of truth via TripStatusMapper) ──
  TripBucket bucketOf(AssignedTrip t) => TripStatusMapper.bucketOf(t.tripStatus);

  bool isAssignedTrip(AssignedTrip t) =>
      TripStatusMapper.isAssigned(t.tripStatus, t.driverId);

  /// Driver earnings for a trip — mirrors the web card exactly
  /// (`financial.driverEarnings || price`). `amountToDriver` is now populated
  /// from `financial.driverEarnings` in [AssignedTrip.fromJson]; the remaining
  /// fields stay as defensive fallbacks for older payload shapes.
  double earningsOf(AssignedTrip t) {
    if ((t.amountToDriver ?? 0) > 0) return t.amountToDriver!; // financial.driverEarnings
    if ((t.price ?? 0) > 0) return t.price!; // backend price (web fallback)
    if ((t.bidAmount ?? 0) > 0) return t.bidAmount!;
    if ((t.totalTripCost ?? 0) > 0) return t.totalTripCost!;
    return _parseAmount(t.payRange) ?? 0;
  }

  double? _parseAmount(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final match = RegExp(r'[\d.]+').firstMatch(raw.replaceAll(',', ''));
    return match == null ? null : double.tryParse(match.group(0)!);
  }

  // ── authoritative stats from `/trips/professional/stats` ──────────────────
  // The web reads its dashboard numbers from this endpoint (the single source
  // of truth) and only falls back to trip-derived values when the API returns
  // nothing. We mirror that exactly so the app shows IDENTICAL figures to the
  // web for the same account, instead of recomputing earnings from local trip
  // fields (which diverged).
  final _apiCompleted = RxnInt();
  final _apiActive = RxnInt();
  final _apiAssigned = RxnInt();
  final _apiTotalEarnings = RxnDouble();
  final _apiEstimatedEarnings = RxnDouble();
  final _apiRating = RxnDouble();

  // ── stats (prefer API value, fall back to web `deriveStatsFromTrips`) ──────
  int get completedCount => _apiCompleted.value ?? _derivedCompletedCount;
  int get _derivedCompletedCount =>
      assignedTrips.where((t) => bucketOf(t) == TripBucket.completed).length;

  int get inProcessCount => _apiActive.value ?? _derivedInProcessCount;
  int get _derivedInProcessCount =>
      assignedTrips.where((t) => bucketOf(t) == TripBucket.inProcess).length;

  int get assignedCount => _apiAssigned.value ?? _derivedAssignedCount;
  int get _derivedAssignedCount => assignedTrips
      .where((t) => isAssignedTrip(t) && bucketOf(t) == TripBucket.upcoming)
      .length;

  int get upcomingCount =>
      assignedTrips.where((t) => bucketOf(t) == TripBucket.upcoming).length;

  int get activeAndAssignedCount => inProcessCount + assignedCount;

  double get totalEarnings => _apiTotalEarnings.value ?? _derivedTotalEarnings;
  double get _derivedTotalEarnings => assignedTrips
      .where((t) => bucketOf(t) == TripBucket.completed)
      .fold(0.0, (sum, t) => sum + earningsOf(t));

  double get estimatedEarnings =>
      _apiEstimatedEarnings.value ?? _derivedEstimatedEarnings;
  double get _derivedEstimatedEarnings => assignedTrips.where((t) {
        final b = bucketOf(t);
        return b == TripBucket.upcoming || b == TripBucket.inProcess;
      }).fold(0.0, (sum, t) => sum + earningsOf(t));

  /// Rating from the stats endpoint; null until the driver has been rated.
  double? get rating => _apiRating.value;

  /// Trips visible for the active filter (mirror web `filteredTrips`).
  List<AssignedTrip> get visibleTrips {
    bool matches(AssignedTrip t) {
      final b = bucketOf(t);
      final isAssigned = isAssignedTrip(t) && b == TripBucket.upcoming;
      final isInProcess = b == TripBucket.inProcess;
      final isCompleted = b == TripBucket.completed;
      switch (selectedFilter.value) {
        case 'Assigned':
          return isAssigned;
        case 'In-Process':
          return isInProcess;
        case 'Completed':
          return isCompleted;
        case 'All':
        default:
          return isAssigned || isInProcess || isCompleted;
      }
    }

    return assignedTrips.where(matches).toList();
  }

  @override
  void onInit() {
    super.onInit();
    fetchAssignedTrips();
  }

  Future<void> fetchAssignedTrips() async {
    try {
      isLoading(true);
      hasError(false);
      errorMessage('');
      final userId = _authService.currentUserId;

      // If userId is empty the token may not be loaded yet — still attempt
      // the API call because the Bearer token is injected by the interceptor.
      // An empty userId only means the reactive state isn't populated yet.
      if (userId.isEmpty) {
        AppLogger.d('⚠️ userId empty — attempting fetch anyway via token');
      }

      AppLogger.d("🚗 Fetching assigned trips (userId=$userId)");

      // Use dynamic to handle both array and object response shapes
      final raw = await ApiClient.instance.get<dynamic>(
        ApiEndpoints.trips.list,
      );

      AppLogger.d("🚗 Raw response type: ${raw.runtimeType}");

      List<dynamic> tripData = [];
      if (raw is List) {
        tripData = raw;
      } else if (raw is Map<String, dynamic>) {
        tripData = (raw['trips'] ?? raw['data'] ?? raw['result'] ?? []) as List<dynamic>;
      }

      AppLogger.d("🚗 Parsed ${tripData.length} trips");

      if (tripData.isEmpty) {
        AppLogger.d('ℹ️ No assigned trips found for this user');
        assignedTrips.value = [];
      } else {
        final List<AssignedTrip> trips = tripData
            .whereType<Map<String, dynamic>>()
            .map((data) => AssignedTrip.fromJson(data))
            .toList();

        // Calculate distance from current location
        Position? currentPos = await LocationService.getCurrentPosition();
        if (currentPos != null) {
          AppLogger.d(
            "📍 My Current Position: ${currentPos.latitude}, ${currentPos.longitude}",
          );
          for (var trip in trips) {
            if (trip.latitude != null && trip.longitude != null) {
              double distanceInMeters = Geolocator.distanceBetween(
                currentPos.latitude,
                currentPos.longitude,
                trip.latitude!,
                trip.longitude!,
              );
              trip.calculatedDistance = distanceInMeters / 1000; // km

              // Estimate ETA (average speed 40km/h)
              double hours = trip.calculatedDistance! / 40;
              int minutes = (hours * 60).round();
              if (minutes < 60) {
                trip.estimatedEta = "$minutes mins";
              } else {
                int h = minutes ~/ 60;
                int m = minutes % 60;
                trip.estimatedEta = "${h}h ${m}m";
              }
            }
          }
        }

        // Sort trips by distance (nearest first)
        trips.sort((a, b) {
          if (a.calculatedDistance == null && b.calculatedDistance == null) {
            return 0;
          }
          if (a.calculatedDistance == null) return 1;
          if (b.calculatedDistance == null) return -1;
          return a.calculatedDistance!.compareTo(b.calculatedDistance!);
        });

        assignedTrips.value = trips;
        AppLogger.d(
          "✅ Fetched and sorted ${assignedTrips.length} assigned trips",
        );
      }

      // Refresh the authoritative dashboard stats alongside the list (web
      // parity: `useTrips` runs `fetchTrips` + `fetchStats` together). Fire and
      // forget — a stats failure must never break the trip list.
      unawaited(fetchProfessionalStats());
    } on DioException catch (e) {
      final apiError = e.error;
      final msg = apiError is ApiException ? apiError.message : 'Failed to load assigned trips';
      AppLogger.d('❌ Error fetching assigned trips: $msg');
      assignedTrips.value = [];
      hasError(true);
      errorMessage(msg);
    } catch (e) {
      AppLogger.d('❌ Error fetching assigned trips: $e');
      assignedTrips.value = [];
      hasError(true);
      errorMessage('Something went wrong while loading your trips.');
    } finally {
      isLoading(false);
    }
  }

  /// Fetch the professional dashboard stats from the SAME endpoint the web uses
  /// (`GET /trips/professional/stats`). The backend wraps the payload as
  /// `{ message, data: {...} }`; we unwrap it (web reads `response.data.data`).
  /// These authoritative values feed the stats header so the app matches the
  /// web exactly for the same account.
  Future<void> fetchProfessionalStats() async {
    try {
      final raw = await ApiClient.instance.get<Map<String, dynamic>>(
        ApiEndpoints.trips.professionalStats,
      );
      final data = (raw['data'] is Map<String, dynamic>)
          ? raw['data'] as Map<String, dynamic>
          : raw;

      int? readInt(List<String> keys) {
        for (final k in keys) {
          final v = data[k];
          if (v is num) return v.toInt();
          final p = int.tryParse(v?.toString() ?? '');
          if (p != null) return p;
        }
        return null;
      }

      double? readDouble(List<String> keys) {
        for (final k in keys) {
          final v = data[k];
          if (v is num) return v.toDouble();
          final p = double.tryParse(v?.toString().replaceAll(',', '') ?? '');
          if (p != null) return p;
        }
        return null;
      }

      _apiCompleted.value = readInt(['completed', 'completedTrips']);
      _apiActive.value = readInt(['inProgress', 'activeTrips', 'active']);
      _apiAssigned.value = readInt(['assigned', 'assignedTrips']);
      _apiTotalEarnings.value = readDouble(['earnings', 'totalEarnings']);
      _apiEstimatedEarnings.value =
          readDouble(['estimatedEarnings', 'pendingAmount']);
      _apiRating.value = readDouble(['rating']);

      AppLogger.d(
          '✅ Professional stats: ₹${_apiTotalEarnings.value}, '
          '${_apiCompleted.value} completed, ${_apiActive.value} active');
    } catch (e) {
      // Non-fatal: the stats header falls back to trip-derived values.
      AppLogger.d('⚠️ professional stats fetch failed (using derived): $e');
    }
  }

  /// Remove a trip from the local cache immediately — used when a trip turns out
  /// to be gone server-side (e.g. the company deleted it and a per-trip call
  /// returned 404). Keeps the Professional list synchronized so a deleted trip
  /// never lingers as a stale, un-openable card.
  void removeTripLocally(String tripId) {
    final before = assignedTrips.length;
    assignedTrips.removeWhere((t) => t.tripId == tripId);
    if (assignedTrips.length != before) {
      assignedTrips.refresh();
      AppLogger.d('🗑️ Removed stale trip $tripId from local cache');
    }
  }
}
