import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_saas_driver/core/network/api_client.dart';
import 'package:fleet_saas_driver/core/network/api_exception.dart';
import 'package:fleet_saas_driver/features/exercises/data/exercises_api.dart';

class RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int status = 200;
  dynamic payload = <String, dynamic>{'unavailable_reason': 'birth_date_missing', 'exercises': []};
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
      RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(
        jsonEncode({'success': status < 400, 'data': payload, 'message': 'not allowed'}), status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        });
  }
}

void main() {
  late RecordingAdapter adapter;
  late ExercisesApi api;
  setUp(() {
    adapter = RecordingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))..httpClientAdapter = adapter;
    api = ExercisesApi(ApiClient(getToken: () async => 'test-token', dio: dio));
  });
  test('family context and authentication accompany every exercise request', () async {
    await api.forMember(3, 8);
    await api.detail(4, 8);
    adapter.payload = [];
    await api.assignments(3, 8);
    await api.assign(3, 4, 8, {'recurrence_type': 'daily', 'points': 7});
    await api.archive(9, 8);
    expect(adapter.requests.map((r) => r.path), [
      '/family-members/3/exercises',
      '/family-exercises/4',
      '/family-members/3/exercise-assignments',
      '/family-members/3/exercises/4/assign',
      '/family-tasks/9'
    ]);
    for (final r in adapter.requests) {
      expect(r.headers['X-Family-Id'], '8');
      expect(r.headers['Authorization'], 'Bearer test-token');
    }
    expect(adapter.requests.last.data, {'status': 'archived'});
  });
  test('missing birth date remains distinguishable from an empty catalog', () async {
    final result = await api.forMember(3, null);
    expect(result['unavailable_reason'], 'birth_date_missing');
    expect(adapter.requests.single.headers.containsKey('X-Family-Id'), false);
  });
  test('forbidden responses surface the API error instead of showing success', () async {
    adapter.status = 403;
    await expectLater(api.assign(3, 4, 8, {'recurrence_type': 'daily'}),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)));
  });
}
