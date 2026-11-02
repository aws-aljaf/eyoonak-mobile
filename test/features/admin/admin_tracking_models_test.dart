import 'package:fleet_saas_driver/features/admin/data/admin_tracking_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdminVehicleLocation.fromJson', () {
    test('parses a full VehicleLiveLocationResource payload', () {
      final vehicle = AdminVehicleLocation.fromJson({
        'vehicle_id': 10,
        'plate_number': 'أ ب ج 123',
        'status': 'moving',
        'current_driver_id': 5,
        'lat': 33.315,
        'lng': 44.366,
        'last_location_at': '2026-09-19T08:00:00Z',
      });

      expect(vehicle.vehicleId, 10);
      expect(vehicle.plateNumber, 'أ ب ج 123');
      expect(vehicle.status, 'moving');
      expect(vehicle.currentDriverId, 5);
      expect(vehicle.lat, 33.315);
      expect(vehicle.lng, 44.366);
      expect(vehicle.lastLocationAt, isNotNull);
    });

    test('tolerates a vehicle with no current driver and no recorded location yet', () {
      final vehicle = AdminVehicleLocation.fromJson({
        'vehicle_id': 11,
        'plate_number': 'د هـ و 456',
        'status': 'out_of_service',
      });

      expect(vehicle.currentDriverId, isNull);
      expect(vehicle.lat, isNull);
      expect(vehicle.lng, isNull);
      expect(vehicle.lastLocationAt, isNull);
    });
  });
}
