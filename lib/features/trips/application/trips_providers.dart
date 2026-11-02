import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/trip_models.dart';

final myTripsProvider = FutureProvider.autoDispose<List<Trip>>((ref) async {
  final user = ref.watch(authControllerProvider).user;
  final driverId = user?.driverId;

  if (driverId == null) {
    return const [];
  }

  return ref.watch(tripsRepositoryProvider).myTrips(driverId: driverId);
});

final tripDetailProvider = FutureProvider.autoDispose.family<Trip, int>((ref, tripId) async {
  return ref.watch(tripsRepositoryProvider).tripDetail(tripId);
});

/// `TripsApi.events()` directly, bypassing `TripsRepository` — unlike
/// `tripDetailProvider`, this has no offline-cache fallback: the event
/// log is supplementary history, not something a driver needs while
/// offline the way the trip's own current state (cached by
/// `tripDetail()`) is. Same "raw JSON from Api ← model from provider"
/// split used throughout this app's other `*Api` classes.
final tripEventsProvider = FutureProvider.autoDispose.family<List<TripEvent>, int>((ref, tripId) async {
  final raw = await ref.watch(tripsApiProvider).events(tripId);

  return raw.map((e) => TripEvent.fromJson(Map<String, dynamic>.from(e as Map))).toList();
});

/// The one trip (if any) the Trip screen and the background GPS service
/// both treat as "the active trip" — the most recent one whose status is
/// still `isActivelyTracked` (see Trip.isActivelyTracked).
final activeTripProvider = FutureProvider.autoDispose<Trip?>((ref) async {
  final trips = await ref.watch(myTripsProvider.future);

  for (final trip in trips) {
    if (trip.isActivelyTracked) {
      return trip;
    }
  }

  return null;
});
