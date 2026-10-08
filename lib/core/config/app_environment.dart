import 'package:flutter_dotenv/flutter_dotenv.dart';

/// App environment configuration.
///
/// Mirrors wheelboard-fe's NEXT_PUBLIC_API_URL pattern:
///   - Set API_URL in .env for dev  → http://10.96.16.135:8000
///   - Set API_URL in .env for prod → https://api.wheelboard.in
///
/// The .env file is the single source of truth — no need to change any Dart file.
class AppEnvironment {
  /// Production API, used when .env has no API_URL.
  static const String _defaultApiUrl = 'https://api.wheelboard.in';

  /// Full API base URL including the global `/api` prefix.
  /// Reads API_URL from .env, then appends /api (same as wheelboard-fe's NEXT_PUBLIC_API_URL + '/api').
  static String get apiBaseUrl {
    final url = dotenv.maybeGet('API_URL') ?? _defaultApiUrl;
    return '$url/api';
  }

  /// Raw origin without the /api suffix (used for image URLs, sockets, etc.)
  static String get origin {
    return dotenv.maybeGet('API_URL') ?? _defaultApiUrl;
  }

  /// WebSocket URL for real-time tracking.
  static String get socketUrl => '$origin/tracking';

  static bool get isProduction {
    final url = dotenv.maybeGet('API_URL') ?? '';
    return !url.contains('localhost') &&
        !url.contains('10.') &&
        !url.contains('192.168.');
  }
}
