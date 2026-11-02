import 'package:fleet_saas_driver/features/admin/data/admin_vehicle_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdminVehicle.fromJson', () {
    test('parses a full VehicleResource payload, including nested relations', () {
      final vehicle = AdminVehicle.fromJson({
        'id': 1,
        'branch_id': 4,
        'vehicle_type_id': 2,
        'vehicle_type': {'id': 2, 'name': 'Pickup', 'name_ar': 'بيك أب'},
        'plate_number': '12345',
        'plate_governorate': 'بغداد',
        'brand': 'Toyota',
        'model': 'Hilux',
        'year': 2022,
        'color': 'أبيض',
        'vin': 'VIN123',
        'engine_number': 'ENG123',
        'chassis_number': 'CHS123',
        'fuel_type': 'diesel',
        'tank_capacity_liters': 80,
        'current_mileage': 15000,
        'current_driver_id': 9,
        'current_driver': {'id': 9, 'full_name': 'أحمد علي'},
        'status': 'active',
        'insurance_expiry_date': '2027-01-01',
        'registration_expiry_date': '2027-02-01',
        'license_expiry_date': '2027-03-01',
        'inspection_expiry_date': '2027-04-01',
        'last_known_lat': 33.3,
        'last_known_lng': 44.4,
        'last_location_at': '2026-09-13T10:00:00Z',
        'created_at': '2025-01-01T00:00:00Z',
      });

      expect(vehicle.id, 1);
      expect(vehicle.branchId, 4);
      expect(vehicle.vehicleTypeId, 2);
      expect(vehicle.vehicleTypeName, 'بيك أب');
      expect(vehicle.plateNumber, '12345');
      expect(vehicle.brand, 'Toyota');
      expect(vehicle.model, 'Hilux');
      expect(vehicle.displayName, 'Toyota Hilux');
      expect(vehicle.currentDriverId, 9);
      expect(vehicle.currentDriverName, 'أحمد علي');
      expect(vehicle.status, 'active');
      expect(vehicle.lastKnownLat, 33.3);
      expect(vehicle.lastKnownLng, 44.4);
      expect(vehicle.lastLocationAt, isNotNull);
      expect(vehicle.createdAt, isNotNull);
    });

    test('tolerates whenLoaded() relations arriving as an empty array instead of an object', () {
      // JsonResource::whenLoaded() serializes to `[]` (not `null`) when the
      // relation wasn't eager-loaded — never assume a populated Map here.
      final vehicle = AdminVehicle.fromJson({
        'id': 2,
        'plate_number': '99999',
        'vehicle_type': [],
        'current_driver': [],
      });

      expect(vehicle.vehicleTypeName, isNull);
      expect(vehicle.currentDriverName, isNull);
      expect(vehicle.displayName, '');
    });

    test('tolerates a minimal payload with no optional fields at all', () {
      final vehicle = AdminVehicle.fromJson({'id': 3});

      expect(vehicle.plateNumber, '');
      expect(vehicle.status, isNull);
      expect(vehicle.vehicleTypeId, isNull);
      expect(vehicle.currentDriverId, isNull);
      expect(vehicle.lastKnownLat, isNull);
      expect(vehicle.lastLocationAt, isNull);
      expect(vehicle.createdAt, isNull);
    });
  });

  test('vehicleStatusLabels covers every status StoreVehicleRequest allows', () {
    expect(vehicleStatusLabels.keys, containsAll(['active', 'moving', 'idle', 'maintenance', 'out_of_service']));
  });
}
