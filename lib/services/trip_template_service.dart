import 'package:dio/dio.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/api_exception.dart';
import '../models/trip_template_model.dart';

/// Repeat trips for fixed routes — backend `/trip-templates` (fleet owners).
/// Responses are wrapped as `{ success, data }`.
class TripTemplateService {
  Future<List<TripTemplate>> list() async {
    final data = await _call(() => ApiClient.instance.get<dynamic>(ApiEndpoints.tripTemplates.list),
        'Failed to load repeat trips');
    return (data as List? ?? const [])
        .whereType<Map>()
        .map((e) => TripTemplate.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<TripTemplate> get(String id) => _one(
      () => ApiClient.instance.get<dynamic>(ApiEndpoints.tripTemplates.byId(id)),
      'Failed to load repeat trip');

  Future<TripTemplate> create(Map<String, dynamic> body) => _one(
      () => ApiClient.instance.post<dynamic>(ApiEndpoints.tripTemplates.create, data: body),
      'Failed to create repeat trip');

  Future<TripTemplate> update(String id, Map<String, dynamic> body) => _one(
      () => ApiClient.instance.patch<dynamic>(ApiEndpoints.tripTemplates.byId(id), data: body),
      'Failed to update repeat trip');

  Future<TripTemplate> setPaused(String id, bool paused) => _one(
      () => ApiClient.instance.post<dynamic>(
          paused ? ApiEndpoints.tripTemplates.pause(id) : ApiEndpoints.tripTemplates.resume(id)),
      paused ? 'Failed to pause' : 'Failed to resume');

  Future<TripTemplate> skip(String id, String date) => _one(
      () => ApiClient.instance.post<dynamic>(ApiEndpoints.tripTemplates.skip(id), data: {'date': date}),
      'Failed to skip trip');

  Future<TripTemplate> unskip(String id, String date) => _one(
      () => ApiClient.instance.post<dynamic>(ApiEndpoints.tripTemplates.unskip(id), data: {'date': date}),
      'Failed to restore trip');

  Future<void> delete(String id) => _call(
      () => ApiClient.instance.delete<dynamic>(ApiEndpoints.tripTemplates.byId(id)),
      'Failed to stop repeat trip');

  Future<TripTemplate> _one(Future<dynamic> Function() req, String fallback) async {
    final data = await _call(req, fallback);
    return TripTemplate.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<dynamic> _call(Future<dynamic> Function() req, String fallback) async {
    try {
      final raw = await req();
      return (raw is Map && raw.containsKey('data')) ? raw['data'] : raw;
    } on DioException catch (e) {
      throw Exception(_msg(e, fallback));
    }
  }

  String _msg(DioException e, String fallback) {
    if (e.error is ApiException) return (e.error as ApiException).message;
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      final m = data['message'];
      return m is List ? m.join(', ') : m.toString();
    }
    return '$fallback (${e.response?.statusCode ?? 'network error'})';
  }
}
