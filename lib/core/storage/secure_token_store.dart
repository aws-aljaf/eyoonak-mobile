import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the Sanctum token + the stable `device_uuid` this app
/// registered with (module 25 — "Remember Device"). Backed by the
/// platform keystore/keychain via flutter_secure_storage, never plain
/// SharedPreferences — a Sanctum token is a bearer credential.
class SecureTokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'auth.sanctum_token';
  static const _deviceUuidKey = 'auth.device_uuid';
  static const _driverIdKey = 'auth.driver_id';

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);

  Future<void> clearToken() => _storage.delete(key: _tokenKey);

  /// A device_uuid, once generated, is kept forever on this install so
  /// re-logging in always "remembers" the same device row on the backend
  /// (DeviceService::issue upserts by device_uuid) instead of piling up a
  /// new `devices` row every time the app is reopened.
  Future<String?> readDeviceUuid() => _storage.read(key: _deviceUuidKey);

  Future<void> saveDeviceUuid(String uuid) => _storage.write(key: _deviceUuidKey, value: uuid);

  Future<int?> readDriverId() async {
    final raw = await _storage.read(key: _driverIdKey);

    return raw == null ? null : int.tryParse(raw);
  }

  Future<void> saveDriverId(int? driverId) {
    if (driverId == null) {
      return _storage.delete(key: _driverIdKey);
    }

    return _storage.write(key: _driverIdKey, value: driverId.toString());
  }

  Future<void> clearAll() => _storage.deleteAll();
}
