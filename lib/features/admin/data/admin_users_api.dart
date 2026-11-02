import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';
import '../../auth/data/session_device.dart';
import 'admin_user_models.dart';

/// Talks to `UserController` in full now
/// (backend/app/Http/Controllers/Api/V1/UserController.php) — every method
/// on that controller verified directly (including `UserPolicy`/each
/// FormRequest's `authorize()`) before building this. `UserPolicy::viewAny()`
/// requires `users.view` — same "the request is the real gate" convention as
/// every other admin API class in this feature: `index()`/`show()`/
/// `devices()` never re-check that permission client-side beyond the entry
/// point (`AdminHomeScreen` only ever renders the "المستخدمون" tile for an
/// account whose `permissions` already include it).
///
/// **The write methods below (`create`/`update`/`delete`/`assignRoles`/
/// `resetPassword`/`suspend`/`reactivate`/`forceLogout`) are the highest-
/// sensitivity slice of the whole admin-unification initiative** (see
/// `claude/admin-unification-plan.md`'s phased plan) — each gates on its own
/// permission (`users.create`/`edit`/`delete`/`manage_status`/`force_logout`,
/// verified one-by-one against `UserPolicy`), and three of them
/// (`delete`/`suspend`&`reactivate`/`forceLogout`) are blocked server-side
/// for the caller acting on their own account (`UserPolicy`: `id !==
/// target.id`). `AdminUserDetailScreen` also hides those specific actions
/// entirely when viewing the caller's own profile — defense-in-depth for a
/// cleaner UX (avoiding a confusing 403), not a substitute for the real
/// server-side check. `assignRoles`/`update`(`status`)/`resetPassword` carry
/// NO such self-exclusion on the backend at all (verified directly — this is
/// a genuine gap in `UserPolicy`, not an oversight in this class): `update()`
/// deliberately never sends a `status` field at all (suspend/reactivate are
/// the only path to change it, so the self-suspend gap in the general edit
/// endpoint is never reachable from this app), and `AdminUserDetailScreen`
/// shows an explicit self-edit warning before `assignRoles` and hides
/// `resetPassword` for self (revoking your own tokens mid-session would just
/// log the caller out).
class AdminUsersApi {
  AdminUsersApi(this._client);

  final ApiClient _client;

  /// `branch_id` is a real server-side filter too
  /// (`UserController::index()`) but isn't exposed here — same reasoning
  /// `AdminVehiclesApi`/`AdminDriversApi` already documented: no endpoint
  /// anywhere lists a company's branches for a filter dropdown yet.
  /// `status`/`q` (name/email/phone search) cover what an office user can
  /// use without that lookup.
  Future<ApiEnvelope> index({
    int page = 1,
    int perPage = 20,
    String? status,
    String? q,
  }) {
    return _client.getPaginated(
      '/users',
      query: {
        'page': page,
        'per_page': perPage,
        if (status != null && status.isNotEmpty) 'status': status,
        if (q != null && q.isNotEmpty) 'q': q,
      },
    );
  }

  Future<AdminUser> show(int userId) async {
    final data = await _client.get('/users/$userId');

    return AdminUser.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// `GET /users/{user}/devices` — `UserPolicy::viewDevices()` is a plain
  /// alias of `view()` (self, or `users.view` + same company), so an
  /// office account with `users.view` sees this exactly like it sees the
  /// rest of the profile. Reuses `SessionDevice` (the same model
  /// `features/auth/data/session_device.dart` already parses `GET
  /// /auth/devices` into) rather than a duplicate admin-only class, since
  /// `DeviceResource` is the identical shape either way — same
  /// reuse-over-duplication call as `AdminTripDetailScreen` reusing
  /// `tripDetailProvider` in PR #57.
  Future<List<SessionDevice>> devices(int userId) async {
    final data = await _client.get('/users/$userId/devices');

    return (data as List).map((e) => SessionDevice.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// `fields` matches `StoreUserRequest`'s rules exactly (already
  /// snake_case-keyed) — `role_ids` is `sometimes`/optional there, so
  /// `AdminUserFormScreen` omits the key entirely when nothing was picked
  /// rather than sending an empty array (an empty array is meaningful on
  /// `assignRoles` below — "strip all roles" — but `store()` simply treats
  /// an absent key as "no roles yet", so the two must not be conflated).
  Future<AdminUser> create(Map<String, dynamic> fields) async {
    final data = await _client.post('/users', data: fields);

    return AdminUser.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// `fields` matches `UpdateUserRequest`'s rules — deliberately never
  /// includes `status` (see this class's own docblock) or `password`/
  /// `role_ids` (neither field exists on this FormRequest at all; those go
  /// through `resetPassword()`/`assignRoles()` below instead).
  Future<AdminUser> update(int userId, Map<String, dynamic> fields) async {
    final data = await _client.put('/users/$userId', data: fields);

    return AdminUser.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Soft-deletes the account (`User` uses `SoftDeletes` — verified directly
  /// against the model) but there is no restore surface anywhere in this API
  /// today, so treat it as irreversible from this app's perspective.
  Future<void> delete(int userId) {
    return _client.delete('/users/$userId');
  }

  /// `roleIds` replaces the user's ENTIRE role set (`AssignRolesRequest` +
  /// `sync()` server-side, not attach/detach) — an empty list is valid and
  /// strips every role, so `AdminUserAssignRolesScreen` confirms explicitly
  /// before sending one.
  Future<AdminUser> assignRoles(int userId, List<int> roleIds) async {
    final data = await _client.post('/users/$userId/roles', data: {'role_ids': roleIds});

    return AdminUser.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Returns the new plaintext temporary password — `UserController::
  /// resetPassword()` hands it back exactly once in this response body (no
  /// SMS/email delivery wired yet, by explicit design comment on that
  /// method), and also revokes every existing token for the target account.
  /// The caller must show/let the admin copy it immediately; it can never be
  /// retrieved again after this call returns.
  Future<String> resetPassword(int userId) async {
    final data = await _client.post('/users/$userId/reset-password');

    return Map<String, dynamic>.from(data as Map)['temporary_password'] as String;
  }

  /// Sets `status = suspended`. Does **not** revoke the account's existing
  /// tokens/devices on its own (verified directly against
  /// `UserController::suspend()`) — pair with `forceLogout()` below for an
  /// immediate kick, otherwise a suspended user stays signed in on any
  /// device until their token naturally expires or an admin force-logs them
  /// out separately.
  Future<AdminUser> suspend(int userId) async {
    final data = await _client.post('/users/$userId/suspend');

    return AdminUser.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<AdminUser> reactivate(int userId) async {
    final data = await _client.post('/users/$userId/reactivate');

    return AdminUser.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Revokes every Sanctum token AND marks every `Device` row `is_revoked`
  /// for this account — a real "kick everywhere," per
  /// `UserController::forceLogout()`'s own docblock.
  Future<void> forceLogout(int userId) {
    return _client.post('/users/$userId/force-logout');
  }
}
