import 'package:dio/dio.dart';

import '../core/auth/auth_service.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/api_exception.dart';
import '../models/wheelbot_message.dart';

class WheelbotService {
  const WheelbotService();

  Future<WheelbotReply> send({
    required List<WheelbotMessage> messages,
    String? provider,
  }) async {
    try {
      final raw = await ApiClient.instance.post<dynamic>(
        ApiEndpoints.chat.send,
        data: {
          'messages': messages.map((m) => m.toApiJson()).toList(),
          if (AuthService.to.userId.isNotEmpty) 'userId': AuthService.to.userId,
          if (provider != null) 'provider': provider,
        },
      );

      if (raw is Map) {
        return WheelbotReply.fromJson(Map<String, dynamic>.from(raw));
      }

      return const WheelbotReply(
        success: false,
        error: 'WheelBot returned an unexpected response.',
      );
    } on DioException catch (e) {
      return WheelbotReply(success: false, error: _message(e));
    } catch (e) {
      return WheelbotReply(
        success: false,
        error: 'WheelBot could not respond right now. Please try again.',
      );
    }
  }

  String _message(DioException e) {
    final data = e.response?.data;

    // WheelBot signals its own failures as { success: false, error: '<text>' },
    // where `error` is already a user-facing sentence. Read that before falling
    // back to the interceptor's ApiException, which only knows the generic
    // status-code wording ("Server error. Please try again later.") because the
    // chat endpoint does not use the standard `message` error shape.
    if (data is Map && data['success'] == false) {
      final chatError = data['error'];
      if (chatError is String && chatError.trim().isNotEmpty) return chatError;
    }

    if (e.error is ApiException) return (e.error as ApiException).message;
    if (data is Map) {
      final error = data['error'] ?? data['message'];
      if (error is List) return error.join(', ');
      if (error != null) return error.toString();
    }
    return 'WheelBot backend is not reachable. Please check your connection.';
  }
}
