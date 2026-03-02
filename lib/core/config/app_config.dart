class Env {
  static String _flavor = 'dev';

  static Future<void> load() async {
    // Read from --dart-define (set at build time)
    _flavor = const String.fromEnvironment('FLAVOR', defaultValue: 'dev');
  }

  static bool get isDev => _flavor == 'dev';
  static bool get isProd => _flavor == 'prod';
  static String get flavor => _flavor;

  // API URLs per flavor
  static String get apiBaseUrl => const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.example.com',
  );
}

// core/config/app_config.dart
class AppConfig {
  static const appName = 'Gallery';
  static const packageName = 'com.yourcompany.samsunggalleryclone';

  // Minimum SDK: 21 (Android 5.0) — covers 99.5% of Android devices
  static const minSdkVersion = 21;

  // Target SDK: 34 (Android 14) — required for Play Store 2024+
  static const targetSdkVersion = 34;

  // Trash retention period
  static const trashRetentionDays = 30;

  // Thumbnail cache: max 500MB on disk
  static const thumbnailCacheMaxBytes = 500 * 1024 * 1024;

  // Grid columns in landscape mode
  static const gridColumnsPortrait = 4;
  static const gridColumnsLandscape = 6;

  // Duplicate detection threshold (Hamming distance)
  static const duplicateHashThreshold = 10;

  // Face clustering similarity threshold (cosine)
  static const faceClusterThreshold = 0.6;
}