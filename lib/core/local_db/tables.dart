import 'package:drift/drift.dart';

/// Module 27 — "Offline Queue (SQLite/Drift, UUID-based idempotent sync)".
///
/// Every mutation a driver makes while offline (trip status change, trip
/// cancel, POD upload, SOS) is written here FIRST with a client-generated
/// UUID `id`, then drained by SyncQueueService once connectivity returns.
/// The UUID is what lets the queue safely dedupe a row that's still
/// `pending` from one that already reached `synced` — see
/// SyncQueueService's docblock for the full idempotency reasoning (the
/// backend itself has no generic idempotency-key header; the real safety
/// net for trip-status actions is TripStateMachine rejecting a transition
/// that's no longer valid once it has already been applied once).
class PendingActions extends Table {
  TextColumn get id => text()(); // client-generated UUID v4
  TextColumn get actionType => text()(); // 'trip_status' | 'trip_cancel' | 'pod_upload' | 'sos'
  IntColumn get tripId => integer().nullable()();
  IntColumn get stopId => integer().nullable()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Section 32/module 28 — background GPS points queued exactly the same
/// offline-safe way, then flushed in batches of up to 50 to
/// `POST /locations/batch` (each row's `id` doubles as the `source_uuid`
/// the backend's own migration dedupes on — see documentation/
/// 04-api-specification.md's `/locations` section). That endpoint is
/// Phase 5 scope and doesn't exist server-side yet as of Phase 4 — points
/// simply stay queued (never dropped) until it does; see
/// LocationSyncClient's docblock.
class PendingGpsPoints extends Table {
  TextColumn get id => text()(); // = source_uuid
  IntColumn get tripId => integer().nullable()();
  RealColumn get lat => real()();
  RealColumn get lng => real()();
  RealColumn get speedKph => real().nullable()();
  RealColumn get headingDeg => real().nullable()();
  RealColumn get accuracyM => real().nullable()();
  DateTimeColumn get recordedAt => dateTime()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// A last-known-good local copy of each assigned trip, so the Trip
/// screen still shows something meaningful with no connectivity at all —
/// never blank, never fabricated.
class CachedTrips extends Table {
  IntColumn get tripId => integer()();
  TextColumn get tripJson => text()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {tripId};
}
