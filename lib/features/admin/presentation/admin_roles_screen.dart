import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../application/admin_roles_providers.dart';
import '../data/admin_role_models.dart';

/// "الأدوار والصلاحيات" — `RoleController::index()`
/// (backend/app/Http/Controllers/Api/V1/RoleController.php), verified
/// directly against that controller/`RolePolicy`/`RoleResource` before
/// building this. List + detail + a role's user roster, plus create/edit/
/// delete — see `AdminRolesApi`'s docblock for the full write-action
/// picture (the last, most-sensitive slice of the admin-unification
/// initiative).
///
/// **No permission gate on this screen or route itself for viewing** —
/// same "the request is the gate" convention as every other admin screen:
/// `RolePolicy::viewAny()` (`settings.manage`) is what actually enforces
/// access, and the only entry point (`AdminHomeScreen`) never renders the
/// tile that reaches here unless that permission is already present.
///
/// **The "+" FAB is gated on `settings.manage` too** — unlike
/// `AdminUsersScreen`/`AdminVehiclesScreen` (where `*.create` is a
/// genuinely separate permission from `*.view`), `RolePolicy::create()`
/// requires the exact same `settings.manage` permission as `viewAny()`
/// (verified directly) — there is no narrower "can create roles but not
/// see them" permission in this system, so the FAB is effectively always
/// visible once this screen is reachable at all. Still checked explicitly
/// rather than assumed, for consistency with every other admin screen's
/// FAB gate.
///
/// **No pagination here** — unlike every other list in this feature, the
/// backend itself never paginates `GET /roles` (a company's own custom
/// roles plus a handful of shared system-default templates is always a
/// small list), so `adminRolesProvider` is a plain, non-paged
/// `FutureProvider`.
class AdminRolesScreen extends ConsumerWidget {
  const AdminRolesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rolesAsync = ref.watch(adminRolesProvider);
    final permissions = ref.watch(authControllerProvider).user?.permissions ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('الأدوار والصلاحيات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: () => ref.invalidate(adminRolesProvider),
          ),
        ],
      ),
      floatingActionButton: permissions.contains('settings.manage')
          ? FloatingActionButton(
              tooltip: 'إضافة دور',
              onPressed: () async {
                final created = await context.push<bool>('/admin/roles/new');

                if (created == true) {
                  ref.invalidate(adminRolesProvider);
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
      body: rolesAsync.when(
        data: (roles) {
          if (roles.isEmpty) {
            return const Center(child: Text('لا توجد أدوار مُعرَّفة بعد.'));
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(adminRolesProvider),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: roles.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _RoleCard(role: roles[index]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(adminRolesProvider),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role});

  final AdminRole role;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(role.isSystemDefault ? Icons.verified_outlined : Icons.badge_outlined),
        title: Text(role.displayName),
        subtitle: Text('${role.permissions.length} صلاحية${role.isSystemDefault ? ' • قالب افتراضي' : ''}'),
        trailing: const Icon(Icons.chevron_left),
        onTap: () => context.push('/admin/roles/${role.id}'),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('تعذر تحميل قائمة الأدوار: $message', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
