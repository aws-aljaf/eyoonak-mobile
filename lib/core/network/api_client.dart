import '../sync/family_offline.dart';
import 'package:dio/dio.dart';

import 'api_config.dart';
import 'api_envelope.dart';
import 'api_exception.dart';

/// Thin wrapper around Dio that speaks the exact unified response envelope
/// from documentation/04-api-specification.md section 1. Every feature's
/// data layer goes through this — nothing constructs its own Dio instance
/// or parses `success`/`data`/`errors` by hand.
///
/// Takes a plain `getToken` callback rather than a concrete
/// `SecureTokenStore` — that's the only thing this class actually needs
/// (dependency inversion), and it means tests can supply a trivial fake
/// with no flutter_secure_storage platform channel involved at all. See
/// lib/app/providers.dart for how it's wired to the real store.
class ApiClient {
  ApiClient(
      {required Future<String?> Function() getToken,
      Dio? dio,
      String? baseUrl,
      this.familyOffline})
      : _getToken = getToken,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? ApiConfig.baseUrl,
                connectTimeout: ApiConfig.connectTimeout,
                receiveTimeout: ApiConfig.receiveTimeout,
                headers: const {
                  'Accept': 'application/json',
                  // Section 2 of the API spec: NEVER an X-Tenant-Company
                  // header — company_id is derived server-side from the
                  // authenticated user only.
                  'Accept-Language': 'ar',
                },
              ),
            ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _getToken();

          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          handler.next(options);
        },
      ),
    );
  }

  final FamilyOffline? familyOffline;
  final Dio _dio;
  final Future<String?> Function() _getToken;

  /// Returns just `data` for a single-resource endpoint. `headers`, when
  /// given, are merged on top of the interceptor-injected Authorization
  /// header for this one request only — added for `X-Family-Id` (see
  /// FamilyApi), never a substitute for it.
  Future<dynamic> get(String path,
      {Map<String, dynamic>? query, Map<String, dynamic>? headers}) async {
    final body = await _request('GET', path, query: query, headers: headers);

    return body['data'];
  }

  /// Returns `data` + `meta` for a paginated list endpoint.
  Future<ApiEnvelope> getPaginated(
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
  }) async {
    final body = await _request('GET', path, query: query, headers: headers);

    return ApiEnvelope(
      data: (body['data'] as List?) ?? const [],
      meta: Map<String, dynamic>.from(body['meta'] as Map? ?? const {}),
    );
  }

  Future<dynamic> post(String path,
      {dynamic data, Map<String, dynamic>? headers}) async {
    final body = await _request('POST', path, data: data, headers: headers);

    return body['data'];
  }

  Future<dynamic> put(String path,
      {dynamic data, Map<String, dynamic>? headers}) async {
    final body = await _request('PUT', path, data: data, headers: headers);

    return body['data'];
  }

  /// Returns `data` (typically an empty object per the envelope, e.g.
  /// `FamilyGeofenceController::destroy()`'s response) for a delete
  /// endpoint — this backend answers deletes with a 200 JSON envelope, not
  /// a bare 204, so this stays symmetric with `get`/`post`/`put` rather
  /// than a `void` return.
  Future<dynamic> delete(String path, {Map<String, dynamic>? headers}) async {
    final body = await _request('DELETE', path, headers: headers);

    return body['data'];
  }

  Future<dynamic> postMultipart(String path, FormData data,
      {Map<String, dynamic>? headers}) async {
    final body = await _request('POST', path, data: data, headers: headers);

    return body['data'];
  }

  /// Fetches raw bytes from an **absolute** URL — e.g. a `download_url`
  /// minted by `SecureFileService::signedUrl()` — through this same
  /// authenticated Dio instance, so the request carries the exact
  /// `Authorization: Bearer` header the interceptor above attaches to every
  /// other call. This matters: `GET /files/{uuid}` (`SecureFileController`)
  /// sits inside the backend's `auth:sanctum` middleware group *and* behind
  /// its own `signed` middleware — both checks must pass, not the signature
  /// alone (verified directly against `routes/api_v1.php` and
  /// `SecureFileController`'s own docblock, which is explicit about this
  /// being a deliberate two-layer design). A signed link opened directly in
  /// an external browser carries no such header and gets a 401 from this
  /// route — `driver_documents_screen.dart`/`accidents_list_screen.dart`
  /// originally did exactly that via `url_launcher` (a real, shipped gap,
  /// not a hypothetical one); both were fixed to go through
  /// `download()`/this method instead (see `DriversApi.downloadDocument()`/
  /// `AccidentsApi.downloadFile()`) — `url_launcher` is no longer used
  /// anywhere in this app. Dio treats a `path` that already has its own
  /// scheme as a full override of `baseUrl` rather than something to append
  /// to it, so passing the backend's fully-qualified `download_url` straight
  /// through works unlike every bare-path method above.
  Future<List<int>> downloadBytes(String url,
      {Map<String, dynamic>? headers}) async {
    try {
      final response = await _dio.get<List<int>>(url,
          options: Options(responseType: ResponseType.bytes, headers: headers));

      return response.data ?? const [];
    } on DioException catch (error) {
      final body = _asMap(error.response?.data);

      throw ApiException(
        message: (body['message'] as String?) ?? 'تعذر تنزيل الملف',
        statusCode: error.response?.statusCode,
      );
    }
  }

  /// Same authenticated fetch as [downloadBytes], but also surfaces the two
  /// response headers `SecureFileController::show()` always sets
  /// (backend/app/Http/Controllers/Api/V1/SecureFileController.php,
  /// verified directly before adding this) — `Content-Type` (the stored
  /// file's real, sniffed MIME type) and the filename Laravel's
  /// `Storage::disk('local')->response($path, $downloadName, ...)` puts on
  /// `Content-Disposition` (already carries the correct extension
  /// server-side, e.g. "driver-document-license.pdf", derived from the
  /// stored file's own path — never guessed client-side). This is what
  /// `DriversApi.downloadDocument()`/`AccidentsApi.downloadFile()` use
  /// instead of `downloadBytes()` directly: unlike a report export (which
  /// already knows its own format/extension from local metadata — see
  /// `AdminReportExportsApi.download()`), a driver document or accident
  /// attachment has no reliable extension anywhere on its own model (an
  /// accident's police report doesn't even carry a `mime_type` field), so
  /// the server's own filename is the only trustworthy source.
  Future<DownloadedFile> download(String url) async {
    try {
      final response = await _dio.get<List<int>>(url,
          options: Options(responseType: ResponseType.bytes));

      return DownloadedFile(
        bytes: response.data ?? const [],
        filename: _filenameFromContentDisposition(
            response.headers.value('content-disposition')),
        mimeType: response.headers.value('content-type'),
      );
    } on DioException catch (error) {
      final body = _asMap(error.response?.data);

      throw ApiException(
        message: (body['message'] as String?) ?? 'تعذر تنزيل الملف',
        statusCode: error.response?.statusCode,
      );
    }
  }

  /// Parses `Content-Disposition: attachment; filename="driver-document-
  /// license.pdf"` — the exact shape Laravel's `Storage::response()`
  /// produces — into just the filename. Returns `null` on anything
  /// unexpected rather than throwing; every caller already falls back to a
  /// generated name when this comes back empty.
  String? _filenameFromContentDisposition(String? header) {
    if (header == null) {
      return null;
    }

    final match = RegExp('filename="?([^"; ]+)"?').firstMatch(header);

    return match?.group(1);
  }

  Future<void> flushFamilyOffline() async {
    await familyOffline?.flush((method, path, {headers}) =>
        _networkRequest(method, path, headers: headers));
  }

  Future<Map<String, dynamic>> _request(String method, String path,
      {Map<String, dynamic>? query,
      dynamic data,
      Map<String, dynamic>? headers}) {
    Future<Map<String, dynamic>> action() => _networkRequest(method, path,
        query: query, data: data, headers: headers);
    return familyOffline?.run(method, path,
            query: query, headers: headers, request: action) ??
        action();
  }

  Future<Map<String, dynamic>> _networkRequest(
    String method,
    String path, {
    Map<String, dynamic>? query,
    dynamic data,
    Map<String, dynamic>? headers,
  }) async {
    // Checked against the actual Dio client's configured baseUrl (not the
    // static ApiConfig.baseUrl directly) — that's what actually determines
    // where a request goes, and it's what lets api_client_test.dart inject
    // a fake Dio with its own baseUrl without ever touching
    // --dart-define=API_BASE_URL. In production _dio's baseUrl always
    // traces back to ApiConfig.baseUrl (see the constructor above), so the
    // guard is unchanged there: a build that forgot --dart-define still
    // fails loudly on the very first request instead of hitting an empty
    // host silently.
    if (_dio.options.baseUrl.isEmpty) {
      throw const ApiException(
        message: 'لم يتم ضبط عنوان الخادم (API_BASE_URL) عند بناء التطبيق.',
      );
    }

    try {
      final response = await _requestWithRetry(
        path,
        queryParameters: query,
        data: data,
        options: Options(method: method, headers: headers),
      );

      final body = _asMap(response.data);

      if (body['success'] != true) {
        throw ApiException(
          message: (body['message'] as String?) ?? 'حدث خطأ غير متوقع',
          statusCode: response.statusCode,
          fieldErrors: _parseFieldErrors(body['errors']),
        );
      }

      return body;
    } on DioException catch (error) {
      final body = _asMap(error.response?.data);

      throw ApiException(
        message: (body['message'] as String?) ??
            error.message ??
            'تعذر الاتصال بالخادم',
        statusCode: error.response?.statusCode,
        fieldErrors: _parseFieldErrors(body['errors']),
      );
    }
  }

  Future<Response<dynamic>> _requestWithRetry(String path,
      {Map<String, dynamic>? queryParameters,
      dynamic data,
      required Options options}) async {
    for (var attempt = 0;; attempt++) {
      try {
        return await _dio.request<dynamic>(path,
            queryParameters: queryParameters, data: data, options: options);
      } on DioException catch (error) {
        final transient = const [
              DioExceptionType.connectionTimeout,
              DioExceptionType.receiveTimeout,
              DioExceptionType.connectionError
            ].contains(error.type) ||
            const [502, 503, 504].contains(error.response?.statusCode);
        if (options.method != 'GET' || !transient || attempt >= 2) rethrow;
        await Future<void>.delayed(
            Duration(milliseconds: 350 * (1 << attempt)));
      }
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    return value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
  }

  Map<String, List<String>> _parseFieldErrors(dynamic errors) {
    if (errors is! Map) {
      return const {};
    }

    return errors.map(
      (key, value) => MapEntry(
        key.toString(),
        value is List
            ? value.map((e) => e.toString()).toList()
            : [value.toString()],
      ),
    );
  }
}

/// Return type of [ApiClient.download] — bytes plus whatever the server's
/// own response headers say about the file, so a caller never has to
/// reconstruct a filename/extension from a model field that may not even
/// exist. `filename`/`mimeType` are both nullable: a caller falls back to
/// a generated name when the header parse comes back empty (should never
/// happen against `SecureFileController::show()`, which always sets both,
/// but this class makes no assumption about what's on the other end of an
/// arbitrary URL).
class DownloadedFile {
  const DownloadedFile({required this.bytes, this.filename, this.mimeType});

  final List<int> bytes;
  final String? filename;
  final String? mimeType;
}
