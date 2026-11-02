import 'package:fleet_saas_driver/features/admin/data/admin_driver_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdminDriver.fromJson', () {
    test('parses a full DriverResource payload', () {
      final driver = AdminDriver.fromJson({
        'id': 1,
        'branch_id': 4,
        'full_name': 'أحمد علي',
        'phone': '07701234567',
        'national_id': 'NID1',
        'governorate': 'بغداد',
        'address': 'الكرادة',
        'birth_date': '1990-01-01',
        'license_number': 'LIC1',
        'license_type': 'عام',
        'license_expiry_date': '2027-01-01',
        'hire_date': '2020-01-01',
        'salary': 500000,
        'status': 'active',
        'current_vehicle_id': 9,
        'emergency_contact_name': 'أم أحمد',
        'emergency_contact_phone': '07709876543',
        'performance_score': 87.5,
        'created_at': '2020-01-01T00:00:00Z',
      });

      expect(driver.id, 1);
      expect(driver.fullName, 'أحمد علي');
      expect(driver.phone, '07701234567');
      expect(driver.status, 'active');
      expect(driver.currentVehicleId, 9);
      expect(driver.performanceScore, 87.5);
      expect(driver.createdAt, isNotNull);
    });

    test('tolerates a minimal payload with no optional fields at all', () {
      final driver = AdminDriver.fromJson({'id': 2});

      expect(driver.fullName, '');
      expect(driver.phone, isNull);
      expect(driver.status, isNull);
      expect(driver.currentVehicleId, isNull);
      expect(driver.createdAt, isNull);
    });
  });

  test('driverStatusLabels covers every status StoreDriverRequest allows', () {
    expect(driverStatusLabels.keys, containsAll(['active', 'suspended', 'terminated']));
  });
}
