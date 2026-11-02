import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_saas_driver/app/auth_navigation.dart';
import 'package:fleet_saas_driver/features/auth/application/auth_state.dart';
import 'package:fleet_saas_driver/features/auth/data/driver_user.dart';
void main() {
  const root = AuthState(status: AuthStatus.authenticated, user: DriverUser(id: 1, name: 'Root', isSuperAdmin: true));
  const family = AuthState(status: AuthStatus.authenticated, user: DriverUser(id: 2, name: 'Parent', hasFamilyMembership: true));
  test('unlinked account stays in membership setup without family access', () {
    const pending = AuthState(status: AuthStatus.authenticated, user: DriverUser(id: 8, name: 'Pending'));
    expect(authRedirect(pending, '/our-home'), '/complete-membership');
    expect(authRedirect(pending, '/admin'), '/complete-membership');
    expect(authRedirect(pending, '/complete-membership'), isNull);
    expect(authRedirect(pending, '/family/membership'), isNull);
    expect(authRedirect(pending, '/family/pair-device'), '/complete-membership');
    expect(authRedirect(pending, '/profile/account-deletion'), isNull);
    expect(landingRoute(pending.user), '/complete-membership');
  });
  test('root can reach account device and deletion settings', () {
    expect(authRedirect(root, '/profile/devices'), isNull);
    expect(authRedirect(root, '/profile/account-deletion'), isNull);
  });
  test('account routes do not widen root access to family or driver data', () {
    expect(authRedirect(root, '/our-home'), '/platform-admin');
    expect(authRedirect(root, '/profile/documents/4'), '/platform-admin');
    expect(authRedirect(root, '/profile/accidents'), '/platform-admin');
  });
  test('family cannot enter platform administration', () {
    expect(authRedirect(family, '/platform-admin'), '/our-home');
  });
  test('anonymous account settings and pending two factor stay protected', () {
    expect(authRedirect(const AuthState(status: AuthStatus.unauthenticated), '/profile/devices'), '/login');
    expect(authRedirect(const AuthState(status: AuthStatus.twoFactorRequired), '/profile/account-deletion'), '/2fa');
    expect(authRedirect(const AuthState(status: AuthStatus.authenticating), '/register-family'), isNull);
  });
}
