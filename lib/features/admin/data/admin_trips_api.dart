import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';
import '../../trips/data/trip_models.dart';

/// Talks to `TripController::index()`
/// (backend/app/Http/Controllers/Api/V1/Trips/TripController.php),
/// verified directly against that controller/`TripPolicy`/`TripResource`
/// before building this. `TripPolicy::viewAny()` requires `trips.view` —
/// same "the request is the real gate" convention as every other admin
/// API class: this app never re-checks that permission client-side beyond
/// the entry point (`AdminHomeScreen`'s "إدارة الرحلات" tile).
///
/// Deliberately **not** `TripsApi.myTrips()` from `features/trips/data` —
/// that method always forces a `driver_id` filter (module 26's "my own
/// trips only" self-service view). This class calls the same `/trips`
/// endpoint with no forced filter, matching the web dashboard's company-
/// wide trip list. `driver_id`/`vehicle_id` filters exist on the backend
/// but aren't exposed here yet, same reasoning as `AdminVehiclesApi`/
/// `AdminDriversApi` leaving out ids that would need another lookup
/// endpoint this app doesn't have — `status`/`date_from`/`date_to` cover
/// what an office user can use without one.
///
/// Trip **detail** deliberately reuses `tripDetailProvider`/
/// `tripEventsProvider` from `features/trips/application/trips_providers.dart`
/// rather than a new admin-only fetch: both already call the plain
/// `TripController::show()`/`::events()` by id with no driver-scoping of
/// their own (verified directly — `TripsRepository.tripDetail()` and
/// `TripsApi.events()` take only a bare `tripId`), so there is nothing
/// admin-specific to add for reading a single trip.
///
/// **`create()`/`update()`/`cancel()` are the write half of this class**
/// (`TripController::store()`/`::update()`/`::cancel()`, gated
/// respectively by `trips.create`/`trips.edit`/`trips.cancel` — verified
/// directly against `TripPolicy` and each FormRequest's `authorize()`
/// before building this).
///
/// **Deliberately no `delete()`** — `TripPolicy` has no `delete` ability
/// and the route is declared `Route::apiResource('trips',
/// TripController::class)->except(['destroy'])` (verified directly in
/// `routes/api_v1.php`), the same treatment given to `shipments`/
/// `accidents` in that file. Trips, shipments, and accidents are a
/// deliberate "no hard delete, cancel-only lifecycle end" trio —
/// `cancel()` is the correct destructive action here, not a `DELETE` call.
///
/// **`update()` is only reachable while a trip is still `draft`/
/// `assigned`/`accepted`** — `UpdateTripRequest::withValidator` rejects the
/// entire request once status moves past `accepted` (verified directly;
/// see `Trip.isCoreEditable`, which mirrors this exactly). `status` itself
/// can never be set through `create()`/`update()` — the backend forces
/// `status: 'draft'` on `store()` unconditionally and `UpdateTripRequest`
/// has no `status` rule at all. Changing status is `POST
/// /trips/{id}/status` (module 26's own `TripsApi.updateStatus()`), a
/// separate state-machine action this admin surface deliberately does not
/// add — office staff creating/editing/cancelling trips is this PR's
/// scope, not re-implementing the state-machine UI `TripDetailScreen`
/// already gives drivers for their own trips.
///
/// **`create()`'s `fields` may include a `stops` array** (matches
/// `StoreTripRequest`'s own `stops.*.address`/`contact_name`/
/// `contact_phone` rules — `sequence_no` is never sent, the backend derives
/// it from array order). **`update()`'s `fields` must never include
/// `stops`** — `UpdateTripRequest` has no `stops` rule at all (stops are
/// create-only; there is no endpoint to edit/add/remove a stop afterward,
/// only `uploadPod()` to mark one complete) — `AdminTripFormScreen` only
/// renders the stops editor in create mode for exactly this reason.
class AdminTripsApi {
  AdminTripsApi(this._client);

  final ApiClient _client;

  Future<ApiEnvelope> index({
    int page = 1,
    int perPage = 20,
    String? status,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    return _client.getPaginated(
      '/trips',
      query: {
        'page': page,
        'per_page': perPage,
        if (status != null && status.isNotEmpty) 'status': status,
        if (dateFrom != null) 'date_from': _formatDate(dateFrom),
        if (dateTo != null) 'date_to': _formatDate(dateTo),
      },
    );
  }

  /// `fields` matches `StoreTripRequest`'s rules exactly (already
  /// snake_case-keyed, `customer_id` deliberately omitted — no endpoint
  /// anywhere in this app lists a company's customers for a picker, same
  /// reasoning `branch_id`/`user_id` are left out of the vehicle/driver
  /// forms).
  Future<Trip> create(Map<String, dynamic> fields) async {
    final data = await _client.post('/trips', data: fields);

    return Trip.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// `fields` matches `UpdateTripRequest`'s rules — see this class's own
  /// docblock for why `stops`/`status` must never be included.
  Future<Trip> update(int tripId, Map<String, dynamic> fields) async {
    final data = await _client.put('/trips/$tripId', data: fields);

    return Trip.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// `reason` matches `CancelTripRequest`'s own nullable `reason` field.
  /// The backend re-validates `TripStateMachine::canCancel()` at call time
  /// regardless of `Trip.canCancel` — that field is only ever a
  /// point-in-time hint for the UI, same "the request is the real gate"
  /// convention as everywhere else in this app.
  Future<Trip> cancel(int tripId, {String? reason}) async {
    final data = await _client.post('/trips/$tripId/cancel', data: {'reason': reason});

    return Trip.fromJson(Map<String, dynamic>.from(data as Map));
  }

  // Same manual `YYYY-MM-DD` formatting as `AuditLogsApi` — no `intl`
  // dependency in this app.
  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');

    return '$y-$m-$d';
  }
}
