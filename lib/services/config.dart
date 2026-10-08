enum Environment { local, testing, production }

class AppConfig {
  // 10.0.2.2 is the Android emulator's alias for host machine localhost.
  // For a physical device on the same Wi-Fi, replace with your machine's LAN IP.
  static const String _localBaseUrl = 'http://10.0.2.2:8000/';
  static const String _testingBaseUrl =
      'https://wheelboardapi.addonshareware.com/';
  static const String _productionBaseUrl = 'https://api.wheelboard.in/';

  /// Change this to switch environments
  static Environment currentEnvironment = Environment.local;

  static String get baseUrl {
    switch (currentEnvironment) {
      case Environment.local:
        return _localBaseUrl;
      case Environment.testing:
        return _testingBaseUrl;
      case Environment.production:
        return _productionBaseUrl;
    }
  }
}
