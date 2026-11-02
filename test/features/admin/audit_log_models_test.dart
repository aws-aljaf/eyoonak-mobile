import 'package:fleet_saas_driver/features/admin/data/audit_log_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuditLog.fromJson', () {
    test('parses a full AuditLogResource payload, including the actor', () {
      final log = AuditLog.fromJson({
        'id': 1,
        'action': 'vehicle.updated',
        'model_type': 'Vehicle',
        'model_id': 5,
        'user': {'id': 3, 'name': 'Ahmed'},
        'ip_address': '10.0.0.1',
        'old_values': {'status': 'active'},
        'new_values': {'status': 'maintenance'},
        'created_at': '2026-09-12T10:05:00Z',
      });

      expect(log.id, 1);
      expect(log.action, 'vehicle.updated');
      expect(log.modelType, 'Vehicle');
      expect(log.modelId, 5);
      expect(log.userName, 'Ahmed');
      expect(log.ipAddress, '10.0.0.1');
      expect(log.oldValues, {'status': 'active'});
      expect(log.newValues, {'status': 'maintenance'});
      expect(log.createdAt, isNotNull);
    });

    test('tolerates a row with no user, no model, and no old/new values', () {
      final log = AuditLog.fromJson({
        'id': 2,
        'action': 'auth.login',
        'created_at': '2026-09-12T10:00:00Z',
      });

      expect(log.modelType, isNull);
      expect(log.modelId, isNull);
      expect(log.userName, isNull);
      expect(log.ipAddress, isNull);
      expect(log.oldValues, isNull);
      expect(log.newValues, isNull);
    });

    test('tolerates a null created_at', () {
      final log = AuditLog.fromJson({'id': 3, 'action': 'x'});

      expect(log.createdAt, isNull);
    });
  });
}
