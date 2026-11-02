import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';
import 'admin_driver_models.dart';

/// Talks to `DriverController` in full now
/// (backend/app/Http/Controllers/Api/V1/Fleet/DriverController.php) — every
/// method on that controller verified directly (including `DriverPolicy`/
/// both FormRequests' `authorize()`) before building this. `DriverPolicy::
/// viewAny()` requires `drivers.view` — same "the request is the real
/// gate" convention as `AdminVehiclesApi`: `index()`/`show()` never
/// re-check that permission client-side beyond the entry point
/// (`AdminHomeScreen` only ever renders the "السائقون" tile for an account
/// whose `permissions` already include it).
///
/// `branch_id` filter exists on the backend but isn't exposed here yet —
/// same reasoning as `AdminVehiclesApi` leaving out `branch_id`/
/// `vehicle_type_id`: no endpoint anywhere lists a company's branches for
/// a filter dropdown. `status`/`q` (name/phone search) cover what an
/// office user can use without that lookup.
///
/// **`create()`/`update()` deliberately never send `user_id`** — a driver
/// can optionally be linked to an existing `User` account for app login
/// (`Driver.user_id`, verified directly against the model/FormRequests),
/// but there is no endpoint anywhere in this app to list "company users
/// not yet linked to a driver" for a picker, same reasoning `branch_id` is
/// left out above. A driver is simply created/kept unlinked from here; an
/// office admin with `users.edit` can still link the account from the web
/// dashboard if needed. This is unrelated to `UserController` entirely —
/// `DriverController::store()`/`update()` never create or touch `User`
/// rows themselves.
///
/// **Two real gaps discovered here during PR #76, both since fixed
/// server-side (this class needed no changes — the fix lives entirely in
/// `DriverController`)**: (1) `Driver` uses `SoftDeletes`, so `delete()`
/// never physically removes the row — `vehicles.current_driver_id`'s
/// `nullOnDelete()` FK behavior only fires on a hard delete, so
/// `DriverController::destroy()` now clears both
/// `vehicles.current_driver_id` and the driver's own
/// `current_vehicle_id` explicitly (mirroring
/// `VehicleController::assignDriver()`'s own dual-clearing logic) rather
/// than relying on the FK. (2) Unlike `UserController::destroy()`/
/// `suspend()`/`forceLogout()`, nothing in `DriverController` used to
/// revoke the linked `User`'s Sanctum tokens/devices on delete or on a
/// `status` transition to `suspended`/`terminated` — `DriverController`
/// now does this too (`revokeDriverAccountAccess()`, mirroring
/// `UserController::forceLogout()`'s exact token+device pair) on delete
/// and on any `update()` that changes `status` to `suspended` or
/// `terminated`; the vehicle release additionally only happens on
/// `terminated`, not `suspended` (a suspension is presumed temporary).
/// `AdminDriverDetailScreen`'s inline warning before delete about a
/// dangling vehicle assignment is now purely informative (the assignment
/// really is released) rather than a warning about an actual gap.
class AdminDriversApi {
  AdminDriversApi(this._client);

  final ApiClient _client;

  Future<ApiEnvelope> index({
    int page = 1,
    int perPage = 20,
    String? status,
    String? q,
  }) {
    return _client.getPaginated(
      '/drivers',
      query: {
        'page': page,
        'per_page': perPage,
        if (status != null && status.isNotEmpty) 'status': status,
        if (q != null && q.isNotEmpty) 'q': q,
      },
    );
  }

  Future<AdminDriver> show(int driverId) async {
    final data = await _client.get('/drivers/$driverId');

    return AdminDriver.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// `fields` matches `StoreDriverRequest`'s rules exactly (already
  /// snake_case-keyed, `user_id`/`branch_id` deliberately omitted — see
  /// this class's own docblock).
  Future<AdminDriver> create(Map<String, dynamic> fields) async {
    final data = await _client.post('/drivers', data: fields);

    return AdminDriver.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// `fields` matches `UpdateDriverRequest`'s rules — `status` travels
  /// through this same general endpoint (verified directly: there is no
  /// dedicated suspend/reactivate/terminate action for drivers the way
  /// `UserController` has for users), so `AdminDriverFormScreen` treats it
  /// as an ordinary dropdown field, same as `AdminVehicleFormScreen` does
  /// for a vehicle's `status`.
  Future<AdminDriver> update(int driverId, Map<String, dynamic> fields) async {
    final data = await _client.put('/drivers/$driverId', data: fields);

    return AdminDriver.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Soft-deletes the driver (`Driver` uses `SoftDeletes`) but there is no
  /// restore surface anywhere in this API today, so treat it as
  /// irreversible from this app's perspective — same convention as
  /// `AdminUsersApi.delete()`. See this class's own docblock for the two
  /// gaps this leaves open (dangling vehicle assignment, live tokens on a
  /// linked user account).
  Future<void> delete(int driverId) {
    return _client.delete('/drivers/$driverId');
  }
}
