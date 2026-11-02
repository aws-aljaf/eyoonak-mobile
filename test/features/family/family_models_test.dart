import 'package:fleet_saas_driver/features/family/data/family_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FamilyModel', () {
    test('parses a FamilyResource payload', () {
      final family = FamilyModel.fromJson({
        'id': 1,
        'name': 'عائلة أحمد',
        'status': 'active',
        'plan': 'free',
        'owner_user_id': 3,
      });

      expect(family.id, 1);
      expect(family.name, 'عائلة أحمد');
      expect(family.status, 'active');
      expect(family.plan, 'free');
      expect(family.ownerUserId, 3);
    });
  });

  group('FamilyMemberModel', () {
    test('parses a full FamilyMemberResource payload with a visible latest_location', () {
      final member = FamilyMemberModel.fromJson({
        'id': 10,
        'full_name': 'سارة',
        'relationship': 'الابنة',
        'phone': '0770',
        'avatar_path': null,
        'status': 'active',
        'linked_user_id': 4,
        'last_seen_at': '2026-09-08T10:00:00Z',
        'latest_location': {
          'latitude': 33.3,
          'longitude': 44.4,
          'battery_level': 80,
          'recorded_at': '2026-09-08T10:00:00Z',
        },
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      });

      expect(member.fullName, 'سارة');
      expect(member.relationship, 'الابنة');
      expect(member.latestLocation, isNotNull);
      expect(member.latestLocation!.latitude, 33.3);
      expect(member.latestLocation!.batteryLevel, 80);
      expect(member.isMe(4), isTrue);
      expect(member.isMe(999), isFalse);
    });

    test('a member with no location data yet has a null latest_location', () {
      final member = FamilyMemberModel.fromJson({
        'id': 11,
        'full_name': 'خالد',
        'relationship': 'الابن',
        'status': 'pending',
        'linked_user_id': null,
        'last_seen_at': null,
        'latest_location': null,
      });

      expect(member.latestLocation, isNull);
      expect(member.lastSeenAt, isNull);
      expect(member.isMe(4), isFalse);
    });

    test('a viewer without a tracking capability sees a latest_location object with redacted (null) fields', () {
      // FamilyMemberResource still emits the object when there IS
      // location data, but nulls out the specific fields the viewer lacks
      // capability for — see that resource's docblock. The model must not
      // conflate "no data" with "redacted": both render the same way, by
      // design, but the object itself is non-null here.
      final member = FamilyMemberModel.fromJson({
        'id': 12,
        'full_name': 'ليلى',
        'relationship': 'الأم',
        'status': 'active',
        'last_seen_at': null,
        'latest_location': {
          'latitude': null,
          'longitude': null,
          'battery_level': null,
          'recorded_at': null,
        },
      });

      expect(member.latestLocation, isNotNull);
      expect(member.latestLocation!.latitude, isNull);
      expect(member.latestLocation!.batteryLevel, isNull);
    });
  });

  group('FamilyLocationPoint', () {
    test('parses a full FamilyMemberLocationResource payload', () {
      final point = FamilyLocationPoint.fromJson({
        'id': 501,
        'lat': 33.3,
        'lng': 44.4,
        'accuracy_meters': 12.5,
        'battery_level': 76,
        'recorded_at': '2026-09-08T10:00:00Z',
      });

      expect(point.id, 501);
      expect(point.latitude, 33.3);
      expect(point.longitude, 44.4);
      expect(point.accuracyMeters, 12.5);
      expect(point.batteryLevel, 76);
      expect(point.recordedAt, '2026-09-08T10:00:00Z');
    });

    test('accuracy_meters and battery_level are optional', () {
      final point = FamilyLocationPoint.fromJson({
        'id': 502,
        'lat': 1,
        'lng': 2,
        'accuracy_meters': null,
        'battery_level': null,
        'recorded_at': '2026-09-08T10:05:00Z',
      });

      expect(point.accuracyMeters, isNull);
      expect(point.batteryLevel, isNull);
    });
  });

  group('DevicePairingCode', () {
    test('parses a full pairing-code generation response', () {
      final pairing = DevicePairingCode.fromJson({
        'code': 'AB3D9F2K',
        'expires_at': '2026-09-09T10:15:00+00:00',
        'family_member_name': 'سارة',
      });

      expect(pairing.code, 'AB3D9F2K');
      expect(pairing.expiresAt, DateTime.parse('2026-09-09T10:15:00+00:00'));
      expect(pairing.familyMemberName, 'سارة');
    });

    test('family_member_name is optional', () {
      final pairing = DevicePairingCode.fromJson({
        'code': 'ZZ11QQ22',
        'expires_at': '2026-09-09T10:15:00+00:00',
        'family_member_name': null,
      });

      expect(pairing.familyMemberName, isNull);
    });
  });

  group('FamilyAlertModel', () {
    test('parses a full AlertResource payload', () {
      final alert = FamilyAlertModel.fromJson({
        'id': 77,
        'family_member_id': 10,
        'type': 'geofence_exit',
        'severity': 'warning',
        'status': 'unread',
        'title': 'خروج من المنطقة الآمنة',
        'body': 'غادرت سارة منطقة "المنزل"',
        'payload': {'geofence_id': 5},
        'resolved_by_user_id': null,
        'resolved_at': null,
        'created_at': '2026-09-09T10:15:00+00:00',
      });

      expect(alert.id, 77);
      expect(alert.familyMemberId, 10);
      expect(alert.type, 'geofence_exit');
      expect(alert.severity, 'warning');
      expect(alert.status, 'unread');
      expect(alert.title, 'خروج من المنطقة الآمنة');
      expect(alert.body, 'غادرت سارة منطقة "المنزل"');
      expect(alert.payload, {'geofence_id': 5});
      expect(alert.isUnread, isTrue);
      expect(alert.isResolved, isFalse);
    });

    test('a family-wide alert has a null family_member_id, and a resolved alert carries resolver info', () {
      final alert = FamilyAlertModel.fromJson({
        'id': 78,
        'family_member_id': null,
        'type': 'sos',
        'severity': 'critical',
        'status': 'resolved',
        'title': 'نداء استغاثة',
        'body': null,
        'payload': null,
        'resolved_by_user_id': 2,
        'resolved_at': '2026-09-09T10:20:00+00:00',
        'created_at': '2026-09-09T10:15:00+00:00',
      });

      expect(alert.familyMemberId, isNull);
      expect(alert.body, isNull);
      expect(alert.payload, isNull);
      expect(alert.isUnread, isFalse);
      expect(alert.isResolved, isTrue);
      expect(alert.resolvedByUserId, 2);
      expect(alert.resolvedAt, '2026-09-09T10:20:00+00:00');
    });
  });

  group('EmergencyContactModel', () {
    test('parses a full EmergencyContactResource payload', () {
      final contact = EmergencyContactModel.fromJson({
        'id': 5,
        'name': 'خالتي منى',
        'phone': '07701234567',
        'relationship': 'خالة',
        'notify_on_sos': true,
        'created_at': '2026-09-09T10:15:00+00:00',
      });

      expect(contact.id, 5);
      expect(contact.name, 'خالتي منى');
      expect(contact.phone, '07701234567');
      expect(contact.relationship, 'خالة');
      expect(contact.notifyOnSos, isTrue);
    });

    test('relationship is optional', () {
      final contact = EmergencyContactModel.fromJson({
        'id': 6,
        'name': 'الجار أبو علي',
        'phone': '07709876543',
        'relationship': null,
        'notify_on_sos': false,
        'created_at': '2026-09-09T10:15:00+00:00',
      });

      expect(contact.relationship, isNull);
      expect(contact.notifyOnSos, isFalse);
    });
  });

  group('SosEventModel', () {
    test('parses a full active SosEventResource payload with a loaded family member name', () {
      final event = SosEventModel.fromJson({
        'id': 9,
        'family_member_id': 12,
        'family_member_name': 'ليلى',
        'triggered_by_user_id': 4,
        'lat': 33.3,
        'lng': 44.4,
        'battery_level': 15,
        'status': 'active',
        'acknowledged_by_user_id': null,
        'acknowledged_at': null,
        'resolved_by_user_id': null,
        'resolved_at': null,
        'notified_emergency_contact_ids': [5, 6],
        'created_at': '2026-09-10T10:15:00+00:00',
      });

      expect(event.id, 9);
      expect(event.familyMemberId, 12);
      expect(event.familyMemberName, 'ليلى');
      expect(event.latitude, 33.3);
      expect(event.longitude, 44.4);
      expect(event.batteryLevel, 15);
      expect(event.notifiedEmergencyContactIds, [5, 6]);
      expect(event.isActive, isTrue);
      expect(event.isAcknowledged, isFalse);
      expect(event.isResolved, isFalse);
    });

    test('an unloaded family_member_name is null, and a resolved event carries the full audit trail', () {
      final event = SosEventModel.fromJson({
        'id': 10,
        'family_member_id': 13,
        'triggered_by_user_id': 4,
        'lat': 1,
        'lng': 2,
        'battery_level': null,
        'status': 'resolved',
        'acknowledged_by_user_id': 2,
        'acknowledged_at': '2026-09-10T10:16:00+00:00',
        'resolved_by_user_id': 2,
        'resolved_at': '2026-09-10T10:30:00+00:00',
        'notified_emergency_contact_ids': null,
        'created_at': '2026-09-10T10:15:00+00:00',
      });

      expect(event.familyMemberName, isNull);
      expect(event.batteryLevel, isNull);
      expect(event.notifiedEmergencyContactIds, isNull);
      expect(event.isActive, isFalse);
      expect(event.isResolved, isTrue);
      expect(event.acknowledgedByUserId, 2);
      expect(event.resolvedByUserId, 2);
    });
  });
}
