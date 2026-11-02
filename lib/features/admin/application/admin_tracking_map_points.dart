import '../data/admin_tracking_models.dart';

/// One vehicle with coordinates definite enough to place a marker for —
/// pairs the vehicle (for the popup's plate/status/last-seen text) with
/// resolved, non-null coordinates. Mirrors `FamilyMapPoint`
/// (features/family/application/family_map_points.dart) exactly, for the
/// same reason: keep the "which rows actually get a marker" logic a pure,
/// unit-testable function, separate from the widget that plots it.
class AdminTrackingMapPoint {
  const AdminTrackingMapPoint({required this.vehicle, required this.latitude, required this.longitude});

  final AdminVehicleLocation vehicle;
  final double latitude;
  final double longitude;
}

/// `GET /locations/live` already filters to vehicles with a non-null
/// `last_known_lat`/`last_known_lng` server-side, so in practice every row
/// here has coordinates — but this stays defensive (mirroring
/// `familyMapPoints`) rather than assuming a response invariant a future
/// backend change could quietly break.
List<AdminTrackingMapPoint> adminTrackingMapPoints(List<AdminVehicleLocation> vehicles) {
  return [
    for (final vehicle in vehicles)
      if (vehicle.lat != null && vehicle.lng != null)
        AdminTrackingMapPoint(vehicle: vehicle, latitude: vehicle.lat!, longitude: vehicle.lng!),
  ];
}
