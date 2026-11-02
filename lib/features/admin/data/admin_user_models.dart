/// Full admin-facing view of `UserResource`
/// (backend/app/Http/Resources/Api/V1/UserResource.php), verified directly
/// against that resource before building this — reached only by an account
/// with `users.view` via `AdminHomeScreen`'s "المستخدمون" tile.
///
/// **Two fields `UserResource` returns are deliberately absent here**:
/// `permissions` (the effective permission-key list) and `driver_id` — both
/// are gated server-side by `$request->routeIs('api.v1.auth.me')`, i.e.
/// only ever populated for the caller's own profile (`GET /auth/me`), never
/// for `GET /users`/`GET /users/{id}` regardless of the caller's own
/// permissions. `roles` (role slugs) is what this screen shows instead —
/// enough to know *which* roles a user holds; the permissions those roles
/// grant are one tap away on `AdminRoleDetailScreen`.
class AdminUser {
  const AdminUser({
    required this.id,
    this.companyId,
    this.branchId,
    this.branchName,
    this.name = '',
    this.email = '',
    this.phone,
    this.avatarPath,
    this.locale,
    this.status,
    this.isSuperAdmin = false,
    this.twoFactorEnabled = false,
    this.lastLoginAt,
    this.roles = const [],
    this.createdAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    final branch = json['branch'] as Map<String, dynamic>?;
    final rolesJson = json['roles'] as List<dynamic>? ?? const [];

    return AdminUser(
      id: json['id'] as int,
      companyId: json['company_id'] as int?,
      branchId: json['branch_id'] as int?,
      branchName: branch?['name'] as String?,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      avatarPath: json['avatar_path'] as String?,
      locale: json['locale'] as String?,
      status: json['status'] as String?,
      isSuperAdmin: json['is_super_admin'] as bool? ?? false,
      twoFactorEnabled: json['two_factor_enabled'] as bool? ?? false,
      lastLoginAt: json['last_login_at'] != null ? DateTime.tryParse(json['last_login_at'] as String) : null,
      roles: rolesJson.map((e) => e as String).toList(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  final int id;
  final int? companyId;
  final int? branchId;
  final String? branchName;
  final String name;
  final String email;
  final String? phone;
  final String? avatarPath;
  final String? locale;
  final String? status;
  final bool isSuperAdmin;
  final bool twoFactorEnabled;
  final DateTime? lastLoginAt;
  final List<String> roles;
  final DateTime? createdAt;
}

/// Mirrors the `status` enum on the `users` table exactly
/// (`database/migrations/2024_01_01_000003_add_tenant_fields_to_users_table.php`:
/// `enum('status', ['active', 'suspended', 'invited'])`).
const Map<String, String> userStatusLabels = {
  'active': 'نشط',
  'suspended': 'موقوف',
  'invited': 'مدعو (لم يُفعّل الحساب بعد)',
};
