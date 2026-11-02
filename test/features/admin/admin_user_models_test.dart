import 'package:fleet_saas_driver/features/admin/data/admin_user_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdminUser.fromJson', () {
    test('parses a full UserResource payload', () {
      final user = AdminUser.fromJson({
        'id': 1,
        'company_id': 3,
        'branch_id': 4,
        'branch': {'id': 4, 'name': 'فرع الكرادة'},
        'name': 'سارة محمد',
        'email': 'sara@example.com',
        'phone': '07701234567',
        'avatar_path': null,
        'locale': 'ar',
        'status': 'active',
        'is_super_admin': false,
        'two_factor_enabled': true,
        'last_login_at': '2026-09-01T10:00:00Z',
        'roles': ['fleet_manager', 'dispatcher'],
        'created_at': '2024-01-01T00:00:00Z',
      });

      expect(user.id, 1);
      expect(user.name, 'سارة محمد');
      expect(user.email, 'sara@example.com');
      expect(user.branchName, 'فرع الكرادة');
      expect(user.status, 'active');
      expect(user.isSuperAdmin, isFalse);
      expect(user.twoFactorEnabled, isTrue);
      expect(user.roles, ['fleet_manager', 'dispatcher']);
      expect(user.lastLoginAt, isNotNull);
      expect(user.createdAt, isNotNull);
    });

    test('tolerates a minimal payload with no optional fields and no roles/branch loaded', () {
      final user = AdminUser.fromJson({'id': 2});

      expect(user.name, '');
      expect(user.email, '');
      expect(user.branchName, isNull);
      expect(user.status, isNull);
      expect(user.roles, isEmpty);
      expect(user.lastLoginAt, isNull);
      expect(user.createdAt, isNull);
    });
  });

  test('userStatusLabels covers every status the users table enum allows', () {
    expect(userStatusLabels.keys, containsAll(['active', 'suspended', 'invited']));
  });
}
