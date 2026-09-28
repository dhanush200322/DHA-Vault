class AppConfig {
  static const String appName = 'DHA Vault';
  static const String appTagline = 'Your Documents. Secured. Organized. Instantly Accessible.';
  
  // Connect to local NestJS backend
  // Primary is USB port reverse (127.0.0.1:4000), fallback is local Wi-Fi LAN (10.209.183.195:4000)
  static String apiBaseUrl = 'http://127.0.0.1:4000';
  static const String defaultUsbUrl = 'http://127.0.0.1:4000';
  static const String fallbackLanUrl = 'http://10.209.183.195:4000';

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
