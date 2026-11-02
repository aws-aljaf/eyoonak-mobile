import 'package:fleet_saas_driver/features/admin/data/admin_role_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdminRole.fromJson', () {
    test('parses a full RoleResource payload', () {
      final role = AdminRole.fromJson({
        'id': 1,
        'company_id': 3,
        'name': 'Fleet Manager',
        'name_ar': 'مدير الأسطول',
        'slug': 'fleet_manager',
        'is_system_default': false,
        'is_editable': true,
        'description': 'يدير المركبات والسائقين والرحلات',
        'permissions': ['vehicles.view', 'drivers.view', 'trips.view'],
        'created_at': '2024-01-01T00:00:00Z',
      });

      expect(role.id, 1);
      expect(role.displayName, 'مدير الأسطول');
      expect(role.isSystemDefault, isFalse);
      expect(role.isEditable, isTrue);
      expect(role.permissions, ['vehicles.view', 'drivers.view', 'trips.view']);
      expect(role.createdAt, isNotNull);
    });

    test('falls back to the English name when name_ar is absent, and tolerates a minimal payload', () {
      final role = AdminRole.fromJson({'id': 2, 'name': 'Admin'});

      expect(role.displayName, 'Admin');
      expect(role.isSystemDefault, isFalse);
      expect(role.isEditable, isFalse);
      expect(role.permissions, isEmpty);
      expect(role.createdAt, isNull);
    });
  });

  group('AdminPermission.fromJson', () {
    test('parses a PermissionResource payload', () {
      final permission = AdminPermission.fromJson({
        'id': 10,
        'key': 'vehicles.view',
        'module': 'vehicles',
        'description_ar': 'عرض المركبات',
        'description_en': 'View vehicles',
      });

      expect(permission.key, 'vehicles.view');
      expect(permission.module, 'vehicles');
      expect(permission.descriptionAr, 'عرض المركبات');
    });
  });

  test('permissionModuleLabels covers every module PermissionsSeeder defines', () {
    expect(
      permissionModuleLabels.keys,
      containsAll([
        'branches',
        'users',
        'settings',
        'vehicles',
        'drivers',
        'customers',
        'trips',
        'shipments',
        'maintenance',
        'fuel',
        'expenses',
        'accidents',
        'geofences',
        'tracking',
        'family_tracking',
        'alerts',
        'sos',
        'reports',
        'notifications',
        'subscription',
        'audit_logs',
      ]),
    );
  });
}
