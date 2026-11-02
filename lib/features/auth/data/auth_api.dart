import 'dart:io' show Platform;

import '../../../core/network/api_client.dart';
import 'driver_user.dart';
import 'session_device.dart';

/// Talks to `/api/v1/auth/*` exactly as documented in
/// documentation/04-api-specification.md — no other file constructs these
/// request bodies.
class AuthApi {
  AuthApi(this._client);

  final ApiClient _client;

  static String get platform {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';

    return 'web';
  }

  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
    required String deviceUuid,
    required String deviceName,
    required String appVersion,
  }) async {
    final data = await _client.post('/auth/login', data: {
      'identifier': identifier,
      'password': password,
      'device_uuid': deviceUuid,
      'device_name': deviceName,
      'platform': platform,
      'app_version': appVersion,
    });

    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> registerFamily(
      {required Map<String, dynamic> details,
      required String deviceUuid,
      required String deviceName,
      required String appVersion}) async {
    final data = await _client.post('/family-onboarding', data: {
      ...details,
      'locale': 'ar',
      'device_uuid': deviceUuid,
      'device_name': deviceName,
      'platform': platform,
      'app_version': appVersion
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> verifyTwoFactor({
    required String challenge,
    required String code,
    required String deviceUuid,
    required String deviceName,
    required String appVersion,
  }) async {
    final data = await _client.post('/auth/login/2fa', data: {
      'challenge': challenge,
      'code': code,
      'device_uuid': deviceUuid,
      'device_name': deviceName,
      'platform': platform,
      'app_version': appVersion,
    });

    return Map<String, dynamic>.from(data as Map);
  }

  Future<DriverUser> me() async {
    final data = await _client.get('/auth/me');

    return DriverUser.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> logout() => _client.post('/auth/logout');

  /// `POST /auth/logout-all` — revokes every one of this account's tokens
  /// AND every `Device` row (`AuthController::logoutAll()`), not just this
  /// one. A wire-up of a backend endpoint verified directly against that
  /// controller: fully built and authorized (any authenticated account,
  /// no extra permission) since the auth module's own foundation, but
  /// unreachable from anywhere in this app until now — the exact same
  /// "server-ready capability, no frontend ever called it" gap PR #49
  /// found for `PUT /families/{id}`. Grepped the web reference
  /// (`resources/js`) too before building this: it doesn't call
  /// `logout-all`/`GET auth/devices`/`DELETE auth/devices/{id}` either, so
  /// (as with PR #49) this app is not "catching up to the web app" here —
  /// it is the first frontend to use this account-security surface at all.
  Future<void> logoutAll() => _client.post('/auth/logout-all');

  /// `GET /auth/devices` — every still-active (non-revoked) session this
  /// account is logged into, newest-active-first (server-side order,
  /// `AuthController::devices()`), each flagged `is_current` for the one
  /// answering this very request.
  Future<List<SessionDevice>> devices() async {
    final data = await _client.get('/auth/devices');

    return (data as List).map((e) => SessionDevice.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// `DELETE /auth/devices/{device}` — ends one specific session
  /// (`AuthController::revokeDevice()` deletes its underlying Sanctum
  /// token and marks the `Device` row revoked). The backend itself already
  /// 404s a device id that isn't this account's own — see that method's
  /// docblock — so this sends no extra ownership check client-side; a
  /// device this account can see at all in `devices()` above is always one
  /// it's also allowed to revoke. Revoking the *current* device (`is_current`
  /// on the list) is a legitimate action here (a driver device lost /
  /// stolen, still open on the app that took it) — the caller is expected
  /// to fall back to a local logout afterward the same way `logout()` above
  /// already tolerates its own request 401ing (see AuthController.logout's
  /// `on ApiException` comment), since the token this app is using may now
  /// itself be gone.
  Future<void> revokeDevice(int deviceId) => _client.delete('/auth/devices/$deviceId');
}
