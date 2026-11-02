import 'package:drift/native.dart';
import 'package:fleet_saas_driver/core/local_db/app_database.dart';
import 'package:fleet_saas_driver/core/local_db/offline_queue_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late OfflineQueueRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = OfflineQueueRepository(db);
  });

  tearDown(() => db.close());

  group('pending actions', () {
    test('an enqueued action is returned as pending in creation order', () async {
      await repo.enqueueAction(id: 'a', actionType: 'trip_status', tripId: 1, payload: {'status': 'accepted'});
      await repo.enqueueAction(id: 'b', actionType: 'trip_status', tripId: 1, payload: {'status': 'loading'});

      final pending = await repo.pendingActions();

      expect(pending.map((a) => a.id), ['a', 'b']);
      expect(pending.first.status, 'pending');
      expect(pending.first.payloadJson, contains('accepted'));
    });

    test('marking an action synced removes it from the pending list', () async {
      await repo.enqueueAction(id: 'a', actionType: 'sos', payload: {'lat': 1.0, 'lng': 2.0});

      await repo.markActionSynced('a');

      expect(await repo.pendingActions(), isEmpty);
    });

    test('a permanent failure removes it from pending, a transient one keeps it pending for retry', () async {
      await repo.enqueueAction(id: 'a', actionType: 'trip_status', payload: {});
      await repo.enqueueAction(id: 'b', actionType: 'trip_status', payload: {});

      await repo.recordActionFailure('a', error: 'validation failed', retryCount: 1, permanentlyFailed: true);
      await repo.recordActionFailure('b', error: 'network blip', retryCount: 1, permanentlyFailed: false);

      final pending = await repo.pendingActions();

      expect(pending.map((a) => a.id), ['b']);
      expect(pending.first.retryCount, 1);
      expect(pending.first.lastError, 'network blip');
    });
  });

  group('gps points', () {
    test('unsyncedGpsPointsBatch respects the 50-point cap and creation order', () async {
      for (var i = 0; i < 3; i++) {
        await repo.enqueueGpsPoint(
          id: 'p$i',
          tripId: 7,
          lat: 33.0 + i,
          lng: 44.0 + i,
          recordedAt: DateTime(2026, 1, 1, 0, i),
        );
      }

      final batch = await repo.unsyncedGpsPointsBatch(limit: 2);

      expect(batch.map((p) => p.id), ['p0', 'p1']);
    });

    test('marking points synced excludes them from the next batch', () async {
      await repo.enqueueGpsPoint(id: 'p0', lat: 1, lng: 1, recordedAt: DateTime(2026));
      await repo.enqueueGpsPoint(id: 'p1', lat: 2, lng: 2, recordedAt: DateTime(2026));

      await repo.markGpsPointsSynced(['p0']);

      final remaining = await repo.unsyncedGpsPointsBatch();

      expect(remaining.map((p) => p.id), ['p1']);
    });
  });

  group('trip cache', () {
    test('a cached trip round-trips through jsonEncode/decode', () async {
      await repo.cacheTrip(42, {'id': 42, 'status': 'in_transit', 'trip_number': 'TRP-1'});

      final cached = await repo.cachedTrips();

      expect(cached, hasLength(1));
      expect(cached.first['status'], 'in_transit');
    });

    test('caching the same trip id twice overwrites rather than duplicates', () async {
      await repo.cacheTrip(42, {'id': 42, 'status': 'draft'});
      await repo.cacheTrip(42, {'id': 42, 'status': 'assigned'});

      final cached = await repo.cachedTrips();

      expect(cached, hasLength(1));
      expect(cached.first['status'], 'assigned');
    });
  });
}
