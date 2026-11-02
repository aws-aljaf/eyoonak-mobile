import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../application/admin_vehicles_providers.dart';
import '../data/admin_vehicle_models.dart';

/// "المركبات" — `VehicleController::index()`
/// (backend/app/Http/Controllers/Api/V1/Fleet/VehicleController.php),
/// verified directly against that controller/`VehiclePolicy`/
/// `VehicleResource` before building this.
///
/// **No permission gate on this screen or route itself for viewing** — same
/// "the request is the gate" convention as every other admin/family
/// screen: `VehiclePolicy::viewAny()` (`vehicles.view`) is what actually
/// enforces access, and the only entry point (`AdminHomeScreen`) never
/// renders the tile that reaches here unless that permission is already
/// present on the account.
///
/// **The "+" FAB is the one exception** — `vehicles.create` is a separate
/// permission from `vehicles.view` (verified against `VehiclePolicy`
/// before building this), so someone who can see this list may not be
/// allowed to add to it; the FAB checks `permissions.contains('vehicles.
/// create')` itself, same pattern `AdminReportsScreen`'s "تصدير" action
/// established for `reports.export` vs `reports.view`.
///
/// **Real prev/next pagination**, mirroring `AuditLogsScreen`/
/// `FamilyTimelineScreen` exactly — a company's vehicle list can grow
/// past a single page, unlike the driver's own one-vehicle self-service
/// screen (`features/vehicles/presentation` doesn't even exist; that
/// feature is API-only, see `VehiclesApi`'s own docblock).
class AdminVehiclesScreen extends ConsumerWidget {
  const AdminVehiclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(adminVehiclesProvider);
    final permissions = ref.watch(authControllerProvider).user?.permissions ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('المركبات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: () => ref.invalidate(adminVehiclesProvider),
          ),
        ],
      ),
      floatingActionButton: permissions.contains('vehicles.create')
          ? FloatingActionButton(
              tooltip: 'إضافة مركبة',
              onPressed: () async {
                final created = await context.push<bool>('/admin/vehicles/new');

                if (created == true) {
                  ref.invalidate(adminVehiclesProvider);
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          const _FilterBar(),
          Expanded(
            child: vehiclesAsync.when(
              data: (envelope) {
                final items = envelope.data
                    .map((e) => AdminVehicle.fromJson(Map<String, dynamic>.from(e as Map)))
                    .toList();

                return _VehiclesBody(items: items, currentPage: envelope.currentPage, lastPage: envelope.lastPage);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _ErrorState(
                message: error.toString(),
                onRetry: () => ref.invalidate(adminVehiclesProvider),
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

  /// Every filter change also resets the page back to 1 — same reasoning
  /// as `AuditLogsScreen`'s `_applyAction`: a narrower filter could
  /// otherwise leave the screen stuck on a now out-of-range page.
  void _applySearch(String value) {
    ref.read(adminVehiclesSearchFilterProvider.notifier).state = value.trim().isEmpty ? null : value.trim();
    ref.read(adminVehiclesPageProvider.notifier).state = 1;
  }

  void _setStatus(String? status) {
    ref.read(adminVehiclesStatusFilterProvider.notifier).state = status;
    ref.read(adminVehiclesPageProvider.notifier).state = 1;
  }

  @override
  Widget build(BuildContext context) {
    final selectedStatus = ref.watch(adminVehiclesStatusFilterProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'بحث',
              hintText: 'رقم اللوحة أو الماركة أو الموديل',
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
                for (final entry in vehicleStatusLabels.entries)
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

class _VehiclesBody extends ConsumerWidget {
  const _VehiclesBody({required this.items, required this.currentPage, required this.lastPage});

  final List<AdminVehicle> items;
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
                    onRefresh: () async => ref.invalidate(adminVehiclesProvider),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: const Center(child: Text('لا توجد مركبات مطابقة.')),
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async => ref.invalidate(adminVehiclesProvider),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _VehicleCard(vehicle: items[index]),
                  ),
                ),
        ),
        _PagerBar(currentPage: currentPage, lastPage: lastPage),
      ],
    );
  }
}

/// Mirrors `AuditLogsScreen`'s `_PagerBar` exactly.
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
                  ? () => ref.read(adminVehiclesPageProvider.notifier).state = currentPage - 1
                  : null,
              icon: const Icon(Icons.chevron_right),
              label: const Text('السابق'),
            ),
            Text('صفحة $currentPage من $lastPage', style: Theme.of(context).textTheme.bodySmall),
            TextButton(
              onPressed: currentPage < lastPage
                  ? () => ref.read(adminVehiclesPageProvider.notifier).state = currentPage + 1
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

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.vehicle});

  final AdminVehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final statusLabel = vehicle.status != null ? vehicleStatusLabels[vehicle.status] ?? vehicle.status! : null;

    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.local_shipping_outlined)),
        title: Text(
          vehicle.displayName.isEmpty ? vehicle.plateNumber : '${vehicle.plateNumber} — ${vehicle.displayName}',
        ),
        subtitle: Text(
          vehicle.currentDriverName != null ? 'السائق: ${vehicle.currentDriverName}' : 'بلا سائق حاليًا',
        ),
        trailing: statusLabel != null
            ? Chip(label: Text(statusLabel), visualDensity: VisualDensity.compact)
            : const Icon(Icons.chevron_left),
        onTap: () => context.push('/admin/vehicles/${vehicle.id}'),
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
                  Text('تعذر تحميل قائمة المركبات: $message', textAlign: TextAlign.center),
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
