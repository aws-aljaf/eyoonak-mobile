/// Mirrors the unified error envelope documented in
/// documentation/04-api-specification.md section 1:
/// `{ "success": false, "message": "...", "errors": { field: [...] } }`.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.fieldErrors = const {},
  });

  final String message;
  final int? statusCode;
  final Map<String, List<String>> fieldErrors;

  bool get isUnauthorized => statusCode == 401;

  bool get isValidation => statusCode == 422;

  bool get isNetwork => statusCode == null;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
