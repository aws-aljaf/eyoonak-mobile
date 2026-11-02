import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_envelope.dart';
import '../data/admin_role_models.dart';

/// `RoleController::index()` already returns the full (small — one company's
/// custom roles plus the shared system defaults) list unpaginated, so this
/// is a plain `FutureProvider`, not a page-driven one like every other list
/// in this feature.
final adminRolesProvider = FutureProvider.autoDispose<List<AdminRole>>((ref) {
  return ref.watch(adminRolesApiProvider).index();
});

/// `.family` keyed by role id — re-fetches on top of whatever
/// `adminRolesProvider` already has, same reasoning as
/// `adminDriverDetailProvider`: harmless for a resource this small, and
/// keeps this screen resilient to being deep-linked to directly later.
final adminRoleDetailProvider = FutureProvider.autoDispose.family<AdminRole, int>((ref, roleId) {
  return ref.watch(adminRolesApiProvider).show(roleId);
});

/// The full permission catalogue, grouped by module exactly as
/// `PermissionController::index()` returns it — fetched once and reused by
/// every `AdminRoleDetailScreen` visit this session (`.autoDispose` still
/// disposes it once nothing is watching, same as everything else here).
final adminPermissionsCatalogProvider = FutureProvider.autoDispose<Map<String, List<AdminPermission>>>((ref) {
  return ref.watch(adminPermissionsApiProvider).index();
});

/// Page state for `AdminRoleUsersScreen`, keyed per role id so switching
/// between two roles' rosters doesn't share one page number.
final adminRoleUsersPageProvider = StateProvider.autoDispose.family<int, int>((ref, roleId) => 1);

final adminRoleUsersProvider = FutureProvider.autoDispose.family<ApiEnvelope, int>((ref, roleId) {
  final page = ref.watch(adminRoleUsersPageProvider(roleId));

  return ref.watch(adminRolesApiProvider).usersForRole(roleId, page: page);
});
