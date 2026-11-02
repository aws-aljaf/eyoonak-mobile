import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';
import 'admin_role_models.dart';

/// Talks to `RoleController` in full now
/// (backend/app/Http/Controllers/Api/V1/RoleController.php), verified
/// directly against that controller/`RolePolicy`/both role FormRequests
/// before building this. `RolePolicy::viewAny()`/`::view()` both require
/// `settings.manage` — same "the request is the real gate" convention as
/// every other admin API class in this feature.
///
/// **The write methods below (`create`/`update`/`delete`) are the last,
/// most-sensitive slice of the whole admin-unification initiative** — role
/// write actions were deliberately deferred at PR #75's scoping decision
/// because they can grant/revoke permissions, not just edit one entity's own
/// fields (see `claude/admin-unification-plan.md`'s phased plan). Both
/// `store()` and `update()` accept `permission_ids` directly and `sync()`
/// them **in the same DB transaction** as the name/description fields
/// (verified directly against `RoleController`) — unlike a user's roles
/// (`assignRoles()`, a separate endpoint/screen entirely), a role's own
/// permission set is edited as part of the same save as its basic fields,
/// so `create()`/`update()` below always carry `permission_ids` together
/// with the rest of the payload.
///
/// `RolePolicy::update()`/`::delete()` both hard-require `company_id !==
/// null` (i.e. `role.isEditable`) — the shared system-default templates
/// (`company_id == null`) can never be mutated via this API by anyone,
/// verified directly, no super-admin bypass exists on those two abilities.
/// `delete()` additionally requires `!is_system_default`. **No "in use"
/// guard exists server-side at all** — `role_permissions`/`user_roles` both
/// cascade-delete, so removing a role silently strips it from every user
/// who held it; there is no "restrict if referenced" precedent anywhere
/// else in this codebase to copy (verified directly), so the only
/// mitigation is a client-side confirmation warning — see
/// `AdminRoleDetailScreen`'s delete dialog.
///
/// `usersForRole()` reuses `AdminUser.fromJson` directly — `RoleController
/// ::usersForRole()` returns `UserResource::collection()`, the identical
/// shape `AdminUsersApi` already parses, so no separate model is needed
/// (same reuse call as `AdminUsersApi.devices()` reusing `SessionDevice`).
class AdminRolesApi {
  AdminRolesApi(this._client);

  final ApiClient _client;

  Future<List<AdminRole>> index() async {
    final data = await _client.get('/roles');

    return (data as List).map((e) => AdminRole.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<AdminRole> show(int roleId) async {
    final data = await _client.get('/roles/$roleId');

    return AdminRole.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<ApiEnvelope> usersForRole(int roleId, {int page = 1, int perPage = 20}) {
    return _client.getPaginated('/roles/$roleId/users', query: {'page': page, 'per_page': perPage});
  }

  /// `fields` matches `StoreRoleRequest`'s rules exactly (already
  /// snake_case-keyed) — `company_id`/`is_system_default` are never sent
  /// (`RoleController::store()` forces `company_id = $request->user()
  /// ->company_id` and `is_system_default = false` unconditionally, so a
  /// newly created role is always this company's own, never a shared
  /// template).
  Future<AdminRole> create(Map<String, dynamic> fields) async {
    final data = await _client.post('/roles', data: fields);

    return AdminRole.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// `fields` matches `UpdateRoleRequest`'s rules — deliberately never
  /// includes `slug` (the FormRequest has no rule for it at all; the field
  /// is immutable after creation, verified directly).
  Future<AdminRole> update(int roleId, Map<String, dynamic> fields) async {
    final data = await _client.put('/roles/$roleId', data: fields);

    return AdminRole.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Hard-deletes the role (`Role` has no `SoftDeletes` — verified directly
  /// against the model) — irreversible, and cascades `role_permissions`/
  /// `user_roles` rows for every user who held it. See this class's own
  /// docblock for why there is no "in use" guard to rely on.
  Future<void> delete(int roleId) {
    return _client.delete('/roles/$roleId');
  }
}

/// Talks to `PermissionController::index()`
/// (backend/app/Http/Controllers/Api/V1/PermissionController.php) —
/// verified directly before building this. Gated by the same
/// `settings.manage` check as managing roles (`$this->authorize('viewAny',
/// \App\Models\Role::class)` — the controller's own comment notes this is
/// intentional, not an oversight). Response is grouped by `module` server-
/// side (`Permission::query()->...->groupBy('module')`), so this parses
/// directly into that same `Map<String, List<AdminPermission>>` shape
/// rather than flattening it — `AdminRoleDetailScreen` renders one section
/// per module in exactly this order.
class AdminPermissionsApi {
  AdminPermissionsApi(this._client);

  final ApiClient _client;

  Future<Map<String, List<AdminPermission>>> index() async {
    final data = await _client.get('/permissions');
    final grouped = Map<String, dynamic>.from(data as Map);

    return grouped.map((module, list) {
      final permissions = (list as List)
          .map((e) => AdminPermission.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      return MapEntry(module, permissions);
    });
  }
}
