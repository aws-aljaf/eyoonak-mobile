import 'package:drift/native.dart';
import 'package:fleet_saas_driver/core/local_db/app_database.dart';
import 'package:fleet_saas_driver/core/local_db/offline_queue_repository.dart';
import 'package:fleet_saas_driver/core/network/api_exception.dart';
import 'package:fleet_saas_driver/core/sync/sync_queue_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late OfflineQueueRepository queue;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    queue = OfflineQueueRepository(db);
  });

  tearDown(() => db.close());

  test('a successful handler call marks the action synced', () async {
    await queue.enqueueAction(id: 'a', actionType: 'trip_status', tripId: 1, payload: {'status': 'accepted'});

    final service = SyncQueueService(queue: queue, handlers: {
      'trip_status': (action) async {},
    });

    await service.flush();

    expect(await queue.pendingActions(), isEmpty);
  });

  test(
      'a 422 (validation) response is treated as "already applied" and permanently '
      'stops retrying — the TripStateMachine-rejection safety net', () async {
    await queue.enqueueAction(id: 'a', actionType: 'trip_status', tripId: 1, payload: {'status': 'accepted'});

    final service = SyncQueueService(queue: queue, handlers: {
      'trip_status': (action) async {
        throw const ApiException(message: 'لا يمكن الانتقال', statusCode: 422);
      },
    });

    await service.flush();

    // Not pending (it was resolved as permanently failed), and not
    // silently retried forever.
    expect(await queue.pendingActions(), isEmpty);
  });

  test('a transient failure (e.g. network) keeps the action pending and stops the pass', () async {
    await queue.enqueueAction(id: 'a', actionType: 'trip_status', tripId: 1, payload: {});
    await queue.enqueueAction(id: 'b', actionType: 'trip_status', tripId: 1, payload: {});

    var callCount = 0;
    final service = SyncQueueService(queue: queue, handlers: {
      'trip_status': (action) async {
        callCount++;
        throw const ApiException(message: 'network error');
      },
    });

    await service.flush();

    final pending = await queue.pendingActions();
    expect(pending.map((a) => a.id), ['a', 'b']);
    expect(pending.first.retryCount, 1);
    // Only the FIRST action was attempted — the pass stops rather than
    // skipping ahead to a later action on the same trip out of order.
    expect(callCount, 1);
  });

  test('an action reaches permanentlyFailed once retryCount hits maxRetries', () async {
    await queue.enqueueAction(id: 'a', actionType: 'trip_status', tripId: 1, payload: {});

    final service = SyncQueueService(
      queue: queue,
      maxRetries: 2,
      handlers: {
        'trip_status': (action) async {
          throw const ApiException(message: 'server error', statusCode: 500);
        },
      },
    );

    await service.flush(); // retryCount -> 1, still pending
    expect((await queue.pendingActions()).single.retryCount, 1);

    await service.flush(); // retryCount -> 2 == maxRetries, now permanently failed
    expect(await queue.pendingActions(), isEmpty);
  });

  test('an unknown actionType is marked permanently failed instead of looping forever', () async {
    await queue.enqueueAction(id: 'a', actionType: 'some_future_action', payload: {});

    final service = SyncQueueService(queue: queue, handlers: const {});

    await service.flush();

    expect(await queue.pendingActions(), isEmpty);
  });

  test('two sequential flush() calls each process independently once the blocker syncs', () async {
    await queue.enqueueAction(id: 'a', actionType: 'trip_status', tripId: 1, payload: {'status': 'accepted'});
    await queue.enqueueAction(id: 'b', actionType: 'trip_status', tripId: 1, payload: {'status': 'loading'});

    var succeedNow = false;
    final service = SyncQueueService(queue: queue, handlers: {
      'trip_status': (action) async {
        if (!succeedNow) {
          throw const ApiException(message: 'offline');
        }
      },
    });

    await service.flush();
    expect(await queue.pendingActions(), hasLength(2)); // both still queued, pass stopped at 'a'

    succeedNow = true;
    await service.flush();
    expect(await queue.pendingActions(), isEmpty); // both drain once the network is back
  });
}
