import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../trips/data/trip_models.dart';
import '../application/admin_trips_providers.dart';
import '../data/trip_status_labels.dart';

/// "إدارة الرحلات" — `TripController::index()`
/// (backend/app/Http/Controllers/Api/V1/Trips/TripController.php),
/// verified directly against that controller/`TripPolicy`/`TripResource`
/// before building this.
///
/// **No permission gate on this screen or route itself** — same
/// "the request is the gate" convention as every other admin screen:
/// `TripPolicy::viewAny()` (`trips.view`) is what actually enforces
/// access, and the only entry point (`AdminHomeScreen`) never renders the
/// tile that reaches here unless that permission is already present.
///
/// **The "+" FAB is the one exception** — `trips.create` is a separate
/// permission from `trips.view` (verified against `TripPolicy` before
/// building this), same pattern `AdminVehiclesScreen`/`AdminDriversScreen`'s
/// own FABs already established. The rest of the write surface (edit/
/// cancel) lives on `AdminTripDetailScreen` instead — see `AdminTripsApi`'s
/// docblock for the full picture of what's gated where, including why
/// there is no delete/status-change surface at all.
///
/// **Real prev/next pagination**, mirroring `AdminVehiclesScreen`/
/// `AdminDriversScreen` exactly — reuses the existing `Trip` model from
/// `features/trips/data/trip_models.dart` rather than a new admin-only
/// model, since it already mirrors `TripResource` field-for-field
/// (nested vehicle/driver/customer names, plus the raw FK ids/scalars
/// added for this PR's write form) with nothing missing.
class AdminTripsScreen extends ConsumerWidget {
  const AdminTripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(adminTripsProvider);
    final permissions = ref.watch(authControllerProvider).user?.permissions ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الرحلات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: () => ref.invalidate(adminTripsProvider),
          ),
        ],
      ),
      floatingActionButton: permissions.contains('trips.create')
          ? FloatingActionButton(
              tooltip: 'إضافة رحلة',
              onPressed: () async {
                final created = await context.push<bool>('/admin/trips/new');

                if (created == true) {
                  ref.invalidate(adminTripsProvider);
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          const _FilterBar(),
          Expanded(
            child: tripsAsync.when(
              data: (envelope) {
                final items =
                    envelope.data.map((e) => Trip.fromJson(Map<String, dynamic>.from(e as Map))).toList();

                return _TripsBody(items: items, currentPage: envelope.currentPage, lastPage: envelope.lastPage);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _ErrorState(
                message: error.toString(),
                onRetry: () => ref.invalidate(adminTripsProvider),
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
  void _setStatus(String? status) {
    ref.read(adminTripsStatusFilterProvider.notifier).state = status;
    ref.read(adminTripsPageProvider.notifier).state = 1;
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final initial = isFrom
        ? ref.read(adminTripsFromFilterProvider) ?? now
        : ref.read(adminTripsToFilterProvider) ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
    );

    if (picked == null) {
      return;
    }

    if (isFrom) {
      ref.read(adminTripsFromFilterProvider.notifier).state = picked;
    } else {
      ref.read(adminTripsToFilterProvider.notifier).state = picked;
    }

    ref.read(adminTripsPageProvider.notifier).state = 1;
  }

  void _clearFilters() {
    ref.read(adminTripsStatusFilterProvider.notifier).state = null;
    ref.read(adminTripsFromFilterProvider.notifier).state = null;
    ref.read(adminTripsToFilterProvider.notifier).state = null;
    ref.read(adminTripsPageProvider.notifier).state = 1;
  }

  @override
  Widget build(BuildContext context) {
    final selectedStatus = ref.watch(adminTripsStatusFilterProvider);
    final from = ref.watch(adminTripsFromFilterProvider);
    final to = ref.watch(adminTripsToFilterProvider);
    final hasAnyFilter = selectedStatus != null || from != null || to != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(isFrom: true),
                  icon: const Icon(Icons.date_range_outlined, size: 18),
                  label: Text(from == null ? 'من تاريخ' : _formatDate(from)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(isFrom: false),
                  icon: const Icon(Icons.date_range_outlined, size: 18),
                  label: Text(to == null ? 'إلى تاريخ' : _formatDate(to)),
                ),
              ),
              if (hasAnyFilter)
                IconButton(
                  tooltip: 'مسح الفلاتر',
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  onPressed: _clearFilters,
                ),
            ],
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
                for (final entry in tripStatusLabels.entries)
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

class _TripsBody extends ConsumerWidget {
  const _TripsBody({required this.items, required this.currentPage, required this.lastPage});

  final List<Trip> items;
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
                    onRefresh: () async => ref.invalidate(adminTripsProvider),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: const Center(child: Text('لا توجد رحلات مطابقة.')),
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async => ref.invalidate(adminTripsProvider),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _TripCard(trip: items[index]),
                  ),
                ),
        ),
        _PagerBar(currentPage: currentPage, lastPage: lastPage),
      ],
    );
  }
}

/// Mirrors `AdminVehiclesScreen`/`AdminDriversScreen`'s `_PagerBar` exactly.
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
                  ? () => ref.read(adminTripsPageProvider.notifier).state = currentPage - 1
                  : null,
              icon: const Icon(Icons.chevron_right),
              label: const Text('السابق'),
            ),
            Text('صفحة $currentPage من $lastPage', style: Theme.of(context).textTheme.bodySmall),
            TextButton(
              onPressed: currentPage < lastPage
                  ? () => ref.read(adminTripsPageProvider.notifier).state = currentPage + 1
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

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final statusLabel = tripStatusLabels[trip.status] ?? trip.status;

    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.route_outlined)),
        title: Text(trip.tripNumber),
        subtitle: Text('${trip.originAddress} → ${trip.destinationAddress}'),
        trailing: Chip(label: Text(statusLabel), visualDensity: VisualDensity.compact),
        onTap: () => context.push('/admin/trips/${trip.id}'),
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
                  Text('تعذر تحميل قائمة الرحلات: $message', textAlign: TextAlign.center),
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

String _formatDate(DateTime dt) {
  final d = dt.day.toString().padLeft(2, '0');
  final m = dt.month.toString().padLeft(2, '0');

  return '$d/$m/${dt.year}';
}
