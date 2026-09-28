class AppConstants {
  // API
  static const String apiBaseUrl = 'https://podcasts-api-six.vercel.app/api';
  static const int defaultPageSize = 20;
  static const int defaultSearchLimit = 30;

  // App
  static const String appName = 'AURA';
  static const String appVersion = '1.0.0';
  static const int appVersionCode = 1;

  // In-app update configuration
  // Place a version.json file on your website or GitHub repository
  static const String updateCheckUrl = 'https://raw.githubusercontent.com/ayushthakur/aura/main/version.json';
  static const String defaultWebsiteUrl = 'https://aurapodcast.app';
  static const String keyDismissedUpdateVersion = 'dismissed_update_version';

  // Hive boxes
  static const String episodeBox = 'episodes';
  static const String downloadBox = 'downloads';
  static const String playlistBox = 'playlists';
  static const String bookmarkBox = 'bookmarks';
  static const String historyBox = 'history';
  static const String settingsBox = 'settings';
  static const String cacheBox = 'cache';

  // Settings keys
  static const String keyThemeMode = 'theme_mode';
  static const String keyPlaybackSpeed = 'playback_speed';
  static const String keyLastPosition = 'last_position_';
  static const String keyUserName = 'user_name';

  // Audio
  static const List<double> speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0];
  static const double defaultSpeed = 1.0;

  // Download quality preference
  static const String prefAudioQuality = 'audio_quality';
  static const String quality320 = '320kbps';
  static const String quality160 = '160kbps';
  static const String quality96 = '96kbps';

  // Cache duration
  static const Duration searchCacheDuration = Duration(minutes: 10);
  static const Duration showCacheDuration = Duration(hours: 1);
}
