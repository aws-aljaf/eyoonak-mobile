/// Production endpoint is safe by default; staging builds can override it
/// with --dart-define=API_BASE_URL=https://staging.example/api/v1.
class ApiConfig {
  const ApiConfig._();

  static const String baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://app.eyoonak.com/api/v1');

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);
}
