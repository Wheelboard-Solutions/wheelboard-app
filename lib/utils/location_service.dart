import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../utils/app_logger.dart';

/// Reusable Location Service for getting current location
class LocationService {
  /// Settings for continuous trip tracking streams.
  ///
  /// On iOS this keeps updates flowing while the app is backgrounded or the
  /// phone is locked (requires the `location` UIBackgroundMode in Info.plist)
  /// and shows the blue status-bar indicator so the driver knows tracking is on.
  static LocationSettings trackingSettings({int distanceFilter = 10}) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }
    return LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilter,
    );
  }

  /// Get current location coordinates
  static Future<Position?> getCurrentPosition() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        AppLogger.d('❌ Location services are disabled');
        return null;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          AppLogger.d('❌ Location permissions are denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        AppLogger.d('❌ Location permissions are permanently denied');
        return null;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      AppLogger.d(
        '✅ Current Location: ${position.latitude}, ${position.longitude}',
      );
      return position;
    } catch (e) {
      AppLogger.d('❌ Error getting current location: $e');
      return null;
    }
  }

  /// Get address from coordinates (reverse geocoding)
  static Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;

        // Build address string (skip 'name' as it often contains Plus Code)
        List<String> addressParts = [];

        // Skip 'name' field to avoid Plus Codes like "H85V+6RP"
        // Add street only if it doesn't contain Plus Code pattern
        if (place.street != null && place.street!.isNotEmpty) {
          if (!place.street!.contains('+')) {
            addressParts.add(place.street!);
          }
        }

        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          addressParts.add(place.subLocality!);
        }

        if (place.locality != null && place.locality!.isNotEmpty) {
          addressParts.add(place.locality!);
        }

        if (place.administrativeArea != null &&
            place.administrativeArea!.isNotEmpty) {
          addressParts.add(place.administrativeArea!);
        }

        if (place.postalCode != null && place.postalCode!.isNotEmpty) {
          addressParts.add(place.postalCode!);
        }

        String address = addressParts.join(', ');
        AppLogger.d('✅ Address: $address');
        return address.isNotEmpty ? address : null;
      }

      return null;
    } catch (e) {
      AppLogger.d('❌ Error getting address: $e');
      return null;
    }
  }

  /// Get current location and convert to address (combined method)
  static Future<String?> getCurrentLocationAddress() async {
    Position? position = await getCurrentPosition();
    if (position == null) return null;

    return await getAddressFromCoordinates(
      position.latitude,
      position.longitude,
    );
  }
}
