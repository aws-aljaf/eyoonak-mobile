import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/admin_roles_providers.dart';
import '../data/admin_user_models.dart';

/// "من يملك هذا الدور" — `RoleController::usersForRole()`
/// (backend/app/Http/Controllers/Api/V1/RoleController.php), verified
/// directly against that controller before building this. Reached only
/// from `AdminRoleDetailScreen`, which already required `settings.manage`
/// to load at all, so this screen carries no permission gate of its own
/// either — `RolePolicy::view()` is what actually enforces it server-side.
///
/// Reuses `AdminUser.fromJson` directly (the endpoint returns
/// `UserResource::collection()`, the identical shape `AdminUsersScreen`
/// already parses) rather than a separate roster model — same reuse call
/// documented on `AdminRolesApi.usersForRole()`. Tapping a row goes to the
/// same `AdminUserDetailScreen` as the main users list.
class AdminRoleUsersScreen extends ConsumerWidget {
  const AdminRoleUsersScreen({super.key, required this.roleId, this.roleName});

  final int roleId;
  final String? roleName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(adminRoleUsersProvider(roleId));

    return Scaffold(
      appBar: AppBar(
        title: Text(roleName != null ? 'مستخدمو "$roleName"' : 'من يملك هذا الدور'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: () => ref.invalidate(adminRoleUsersProvider(roleId)),
          ),
        ],
      ),
      body: usersAsync.when(
        data: (envelope) {
          final items = envelope.data.map((e) => AdminUser.fromJson(Map<String, dynamic>.from(e as Map))).toList();

          return _UsersBody(roleId: roleId, items: items, currentPage: envelope.currentPage, lastPage: envelope.lastPage);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(adminRoleUsersProvider(roleId)),
        ),
      ),
    );
  }
}

class _UsersBody extends ConsumerWidget {
  const _UsersBody({required this.roleId, required this.items, required this.currentPage, required this.lastPage});

  final int roleId;
  final List<AdminUser> items;
  final int currentPage;
  final int lastPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Expanded(
          child: items.isEmpty
              ? LayoutBuilder(
                  builder: (context, constraints) => RefreshIndicator(
                    onRefresh: () async => ref.invalidate(adminRoleUsersProvider(roleId)),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: const Center(child: Text('لا يملك أي مستخدم هذا الدور حاليًا.')),
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async => ref.invalidate(adminRoleUsersProvider(roleId)),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _UserCard(user: items[index]),
                  ),
                ),
        ),
        _PagerBar(roleId: roleId, currentPage: currentPage, lastPage: lastPage),
      ],
    );
  }
}

/// Mirrors the rest of this feature's `_PagerBar`, just driven by the
/// role-keyed `adminRoleUsersPageProvider` family instead of a single
/// global page provider.
class _PagerBar extends ConsumerWidget {
  const _PagerBar({required this.roleId, required this.currentPage, required this.lastPage});

  final int roleId;
  final int currentPage;
  final int lastPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: currentPage > 1
                  ? () => ref.read(adminRoleUsersPageProvider(roleId).notifier).state = currentPage - 1
                  : null,
              icon: const Icon(Icons.chevron_right),
              label: const Text('السابق'),
            ),
            Text('صفحة $currentPage من $lastPage', style: Theme.of(context).textTheme.bodySmall),
            TextButton(
              onPressed: currentPage < lastPage
                  ? () => ref.read(adminRoleUsersPageProvider(roleId).notifier).state = currentPage + 1
                  : null,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text('التالي'), Icon(Icons.chevron_left)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final statusLabel = user.status != null ? userStatusLabels[user.status] ?? user.status! : null;

    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon(user.isSuperAdmin ? Icons.shield_outlined : Icons.person_outline)),
        title: Text(user.name),
        subtitle: Text(user.email),
        trailing: statusLabel != null
            ? Chip(label: Text(statusLabel), visualDensity: VisualDensity.compact)
            : const Icon(Icons.chevron_left),
        onTap: () => context.push('/admin/users/${user.id}'),
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
                  Text('تعذر تحميل قائمة المستخدمين: $message', textAlign: TextAlign.center),
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
