/// Hand-typed latitude/longitude, parsed and validated.
///
/// Mirrors `parseManualCoordinates` in wheelboard-fe (`src/lib/serviceLocation`
/// usage in `AddServiceModal`): the same accepted range, the same all-or-nothing
/// rule, and the same treatment of zero as a real coordinate. Kept as a pure
/// top-level function rather than a method on a `State` so the rules can be
/// tested directly instead of through a widget.
library;

/// The outcome of reading a manual coordinate pair.
///
/// `error == null` means the input is usable — which includes BOTH FIELDS
/// BLANK, a legitimate answer meaning "address only, no pin". Callers must
/// therefore check `error`, not whether the coordinates are null.
class ManualCoordinates {
  const ManualCoordinates({this.latitude, this.longitude, this.error});

  final double? latitude;
  final double? longitude;
  final String? error;

  /// A complete, in-range pair.
  bool get hasPin => latitude != null && longitude != null;

  const ManualCoordinates.empty() : latitude = null, longitude = null, error = null;

  ManualCoordinates.invalid(String message)
    : latitude = null,
      longitude = null,
      error = message;
}

/// Read a hand-typed coordinate pair.
///
/// Both blank is valid — the provider gave an address without a pin, exactly as
/// a listing saved before the Places flow. Anything else must be a complete,
/// in-range pair: half a coordinate is not a location, and an out-of-range
/// value is a typo rather than a place. Zero is a real coordinate and is
/// preserved as one, so a listing on the equator or the prime meridian is not
/// silently discarded.
ManualCoordinates parseManualCoordinates(String latText, String lngText) {
  final lat = latText.trim();
  final lng = lngText.trim();

  if (lat.isEmpty && lng.isEmpty) {
    return const ManualCoordinates.empty();
  }
  if (lat.isEmpty || lng.isEmpty) {
    return ManualCoordinates.invalid(
      'Enter both latitude and longitude, or leave both blank.',
    );
  }

  final latitude = double.tryParse(lat);
  final longitude = double.tryParse(lng);
  if (latitude == null || longitude == null) {
    return ManualCoordinates.invalid(
      'Latitude and longitude must be numbers, e.g. 19.076090.',
    );
  }
  // NaN and infinity parse successfully from "NaN"/"Infinity" but locate
  // nothing, so they are rejected alongside out-of-range values.
  if (!latitude.isFinite || latitude < -90 || latitude > 90) {
    return ManualCoordinates.invalid('Latitude must be between -90 and 90.');
  }
  if (!longitude.isFinite || longitude < -180 || longitude > 180) {
    return ManualCoordinates.invalid(
      'Longitude must be between -180 and 180.',
    );
  }

  return ManualCoordinates(latitude: latitude, longitude: longitude);
}
