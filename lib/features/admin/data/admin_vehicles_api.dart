import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';
import 'admin_vehicle_models.dart';

/// Talks to `VehicleController::index()`/`::show()`
/// (backend/app/Http/Controllers/Api/V1/Fleet/VehicleController.php),
/// verified directly against that controller/`VehiclePolicy`/
/// `VehicleResource` before building this. `VehiclePolicy::viewAny()`
/// requires `vehicles.view` — same "the request is the real gate"
/// convention as every other admin screen in this app: this class never
/// re-checks that permission client-side beyond the entry point
/// (`AdminHomeScreen` only ever renders the "المركبات" tile for an
/// account whose `permissions` already include it).
///
/// `branch_id`/`vehicle_type_id` **filters** on `index()` exist on the
/// backend but aren't exposed here yet — same reasoning as `AuditLogsApi`
/// leaving out `model_type`: this app has no endpoint anywhere that lists a
/// company's branches for a filter dropdown (`vehicle_type_id` itself now
/// has one — `AdminVehicleTypesApi` — but only feeds the create/edit form
/// below, not this list's filter bar, to keep this PR's scope to the write
/// actions the plan actually asked for). `status`/`q` (plate number/brand/
/// model search) cover what an office user can use without that lookup.
///
/// `create()`/`update()`/`delete()`/`assignDriver()` are the write half of
/// this class (`VehicleController::store()`/`::update()`/`::destroy()`/
/// `::assignDriver()`, gated respectively by `vehicles.create`/`edit`/
/// `delete`/`edit` — verified directly against `VehiclePolicy` and each
/// FormRequest's `authorize()` before building this) — deliberately added
/// in the same PR as the read methods above rather than a separate class,
/// unlike `AdminReportsApi`/`AdminReportExportsApi`'s split: here every
/// method gates on a permission that is either the same as `vehicles.view`
/// (which the whole screen already required to load) or a strictly
/// additive one on the *same* entity, not a materially different audience
/// the way `reports.export` was.
class AdminVehiclesApi {
  AdminVehiclesApi(this._client);

  final ApiClient _client;

  Future<ApiEnvelope> index({
    int page = 1,
    int perPage = 20,
    String? status,
    String? q,
  }) {
    return _client.getPaginated(
      '/vehicles',
      query: {
        'page': page,
        'per_page': perPage,
        if (status != null && status.isNotEmpty) 'status': status,
        if (q != null && q.isNotEmpty) 'q': q,
      },
    );
  }

  Future<AdminVehicle> show(int vehicleId) async {
    final data = await _client.get('/vehicles/$vehicleId');

    return AdminVehicle.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// `fields` is whatever subset of `StoreVehicleRequest`'s rules the form
  /// collected (already snake_case-keyed, matching the API directly — see
  /// `AdminVehicleFormScreen._buildPayload()`) — kept as a plain map here
  /// rather than a bespoke "new vehicle" model, since the create and edit
  /// forms share one builder and the backend itself accepts a plain
  /// key/value body.
  Future<AdminVehicle> create(Map<String, dynamic> fields) async {
    final data = await _client.post('/vehicles', data: fields);

    return AdminVehicle.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<AdminVehicle> update(int vehicleId, Map<String, dynamic> fields) async {
    final data = await _client.put('/vehicles/$vehicleId', data: fields);

    return AdminVehicle.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> delete(int vehicleId) {
    return _client.delete('/vehicles/$vehicleId');
  }

  /// `driverId == null` unassigns whoever currently drives this vehicle —
  /// mirrors `AssignDriverRequest`'s own `driver_id` rule (`nullable`)
  /// exactly, verified directly against that FormRequest before building
  /// this.
  Future<AdminVehicle> assignDriver(int vehicleId, int? driverId) async {
    final data = await _client.post('/vehicles/$vehicleId/assign-driver', data: {'driver_id': driverId});

    return AdminVehicle.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
