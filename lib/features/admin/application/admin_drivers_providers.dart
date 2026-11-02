import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_envelope.dart';
import '../data/admin_driver_models.dart';

/// Resets to page 1 whenever this screen is left and reopened
/// (`.autoDispose`) — same reasoning as `adminVehiclesPageProvider`.
final adminDriversPageProvider = StateProvider.autoDispose<int>((ref) => 1);

/// `null` = "الكل" (no status filter) — one of `driverStatusLabels`' keys
/// otherwise.
final adminDriversStatusFilterProvider = StateProvider.autoDispose<String?>((ref) => null);

/// Free-text search — matches `DriverController::index()`'s own
/// `full_name`/`phone` `LIKE '%{value}%'` match.
final adminDriversSearchFilterProvider = StateProvider.autoDispose<String?>((ref) => null);

final adminDriversProvider = FutureProvider.autoDispose<ApiEnvelope>((ref) async {
  final page = ref.watch(adminDriversPageProvider);
  final status = ref.watch(adminDriversStatusFilterProvider);
  final q = ref.watch(adminDriversSearchFilterProvider);

  return ref.watch(adminDriversApiProvider).index(page: page, status: status, q: q);
});

/// `.family` keyed by driver id — same reasoning as
/// `adminVehicleDetailProvider`: a fresh fetch per id rather than reusing
/// the list row's summary, to also pick up fields the list doesn't
/// bother rendering (national id, address, emergency contact, ...).
final adminDriverDetailProvider = FutureProvider.autoDispose.family<AdminDriver, int>((ref, driverId) {
  return ref.watch(adminDriversApiProvider).show(driverId);
});
