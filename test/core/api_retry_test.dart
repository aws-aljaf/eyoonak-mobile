import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_saas_driver/core/network/api_client.dart';
import 'package:fleet_saas_driver/core/network/api_exception.dart';

class FlakyAdapter implements HttpClientAdapter {
  FlakyAdapter(this.failures, {this.status});
  final int failures;
  final int? status;
  int calls = 0;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? body, Future<void>? cancel) async {
    calls++;
    if (calls <= failures) {
      if (status != null) return ResponseBody.fromString('{}', status!, headers: {Headers.contentTypeHeader: ['application/json']});
      throw DioException(requestOptions: options, type: DioExceptionType.connectionTimeout);
    }
    return ResponseBody.fromString(jsonEncode({'success': true, 'data': {'ok': true}}), 200,
      headers: {Headers.contentTypeHeader: ['application/json']});
  }
}
void main() {
  ApiClient client(FlakyAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api/v1'));
    dio.httpClientAdapter = adapter;
    return ApiClient(getToken: () async => null, dio: dio);
  }
  test('GET recovers after two transient failures', () async {
    final adapter = FlakyAdapter(2);
    expect(await client(adapter).get('/items'), {'ok': true});
    expect(adapter.calls, 3);
  });
  test('GET retries are bounded', () async {
    final adapter = FlakyAdapter(99);
    await expectLater(client(adapter).get('/items'), throwsA(isA<ApiException>()));
    expect(adapter.calls, 3);
  });
  test('POST is never replayed', () async {
    final adapter = FlakyAdapter(1);
    await expectLater(client(adapter).post('/items', data: {'name': 'one'}), throwsA(isA<ApiException>()));
    expect(adapter.calls, 1);
  });
  test('unauthorized GET is never replayed', () async {
    final adapter = FlakyAdapter(1, status: 401);
    await expectLater(client(adapter).get('/items'), throwsA(isA<ApiException>()));
    expect(adapter.calls, 1);
  });
}
