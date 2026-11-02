import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_envelope.dart';
import '../data/admin_vehicle_models.dart';

/// Resets to page 1 whenever this screen is left and reopened
/// (`.autoDispose`) — same reasoning as `auditLogsPageProvider`: an admin
/// reopening the vehicles list later should start from page 1, not a
/// stale deep page from a previous visit.
final adminVehiclesPageProvider = StateProvider.autoDispose<int>((ref) => 1);

/// `null` = "الكل" (no status filter) — one of `vehicleStatusLabels`' keys
/// otherwise.
final adminVehiclesStatusFilterProvider = StateProvider.autoDispose<String?>((ref) => null);

/// Free-text search — matches `VehicleController::index()`'s own
/// `plate_number`/`brand`/`model` `LIKE '%{value}%'` match.
final adminVehiclesSearchFilterProvider = StateProvider.autoDispose<String?>((ref) => null);

final adminVehiclesProvider = FutureProvider.autoDispose<ApiEnvelope>((ref) async {
  final page = ref.watch(adminVehiclesPageProvider);
  final status = ref.watch(adminVehiclesStatusFilterProvider);
  final q = ref.watch(adminVehiclesSearchFilterProvider);

  return ref.watch(adminVehiclesApiProvider).index(page: page, status: status, q: q);
});

/// `.family` keyed by vehicle id — `AdminVehicleDetailScreen` is always
/// reached by tapping a specific row on `AdminVehiclesScreen`, so a fresh
/// fetch per id (rather than reusing the summary already in hand from the
/// list) is the simplest way to also pick up fields the list row doesn't
/// bother rendering (VIN, engine/chassis numbers, expiry dates).
final adminVehicleDetailProvider = FutureProvider.autoDispose.family<AdminVehicle, int>((ref, vehicleId) {
  return ref.watch(adminVehiclesApiProvider).show(vehicleId);
});
