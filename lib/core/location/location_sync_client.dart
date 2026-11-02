import '../local_db/offline_queue_repository.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';

/// Flushes queued GPS points to `POST /locations/batch` (section 32,
/// module 32) in batches of up to 50 — the exact cap documented in
/// documentation/04-api-specification.md, which also documents
/// `source_uuid` per point as the server-side dedup key; this class sends
/// each `PendingGpsPoint.id` as exactly that.
///
/// IMPORTANT: `/locations/batch` is Phase 5 (Live Tracking) scope and
/// does not exist on the backend yet as of Phase 4 — every call here will
/// 404 until Phase 5 ships. That is expected and safe: `flush()` simply
/// leaves points queued (never marks them synced, never drops them) on
/// any failure, so the very first successful flush after Phase 5 lands
/// drains the full backlog with no code change needed on this side.
class LocationSyncClient {
  LocationSyncClient({required OfflineQueueRepository queue, required ApiClient client})
      : _queue = queue,
        _client = client;

  final OfflineQueueRepository _queue;
  final ApiClient _client;

  Future<void> flush() async {
    while (true) {
      final batch = await _queue.unsyncedGpsPointsBatch();

      if (batch.isEmpty) {
        return;
      }

      try {
        await _client.post('/locations/batch', data: {
          'points': batch
              .map((p) => {
                    'source_uuid': p.id,
                    'trip_id': p.tripId,
                    'lat': p.lat,
                    'lng': p.lng,
                    'speed_kph': p.speedKph,
                    'heading_deg': p.headingDeg,
                    'accuracy_m': p.accuracyM,
                    'recorded_at': p.recordedAt.toIso8601String(),
                  })
              .toList(),
        });

        await _queue.markGpsPointsSynced(batch.map((p) => p.id).toList());
      } on ApiException {
        // See docblock — stays queued, retried on the next flush() call.
        return;
      }
    }
  }
}
