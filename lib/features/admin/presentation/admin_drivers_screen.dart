import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../application/admin_drivers_providers.dart';
import '../data/admin_driver_models.dart';

/// "السائقون" — `DriverController::index()`
/// (backend/app/Http/Controllers/Api/V1/Fleet/DriverController.php),
/// verified directly against that controller/`DriverPolicy`/
/// `DriverResource` before building this.
///
/// **No permission gate on this screen or route itself for viewing** —
/// same "the request is the gate" convention as `AdminVehiclesScreen`:
/// `DriverPolicy::viewAny()` (`drivers.view`) is what actually enforces
/// access, and the only entry point (`AdminHomeScreen`) never renders the
/// tile that reaches here unless that permission is already present.
///
/// **The "+" FAB is the one exception** — `drivers.create` is a separate
/// permission from `drivers.view` (verified against `DriverPolicy` before
/// building this), same pattern `AdminVehiclesScreen`'s own FAB
/// established for `vehicles.create` vs `vehicles.view`. The rest of the
/// write surface (edit/delete) lives on `AdminDriverDetailScreen` instead
/// — see `AdminDriversApi`'s docblock for the full picture of what's
/// gated where.
///
/// **Real prev/next pagination**, mirroring `AdminVehiclesScreen` exactly.
class AdminDriversScreen extends ConsumerWidget {
  const AdminDriversScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driversAsync = ref.watch(adminDriversProvider);
    final permissions = ref.watch(authControllerProvider).user?.permissions ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('السائقون'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: () => ref.invalidate(adminDriversProvider),
          ),
        ],
      ),
      floatingActionButton: permissions.contains('drivers.create')
          ? FloatingActionButton(
              tooltip: 'إضافة سائق',
              onPressed: () async {
                final created = await context.push<bool>('/admin/drivers/new');

                if (created == true) {
                  ref.invalidate(adminDriversProvider);
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          const _FilterBar(),
          Expanded(
            child: driversAsync.when(
              data: (envelope) {
                final items = envelope.data
                    .map((e) => AdminDriver.fromJson(Map<String, dynamic>.from(e as Map)))
                    .toList();

                return _DriversBody(items: items, currentPage: envelope.currentPage, lastPage: envelope.lastPage);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _ErrorState(
                message: error.toString(),
                onRetry: () => ref.invalidate(adminDriversProvider),
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
    ref.read(adminDriversSearchFilterProvider.notifier).state = value.trim().isEmpty ? null : value.trim();
    ref.read(adminDriversPageProvider.notifier).state = 1;
  }

  void _setStatus(String? status) {
    ref.read(adminDriversStatusFilterProvider.notifier).state = status;
    ref.read(adminDriversPageProvider.notifier).state = 1;
  }

  @override
  Widget build(BuildContext context) {
    final selectedStatus = ref.watch(adminDriversStatusFilterProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'بحث',
              hintText: 'الاسم أو رقم الهاتف',
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
                for (final entry in driverStatusLabels.entries)
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

class _DriversBody extends ConsumerWidget {
  const _DriversBody({required this.items, required this.currentPage, required this.lastPage});

  final List<AdminDriver> items;
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
                    onRefresh: () async => ref.invalidate(adminDriversProvider),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: const Center(child: Text('لا يوجد سائقون مطابقون.')),
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async => ref.invalidate(adminDriversProvider),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _DriverCard(driver: items[index]),
                  ),
                ),
        ),
        _PagerBar(currentPage: currentPage, lastPage: lastPage),
      ],
    );
  }
}

/// Mirrors `AdminVehiclesScreen`'s `_PagerBar` exactly.
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
                  ? () => ref.read(adminDriversPageProvider.notifier).state = currentPage - 1
                  : null,
              icon: const Icon(Icons.chevron_right),
              label: const Text('السابق'),
            ),
            Text('صفحة $currentPage من $lastPage', style: Theme.of(context).textTheme.bodySmall),
            TextButton(
              onPressed: currentPage < lastPage
                  ? () => ref.read(adminDriversPageProvider.notifier).state = currentPage + 1
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

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.driver});

  final AdminDriver driver;

  @override
  Widget build(BuildContext context) {
    final statusLabel = driver.status != null ? driverStatusLabels[driver.status] ?? driver.status! : null;

    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.badge_outlined)),
        title: Text(driver.fullName),
        subtitle: Text(driver.phone ?? 'بلا رقم هاتف مسجَّل'),
        trailing: statusLabel != null
            ? Chip(label: Text(statusLabel), visualDensity: VisualDensity.compact)
            : const Icon(Icons.chevron_left),
        onTap: () => context.push('/admin/drivers/${driver.id}'),
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
                  Text('تعذر تحميل قائمة السائقين: $message', textAlign: TextAlign.center),
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
