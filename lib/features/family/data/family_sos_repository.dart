import 'package:uuid/uuid.dart';

import '../../../core/local_db/offline_queue_repository.dart';
import '../../../core/sync/sync_queue_service.dart';

/// Mirrors `SosRepository` (lib/features/sos/data/sos_repository.dart) —
/// same "queue first, flush immediately" safety reasoning: a family SOS
/// press must survive a dead zone or a killed app exactly like a driver's
/// SOS does, so it goes through the offline queue rather than a bare API
/// call. `family_member_id`/`family_id` ride inside the JSON payload
/// rather than as dedicated `PendingActions` columns (unlike `trip_id`) —
/// OfflineQueueRepository's payload column is a free-form JSON blob for
/// exactly this reason, so this needed no schema migration.
class FamilySosRepository {
  FamilySosRepository({required OfflineQueueRepository queue, required SyncQueueService syncQueue})
      : _queue = queue,
        _syncQueue = syncQueue;

  final OfflineQueueRepository _queue;
  final SyncQueueService _syncQueue;
  final _uuid = const Uuid();

  Future<void> trigger({
    required int familyMemberId,
    required double lat,
    required double lng,
    int? batteryLevel,
    int? familyId,
  }) async {
    await _queue.enqueueAction(
      id: _uuid.v4(),
      actionType: 'family_sos',
      payload: {
        'family_member_id': familyMemberId,
        'lat': lat,
        'lng': lng,
        if (batteryLevel != null) 'battery_level': batteryLevel,
        if (familyId != null) 'family_id': familyId,
      },
    );
    await _syncQueue.flush();
  }
}
