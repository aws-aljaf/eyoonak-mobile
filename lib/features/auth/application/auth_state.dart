import '../data/driver_user.dart';

enum AuthStatus { unknown, unauthenticated, authenticating, twoFactorRequired, authenticated }

class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.errorMessage,
    this.twoFactorChallenge,
  });

  final AuthStatus status;
  final DriverUser? user;
  final String? errorMessage;
  final String? twoFactorChallenge;

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;

  AuthState copyWith({
    AuthStatus? status,
    DriverUser? user,
    String? errorMessage,
    bool clearError = false,
    String? twoFactorChallenge,
    bool clearChallenge = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      twoFactorChallenge: clearChallenge ? null : (twoFactorChallenge ?? this.twoFactorChallenge),
    );
  }
}
