import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_envelope.dart';

/// Resets to page 1 whenever this screen is left and reopened
/// (`.autoDispose`) — same reasoning as `adminVehiclesPageProvider`/
/// `adminDriversPageProvider`.
final adminTripsPageProvider = StateProvider.autoDispose<int>((ref) => 1);

/// `null` = "الكل" (no status filter) — one of `tripStatusLabels`' keys
/// otherwise.
final adminTripsStatusFilterProvider = StateProvider.autoDispose<String?>((ref) => null);

final adminTripsFromFilterProvider = StateProvider.autoDispose<DateTime?>((ref) => null);

final adminTripsToFilterProvider = StateProvider.autoDispose<DateTime?>((ref) => null);

final adminTripsProvider = FutureProvider.autoDispose<ApiEnvelope>((ref) async {
  final page = ref.watch(adminTripsPageProvider);
  final status = ref.watch(adminTripsStatusFilterProvider);
  final from = ref.watch(adminTripsFromFilterProvider);
  final to = ref.watch(adminTripsToFilterProvider);

  return ref.watch(adminTripsApiProvider).index(page: page, status: status, dateFrom: from, dateTo: to);
});

// No `adminTripDetailProvider` here on purpose — `AdminTripDetailScreen`
// reuses `tripDetailProvider`/`tripEventsProvider` from
// `features/trips/application/trips_providers.dart` directly (see
// `AdminTripsApi`'s docblock for why: both are already generic by
// `tripId` with no driver-scoping of their own).
