import 'package:dio/dio.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/api_exception.dart';
import '../models/referral_program_model.dart';

/// Service Provider refer & earn — backend `modules/referral-program`.
/// Responses are wrapped as `{ success, data }`.
class ReferralProgramService {
  Future<ReferralRates> getRates() async {
    final data = await _get(ApiEndpoints.referralProgram.settings, 'Failed to load rates');
    return data is Map ? ReferralRates.fromJson(Map<String, dynamic>.from(data)) : ReferralRates.defaults;
  }

  Future<MyReferrals> getMyReferrals() async {
    final data = await _get(ApiEndpoints.referralProgram.myReferrals, 'Failed to load referrals');
    return MyReferrals.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// `{ referred: bool, code: String?, appliedAt: String? }`
  Future<Map<String, dynamic>> getReferredBy() async {
    final data = await _get(ApiEndpoints.referralProgram.referredBy, 'Failed to load referral status');
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  Future<void> applyCode(String code) async {
    try {
      await ApiClient.instance.post<dynamic>(
        ApiEndpoints.referralProgram.applyCode,
        data: {'code': code.trim().toUpperCase()},
      );
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Could not apply code'));
    }
  }

  Future<dynamic> _get(String path, String fallback) async {
    try {
      final raw = await ApiClient.instance.get<dynamic>(path);
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
