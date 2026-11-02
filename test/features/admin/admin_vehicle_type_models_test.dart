import 'package:fleet_saas_driver/features/admin/data/admin_vehicle_type_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdminVehicleType.fromJson', () {
    test('parses a full VehicleTypeResource payload', () {
      final type = AdminVehicleType.fromJson({
        'id': 2,
        'name': 'Pickup',
        'name_ar': 'بيك أب',
        'is_system_default': true,
      });

      expect(type.id, 2);
      expect(type.name, 'Pickup');
      expect(type.nameAr, 'بيك أب');
      expect(type.isSystemDefault, isTrue);
      expect(type.displayName, 'بيك أب');
    });

    test('defaults isSystemDefault to false when absent, and falls back to the id when no name exists', () {
      final type = AdminVehicleType.fromJson({'id': 7});

      expect(type.isSystemDefault, isFalse);
      expect(type.name, isNull);
      expect(type.nameAr, isNull);
      expect(type.displayName, '#7');
    });

    test('displayName prefers nameAr over name when both are present', () {
      final type = AdminVehicleType.fromJson({'id': 3, 'name': 'Sedan', 'name_ar': 'سيدان'});

      expect(type.displayName, 'سيدان');
    });

    test('displayName falls back to name when nameAr is absent', () {
      final type = AdminVehicleType.fromJson({'id': 4, 'name': 'Van'});

      expect(type.displayName, 'Van');
    });
  });
}
