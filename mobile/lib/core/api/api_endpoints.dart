class ApiEndpoints {
  static const String health = '/health';
  
  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';

  // Users
  static const String me = '/users/me';

  // Categories
  static const String categories = '/categories';
  static String category(String id) => '/categories/$id';

  // Documents
  static const String documents = '/documents';
  static const String documentUpload = '/documents/upload';
  static const String documentStats = '/documents/stats/overview';
  static String document(String id) => '/documents/$id';
  static String documentDownload(String id) => '/documents/$id/download';
  static String documentPreview(String id) => '/documents/$id/preview';
  static String documentFavorite(String id) => '/documents/$id/favorite';
  static String documentArchive(String id) => '/documents/$id/archive';

  // Security
  static const String securitySettings = '/security/settings';
  static const String verifyPin = '/security/verify-pin';

  // Sharing
  static const String createShare = '/sharing/create';
  static const String myShares = '/sharing/my-shares';
  static String revokeShare(String id) => '/sharing/$id/revoke';
  static String publicShare(String token) => '/sharing/public/$token';

  // Search
  static const String search = '/search';

  // OCR & Intelligence
  static String documentOcr(String id) => '/documents/$id/ocr';
  static String documentIntelligence(String id) => '/documents/$id/intelligence';

  // Reminders
  static String documentReminders(String id) => '/documents/$id/reminders';
  static const String remindersCheck = '/reminders/check';

  // Notifications
  static const String notifications = '/notifications';
  static String notificationRead(String id) => '/notifications/$id/read';
  static const String notificationsReadAll = '/notifications/read-all';
}
