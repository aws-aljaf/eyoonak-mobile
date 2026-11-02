import 'package:uuid/uuid.dart';

import '../../../core/local_db/offline_queue_repository.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/sync/sync_queue_service.dart';
import 'trip_models.dart';
import 'trips_api.dart';

/// The single place trip screens read from and write through. Reads
/// prefer the real API and fall back to the local cache only when it
/// fails (module 27's "offline viewing" — never a blank screen with no
/// connectivity). Every write is enqueued to the offline queue and then
/// flushed immediately — see SyncQueueService's docblock for why mutation
/// screens never call TripsApi directly.
class TripsRepository {
  TripsRepository({
    required TripsApi api,
    required OfflineQueueRepository queue,
    required SyncQueueService syncQueue,
  })  : _api = api,
        _queue = queue,
        _syncQueue = syncQueue;

  final TripsApi _api;
  final OfflineQueueRepository _queue;
  final SyncQueueService _syncQueue;
  final _uuid = const Uuid();

  Future<List<Trip>> myTrips({required int driverId, String? status}) async {
    try {
      final envelope = await _api.myTrips(driverId: driverId, status: status);
      final trips = envelope.data.map((e) => Trip.fromJson(Map<String, dynamic>.from(e as Map))).toList();

      for (final json in envelope.data) {
        await _queue.cacheTrip((json as Map)['id'] as int, Map<String, dynamic>.from(json));
      }

      return trips;
    } on ApiException {
      final cached = await _queue.cachedTrips();
      final trips = cached.map(Trip.fromJson).toList();

      if (status != null) {
        return trips.where((t) => t.status == status).toList();
      }

      return trips;
    }
  }

  Future<Trip> tripDetail(int tripId) async {
    try {
      final json = await _api.show(tripId);
      await _queue.cacheTrip(tripId, json);

      return Trip.fromJson(json);
    } on ApiException {
      final cached = await _queue.cachedTrips();
      final match = cached.where((t) => t['id'] == tripId);

      if (match.isEmpty) {
        rethrow;
      }

      return Trip.fromJson(match.first);
    }
  }

  Future<void> updateStatus(int tripId, {required String status, double? lat, double? lng, String? notes}) async {
    await _queue.enqueueAction(
      id: _uuid.v4(),
      actionType: 'trip_status',
      tripId: tripId,
      payload: {
        'status': status,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (notes != null) 'notes': notes,
      },
    );
    await _syncQueue.flush();
  }

  Future<void> cancel(int tripId, {String? reason}) async {
    await _queue.enqueueAction(
      id: _uuid.v4(),
      actionType: 'trip_cancel',
      tripId: tripId,
      payload: {if (reason != null) 'reason': reason},
    );
    await _syncQueue.flush();
  }

  Future<void> uploadPod(
    int tripId,
    int stopId, {
    required String receiverName,
    String? receiverPhone,
    required double lat,
    required double lng,
    String? notes,
    String? signaturePath,
    List<String> photoPaths = const [],
  }) async {
    await _queue.enqueueAction(
      id: _uuid.v4(),
      actionType: 'pod_upload',
      tripId: tripId,
      stopId: stopId,
      payload: {
        'receiver_name': receiverName,
        if (receiverPhone != null) 'receiver_phone': receiverPhone,
        'lat': lat,
        'lng': lng,
        if (notes != null) 'notes': notes,
        if (signaturePath != null) 'signature_path': signaturePath,
        'photo_paths': photoPaths,
      },
    );
    await _syncQueue.flush();
  }

  /// Exposed for the "pending changes" badge on the dashboard.
  Stream<int> watchPendingActionCount() => _queue.watchPendingCount();

  TripsApi get api => _api;
}
