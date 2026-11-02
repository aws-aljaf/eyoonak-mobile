import 'package:fleet_saas_driver/features/admin/application/admin_tracking_map_points.dart';
import 'package:fleet_saas_driver/features/admin/data/admin_tracking_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a vehicle with null lat/lng is left off the map', () {
    final points = adminTrackingMapPoints([
      const AdminVehicleLocation(vehicleId: 1, plateNumber: 'أ ب ج 123', status: 'idle'),
    ]);

    expect(points, isEmpty);
  });

  test('a vehicle with only one of lat/lng resolved is left off the map', () {
    final points = adminTrackingMapPoints([
      const AdminVehicleLocation(vehicleId: 2, plateNumber: 'د هـ و 456', lat: 33.3),
    ]);

    expect(points, isEmpty);
  });

  test('a vehicle with resolved coordinates gets exactly one point carrying them', () {
    final points = adminTrackingMapPoints([
      const AdminVehicleLocation(vehicleId: 3, plateNumber: 'ز ح ط 789', status: 'moving', lat: 33.3, lng: 44.4),
    ]);

    expect(points, hasLength(1));
    expect(points.single.latitude, 33.3);
    expect(points.single.longitude, 44.4);
    expect(points.single.vehicle.plateNumber, 'ز ح ط 789');
  });

  test('a mixed fleet only plots vehicles with resolved coordinates, preserving order', () {
    final points = adminTrackingMapPoints([
      const AdminVehicleLocation(vehicleId: 1, plateNumber: 'بلا موقع'),
      const AdminVehicleLocation(vehicleId: 2, plateNumber: 'أول', lat: 1, lng: 2),
      const AdminVehicleLocation(vehicleId: 3, plateNumber: 'نصف بيانات فقط', lat: 5),
      const AdminVehicleLocation(vehicleId: 4, plateNumber: 'ثانٍ', lat: 3, lng: 4),
    ]);

    expect(points.map((p) => p.vehicle.plateNumber), ['أول', 'ثانٍ']);
  });
}
