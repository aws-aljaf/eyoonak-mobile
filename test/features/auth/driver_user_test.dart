import 'package:fleet_saas_driver/features/auth/data/driver_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('root admin uses platform management without driver or family tracking', () {
    final user = DriverUser.fromJson({
      'id': 1,
      'name': 'Admin',
      'is_super_admin': true,
      'has_family_membership': true,
      'driver_id': 7,
      'permissions': ['*']
    });
    expect(user.isSuperAdmin, isTrue);
    expect(user.hasManagementAccess, isTrue);
    expect(user.hasNoAppAccess, isFalse);
    expect(user.hasFamilyAccess, isFalse);
    expect(user.isDriver, isFalse);
  });

  test('a user with a driver_id is recognized as a driver', () {
    final user = DriverUser.fromJson({'id': 1, 'name': 'Ali', 'company_id': 9, 'driver_id': 5});

    expect(user.isDriver, isTrue);
    expect(user.driverId, 5);
  });

  test('a user with no driver_id (office staff, no family permissions) is NOT a driver and has no app access', () {
    final user = DriverUser.fromJson({'id': 1, 'name': 'Manager', 'company_id': 9});

    expect(user.isDriver, isFalse);
    expect(user.driverId, isNull);
    expect(user.hasFamilyAccess, isFalse);
    expect(user.hasNoAppAccess, isTrue);
  });

  test('permissions default to an empty list when absent from the payload', () {
    final user = DriverUser.fromJson({'id': 1, 'name': 'X', 'company_id': 1});

    expect(user.permissions, isEmpty);
  });

  test('a self-registered family account has a null company_id and must not throw', () {
    // FamilyOnboardingService creates the User with no company_id/branch_id
    // at all (backend/app/Services/Family/FamilyOnboardingService.php) — the
    // wire value is genuinely null, not merely absent.
    final user = DriverUser.fromJson({
      'id': 2,
      'name': 'Family Owner',
      'company_id': null,
      'permissions': ['family_tracking.view', 'family_tracking.create', 'sos.view'],
    });

    expect(user.companyId, isNull);
    expect(user.isDriver, isFalse);
    expect(user.hasFamilyAccess, isTrue);
    expect(user.hasNoAppAccess, isFalse);
  });

  test('sos.view alone also counts as family access, without family_tracking.view', () {
    final user = DriverUser.fromJson({
      'id': 3,
      'name': 'SOS Viewer',
      'company_id': null,
      'permissions': ['sos.view'],
    });

    expect(user.hasFamilyAccess, isTrue);
  });

  test('a driver who is also a family member has both flags true and no app access is false', () {
    final user = DriverUser.fromJson({
      'id': 4,
      'name': 'Driver+Family',
      'company_id': 9,
      'driver_id': 7,
      'permissions': ['family_tracking.view'],
    });

    expect(user.isDriver, isTrue);
    expect(user.hasFamilyAccess, isTrue);
    expect(user.hasNoAppAccess, isFalse);
  });

  test('a pure office/RBAC account with a management permission has app access via hasManagementAccess', () {
    final user = DriverUser.fromJson({
      'id': 5,
      'name': 'Fleet Manager',
      'company_id': 9,
      'permissions': ['vehicles.view', 'drivers.view'],
    });

    expect(user.isDriver, isFalse);
    expect(user.hasFamilyAccess, isFalse);
    expect(user.hasManagementAccess, isTrue);
    expect(user.hasNoAppAccess, isFalse);
  });

  test('a permission outside the management set does not grant management access', () {
    final user = DriverUser.fromJson({
      'id': 6,
      'name': 'Customer Clerk',
      'company_id': 9,
      'permissions': ['customers.view'],
    });

    expect(user.hasManagementAccess, isFalse);
    expect(user.hasNoAppAccess, isTrue);
  });

  test('a driver who also holds a management permission keeps hasNoAppAccess false via either flag', () {
    final user = DriverUser.fromJson({
      'id': 7,
      'name': 'Driver+Manager',
      'company_id': 9,
      'driver_id': 8,
      'permissions': ['audit_logs.view'],
    });

    expect(user.isDriver, isTrue);
    expect(user.hasManagementAccess, isTrue);
    expect(user.hasNoAppAccess, isFalse);
  });
}
