import 'dart:convert';

import 'package:drift/drift.dart';

import 'app_database.dart';

/// Every read/write against the offline-queue tables goes through here —
/// SyncQueueService and the feature repositories never touch the
/// generated Drift companions directly.
class OfflineQueueRepository {
  OfflineQueueRepository(this._db);

  final AppDatabase _db;

  Future<void> enqueueAction({
    required String id,
    required String actionType,
    int? tripId,
    int? stopId,
    required Map<String, dynamic> payload,
  }) {
    return _db.into(_db.pendingActions).insertOnConflictUpdate(
          PendingActionsCompanion.insert(
            id: id,
            actionType: actionType,
            tripId: Value(tripId),
            stopId: Value(stopId),
            payloadJson: jsonEncode(payload),
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<List<PendingAction>> pendingActions() {
    return (_db.select(_db.pendingActions)
          ..where((t) => t.status.equals('pending'))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();
  }

  Future<void> markActionSynced(String id) {
    return (_db.update(_db.pendingActions)..where((t) => t.id.equals(id)))
        .write(const PendingActionsCompanion(status: Value('synced')));
  }

  /// `permanentlyFailed` marks a row so it's never retried again (e.g. the
  /// server rejected it with a validation error that will never resolve
  /// itself, like the trip already being cancelled by someone else) —
  /// distinct from a transient failure, which stays `pending` so the next
  /// sync pass retries it.
  Future<void> recordActionFailure(
    String id, {
    required String error,
    required int retryCount,
    required bool permanentlyFailed,
  }) {
    return (_db.update(_db.pendingActions)..where((t) => t.id.equals(id))).write(
      PendingActionsCompanion(
        status: Value(permanentlyFailed ? 'failed' : 'pending'),
        lastError: Value(error),
        retryCount: Value(retryCount),
      ),
    );
  }

  Stream<int> watchPendingCount() {
    final query = _db.select(_db.pendingActions)..where((t) => t.status.equals('pending'));

    return query.watch().map((rows) => rows.length);
  }

  Future<void> enqueueGpsPoint({
    required String id,
    int? tripId,
    required double lat,
    required double lng,
    double? speedKph,
    double? headingDeg,
    double? accuracyM,
    required DateTime recordedAt,
  }) {
    return _db.into(_db.pendingGpsPoints).insertOnConflictUpdate(
          PendingGpsPointsCompanion.insert(
            id: id,
            tripId: Value(tripId),
            lat: lat,
            lng: lng,
            speedKph: Value(speedKph),
            headingDeg: Value(headingDeg),
            accuracyM: Value(accuracyM),
            recordedAt: recordedAt,
          ),
        );
  }

  /// Up to 50 points per call — matches `/locations/batch`'s documented
  /// cap exactly (documentation/04-api-specification.md).
  Future<List<PendingGpsPoint>> unsyncedGpsPointsBatch({int limit = 50}) {
    return (_db.select(_db.pendingGpsPoints)
          ..where((t) => t.synced.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.recordedAt)])
          ..limit(limit))
        .get();
  }

  Future<void> markGpsPointsSynced(List<String> ids) {
    return (_db.update(_db.pendingGpsPoints)..where((t) => t.id.isIn(ids)))
        .write(const PendingGpsPointsCompanion(synced: Value(true)));
  }

  Future<void> cacheTrip(int tripId, Map<String, dynamic> json) {
    return _db.into(_db.cachedTrips).insertOnConflictUpdate(
          CachedTripsCompanion.insert(
            tripId: Value(tripId),
            tripJson: jsonEncode(json),
            cachedAt: DateTime.now(),
          ),
        );
  }

  Future<List<Map<String, dynamic>>> cachedTrips() async {
    final rows = await _db.select(_db.cachedTrips).get();

    return rows.map((r) => Map<String, dynamic>.from(jsonDecode(r.tripJson) as Map)).toList();
  }
}
