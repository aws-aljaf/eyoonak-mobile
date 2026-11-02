import 'package:uuid/uuid.dart';

import '../../../core/local_db/offline_queue_repository.dart';
import '../../../core/sync/sync_queue_service.dart';

/// A safety feature must never depend on the network being reachable at
/// the exact moment the driver presses SOS — like every other mutation,
/// it's enqueued to the offline queue first (so it survives an app kill
/// or a dead zone) and flushed immediately after.
class SosRepository {
  SosRepository({required OfflineQueueRepository queue, required SyncQueueService syncQueue})
      : _queue = queue,
        _syncQueue = syncQueue;

  final OfflineQueueRepository _queue;
  final SyncQueueService _syncQueue;
  final _uuid = const Uuid();

  Future<void> trigger({required double lat, required double lng, int? tripId, String? message}) async {
    await _queue.enqueueAction(
      id: _uuid.v4(),
      actionType: 'sos',
      tripId: tripId,
      payload: {
        'lat': lat,
        'lng': lng,
        if (message != null) 'message': message,
      },
    );
    await _syncQueue.flush();
  }
}
