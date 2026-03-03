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