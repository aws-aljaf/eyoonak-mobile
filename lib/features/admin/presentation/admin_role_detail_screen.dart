import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../application/admin_roles_providers.dart';
import '../data/admin_role_models.dart';

/// Full detail view for one role — reached only by tapping a row on
/// `AdminRolesScreen`, which already required `settings.manage` to load at
/// all, so (same "the request is the gate" convention as every other
/// screen in this app) this screen has no permission gate of its own
/// either for *viewing*; `RoleController::show()`/`RolePolicy::view()` are
/// what actually enforce it server-side.
///
/// Shows the full permission catalogue (`GET /permissions`) grouped by
/// module, with this role's own `permissions` list used only to mark which
/// ones are granted — a read-only checklist here; editing the permission
/// set happens on `AdminRoleFormScreen` instead (see that screen's own
/// docblock for why permission-editing lives inside the same form as the
/// basic fields rather than a separate screen, unlike a user's roles).
///
/// The edit/delete actions below are gated on `role.isEditable`
/// (`RolePolicy::update()`'s own `company_id !== null` check, verified
/// directly — the shared system-default templates can never be mutated by
/// anyone via this API) and, for delete specifically, also
/// `!role.isSystemDefault` (`RolePolicy::delete()`'s extra check — in
/// practice always `false` already once `isEditable` is `true`, since
/// `RoleController::store()` forces `is_system_default = false` on every
/// company-created role, but replicated here to match the policy exactly
/// rather than relying on that being true today).
class AdminRoleDetailScreen extends ConsumerWidget {
  const AdminRoleDetailScreen({super.key, required this.roleId});

  final int roleId;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, AdminRole role) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الدور'),
        content: Text(
          'هل أنت متأكد من حذف دور "${role.displayName}"؟ '
          'سيُزال هذا الدور فورًا من كل مستخدم يحمله حاليًا — لا يوجد تحقق من عدد '
          'المستخدمين المرتبطين به قبل الحذف، ولا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      await ref.read(adminRolesApiProvider).delete(role.id);
      ref.invalidate(adminRolesProvider);

      if (context.mounted) {
        context.pop();
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حذف الدور: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleAsync = ref.watch(adminRoleDetailProvider(roleId));
    final role = roleAsync.valueOrNull;
    final permissions = ref.watch(authControllerProvider).user?.permissions ?? const [];
    // Each flag independently re-checks `role != null` (rather than
    // `canDelete` being built as `canEdit && ...`) — same convention
    // `AdminTripDetailScreen` established for `canEdit`/`canCancel` in
    // PR #77, after CI proved a local `final` variable only promotes
    // reliably when the SAME expression's own `&&` chain demonstrates the
    // null check, not when a later expression merely reuses another
    // boolean's already-established truth.
    final canEdit = permissions.contains('settings.manage') && role != null && role.isEditable;
    final canDelete =
        permissions.contains('settings.manage') && role != null && role.isEditable && !role.isSystemDefault;

    return Scaffold(
      appBar: AppBar(
        title: Text(role?.displayName ?? 'تفاصيل الدور'),
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'تعديل الدور',
              onPressed: () async {
                final saved = await context.push<bool>('/admin/roles/${role.id}/edit', extra: role);
                if (saved == true) {
                  ref.invalidate(adminRoleDetailProvider(roleId));
                  ref.invalidate(adminRolesProvider);
                }
              },
            ),
          if (canDelete)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'حذف الدور',
              onPressed: () => _confirmDelete(context, ref, role),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: () {
              ref.invalidate(adminRoleDetailProvider(roleId));
              ref.invalidate(adminPermissionsCatalogProvider);
            },
          ),
        ],
      ),
      body: roleAsync.when(
        data: (role) => _DetailBody(role: role),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(adminRoleDetailProvider(roleId)),
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.role});

  final AdminRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(adminPermissionsCatalogProvider);
    final grantedKeys = role.permissions.toSet();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: Text(role.displayName, style: Theme.of(context).textTheme.headlineSmall)),
            if (role.isSystemDefault) const Chip(label: Text('قالب افتراضي')),
          ],
        ),
        if (role.description != null) ...[
          const SizedBox(height: 4),
          Text(role.description!, style: Theme.of(context).textTheme.bodyMedium),
        ],
        const SizedBox(height: 4),
        Text(
          role.isEditable ? 'قابل للتعديل من قِبل شركتك' : 'قالب مشترك للقراءة فقط',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.groups_outlined),
            title: const Text('من يملك هذا الدور'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => context.push('/admin/roles/${role.id}/users'),
          ),
        ),
        const SizedBox(height: 12),
        Text('الصلاحيات (${grantedKeys.length})', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        catalogAsync.when(
          data: (catalog) => _PermissionsChecklist(catalog: catalog, grantedKeys: grantedKeys),
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => Text('تعذر تحميل قائمة الصلاحيات: $error', style: const TextStyle(color: Colors.red)),
        ),
      ],
    );
  }
}

class _PermissionsChecklist extends StatelessWidget {
  const _PermissionsChecklist({required this.catalog, required this.grantedKeys});

  final Map<String, List<AdminPermission>> catalog;
  final Set<String> grantedKeys;

  @override
  Widget build(BuildContext context) {
    final modules = catalog.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final module in modules)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    permissionModuleLabels[module] ?? module,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  for (final permission in catalog[module]!) _PermissionRow(permission: permission, granted: grantedKeys.contains(permission.key)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.permission, required this.granted});

  final AdminPermission permission;
  final bool granted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            granted ? Icons.check_circle : Icons.remove_circle_outline,
            size: 18,
            color: granted ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              permission.descriptionAr ?? permission.key,
              style: TextStyle(color: granted ? null : Colors.grey),
            ),
          ),
        ],
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
                  Text('تعذر تحميل بيانات الدور: $message', textAlign: TextAlign.center),
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
