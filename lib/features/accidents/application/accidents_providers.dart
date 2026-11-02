import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../drivers/data/driver_profile.dart';
import '../../vehicles/data/vehicle_models.dart';
import '../data/accident_models.dart';

/// `AccidentsApi.index()` directly, no repository/offline-cache layer —
/// matches every family-tracking screen's convention (accidents are a
/// server-side, occasionally-created record, not something a driver needs
/// available while offline the way active-trip state is).
final myAccidentsProvider = FutureProvider.autoDispose<List<Accident>>((ref) async {
  final raw = await ref.watch(accidentsApiProvider).index();

  return raw.map((e) => Accident.fromJson(Map<String, dynamic>.from(e as Map))).toList();
});

/// A second, independent fetch of the driver's own profile (deliberately
/// NOT sharing `ProfileScreen`'s own `_driverProfileProvider` — that one
/// is file-private by convention, and Dart's `_` privacy is per-library,
/// not per-feature, see this project's PR #48 lesson) — used only to read
/// `currentVehicleId` for pre-filling a new accident report.
final reportingDriverProfileProvider = FutureProvider.autoDispose<DriverProfile?>((ref) async {
  final driverId = ref.watch(authControllerProvider).user?.driverId;

  if (driverId == null) {
    return null;
  }

  return ref.watch(driversApiProvider).show(driverId);
});

/// The driver's currently-assigned vehicle, shown read-only on the report
/// form so the driver can confirm it's the right one before submitting —
/// this app has no way to pick a different one (`VehiclesApi` has no
/// `index()`, see `DriverProfile.currentVehicleId`'s docblock). Resolves
/// to `null` both while `currentVehicleId` is still loading and when the
/// driver genuinely has none assigned.
final reportingVehicleProvider = FutureProvider.autoDispose<VehicleInfo?>((ref) async {
  final profile = await ref.watch(reportingDriverProfileProvider.future);
  final vehicleId = profile?.currentVehicleId;

  if (vehicleId == null) {
    return null;
  }

  return ref.watch(vehiclesApiProvider).show(vehicleId);
});
