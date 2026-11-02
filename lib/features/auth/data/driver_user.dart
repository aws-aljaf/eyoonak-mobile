/// Mirrors `UserResource` (backend/app/Http/Resources/Api/V1/UserResource.php).
/// `driverId`/`permissions` are only ever populated from `GET /auth/me` —
/// see that resource's docblock on why it's safe to trust (never
/// client-supplied).
///
/// The class name (and `isDriver`) predate the family feature — this app
/// was originally driver-only (module 25). Kept as-is rather than renamed
/// to avoid a churn-only diff across every file that reads `.driverId`;
/// what changed is that a driver profile is no longer the ONLY way an
/// account is allowed to use this app — see `hasFamilyAccess` below and
/// AuthController._afterAuthenticated().
class DriverUser {
  const DriverUser({
    required this.id,
    required this.name,
    this.companyId,
    this.email,
    this.phone,
    this.driverId,
    this.permissions = const [],
    this.hasFamilyMembership = false,
    this.isSuperAdmin = false,
    this.familyGender,
  });

  factory DriverUser.fromJson(Map<String, dynamic> json) {
    return DriverUser(
      id: json['id'] as int,
      hasFamilyMembership: json['has_family_membership'] == true,
      isSuperAdmin: json['is_super_admin'] == true,
      name: json['name'] as String,
      familyGender: const ['male','female'].contains(json['family_gender']) ? json['family_gender'] as String : null,
      // A self-registered family account (FamilyOnboardingService) has no
      // company at all — `company_id` is genuinely null on the wire for
      // it, not merely absent. Must stay nullable: the old `as int` cast
      // here threw a type error for every family-only login.
      companyId: json['company_id'] as int?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      driverId: json['driver_id'] as int?,
      permissions: (json['permissions'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  final int id;
  final bool hasFamilyMembership;
  final bool isSuperAdmin;
  final String name;
  final String? familyGender;
  final int? companyId;
  final String? email;
  final String? phone;
  final int? driverId;
  final List<String> permissions;

  /// This account has a linked driver profile — the original (still
  /// primary) use of this app.
  bool get isDriver => !isSuperAdmin && driverId != null;

  /// This account can use the family-tracking side of the app — mirrors
  /// the web app's own gate (`family_tracking.view` hides the entire
  /// "العائلة" sidebar group, see AppLayout.vue) plus `sos.view`, since an
  /// account limited to viewing SOS history alone (no general roster
  /// access) still has a legitimate reason to open the family screen.
  /// Note this does NOT gate the SOS *trigger* itself — FamilyMemberPolicy
  /// ::triggerSos() deliberately has no permission check at all (a safety
  /// action must work regardless of what an admin has or hasn't granted).
  bool get hasFamilyAccess =>
      !isSuperAdmin &&
      (hasFamilyMembership || permissions.contains('family_tracking.view') || permissions.contains('sos.view'));

  /// This account can use the new admin/management side of the app (the
  /// former web-only fleet dashboard, now being folded into this same app
  /// — see `AdminHomeScreen`'s docblock). Deliberately a broad "holds ANY
  /// one of these" check, not an exhaustive list of every RBAC permission
  /// this backend defines: it only needs to recognize an account that has
  /// *some* legitimate reason to see the admin entry point at all —
  /// per-section visibility inside `AdminHomeScreen` (and per-action
  /// visibility inside each section's own screen) is what actually gates
  /// what such an account can do, exactly like `hasFamilyAccess` above
  /// only gates reaching `/family` at all, not what's visible inside it.
  /// Kept to permissions this app actually has a built screen for
  /// (`audit_logs.view` today) plus the other RBAC modules named in the
  /// web dashboard's own sidebar groups (`AppLayout.vue`) that this
  /// initiative intends to port next — so an account that will clearly
  /// need this entry point soon isn't rejected at login only to need it
  /// added back permission-by-permission later.
  bool get hasManagementAccess =>
      isSuperAdmin ||
      permissions.any(
        (p) => const {
          'tracking.view',
          'vehicles.view',
          'drivers.view',
          'trips.view',
          'users.view',
          'settings.manage',
          'reports.view',
          'audit_logs.view',
        }.contains(p),
      );

  /// Neither a driver profile, nor any family permission, nor any
  /// management permission — nothing in this app applies to this account.
  bool get hasNoAppAccess => !isDriver && !hasFamilyAccess && !hasManagementAccess;
}
