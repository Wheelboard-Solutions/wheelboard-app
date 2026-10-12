/// A repeat trip (fixed route) — backend `/trip-templates`.
/// Dates are `YYYY-MM-DD` and [startTime] is `HH:mm`, both India time.
class TripStop {
  final String address;
  final double lat;
  final double lng;

  const TripStop({required this.address, required this.lat, required this.lng});

  factory TripStop.fromJson(Map<String, dynamic> j) {
    final c = (j['coordinates'] as List?) ?? const [0, 0];
    return TripStop(
      address: j['address']?.toString() ?? '',
      lng: (c.isNotEmpty ? c[0] as num : 0).toDouble(),
      lat: (c.length > 1 ? c[1] as num : 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'address': address,
        'coordinates': [lng, lat],
      };
}

class TemplateRun {
  final String date;
  final DateTime? startsAt;

  /// scheduled | pending | created | cancelled | skipped | failed
  final String status;
  final String? tripId;
  final String? error;

  TemplateRun.fromJson(Map<String, dynamic> j)
      : date = j['date']?.toString() ?? '',
        startsAt = DateTime.tryParse(j['startsAt']?.toString() ?? '')?.toLocal(),
        status = j['status']?.toString() ?? 'scheduled',
        tripId = j['tripId']?.toString(),
        error = j['error']?.toString();
}

class TripTemplate {
  final String templateId;
  final String name;

  /// active | paused | deleted
  final String status;
  final String vehicleId;
  final String? vehicleNumber;
  final String? driverId;
  final String? driverModel;
  final String? driverName;
  final TripStop start;
  final TripStop end;
  final List<TripStop> stops;
  final double? expectedPay;
  final String startTime;
  final int durationMinutes;

  /// daily | weekdays | dates
  final String repeatType;
  final List<int> weekdays;
  final List<String> dates;
  final String startDate;
  final String? endDate;
  final List<TemplateRun> upcoming;
  final List<TemplateRun> history;

  TripTemplate.fromJson(Map<String, dynamic> j)
      : templateId = j['templateId']?.toString() ?? '',
        name = j['name']?.toString() ?? '',
        status = j['status']?.toString() ?? 'active',
        vehicleId = j['vehicleId']?.toString() ?? '',
        vehicleNumber = j['vehicleNumber']?.toString(),
        driverId = j['driverId']?.toString(),
        driverModel = j['driverModel']?.toString(),
        driverName = j['driverName']?.toString(),
        start = TripStop.fromJson(_map(_map(j['route'])['startLocation'])),
        end = TripStop.fromJson(_map(_map(j['route'])['endLocation'])),
        stops = ((_map(j['route'])['stops'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => TripStop.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        expectedPay = (j['expectedPay'] as num?)?.toDouble(),
        startTime = j['startTime']?.toString() ?? '09:00',
        durationMinutes = (j['durationMinutes'] as num?)?.toInt() ?? 480,
        repeatType = j['repeatType']?.toString() ?? 'daily',
        weekdays = ((j['weekdays'] as List?) ?? const []).map((e) => (e as num).toInt()).toList(),
        dates = ((j['dates'] as List?) ?? const []).map((e) => e.toString()).toList(),
        startDate = j['startDate']?.toString() ?? '',
        endDate = j['endDate']?.toString(),
        upcoming = _runs(j['upcoming']),
        history = _runs(j['history']);

  bool get isPaused => status == 'paused';

  static const _dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  /// "Daily", "Mon, Wed, Fri" or "3 dates".
  String get repeatLabel {
    switch (repeatType) {
      case 'daily':
        return 'Daily';
      case 'weekdays':
        final d = [...weekdays]..sort((a, b) => ((a + 6) % 7).compareTo((b + 6) % 7));
        return d.map((i) => _dayNames[i]).join(', ');
      default:
        return '${dates.length} date${dates.length == 1 ? '' : 's'}';
    }
  }

  static Map<String, dynamic> _map(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  static List<TemplateRun> _runs(dynamic v) => ((v as List?) ?? const [])
      .whereType<Map>()
      .map((e) => TemplateRun.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}
