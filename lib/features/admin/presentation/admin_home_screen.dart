import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';

/// Entry point into the "merge the fleet-admin web dashboard into this same
/// app" initiative — reached by an account with `DriverUser
/// .hasManagementAccess` that lands here directly (a pure office/RBAC
/// account with no driver profile and no family membership, see
/// `router.dart`'s `_landingRoute`), or via the "الإدارة" icon on
/// `HomeShell`/`FamilyHomeScreen` for an account that also holds a
/// driver/family role.
///
/// Deliberately lists ONLY sections that actually have a built screen
/// behind them (audit logs, vehicles, drivers, trips, users, roles &
/// permissions, reports, live tracking today) as real, tappable tiles —
/// every other RBAC module the web dashboard exposes is shown below as a
/// disabled "قريبًا" placeholder, ONLY for a permission this account
/// actually holds, so the roadmap is visible without ever linking to a
/// screen that doesn't exist yet — this project's established "never
/// fabricate a capability" rule applies to UI affordances too, not just
/// data. There is currently no RBAC module left in that "قريبًا" state —
/// `upcoming` below stays as scaffolding for whatever comes next.
///
/// **Reports are read-only for now** (`AdminReportsScreen`) — the six
/// `GET /reports/{type}` views only; `POST /reports/export` (queued
/// PDF/Excel/CSV generation) is deferred to a separate follow-up piece,
/// same incremental "view first, write later" discipline as every other
/// module here — see `AdminReportsApi`'s own docblock.
///
/// **Live tracking (`AdminTrackingScreen`)** is a whole-company map of
/// every vehicle's last-known position, polled on a timer rather than
/// pushed over a websocket — see `AdminTrackingApi`'s own docblock for why
/// (no Echo/Pusher client dependency in this app yet).
///
/// **Users/Roles are read-only for now** (`AdminUsersScreen`/
/// `AdminRolesScreen`) — same incremental scope as vehicles/drivers/trips
/// before them, but this module is flagged in
/// `claude/admin-unification-plan.md` as the highest-sensitivity one
/// (editing another account's status/roles/permissions), so every write
/// action (`create`/`edit`/`delete`/`suspend`/`reactivate`/
/// `reset-password`/`force-logout`/`assign-roles` on `UserController`,
/// `create`/`edit`/`delete` on `RoleController`) is deliberately deferred
/// to a separate follow-up piece once a careful confirmation UX is
/// designed for it — see `AdminUsersApi`/`AdminRolesApi`'s own docblocks.
///
/// **Correction (verified directly against the backend before building
/// the vehicles tile above)**: an earlier version of this docblock claimed
/// `LogsAudit` (backend/app/Models/Concerns/LogsAudit.php) wasn't `use`d
/// by any model, based on a grep for the literal string `"use LogsAudit"`.
/// That pattern never matches this codebase's actual trait-usage syntax —
/// every model combines multiple traits in one statement
/// (`use BelongsToCompany, HasFactory, LogsAudit, SoftDeletes;`), which
/// contains "LogsAudit" but never "use LogsAudit" as an exact substring.
/// Re-checked properly (grep for "LogsAudit" alone, then read the actual
/// `use` statements): the trait has been attached to `Vehicle`, `Driver`,
/// `User`, `Role`, and most other models since Phase 1/2 of this project,
/// long before this initiative started. `audit_logs` is not empty, and no
/// backend change was needed here — the earlier "known gap" note was a
/// false alarm from a bad grep pattern, not a real one.
class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(authControllerProvider).user?.permissions ?? const [];

    final upcoming = <_UpcomingSection>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإدارة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (permissions.contains('vehicles.view'))
            Card(
              child: ListTile(
                leading: const Icon(Icons.local_shipping_outlined),
                title: const Text('المركبات'),
                subtitle: const Text('قائمة مركبات الشركة وتفاصيلها'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => context.push('/admin/vehicles'),
              ),
            ),
          if (permissions.contains('drivers.view'))
            Card(
              child: ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('السائقون'),
                subtitle: const Text('قائمة سائقي الشركة وتفاصيلهم'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => context.push('/admin/drivers'),
              ),
            ),
          if (permissions.contains('trips.view'))
            Card(
              child: ListTile(
                leading: const Icon(Icons.route_outlined),
                title: const Text('إدارة الرحلات'),
                subtitle: const Text('كل رحلات الشركة وتفاصيلها'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => context.push('/admin/trips'),
              ),
            ),
          if (permissions.contains('users.view'))
            Card(
              child: ListTile(
                leading: const Icon(Icons.people_outline),
                title: const Text('المستخدمون'),
                subtitle: const Text('حسابات موظفي الشركة وأدوارهم'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => context.push('/admin/users'),
              ),
            ),
          if (permissions.contains('settings.manage'))
            Card(
              child: ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text('الأدوار والصلاحيات'),
                subtitle: const Text('الأدوار المتاحة وما يملكه كل دور من صلاحيات'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => context.push('/admin/roles'),
              ),
            ),
          if (permissions.contains('audit_logs.view'))
            Card(
              child: ListTile(
                leading: const Icon(Icons.fact_check_outlined),
                title: const Text('سجل العمليات'),
                subtitle: const Text('كل التغييرات المسجَّلة على بيانات الشركة'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => context.push('/admin/audit-logs'),
              ),
            ),
          if (permissions.contains('reports.view'))
            Card(
              child: ListTile(
                leading: const Icon(Icons.bar_chart_outlined),
                title: const Text('التقارير'),
                subtitle: const Text('تقارير الأسطول والسائقين والرحلات والوقود والصيانة والمالية'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => context.push('/admin/reports'),
              ),
            ),
          if (permissions.contains('tracking.view'))
            Card(
              child: ListTile(
                leading: const Icon(Icons.map_outlined),
                title: const Text('التتبع الحي'),
                subtitle: const Text('مواقع كل مركبات الشركة على الخريطة الآن'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => context.push('/admin/tracking'),
              ),
            ),
          if (upcoming.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 16, 4, 4),
              child: Text('قريبًا', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (final section in upcoming)
              Opacity(
                opacity: 0.5,
                child: Card(
                  child: ListTile(
                    leading: Icon(section.icon),
                    title: Text(section.label),
                    trailing: const Chip(label: Text('قريبًا'), visualDensity: VisualDensity.compact),
                    enabled: false,
                  ),
                ),
              ),
          ],
          if (!permissions.contains('vehicles.view') &&
              !permissions.contains('drivers.view') &&
              !permissions.contains('trips.view') &&
              !permissions.contains('users.view') &&
              !permissions.contains('settings.manage') &&
              !permissions.contains('audit_logs.view') &&
              !permissions.contains('reports.view') &&
              !permissions.contains('tracking.view') &&
              upcoming.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('لا توجد صلاحيات إدارية مفعّلة على هذا الحساب بعد.')),
            ),
        ],
      ),
    );
  }
}

class _UpcomingSection {
  const _UpcomingSection({required this.label, required this.icon});

  final String label;
  final IconData icon;
}
