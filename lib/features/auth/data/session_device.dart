/// Mirrors `DeviceResource` (backend/app/Http/Resources/Api/V1/DeviceResource.php)
/// exactly as returned by `GET /auth/devices`. One row per still-active
/// (non-revoked) `Device` this account has ever logged in from — the
/// backend already filters `is_revoked = false` and marks `is_current`
/// itself (comparing against the token this very request authenticated
/// with), so this model does no filtering of its own.
class SessionDevice {
  const SessionDevice({
    required this.id,
    required this.deviceUuid,
    required this.deviceName,
    required this.platform,
    required this.appVersion,
    required this.lastLoginAt,
    required this.lastActiveAt,
    required this.lastIp,
    required this.isCurrent,
    required this.familyMemberName,
  });

  factory SessionDevice.fromJson(Map<String, dynamic> json) {
    // `family_member` is only ever present for a device paired via a
    // pairing code (PR-E) — see DeviceResource's own docblock. Absent
    // (rather than null) for every ordinary fleet/company or plain family
    // account device, so this reads it defensively either way.
    final familyMember = json['family_member'] as Map<String, dynamic>?;

    return SessionDevice(
      id: json['id'] as int,
      deviceUuid: json['device_uuid'] as String?,
      deviceName: json['device_name'] as String?,
      platform: json['platform'] as String?,
      appVersion: json['app_version'] as String?,
      lastLoginAt: json['last_login_at'] as String?,
      lastActiveAt: json['last_active_at'] as String?,
      lastIp: json['last_ip'] as String?,
      isCurrent: json['is_current'] as bool? ?? false,
      familyMemberName: familyMember?['full_name'] as String?,
    );
  }

  final int id;
  final String? deviceUuid;
  final String? deviceName;
  final String? platform;
  final String? appVersion;
  final String? lastLoginAt;
  final String? lastActiveAt;
  final String? lastIp;
  final bool isCurrent;

  /// Set only when this device was paired (device-pairing QR/code flow) to
  /// a tracked family member rather than logged into directly — see
  /// DeviceResource's docblock. Null for every ordinary login.
  final String? familyMemberName;
}
