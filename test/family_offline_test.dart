import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fleet_saas_driver/core/sync/family_offline.dart';
import 'package:fleet_saas_driver/core/network/api_exception.dart';

const headers = {'X-Family-Id': '7'};
Map<String, dynamic> board() => {
      'success': true,
      'data': [
        {'id': 3, 'status': 'pending'}
      ]
    };
Future<Map<String, dynamic>> down() async =>
    throw const ApiException(message: 'offline');
Future<void> seed(FamilyOffline s) async {
  await s.run('GET', '/family-task-occurrences',
      headers: headers, request: () async => board());
}

Future<Map<String, dynamic>> complete(FamilyOffline s) =>
    s.run('POST', '/family-task-occurrences/3/complete',
        headers: headers, request: down);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('only the same user, family and query may read a cached task board',
      () async {
    final s = FamilyOffline()..setUser(1);
    await seed(s);
    final cached = await s.run('GET', '/family-task-occurrences',
        headers: headers, request: down);
    expect(cached['_offline'], true);
    expect(cached['data'][0]['id'], 3);
    await expectLater(
        s.run('GET', '/family-task-occurrences',
            headers: {'X-Family-Id': '8'}, request: down),
        throwsA(isA<ApiException>()));
    await expectLater(
        s.run('GET', '/family-task-occurrences',
            headers: headers, query: {'date': '2030-01-01'}, request: down),
        throwsA(isA<ApiException>()));
    s.setUser(2);
    await expectLater(
        s.run('GET', '/family-task-occurrences',
            headers: headers, request: down),
        throwsA(isA<ApiException>()));
  });
  test(
      'duplicate completion queues once and never fabricates an awarded status',
      () async {
    final s = FamilyOffline()..setUser(1);
    await seed(s);
    final result = await complete(s);
    await complete(s);
    expect(result['data']['status'], 'pending_sync');
    expect(s.pendingCount, 1);
    final cached = await s.run('GET', '/family-task-occurrences',
        headers: headers, request: down);
    expect(cached['data'][0]['status'], 'pending_sync');
  });
  test('an unknown or uncached occurrence cannot be queued', () async {
    final s = FamilyOffline()..setUser(1);
    await seed(s);
    await expectLater(
        s.run('POST', '/family-task-occurrences/99/complete',
            headers: headers, request: down),
        throwsA(isA<ApiException>()));
    expect(s.pendingCount, 0);
  });
  test(
      'pending completion survives restart but is never replayed for another user',
      () async {
    final s = FamilyOffline()..setUser(1);
    await seed(s);
    await complete(s);
    final restarted = FamilyOffline()..setUser(1);
    var calls = 0;
    await restarted.flush((method, path, {headers}) async {
      calls++;
      return {
        'success': true,
        'data': {'id': 3, 'status': 'approved'}
      };
    });
    expect(calls, 1);
    expect(restarted.pendingCount, 0);
    final cached = await restarted.run('GET', '/family-task-occurrences',
        headers: headers, request: down);
    expect(cached['data'][0]['status'], 'approved');
    s.setUser(2);
    await s.flush((_, __, {headers}) async {
      calls++;
      return {};
    });
    expect(calls, 1);
  });
  test('concurrent flush is single flight; network failure retains the action',
      () async {
    final s = FamilyOffline()..setUser(1);
    await seed(s);
    await complete(s);
    var calls = 0;
    final gate = Completer<Map<String, dynamic>>();
    final f = s.flush((_, __, {headers}) {
      calls++;
      return gate.future;
    });
    await Future<void>.delayed(Duration.zero);
    await s.flush((_, __, {headers}) async {
      calls++;
      return {};
    });
    expect(calls, 1);
    gate.completeError(const ApiException(message: 'offline'));
    await f;
    expect(s.pendingCount, 1);
  });
  test('server denial clears pending private data and reports rejection',
      () async {
    final s = FamilyOffline()..setUser(1);
    await seed(s);
    await complete(s);
    await s.flush((_, __, {headers}) async =>
        throw const ApiException(message: 'not allowed', statusCode: 403));
    expect(s.pendingCount, 0);
    expect(s.snapshots, isEmpty);
    expect(s.syncError, contains('not allowed'));
  });
  test('no cached fallback on authorization or validation errors', () async {
    final s = FamilyOffline()..setUser(1);
    await seed(s);
    await expectLater(
        s.run('GET', '/family-task-occurrences',
            headers: headers,
            request: () async =>
                throw const ApiException(message: 'denied', statusCode: 401)),
        throwsA(isA<ApiException>()));
    expect(s.snapshots, isEmpty);
  });
  test('a late old-session response cannot populate a different user cache',
      () async {
    final s = FamilyOffline()..setUser(1);
    final gate = Completer<Map<String, dynamic>>();
    final f = s.run('GET', '/family-task-occurrences',
        headers: headers, request: () => gate.future);
    await Future<void>.delayed(Duration.zero);
    s.setUser(2);
    gate.complete(board());
    await f;
    expect(s.snapshots, isEmpty);
  });
  test('logout clears the previous user pending cache', () async {
    final s = FamilyOffline()..setUser(1);
    await seed(s);
    await complete(s);
    s.setUser(null);
    s.setUser(1);
    var calls = 0;
    await s.flush((_, __, {headers}) async {
      calls++;
      return {};
    });
    expect(calls, 0);
    expect(s.pendingCount, 0);
  });

  test('expired snapshots are not used and unrelated writes are never queued',
      () async {
    final s = FamilyOffline()..setUser(1);
    await seed(s);
    for (final entry in s.snapshots.values) {
      entry['at'] = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 8))
          .toIso8601String();
    }
    await expectLater(
        s.run('GET', '/family-task-occurrences',
            headers: headers, request: down),
        throwsA(isA<ApiException>()));
    await expectLater(s.run('PUT', '/personal/prayer/record', request: down),
        throwsA(isA<ApiException>()));
    expect(s.pendingCount, 0);
  });
  test(
      'prayer preferences remain locally available with an explicit stale marker',
      () async {
    final s = FamilyOffline()..setUser(1);
    await s.run('GET', '/personal/prayer',
        request: () async => {
              'success': true,
              'data': {
                'date': '2026-11-01',
                'preferences': {'timezone': 'Asia/Baghdad'},
                'records': []
              }
            });
    final cached = await s.run('GET', '/personal/prayer', request: down);
    expect(cached['data']['_offline'], true);
    expect(cached['data']['preferences']['timezone'], 'Asia/Baghdad');
  });
}
