import 'package:flutter/foundation.dart';

class AppConfig {
  static const String appName = 'DHA Vault';
  static const String appTagline = 'Your Documents. Secured. Organized. Instantly Accessible.';

  /// Render Production API URL
  static const String defaultProductionUrl = 'https://dha-vault-api.onrender.com';

  /// Compile-time dart define: flutter build apk --dart-define=API_URL=https://...
  static const String _configuredUrl = String.fromEnvironment('API_URL', defaultValue: '');

  /// Local development URLs
  static const String defaultUsbUrl = 'http://127.0.0.1:4000';
  static const String fallbackLanUrl = 'http://10.209.183.195:4000';

  /// Dynamic active API Base URL
  static String apiBaseUrl = _resolveInitialBaseUrl();

  /// Check whether the app is running in production mode
  static bool get isProduction =>
      kReleaseMode ||
      _configuredUrl.startsWith('https://') ||
      apiBaseUrl.startsWith('https://');

  static String _resolveInitialBaseUrl() {
    if (_configuredUrl.isNotEmpty) {
      return _configuredUrl;
    }
    if (kReleaseMode) {
      return defaultProductionUrl;
    }
    return defaultUsbUrl;
  }

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);
}
