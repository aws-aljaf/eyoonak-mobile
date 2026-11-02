import '../../health/application/health_reminders.dart';
import '../../family_life/application/prayer_reminders.dart';
import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/constants.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/secure_token_store.dart';
import '../data/auth_api.dart';
import '../data/driver_user.dart';
import 'auth_state.dart';

/// The single source of truth for "who is logged in" — the router's
/// auth-gate and every screen that needs the current driver read this,
/// never AuthApi directly.
class AuthController extends StateNotifier<AuthState> {
  AuthController(this._authApi, this._tokenStore) : super(const AuthState()) {
    _bootstrap();
  }

  final AuthApi _authApi;
  final SecureTokenStore _tokenStore;

  /// On cold start: if a token was persisted (module 25's "Remember
  /// Device"), validate it against the real backend via GET /auth/me
  /// rather than trusting a locally-cached "logged in" flag — an admin
  /// may have revoked the device server-side since the last launch.
  Future<void> _bootstrap() async {
    final token = await _tokenStore.readToken();

    if (token == null) {
      state = state.copyWith(status: AuthStatus.unauthenticated);

      return;
    }

    try {
      final user = await _authApi.me();
      await _afterAuthenticated(user);
    } on ApiException catch (error) {
      if (error.statusCode != 401 && error.statusCode != 403) {
        state = state.copyWith(status: AuthStatus.unauthenticated,
          errorMessage: 'تعذرت استعادة الجلسة بسبب الاتصال. حسابك محفوظ؛ أعد فتح التطبيق عند عودة الشبكة.');
        return;
      }
      await HealthReminders.instance.endSession();
      await PrayerReminders.instance.clear();
      await _tokenStore.clearAll();
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login({required String identifier, required String password}) async {
    state = state.copyWith(status: AuthStatus.authenticating, clearError: true);

    try {
      final deviceUuid = await _deviceUuid();
      final result = await _authApi.login(
        identifier: identifier,
        password: password,
        deviceUuid: deviceUuid,
        deviceName: _deviceName(),
        appVersion: kAppVersion,
      );

      if (result['requires_2fa'] == true) {
        state = state.copyWith(
          status: AuthStatus.twoFactorRequired,
          twoFactorChallenge: result['challenge'] as String,
        );

        return;
      }

      await _completeLogin(result);
    } on ApiException catch (error) {
      state = state.copyWith(status: AuthStatus.unauthenticated, errorMessage: error.message);
    }
  }

  Future<void> registerFamily(Map<String, dynamic> details) async {
    state = state.copyWith(status: AuthStatus.authenticating, clearError: true);
    try {
      final result = await _authApi.registerFamily(
          details: details, deviceUuid: await _deviceUuid(), deviceName: _deviceName(), appVersion: kAppVersion);
      try {
        await _completeLogin(result);
      } on ApiException catch (error) {
        // A confirmed signup already created the account and its session.
        // A temporary profile fetch failure must not invite duplicate signup.
        if ((error.isNetwork || (error.statusCode ?? 0) >= 500) &&
            result['user'] is Map) {
          await _afterAuthenticated(DriverUser.fromJson({
            ...Map<String, dynamic>.from(result['user'] as Map),
            'has_family_membership': result['family'] is Map,
          }));
        } else {
          rethrow;
        }
      }
    } on ApiException catch (error) {
      state = state.copyWith(status: AuthStatus.unauthenticated, errorMessage: (error.fieldErrors['phone'] ?? []).any((message) => message.contains('مسجّل') || message.contains('مسجل')) ? 'هذا الرقم مسجّل من قبل. افتح تسجيل الدخول؛ لا تحتاج إنشاء حساب جديد.' : (error.fieldErrors.isEmpty ? error.message : error.fieldErrors.values.expand((v) => v).join(' · ')));
    }
  }

  Future<void> verifyTwoFactor(String code) async {
    final challenge = state.twoFactorChallenge;

    if (challenge == null) {
      return;
    }

    state = state.copyWith(status: AuthStatus.authenticating, clearError: true);

    try {
      final deviceUuid = await _deviceUuid();
      final result = await _authApi.verifyTwoFactor(
        challenge: challenge,
        code: code,
        deviceUuid: deviceUuid,
        deviceName: _deviceName(),
        appVersion: kAppVersion,
      );
      await _completeLogin(result);
    } on ApiException catch (error) {
      state = state.copyWith(status: AuthStatus.twoFactorRequired, errorMessage: error.message);
    }
  }

  Future<void> refreshMembership() async {
    try {
      await _afterAuthenticated(await _authApi.me());
    } on ApiException catch (error) {
      state = state.copyWith(errorMessage: error.message);
    }
  }

  Future<void> logout() async {
    try {
      await _authApi.logout();
    } on ApiException {
      // Even if the server call fails (offline, token already expired),
      // the local session must still end — a driver tapping "logout"
      // expects to be logged out immediately, not blocked by a network
      // error.
    }

    await HealthReminders.instance.endSession();
    await PrayerReminders.instance.clear();
    await _tokenStore.clearAll();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Same "always end the local session regardless of the network result"
  /// contract as `logout()` above, but for the "تسجيل الخروج من كل
  /// الأجهزة" action on the new devices screen (`AuthApi.logoutAll()`) —
  /// every token/device this account has, not just this one. Also what a
  /// caller should run after successfully revoking *this* device from its
  /// own devices list (`AuthApi.revokeDevice()`): the underlying token is
  /// already gone server-side at that point, so the `logout()` call this
  /// makes internally is expected to 401 and fall through to the same
  /// local cleanup — never call `logoutAll()` itself again there, since
  /// that would be a second, redundant network round-trip for tokens that
  /// revoke already took care of.
  Future<void> logoutEverywhere() async {
    try {
      await _authApi.logoutAll();
    } on ApiException {
      // Same reasoning as logout() above.
    }

    await HealthReminders.instance.endSession();
    await PrayerReminders.instance.clear();
    await _tokenStore.clearAll();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> _completeLogin(Map<String, dynamic> result) async {
    final token = result['token'] as String;
    await _tokenStore.saveToken(token);

    // The `user` object embedded in the login/2FA response is intentionally
    // minimal (see backend/app/Http/Resources/Api/V1/UserResource.php) —
    // `driver_id`/`permissions` are only ever populated on GET /auth/me, not
    // here. Building a DriverUser straight from `result['user']` therefore
    // always yields `driverId == null`, which made `_afterAuthenticated`
    // reject every real driver login as "not a driver account". Fetch the
    // full profile via /auth/me instead, now that the token is saved.
    final user = await _authApi.me();
    await _afterAuthenticated(user);
  }

  Future<void> _afterAuthenticated(DriverUser user) async {
    await _tokenStore.saveDriverId(user.driverId);
    state = state.copyWith(
      status: AuthStatus.authenticated,
      user: user,
      clearError: true,
      clearChallenge: true,
    );
  }

  Future<String> _deviceUuid() async {
    final existing = await _tokenStore.readDeviceUuid();

    if (existing != null) {
      return existing;
    }

    final generated = const Uuid().v4();
    await _tokenStore.saveDeviceUuid(generated);

    return generated;
  }

  String _deviceName() {
    // No device_info_plus dependency for just a display label — a real
    // (not fabricated) value sourced from dart:io is good enough for the
    // `devices` list shown in the web dashboard.
    return '${Platform.operatingSystem} عيونك';
  }
}
