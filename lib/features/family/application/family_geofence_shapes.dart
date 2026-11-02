import '../data/family_models.dart';

/// One safe zone ready to draw on the map — pairs its label with the
/// already-typed shape from `family_models.dart`. Pulled out of the map
/// screen as a pure function (same reasoning as `familyMapPoints()` in
/// `family_map_points.dart`) so the "which zones actually get drawn"
/// filtering is unit-testable without pumping a real `FlutterMap` widget.
class FamilyGeofenceDrawing {
  const FamilyGeofenceDrawing({required this.id, required this.name, required this.shape});

  final int id;
  final String name;
  final FamilyGeofenceShape shape;
}

/// A geofence the family has since turned off (`isActive == false`) is
/// left off the map entirely — a disabled safe zone drawn as if it were
/// live would be actively misleading on a screen whose entire purpose is
/// showing where members currently are relative to zones that matter
/// right now. This mirrors the web app's `SafeZonesPage.vue`, which lists
/// inactive zones for editing but never overlays them on
/// `FamilyTrackingPage.vue`'s live map.
List<FamilyGeofenceDrawing> familyGeofenceShapes(List<FamilyGeofenceModel> geofences) {
  return [
    for (final geofence in geofences)
      if (geofence.isActive) FamilyGeofenceDrawing(id: geofence.id, name: geofence.name, shape: geofence.shape),
  ];
}
