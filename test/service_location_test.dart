import 'package:flutter_test/flutter_test.dart';
import 'package:wheelboard/models/service_model.dart';
import 'package:wheelboard/utils/manual_coordinates.dart';

/// Service location — the two halves of the same rule.
///
/// A Service Provider types coordinates when they create a listing, and a
/// Transport user must see THAT listing's location when they assign it. Both
/// sides are covered here so the contract cannot drift on one side only.

ServiceModel service({
  String id = 'svc-1',
  String? location,
  String fullAddress = '',
  String city = '',
  double? latitude,
  double? longitude,
}) => ServiceModel(
  serviceId: id,
  serviceTitle: 'Vehicle Transportation',
  city: city,
  fullAddress: fullAddress,
  isAvailable: true,
  businessName: 'Anand Tyres',
  businessType: 'Transport',
  location: location,
  latitude: latitude,
  longitude: longitude,
);

void main() {
  // ───────────────────── Service Provider: manual coordinates ──────────────

  group('manual coordinates — accepted input', () {
    test('a valid pair is accepted and preserved exactly', () {
      final parsed = parseManualCoordinates('19.076090', '72.877426');

      expect(parsed.error, isNull);
      expect(parsed.latitude, 19.076090);
      expect(parsed.longitude, 72.877426);
      expect(parsed.hasPin, isTrue);
    });

    test('both blank is valid — an address with no pin', () {
      final parsed = parseManualCoordinates('', '   ');

      expect(parsed.error, isNull);
      expect(parsed.latitude, isNull);
      expect(parsed.longitude, isNull);
      expect(parsed.hasPin, isFalse);
    });

    test('zero is a real coordinate, not a missing one', () {
      // The equator / prime meridian must survive; treating 0 as "unset" would
      // silently drop a legitimate pin.
      final parsed = parseManualCoordinates('0', '0');

      expect(parsed.error, isNull);
      expect(parsed.latitude, 0);
      expect(parsed.longitude, 0);
      expect(parsed.hasPin, isTrue);
    });

    test('the range boundaries are inside, not outside', () {
      expect(parseManualCoordinates('-90', '-180').error, isNull);
      expect(parseManualCoordinates('90', '180').error, isNull);
    });

    test('surrounding whitespace does not invalidate a pair', () {
      final parsed = parseManualCoordinates('  19.076090 ', ' 72.877426  ');
      expect(parsed.error, isNull);
      expect(parsed.latitude, 19.076090);
    });
  });

  group('manual coordinates — rejected input', () {
    test('latitude beyond ±90 is rejected', () {
      expect(parseManualCoordinates('91', '72.87').error,
          'Latitude must be between -90 and 90.');
      expect(parseManualCoordinates('-90.5', '72.87').error,
          'Latitude must be between -90 and 90.');
    });

    test('longitude beyond ±180 is rejected', () {
      expect(parseManualCoordinates('19.07', '180.1').error,
          'Longitude must be between -180 and 180.');
      expect(parseManualCoordinates('19.07', '-181').error,
          'Longitude must be between -180 and 180.');
    });

    test('half a pair is not a location', () {
      expect(parseManualCoordinates('19.076090', '').error,
          'Enter both latitude and longitude, or leave both blank.');
      expect(parseManualCoordinates('', '72.877426').error,
          'Enter both latitude and longitude, or leave both blank.');
    });

    test('non-numeric input is rejected', () {
      expect(parseManualCoordinates('near the depot', 'behind it').error,
          'Latitude and longitude must be numbers, e.g. 19.076090.');
    });

    test('NaN and Infinity parse as doubles but locate nothing', () {
      expect(parseManualCoordinates('NaN', '72.87').error, isNotNull);
      expect(parseManualCoordinates('Infinity', '72.87').error, isNotNull);
    });

    test('a rejected pair never leaks a usable coordinate', () {
      // The save path reads `latitude`/`longitude`; if a rejected pair still
      // carried values, an out-of-range pin could reach the payload.
      for (final bad in [
        parseManualCoordinates('91', '72.87'),
        parseManualCoordinates('19.07', '181'),
        parseManualCoordinates('19.07', ''),
        parseManualCoordinates('abc', 'def'),
      ]) {
        expect(bad.error, isNotNull);
        expect(bad.latitude, isNull);
        expect(bad.longitude, isNull);
        expect(bad.hasPin, isFalse);
      }
    });
  });

  // ───────────────── Transport user: the assigned service's location ───────

  group('assignment location — the selected service is the source of truth', () {
    test("uses the provider's saved listing address", () {
      final s = service(
        location: 'Ahmedabad, Gujarat',
        latitude: 23.022505,
        longitude: 72.571365,
      );

      expect(s.resolvedLocation, 'Ahmedabad, Gujarat');
      expect(s.hasCoordinates, isTrue);
      expect(s.latitude, 23.022505);
      expect(s.longitude, 72.571365);
    });

    test('falls back to fullAddress, then city — never past the listing', () {
      expect(
        service(fullAddress: 'Shop 4, MIDC Road, Bhiwandi').resolvedLocation,
        'Shop 4, MIDC Road, Bhiwandi',
      );
      expect(service(city: 'Vadodara').resolvedLocation, 'Vadodara');
    });

    test('a listing with no address resolves to empty, not to something else', () {
      // Empty is the signal for the UI to ask the company where the service is
      // needed. Anything non-empty here would be someone else's address.
      expect(service().resolvedLocation, isEmpty);
      expect(service().hasCoordinates, isFalse);
    });

    test('switching services yields the new service, never the previous one', () {
      final a = service(
        id: 'svc-a',
        location: 'Ahmedabad, Gujarat',
        latitude: 23.022505,
        longitude: 72.571365,
      );
      final b = service(
        id: 'svc-b',
        location: 'Bhiwandi, Maharashtra',
        latitude: 19.296820,
        longitude: 73.063004,
      );

      expect(a.resolvedLocation, isNot(b.resolvedLocation));
      expect(b.resolvedLocation, 'Bhiwandi, Maharashtra');
      expect(b.latitude, 19.296820);
    });

    test('a service with no location does not inherit the previous pin', () {
      final withPin = service(
        id: 'svc-a',
        location: 'Ahmedabad, Gujarat',
        latitude: 23.022505,
        longitude: 72.571365,
      );
      final withoutPin = service(id: 'svc-b');

      expect(withPin.hasCoordinates, isTrue);
      expect(withoutPin.hasCoordinates, isFalse);
      expect(withoutPin.latitude, isNull);
      expect(withoutPin.resolvedLocation, isEmpty);
    });

    test('fromJson reads the coordinates the provider saved', () {
      final parsed = ServiceModel.fromJson({
        'id': 'svc-1',
        'title': 'Vehicle Transportation',
        'location': 'Ahmedabad, Gujarat',
        'latitude': 23.022505,
        'longitude': 72.571365,
        'status': 'Published',
      });

      expect(parsed.resolvedLocation, 'Ahmedabad, Gujarat');
      expect(parsed.latitude, 23.022505);
      expect(parsed.longitude, 72.571365);
    });

    test('fromJson keeps an absent pin null rather than defaulting to zero', () {
      final parsed = ServiceModel.fromJson({
        'id': 'svc-2',
        'title': 'Tyre Service',
        'location': 'Surat, Gujarat',
        'status': 'Published',
      });

      expect(parsed.hasCoordinates, isFalse);
      expect(parsed.latitude, isNull);
      expect(parsed.longitude, isNull);
    });
  });
}
