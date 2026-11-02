import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../application/admin_users_providers.dart';
import '../data/admin_user_models.dart';

/// "المستخدمون" — `UserController::index()`
/// (backend/app/Http/Controllers/Api/V1/UserController.php), verified
/// directly against that controller/`UserPolicy`/`UserResource` before
/// building this.
///
/// **No permission gate on this screen or route itself for viewing** — same
/// "the request is the gate" convention as every other admin screen:
/// `UserPolicy::viewAny()` (`users.view`) is what actually enforces
/// access, and the only entry point (`AdminHomeScreen`) never renders the
/// tile that reaches here unless that permission is already present.
///
/// **The "+" FAB is the one exception** — `users.create` is a separate
/// permission from `users.view` (verified against `UserPolicy` before
/// building this), same pattern `AdminVehiclesScreen`'s own FAB established
/// for `vehicles.create` vs `vehicles.view`. The rest of the write surface
/// (edit/roles/suspend/reactivate/reset-password/force-logout/delete) lives
/// on `AdminUserDetailScreen` instead — see `AdminUsersApi`'s docblock for
/// the full picture of what's gated where.
///
/// **Real prev/next pagination**, mirroring the rest of this feature
/// exactly.
class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(adminUsersProvider);
    final permissions = ref.watch(authControllerProvider).user?.permissions ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('المستخدمون'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: () => ref.invalidate(adminUsersProvider),
          ),
        ],
      ),
      floatingActionButton: permissions.contains('users.create')
          ? FloatingActionButton(
              tooltip: 'إضافة مستخدم',
              onPressed: () async {
                final created = await context.push<bool>('/admin/users/new');

                if (created == true) {
                  ref.invalidate(adminUsersProvider);
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          const _FilterBar(),
          Expanded(
            child: usersAsync.when(
              data: (envelope) {
                final items =
                    envelope.data.map((e) => AdminUser.fromJson(Map<String, dynamic>.from(e as Map))).toList();

                return _UsersBody(items: items, currentPage: envelope.currentPage, lastPage: envelope.lastPage);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _ErrorState(
                message: error.toString(),
                onRetry: () => ref.invalidate(adminUsersProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends ConsumerStatefulWidget {
  const _FilterBar();

  @override
  ConsumerState<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends ConsumerState<_FilterBar> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applySearch(String value) {
    ref.read(adminUsersSearchFilterProvider.notifier).state = value.trim().isEmpty ? null : value.trim();
    ref.read(adminUsersPageProvider.notifier).state = 1;
  }

  void _setStatus(String? status) {
    ref.read(adminUsersStatusFilterProvider.notifier).state = status;
    ref.read(adminUsersPageProvider.notifier).state = 1;
  }

  @override
  Widget build(BuildContext context) {
    final selectedStatus = ref.watch(adminUsersStatusFilterProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'بحث',
              hintText: 'الاسم أو البريد الإلكتروني أو الهاتف',
              isDense: true,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                tooltip: 'بحث',
                onPressed: () => _applySearch(_searchController.text),
              ),
            ),
            onSubmitted: _applySearch,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ChoiceChip(
                    label: const Text('الكل'),
                    selected: selectedStatus == null,
                    onSelected: (_) => _setStatus(null),
                  ),
                ),
                for (final entry in userStatusLabels.entries)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ChoiceChip(
                      label: Text(entry.value),
                      selected: selectedStatus == entry.key,
                      onSelected: (_) => _setStatus(entry.key),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _UsersBody extends ConsumerWidget {
  const _UsersBody({required this.items, required this.currentPage, required this.lastPage});

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
                    onRefresh: () async => ref.invalidate(adminUsersProvider),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: const Center(child: Text('لا يوجد مستخدمون مطابقون.')),
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async => ref.invalidate(adminUsersProvider),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _UserCard(user: items[index]),
                  ),
                ),
        ),
        _PagerBar(currentPage: currentPage, lastPage: lastPage),
      ],
    );
  }
}

/// Mirrors the rest of this feature's `_PagerBar` exactly.
class _PagerBar extends ConsumerWidget {
  const _PagerBar({required this.currentPage, required this.lastPage});

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
                  ? () => ref.read(adminUsersPageProvider.notifier).state = currentPage - 1
                  : null,
              icon: const Icon(Icons.chevron_right),
              label: const Text('السابق'),
            ),
            Text('صفحة $currentPage من $lastPage', style: Theme.of(context).textTheme.bodySmall),
            TextButton(
              onPressed: currentPage < lastPage
                  ? () => ref.read(adminUsersPageProvider.notifier).state = currentPage + 1
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
        subtitle: Text([
          user.email,
          if (user.roles.isNotEmpty) user.roles.join('، '),
        ].join(' • ')),
        isThreeLine: user.roles.isNotEmpty,
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
