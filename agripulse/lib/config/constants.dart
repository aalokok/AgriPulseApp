class AppConstants {
  AppConstants._();

  static const String appName = 'AgriPulse';
  static const String oauthClientId = 'farm';
  static const double defaultWaterLevelThreshold = 20.0;
  static const Duration tokenRefreshBuffer = Duration(minutes: 1);
  static const int waterLevelPageSize = 50;
  static const int animalPageSize = 25;
  static const Duration backgroundSyncInterval = Duration(hours: 1);

  // Secure storage keys
  static const String keyServerUrl = 'server_url';
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyTokenExpiry = 'token_expiry';
  static const String keyUsername = 'username';

  // SharedPreferences keys
  static const String keyThreshold = 'water_level_threshold';
  static const String keyNotificationsEnabled = 'notifications_enabled';

  // Notification
  static const String notificationChannelId = 'water_level_alerts';
  static const String notificationChannelName = 'Water Level Alerts';
  static const String notificationChannelDesc =
      'Notifications for water level readings and threshold alerts';

  // WorkManager
  static const String backgroundTaskName = 'waterLevelCheck';
  static const String backgroundTaskTag = 'com.agripulse.waterLevelCheck';
}
