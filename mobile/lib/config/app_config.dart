class AppConfig {
  static const String appName = 'DHA Vault';
  static const String appTagline = 'Your Documents. Secured. Organized. Instantly Accessible.';
  
  // Connect to local NestJS backend
  // For Android emulator 10.0.2.2 is host localhost, for Windows/web localhost is 127.0.0.1
  static const String apiBaseUrl = 'http://127.0.0.1:4000';
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
