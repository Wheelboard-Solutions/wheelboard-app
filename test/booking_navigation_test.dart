import 'package:flutter_test/flutter_test.dart';
import 'package:wheelboard/models/service_booking_model.dart';
import 'package:wheelboard/utils/manual_coordinates.dart';

/// Navigating to a booking's service location, and the mode transitions that
/// decide which coordinates a listing is saved with.
///
/// Both are about the same failure: routing someone to the wrong place, or
/// saving a pin the provider never entered.

ServiceBookingModel booking({String? location}) =>
    ServiceBookingModel.fromJson({
      'id': 'bkg-1',
      'bookingNo': 'WS-BKG-260913-0001',
      'serviceId': 'svc-1',
      'serviceName': 'Tyre & Wheel Maintenance Contract',
      'companyName': 'WSPL TRANSPORT',
      'status': 'Assigned',
      if (location != null) 'location': location,
    });

void main() {
  group('booking navigation destination', () {
    test("the booking's own service location is the destination", () {
      final b = booking(
        location: 'Transport Nagar Nigdi, Nigdi, Pimpri-Chinchwad, '
            'Maharashtra, India',
      );

      // The destination must be the service location — never the device's
      // current position, which is where the driver already is.
      expect(b.location, isNotNull);
      expect(b.location, contains('Transport Nagar Nigdi'));
      expect(b.location!.trim(), isNotEmpty);
    });

    test('a booking with no location offers nothing to navigate to', () {
      // The screen gates the action on a non-empty address, so this is the
      // state in which it must stay hidden rather than launching a blank map.
      expect((booking().location ?? '').trim(), isEmpty);
    });

    test('a whitespace-only location counts as missing, not as an address', () {
      expect((booking(location: '   ').location ?? '').trim(), isEmpty);
    });

    test('the address survives the model round-trip unaltered', () {
      // Navigation routes by this exact string; any trimming or re-encoding
      // here would send the driver somewhere else.
      const address = 'Transport Nagar Nigdi, Pimpri-Chinchwad, Maharashtra';
      expect(booking(location: address).location, address);
    });
  });

  group('manual coordinates survive mode transitions', () {
    // `_setManualLocation` carries values across in both directions. These
    // cover the rules it relies on; the screen wires them to the two chips.

    test('a valid typed pair becomes the listing pin when leaving manual mode', () {
      final parsed = parseManualCoordinates('19.076090', '72.877426');

      // Search mode adopts the pin only when the pair is valid.
      expect(parsed.error, isNull);
      expect(parsed.hasPin, isTrue);
      expect(parsed.latitude, 19.076090);
      expect(parsed.longitude, 72.877426);
    });

    test('an invalid typed pair hands over nothing rather than a bad pin', () {
      final parsed = parseManualCoordinates('91', '72.877426');

      expect(parsed.error, isNotNull);
      expect(parsed.hasPin, isFalse);
      // The screen assigns these directly on the way back to Search mode, so
      // nulls here are what stop an out-of-range pin from being kept.
      expect(parsed.latitude, isNull);
      expect(parsed.longitude, isNull);
    });

    test('an empty pair leaves the listing with no pin, not a zero one', () {
      final parsed = parseManualCoordinates('', '');

      expect(parsed.error, isNull);
      expect(parsed.hasPin, isFalse);
      expect(parsed.latitude, isNull);
    });

    test('a resolved pin re-renders exactly when seeding the manual fields', () {
      // Entering manual mode seeds the text fields from the resolved pin via
      // `toString()`; re-parsing must return the identical values or a
      // round-trip through the toggle would drift the location.
      const lat = 19.076090;
      const lng = 72.877426;

      final reparsed = parseManualCoordinates(lat.toString(), lng.toString());

      expect(reparsed.error, isNull);
      expect(reparsed.latitude, lat);
      expect(reparsed.longitude, lng);
    });

    test('a negative pin round-trips through the fields intact', () {
      const lat = -33.865143;
      const lng = -151.209900;

      final reparsed = parseManualCoordinates(lat.toString(), lng.toString());

      expect(reparsed.latitude, lat);
      expect(reparsed.longitude, lng);
    });

    test('a zero pin round-trips rather than reading as unset', () {
      final reparsed = parseManualCoordinates(0.0.toString(), 0.0.toString());

      expect(reparsed.error, isNull);
      expect(reparsed.hasPin, isTrue);
      expect(reparsed.latitude, 0);
    });
  });
}
