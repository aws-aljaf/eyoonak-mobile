import '../features/auth/application/auth_state.dart';
import '../features/auth/data/driver_user.dart';

String? authRedirect(AuthState authState, String location) {
  final onAuthScreen = location == '/login' ||
      location == '/2fa' ||
      location == '/register-family';
  final onSplash = location == '/splash';

  switch (authState.status) {
    case AuthStatus.unknown:
      return onSplash ? null : '/splash';
    case AuthStatus.unauthenticated:
    case AuthStatus.authenticating:
      return onAuthScreen ? null : '/login';
    case AuthStatus.twoFactorRequired:
      return location == '/2fa' ? null : '/2fa';
    case AuthStatus.authenticated:
      if (authState.user?.hasNoAppAccess == true) {
        return const [
          '/complete-membership',
          '/family/membership',
          '/profile',
          '/profile/devices',
          '/profile/account-deletion'
        ].contains(location)
            ? null
            : '/complete-membership';
      }
      if (authState.user?.isSuperAdmin == true &&
          ![
            '/platform-admin',
            '/profile',
            '/profile/devices',
            '/profile/account-deletion'
          ].contains(location)) {
        return '/platform-admin';
      }
      if (location == '/platform-admin' &&
          authState.user?.isSuperAdmin != true) {
        return landingRoute(authState.user);
      }
      return (onAuthScreen || onSplash) ? landingRoute(authState.user) : null;
  }
}

String landingRoute(DriverUser? user) {
  if (user == null) {
    return '/home';
  }

  if (user.hasNoAppAccess) return '/complete-membership';

  if (user.isSuperAdmin) return '/platform-admin';

  if (!user.isDriver && user.hasFamilyAccess) {
    return '/our-home';
  }

  if (!user.isDriver && !user.hasFamilyAccess && user.hasManagementAccess) {
    return '/admin';
  }

  return '/home';
}
