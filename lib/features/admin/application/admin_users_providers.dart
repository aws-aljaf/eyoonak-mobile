import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_envelope.dart';
import '../../auth/data/session_device.dart';
import '../data/admin_user_models.dart';

/// Resets to page 1 whenever this screen is left and reopened
/// (`.autoDispose`) — same reasoning as `adminDriversPageProvider`.
final adminUsersPageProvider = StateProvider.autoDispose<int>((ref) => 1);

/// `null` = "الكل" (no status filter) — one of `userStatusLabels`' keys
/// otherwise.
final adminUsersStatusFilterProvider = StateProvider.autoDispose<String?>((ref) => null);

/// Free-text search — matches `UserController::index()`'s own
/// `name`/`email`/`phone` `LIKE '%{value}%'` match.
final adminUsersSearchFilterProvider = StateProvider.autoDispose<String?>((ref) => null);

final adminUsersProvider = FutureProvider.autoDispose<ApiEnvelope>((ref) async {
  final page = ref.watch(adminUsersPageProvider);
  final status = ref.watch(adminUsersStatusFilterProvider);
  final q = ref.watch(adminUsersSearchFilterProvider);

  return ref.watch(adminUsersApiProvider).index(page: page, status: status, q: q);
});

/// `.family` keyed by user id — same reasoning as `adminDriverDetailProvider`:
/// a fresh fetch per id rather than reusing the list row's summary.
final adminUserDetailProvider = FutureProvider.autoDispose.family<AdminUser, int>((ref, userId) {
  return ref.watch(adminUsersApiProvider).show(userId);
});

/// Backs the "الأجهزة المسجَّلة" section on `AdminUserDetailScreen` — the
/// admin-viewing-another-account counterpart of `sessionDevicesProvider`
/// (which only ever shows the caller's OWN devices).
final adminUserDevicesProvider = FutureProvider.autoDispose.family<List<SessionDevice>, int>((ref, userId) {
  return ref.watch(adminUsersApiProvider).devices(userId);
});
