/// Mirrors `AuditLogResource` exactly
/// (backend/app/Http/Resources/Api/V1/AuditLogResource.php) — see that
/// class's docblock for why `modelType` is already the short class name
/// (e.g. "FamilyMember") on the wire, not the full namespaced string, and
/// why `user` can be null (a system/console action, or one whose actor was
/// never attached — `AuditLog.user_id` itself is nullable).
class AuditLog {
  const AuditLog({
    required this.id,
    required this.action,
    this.modelType,
    this.modelId,
    this.userName,
    this.ipAddress,
    this.oldValues,
    this.newValues,
    this.createdAt,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map?;

    return AuditLog(
      id: json['id'] as int,
      action: json['action'] as String,
      modelType: json['model_type'] as String?,
      modelId: json['model_id'] as int?,
      userName: user?['name'] as String?,
      ipAddress: json['ip_address'] as String?,
      oldValues: json['old_values'] as Map?,
      newValues: json['new_values'] as Map?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  final int id;
  final String action;
  final String? modelType;
  final int? modelId;
  final String? userName;
  final String? ipAddress;
  final Map? oldValues;
  final Map? newValues;
  final DateTime? createdAt;
}
