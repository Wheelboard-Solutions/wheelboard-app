import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wheelboard/controllers/Professional/assigned_trip_controller.dart';
import 'package:wheelboard/screens/Professional/TrackTrip/TrackTripScreen.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_exception.dart';
import 'package:wheelboard/utils/app_logger.dart';
import 'package:wheelboard/widgets/custom_snackbar.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:wheelboard/utils/location_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geocoding/geocoding.dart' as geo;
import '../../utils/constants.dart';
import 'package:dio/dio.dart';

class TrackTripController extends GetxController {
  final isLoading = false.obs;
  AssignedTripController get _assignedTripController {
    if (!Get.isRegistered<AssignedTripController>()) {
      return Get.put(AssignedTripController());
    }
    return Get.find<AssignedTripController>();
  }

  // Tracking Data
  final currentPosition = Rxn<Position>();
  final distanceRemaining = "Calculating...".obs;
  final eta = "Calculating...".obs;
  final progress = 0.0.obs;
  StreamSubscription<Position>? _positionStream;

  @override
  void onClose() {
    stopLocationUpdates();
    super.onClose();
  }

  void startLocationUpdates(String tripId) async {
    debugPrint("📍 [DEBUG] Starting updates for: $tripId");
    AppLogger.d("📍 Starting location updates for Trip: $tripId");
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint("❌ [DEBUG] Location services disabled");
      AppLogger.d("❌ Location services are disabled");
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint("❌ [DEBUG] Permission denied");
        AppLogger.d("❌ Location permissions are denied");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint("❌ [DEBUG] Permission denied forever");
      AppLogger.d("❌ Location permissions are permanently denied");
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      debugPrint(
        "📍 [DEBUG] Initial Position: ${position.latitude}, ${position.longitude}",
      );
      AppLogger.d(
        "📍 Initial Position: ${position.latitude}, ${position.longitude}",
      );
      currentPosition.value = position;
      _updateTripMetrics(tripId, position);
    } catch (e) {
      debugPrint("❌ [DEBUG] Error initial pos: $e");
      AppLogger.d("❌ Error getting initial position: $e");
    }

    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: LocationService.trackingSettings(),
        ).listen((Position position) {
          AppLogger.d(
            "📍 Position Stream Update: ${position.latitude}, ${position.longitude}",
          );
          currentPosition.value = position;
          _updateTripMetrics(tripId, position);
        });
  }

  void stopLocationUpdates() {
    AppLogger.d("🛑 Stopping location updates");
    _positionStream?.cancel();
    _positionStream = null;
  }

  Future<void> _updateTripMetrics(String tripId, Position position) async {
    try {
      final trip = _assignedTripController.assignedTrips.firstWhere(
        (t) => t.tripId == tripId,
      );

      debugPrint(
        "📊 [DEBUG] Trip Info: Lat=${trip.latitude}, Lng=${trip.longitude}, Dist=${trip.distance}",
      );
      AppLogger.d(
        "📊 Trip Found: ${trip.tripId}, Dest: ${trip.latitude}, ${trip.longitude}, Dist: ${trip.distance}",
      );

      double? destLat = trip.latitude;
      double? destLng = trip.longitude;

      if (destLat == null || destLat == 0 || destLng == null || destLng == 0) {
        debugPrint(
          "🔍 [DEBUG] Geocoding fallback for: ${trip.deliveryLocation}",
        );
        AppLogger.d(
          "🔍 Coordinates missing, attempting geocoding for: ${trip.deliveryLocation}",
        );
        try {
          List<geo.Location> locations = await geo.locationFromAddress(
            trip.deliveryLocation,
          );
          if (locations.isNotEmpty) {
            destLat = locations.first.latitude;
            destLng = locations.first.longitude;
            debugPrint("✅ [DEBUG] Geocoding Success: $destLat, $destLng");
            AppLogger.d("✅ Geocoding Success: $destLat, $destLng");
          }
        } catch (e) {
          debugPrint("❌ [DEBUG] Geocoding Error: $e");
          AppLogger.d("❌ Geocoding Failed for '${trip.deliveryLocation}': $e");
        }
      }

      if (destLat != null && destLat != 0 && destLng != null && destLng != 0) {
        debugPrint("🌐 [DEBUG] Calling Distance Matrix API...");
        _fetchGoogleMetrics(
          position.latitude,
          position.longitude,
          destLat,
          destLng,
          trip.distance,
        );
      } else {
        debugPrint("⚠️ [DEBUG] No coordinates for destination!");
        AppLogger.d("⚠️ Trip destination coordinates could not be determined!");
      }
    } catch (e) {
      AppLogger.d("❌ Error finding trip in controller: $e");
    }
  }

  Future<void> _fetchGoogleMetrics(
    double lat,
    double lng,
    double destLat,
    double destLng,
    String? baseDistance,
  ) async {
    try {
      final url =
          "https://maps.googleapis.com/maps/api/distancematrix/json?origins=$lat,$lng&destinations=$destLat,$destLng&key=${MapsConstants.googleMapsApiKey}";

      debugPrint("🌐 [DEBUG] API Call: $url");
      AppLogger.d("🌐 Calling Google Distance Matrix API...");
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint("✅ [DEBUG] API Body: ${response.body}");
        AppLogger.d("✅ Google API Response: ${response.body}");

        if (data['status'] == 'OK') {
          final element = data['rows'][0]['elements'][0];
          debugPrint("✅ [DEBUG] Element Status: ${element['status']}");
          if (element['status'] == 'OK') {
            distanceRemaining.value = element['distance']['text'];
            eta.value = element['duration']['text'];

            debugPrint(
              "🎯 [DEBUG] Result: ${distanceRemaining.value}, ${eta.value}",
            );
            AppLogger.d(
              "🎯 Metrics Updated: Dist=${distanceRemaining.value}, ETA=${eta.value}",
            );

            // Calculate Progress
            double currentDistMeters = element['distance']['value'].toDouble();
            double totalDistMeters = 0;

            if (baseDistance != null && baseDistance.isNotEmpty) {
              try {
                String distStr = baseDistance.replaceAll(
                  RegExp(r'[^0-9.]'),
                  '',
                );
                totalDistMeters = double.parse(distStr) * 1000;
              } catch (_) {}
            }

            // Fallback: If we don't have total distance, use a sensible default or dynamic estimation
            if (totalDistMeters <= 0) {
              totalDistMeters =
                  currentDistMeters +
                  5000; // Assume we have 5km more if unknown
            }

            double rawProgress = 1.0 - (currentDistMeters / totalDistMeters);
            progress.value = rawProgress.clamp(0.0, 1.0);
            AppLogger.d(
              "📈 Trip Progress: ${progress.value} (Current: $currentDistMeters, Total: $totalDistMeters)",
            );
          } else {
            AppLogger.d("⚠️ Element status not OK: ${element['status']}");
          }
        } else {
          AppLogger.d("⚠️ API status not OK: ${data['status']}");
          if (data['error_message'] != null) {
            AppLogger.d("❌ Error Message: ${data['error_message']}");
          }
        }
      } else {
        AppLogger.d("❌ API HTTP Error: ${response.statusCode}");
      }
    } catch (e) {
      AppLogger.d("❌ Exception in _fetchGoogleMetrics: $e");
    }
  }

  Future<void> startTrip(String tripId) async {
    AppLogger.d("🚀 Starting trip with ID: $tripId");
    isLoading.value = true;
    try {
      await ApiClient.instance.post(
        ApiEndpoints.trips.start(tripId),
      );

      // Update local status
      final index = _assignedTripController.assignedTrips.indexWhere(
        (t) => t.tripId == tripId,
      );
      if (index != -1) {
        final trip = _assignedTripController.assignedTrips[index];
        _assignedTripController.assignedTrips[index] = trip.copyWith(
          tripStatus: 'In Progress',
        );
      }
      SnackBarHelper.success("Trip started successfully");
      // Navigate to TrackTripScreen after starting
      Get.off(() => TrackTripScreen(tripId: tripId));
    } on DioException catch (e) {
      final msg = e.error is ApiException ? (e.error as ApiException).message : 'Failed to start trip';
      SnackBarHelper.error(msg);
    } catch (e) {
      SnackBarHelper.error("An error occurred: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> endTrip(String tripId) async {
    AppLogger.d("🏁 Ending trip with ID: $tripId");
    isLoading.value = true;
    try {
      await ApiClient.instance.post(
        ApiEndpoints.trips.arrive(tripId),
      );

      // Update local status
      final index = _assignedTripController.assignedTrips.indexWhere(
        (t) => t.tripId == tripId,
      );
      if (index != -1) {
        final trip = _assignedTripController.assignedTrips[index];
        _assignedTripController.assignedTrips[index] = trip.copyWith(
          tripStatus: 'Completed',
        );
      }
      // Force refresh all trips to reflect changes in UI
      await _assignedTripController.fetchAssignedTrips();
      _showCompletionDialog();
    } on DioException catch (e) {
      final msg = e.error is ApiException ? (e.error as ApiException).message : 'Failed to end trip';
      SnackBarHelper.error(msg);
    } catch (e) {
      SnackBarHelper.error("An error occurred: $e");
    } finally {
      isLoading.value = false;
    }
  }

  void _showCompletionDialog() {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Close Button
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => Get.back(),
                  child: const Icon(
                    Icons.close,
                    size: 20,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Celebration Icon
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF8C00), Color(0xFFFFC000)],
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const Text('🎉', style: TextStyle(fontSize: 48)),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'Congratulations!',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Trip Successfully Completed!',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF27AE60),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                'Great job completing the trip successfully!\nKeep driving to earn more rewards.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF8E8E8E),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Get.back();
                    Get.back();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF27AE60),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Back to Home',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }
}
