import 'package:dio/dio.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/api_exception.dart';

/// Named, owner-scoped tracker actions. The device API key stays on the server.
class TrackerCommandService {
  Future<List<Map<String, dynamic>>> events(String vehicleId) async {
    try {
      final raw = await ApiClient.instance.get<dynamic>(
        ApiEndpoints.fleet.vehicleEvents(vehicleId),
        queryParameters: {'limit': 20},
      );
      return (raw as List)
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
    } on DioException catch (e) {
      throw Exception(_message(e, 'Could not load tracker events'));
    }
  }

  Future<Map<String, dynamic>> status(String vehicleId) async {
    try {
      final raw = await ApiClient.instance.get<dynamic>(
        ApiEndpoints.fleet.vehicleTracker(vehicleId),
      );
      return Map<String, dynamic>.from(raw as Map);
    } on DioException catch (e) {
      throw Exception(_message(e, 'Could not load tracker status'));
    }
  }

  Future<Map<String, dynamic>> run(
    String vehicleId,
    String action, {
    int? ignitionOnSeconds,
    int? ignitionOffSeconds,
    int? speedKmh,
  }) async {
    try {
      final raw = await ApiClient.instance.post<dynamic>(
        ApiEndpoints.fleet.vehicleTrackerCommands(vehicleId),
        data: {
          'action': action,
          if (ignitionOnSeconds != null) 'ignitionOnSeconds': ignitionOnSeconds,
          if (ignitionOffSeconds != null)
            'ignitionOffSeconds': ignitionOffSeconds,
          if (speedKmh != null) 'speedKmh': speedKmh,
        },
      );
      final result = Map<String, dynamic>.from(raw as Map);
      if (result['success'] != true) {
        throw Exception('The tracker did not acknowledge the command');
      }
      return result;
    } on DioException catch (e) {
      throw Exception(_message(e, 'Could not send tracker command'));
    }
  }

  String _message(DioException e, String fallback) {
    if (e.error is ApiException) return (e.error as ApiException).message;
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      final message = data['message'];
      return message is List ? message.join(', ') : message.toString();
    }
    return '$fallback (${e.response?.statusCode ?? 'network error'})';
  }
}
