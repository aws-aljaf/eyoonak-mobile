import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fleet_saas_driver/core/network/api_client.dart';
import 'package:fleet_saas_driver/core/network/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';

/// A hand-rolled Dio adapter (no extra mocking package needed) that
/// returns a canned envelope for every request, so ApiClient's parsing
/// logic is exercised against the EXACT shape documented in
/// documentation/04-api-specification.md section 1 without any real
/// network call.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.statusCode, this.body);

  final int statusCode;
  final Map<String, dynamic> body;

  /// The headers of the most recent request this adapter served — lets
  /// tests assert on what ApiClient actually sent (e.g. a per-request
  /// `X-Family-Id` override) without a full mocking package.
  RequestOptions? lastRequestOptions;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequestOptions = options;

    final bytes = utf8.encode(jsonEncode(body));

    return ResponseBody.fromBytes(bytes, statusCode, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }
}

void main() {
  ApiClient buildClient(int statusCode, Map<String, dynamic> body) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api/v1'));
    dio.httpClientAdapter = _FakeAdapter(statusCode, body);

    return ApiClient(getToken: () async => null, dio: dio, baseUrl: 'https://api.test/api/v1');
  }

  (ApiClient, _FakeAdapter) buildClientWithAdapter(int statusCode, Map<String, dynamic> body) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api/v1'));
    final adapter = _FakeAdapter(statusCode, body);
    dio.httpClientAdapter = adapter;

    return (ApiClient(getToken: () async => null, dio: dio, baseUrl: 'https://api.test/api/v1'), adapter);
  }

  test('a success envelope returns just the data payload', () async {
    final client = buildClient(200, {
      'success': true,
      'message': 'تم بنجاح',
      'data': {'id': 1, 'name': 'Test'},
      'meta': {},
    });

    final data = await client.get('/trips/1');

    expect(data, {'id': 1, 'name': 'Test'});
  });

  test('a paginated success envelope returns data + meta separately', () async {
    final client = buildClient(200, {
      'success': true,
      'message': 'تم بنجاح',
      'data': [
        {'id': 1},
        {'id': 2},
      ],
      'meta': {'current_page': 1, 'last_page': 3, 'per_page': 20, 'total': 45},
    });

    final envelope = await client.getPaginated('/trips');

    expect(envelope.data, hasLength(2));
    expect(envelope.currentPage, 1);
    expect(envelope.lastPage, 3);
    expect(envelope.hasMorePages, isTrue);
  });

  test('a 422 error envelope throws ApiException with parsed field errors', () async {
    final client = buildClient(422, {
      'success': false,
      'message': 'بيانات غير صالحة',
      'errors': {
        'status': ['لا يمكن الانتقال من الحالة الحالية إلى المطلوبة.'],
      },
    });

    await expectLater(
      client.post('/trips/1/status', data: {'status': 'in_transit'}),
      throwsA(
        isA<ApiException>()
            .having((e) => e.isValidation, 'isValidation', isTrue)
            .having((e) => e.statusCode, 'statusCode', 422)
            .having((e) => e.fieldErrors['status'], 'fieldErrors[status]', isNotEmpty),
      ),
    );
  });

  test('a 401 error is surfaced as isUnauthorized', () async {
    final client = buildClient(401, {'success': false, 'message': 'غير مصرح', 'errors': {}});

    await expectLater(
      client.get('/auth/me'),
      throwsA(isA<ApiException>().having((e) => e.isUnauthorized, 'isUnauthorized', isTrue)),
    );
  });

  test('success:false with a 200 status code is still treated as a failure', () async {
    final client = buildClient(200, {'success': false, 'message': 'خطأ منطقي', 'errors': {}});

    await expectLater(
      client.get('/trips/1'),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'خطأ منطقي')),
    );
  });

  test('a per-request header (e.g. X-Family-Id) is sent alongside the injected Authorization header', () async {
    final (client, adapter) = buildClientWithAdapter(200, {
      'success': true,
      'message': 'تم بنجاح',
      'data': [],
      'meta': {},
    });

    await client.get('/family-members', headers: {'X-Family-Id': '7'});

    expect(adapter.lastRequestOptions?.headers['X-Family-Id'], '7');
  });

  test('delete() sends the DELETE method and returns the data payload', () async {
    final (client, adapter) = buildClientWithAdapter(200, {
      'success': true,
      'message': 'تم حذف المنطقة بنجاح',
      'data': {},
      'meta': {},
    });

    final data = await client.delete('/family-geofences/9', headers: {'X-Family-Id': '3'});

    expect(data, {});
    expect(adapter.lastRequestOptions?.method, 'DELETE');
    expect(adapter.lastRequestOptions?.headers['X-Family-Id'], '3');
  });

  test('omitting headers sends no extra header beyond the client defaults', () async {
    final (client, adapter) = buildClientWithAdapter(200, {
      'success': true,
      'message': 'تم بنجاح',
      'data': {'id': 1},
      'meta': {},
    });

    await client.get('/trips/1');

    expect(adapter.lastRequestOptions?.headers.containsKey('X-Family-Id'), isFalse);
  });
}
