/// Mirrors `RoleResource` (backend/app/Http/Resources/Api/V1/RoleResource.php)
/// exactly, verified directly against that resource before building this —
/// reached only by an account with `settings.manage` via `AdminHomeScreen`'s
/// "الأدوار والصلاحيات" tile. `permissions` is the flat list of permission
/// keys this role grants (e.g. `vehicles.view`) — `RoleController` always
/// eager-loads it (`with('permissions:id,key')`) on both `index()` and
/// `show()`, so it is never absent here the way a `whenLoaded()` field
/// could be.
class AdminRole {
  const AdminRole({
    required this.id,
    this.companyId,
    this.name = '',
    this.nameAr,
    this.slug = '',
    this.isSystemDefault = false,
    this.isEditable = false,
    this.description,
    this.permissions = const [],
    this.createdAt,
  });

  factory AdminRole.fromJson(Map<String, dynamic> json) {
    final permissionsJson = json['permissions'] as List<dynamic>? ?? const [];

    return AdminRole(
      id: json['id'] as int,
      companyId: json['company_id'] as int?,
      name: json['name'] as String? ?? '',
      nameAr: json['name_ar'] as String?,
      slug: json['slug'] as String? ?? '',
      isSystemDefault: json['is_system_default'] as bool? ?? false,
      // `RoleResource` derives this from `company_id !== null` server-side
      // rather than persisting a separate column — read here as a plain
      // boolean either way, no need to re-derive it client-side too.
      isEditable: json['is_editable'] as bool? ?? false,
      description: json['description'] as String?,
      permissions: permissionsJson.map((e) => e as String).toList(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  final int id;
  final int? companyId;
  final String name;
  final String? nameAr;
  final String slug;
  final bool isSystemDefault;
  final bool isEditable;
  final String? description;
  final List<String> permissions;
  final DateTime? createdAt;

  String get displayName => (nameAr != null && nameAr!.isNotEmpty) ? nameAr! : name;
}

/// Mirrors `PermissionResource`
/// (backend/app/Http/Resources/Api/V1/PermissionResource.php) exactly — one
/// row per entry in the platform-wide, fixed catalogue seeded by
/// `PermissionsSeeder` (never re-run per company; every role picks a subset
/// of these same keys).
class AdminPermission {
  const AdminPermission({required this.id, required this.key, required this.module, this.descriptionAr, this.descriptionEn});

  factory AdminPermission.fromJson(Map<String, dynamic> json) {
    return AdminPermission(
      id: json['id'] as int,
      key: json['key'] as String,
      module: json['module'] as String,
      descriptionAr: json['description_ar'] as String?,
      descriptionEn: json['description_en'] as String?,
    );
  }

  final int id;
  final String key;
  final String module;
  final String? descriptionAr;
  final String? descriptionEn;
}

/// UI-only Arabic module-group headers for `AdminRoleDetailScreen`'s
/// permission checklist — mirrors `PermissionsSeeder::$moduleNamesAr`
/// exactly (backend/database/seeders/PermissionsSeeder.php). Duplicated
/// here rather than fetched, same call as `tripStatusLabels`/
/// `driverStatusLabels`: `PermissionResource` already returns each
/// permission's own `description_ar` fully formed (e.g. "عرض المركبات"),
/// so this map is purely for grouping section headers, not a source of
/// truth for any permission's own label.
const Map<String, String> permissionModuleLabels = {
  'branches': 'الفروع',
  'users': 'المستخدمون',
  'settings': 'الإعدادات',
  'vehicles': 'المركبات',
  'drivers': 'السائقون',
  'customers': 'العملاء',
  'trips': 'الرحلات',
  'shipments': 'الشحنات',
  'maintenance': 'الصيانة',
  'fuel': 'الوقود',
  'expenses': 'المصاريف',
  'accidents': 'الحوادث',
  'geofences': 'المناطق الجغرافية',
  'tracking': 'التتبع',
  'family_tracking': 'تتبع العائلة',
  'alerts': 'التنبيهات',
  'sos': 'الاستغاثة',
  'reports': 'التقارير',
  'notifications': 'الإشعارات',
  'subscription': 'الاشتراك',
  'audit_logs': 'سجل العمليات',
};
