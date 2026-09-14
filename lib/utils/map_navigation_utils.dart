import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_logger.dart';

class MapNavigationUtils {
  const MapNavigationUtils._();

  static Future<bool> openDirections({
    LatLng? origin,
    required LatLng destination,
    String? destinationLabel,
  }) async {
    final encodedLabel = Uri.encodeComponent(
      destinationLabel?.trim().isNotEmpty == true
          ? destinationLabel!.trim()
          : '${destination.latitude},${destination.longitude}',
    );
    final destinationParam = '${destination.latitude},${destination.longitude}';
    final originParam = origin == null
        ? null
        : '${origin.latitude},${origin.longitude}';

    final candidates = <Uri>[];

    if (!kIsWeb && Platform.isIOS) {
      candidates.add(
        Uri.parse(
          'http://maps.apple.com/?daddr=$destinationParam&dirflg=d'
          '${originParam != null ? '&saddr=$originParam' : ''}',
        ),
      );
      candidates.add(
        Uri.parse(
          'comgooglemaps://?daddr=$destinationParam&directionsmode=driving'
          '${originParam != null ? '&saddr=$originParam' : ''}',
        ),
      );
    } else if (!kIsWeb && Platform.isAndroid) {
      candidates.add(Uri.parse('google.navigation:q=$destinationParam&mode=d'));
      candidates.add(Uri.parse('geo:0,0?q=$destinationParam($encodedLabel)'));
    }

    candidates.add(
      Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=$destinationParam'
        '${originParam != null ? '&origin=$originParam' : ''}'
        '&travelmode=driving',
      ),
    );

    return _launchFirst(candidates, destinationParam);
  }

  /// Directions to a place identified only by its address.
  ///
  /// For destinations Wheelboard holds as text rather than a pin — a service
  /// booking records its location as an address string and the booking record
  /// has no coordinate columns, so this is the only way to route to one.
  /// Prefer [openDirections] whenever coordinates exist: an address is resolved
  /// by the maps app and can land on the wrong side of a large site.
  ///
  /// Returns false when the address is blank or no maps app could open it, so
  /// the caller can tell the user rather than appearing to do nothing.
  static Future<bool> openDirectionsToAddress({
    required String address,
    LatLng? origin,
  }) async {
    final destination = address.trim();
    if (destination.isEmpty) {
      AppLogger.w('Navigation requested with no destination address');
      return false;
    }

    final encoded = Uri.encodeComponent(destination);
    final originParam = origin == null
        ? null
        : '${origin.latitude},${origin.longitude}';

    final candidates = <Uri>[];

    // Same platform preference order as the coordinate path: the native app
    // first, then the browser.
    if (!kIsWeb && Platform.isIOS) {
      candidates.add(
        Uri.parse(
          'http://maps.apple.com/?daddr=$encoded&dirflg=d'
          '${originParam != null ? '&saddr=$originParam' : ''}',
        ),
      );
      candidates.add(
        Uri.parse(
          'comgooglemaps://?daddr=$encoded&directionsmode=driving'
          '${originParam != null ? '&saddr=$originParam' : ''}',
        ),
      );
    } else if (!kIsWeb && Platform.isAndroid) {
      candidates.add(Uri.parse('google.navigation:q=$encoded&mode=d'));
      candidates.add(Uri.parse('geo:0,0?q=$encoded'));
    }

    candidates.add(
      Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=$encoded'
        '${originParam != null ? '&origin=$originParam' : ''}'
        '&travelmode=driving',
      ),
    );

    return _launchFirst(candidates, destination);
  }

  /// Try each candidate in order; the first the device can open wins.
  static Future<bool> _launchFirst(List<Uri> candidates, String label) async {
    for (final uri in candidates) {
      try {
        if (await canLaunchUrl(uri)) {
          return launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        AppLogger.w('Map launch failed for $uri: $e');
      }
    }

    AppLogger.e('No maps application could open destination $label');
    return false;
  }
}
