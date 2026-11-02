import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../trips/application/trips_providers.dart';
import '../../trips/data/trip_models.dart';
import '../application/admin_trips_providers.dart';
import '../data/trip_status_labels.dart';

/// Detail view for one trip — reached only by tapping a row on
/// `AdminTripsScreen`, which already required `trips.view` to load at all,
/// so (same "the request is the gate" convention as every other screen in
/// this app) this screen has no permission gate of its own either;
/// `TripController::show()`/`TripPolicy::view()` are what actually enforce
/// it server-side.
///
/// Deliberately reuses `tripDetailProvider`/`tripEventsProvider` from
/// `features/trips/application/trips_providers.dart` (the driver
/// self-service feature) rather than new admin-only providers — both are
/// already generic by `tripId` with no driver-scoping (see
/// `AdminTripsApi`'s docblock).
///
/// **Edit and cancel actions**, gated respectively on `trips.edit`/
/// `trips.cancel` (verified directly against `TripPolicy` before adding
/// these) — edit is additionally hidden once `!trip.isCoreEditable`
/// (mirrors `UpdateTripRequest::withValidator`'s own all-or-nothing status
/// gate exactly, see `Trip.isCoreEditable`'s own docblock), and cancel is
/// additionally hidden once `!trip.canCancel` (the resource's own
/// `TripStateMachine::canCancel()` hint). **Still no status-change button**
/// (`POST /trips/{id}/status`) and **still no POD upload** — the former is
/// a deliberately separate state-machine surface this PR does not add (see
/// `AdminTripsApi`'s docblock), the latter stays driver-ownership-only
/// regardless of any permission (`TripPolicy::uploadPod()`), so both are
/// correctly absent here.
class AdminTripDetailScreen extends ConsumerWidget {
  const AdminTripDetailScreen({super.key, required this.tripId});

  final int tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(tripDetailProvider(tripId));
    final permissions = ref.watch(authControllerProvider).user?.permissions ?? const [];
    final trip = tripAsync.valueOrNull;
    final canEdit = permissions.contains('trips.edit') && trip != null && trip.isCoreEditable;
    final canCancel = permissions.contains('trips.cancel') && trip != null && trip.canCancel;

    return Scaffold(
      appBar: AppBar(
        title: Text(trip?.tripNumber ?? 'تفاصيل الرحلة'),
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'تعديل',
              onPressed: () async {
                final updated = await context.push<bool>('/admin/trips/$tripId/edit', extra: trip);

                if (updated == true) {
                  ref.invalidate(tripDetailProvider(tripId));
                }
              },
            ),
          if (canCancel)
            IconButton(
              icon: const Icon(Icons.cancel_outlined),
              tooltip: 'إلغاء الرحلة',
              // `canCancel`'s own `trip != null` check (above) is enough for
              // the analyzer to promote `trip` to non-null here too — no `!`
              // needed (confirmed directly: `flutter analyze` flags one as
              // `unnecessary_non_null_assertion` at this exact call site).
              onPressed: () => _confirmCancel(context, ref, trip),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: () => ref.invalidate(tripDetailProvider(tripId)),
          ),
        ],
      ),
      body: tripAsync.when(
        data: (trip) => _DetailBody(trip: trip),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(tripDetailProvider(tripId)),
        ),
      ),
    );
  }
}

/// `reason` is optional (matches `CancelTripRequest`'s own nullable
/// `reason` field) — collected in the same dialog as the confirmation
/// itself rather than a separate screen, same "confirmation dialog is the
/// whole flow" convention as `AdminDriverDetailScreen`/
/// `AdminVehicleDetailScreen`'s own delete dialogs.
Future<void> _confirmCancel(BuildContext context, WidgetRef ref, Trip trip) async {
  final reasonController = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('إلغاء الرحلة'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('هل أنت متأكد من إلغاء الرحلة "${trip.tripNumber}"؟'),
          const SizedBox(height: 12),
          TextField(
            controller: reasonController,
            decoration: const InputDecoration(labelText: 'سبب الإلغاء (اختياري)', border: OutlineInputBorder()),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('تراجع')),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('تأكيد الإلغاء'),
        ),
      ],
    ),
  );

  if (confirmed != true) {
    reasonController.dispose();
    return;
  }

  final reason = reasonController.text.trim();
  reasonController.dispose();

  try {
    await ref.read(adminTripsApiProvider).cancel(trip.id, reason: reason.isEmpty ? null : reason);
    ref.invalidate(tripDetailProvider(trip.id));
    ref.invalidate(adminTripsProvider);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إلغاء الرحلة: $error')));
    }
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final statusLabel = tripStatusLabels[trip.status] ?? trip.status;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: Text(trip.tripNumber, style: Theme.of(context).textTheme.headlineSmall)),
            Chip(label: Text(statusLabel)),
          ],
        ),
        const SizedBox(height: 8),
        Text('${trip.originAddress} ← ${trip.destinationAddress}'),
        const SizedBox(height: 16),
        _Section(
          title: 'بيانات الرحلة',
          rows: [
            if (trip.vehiclePlateNumber != null) _row('المركبة', trip.vehiclePlateNumber!),
            if (trip.driverName != null) _row('السائق', trip.driverName!),
            if (trip.customerName != null) _row('العميل', trip.customerName!),
            if (trip.cargoDescription != null) _row('الحمولة', trip.cargoDescription!),
            if (trip.expectedStartAt != null) _row('البدء المتوقع', _formatTimestamp(trip.expectedStartAt!)),
            if (trip.expectedArrivalAt != null) _row('الوصول المتوقع', _formatTimestamp(trip.expectedArrivalAt!)),
            if (trip.actualStartAt != null) _row('البدء الفعلي', _formatTimestamp(trip.actualStartAt!)),
            if (trip.actualArrivalAt != null) _row('الوصول الفعلي', _formatTimestamp(trip.actualArrivalAt!)),
            if (trip.notes != null) _row('ملاحظات', trip.notes!),
          ],
        ),
        if (trip.stops.isNotEmpty) ...[
          Text('المحطات', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ...trip.stops.map(
            (stop) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(child: Text('${stop.sequenceNo}')),
                title: Text(stop.address),
                subtitle: Text(stop.status),
                trailing: stop.hasPod ? const Icon(Icons.check_circle, color: Colors.green) : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Text('سجل الأحداث', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        _EventsSection(tripId: trip.id),
      ],
    );
  }

  _DetailRow _row(String label, String value) => _DetailRow(label: label, value: value);
}

/// Same event log reuse as `TripDetailScreen`'s own `_TripEventsSection` —
/// `TripPolicy::viewEvents()` is a plain alias of `view()` (see that
/// policy's docblock), so an office account with `trips.view` already
/// satisfies it exactly as a driver's ownership does.
class _EventsSection extends ConsumerWidget {
  const _EventsSection({required this.tripId});

  final int tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(tripEventsProvider(tripId));

    return eventsAsync.when(
      data: (events) {
        if (events.isEmpty) {
          return const Text('لا توجد أحداث مسجَّلة بعد.', style: TextStyle(color: Colors.grey));
        }

        final sorted = [...events]
          ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));

        return Column(children: sorted.map(_EventTile.new).toList());
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (error, stack) => Text('تعذر تحميل سجل الأحداث: $error', style: const TextStyle(color: Colors.red)),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile(this.event);

  final TripEvent event;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.swap_horiz),
        title: Text(
          event.oldStatus != null ? '${event.oldStatus} → ${event.newStatus}' : (event.newStatus ?? event.eventType),
        ),
        subtitle: Text([
          if (event.createdAt != null) _formatTimestamp(event.createdAt!),
          if (event.reasonOrNotes != null) event.reasonOrNotes!,
        ].join(' • ')),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});

  final String title;
  final List<_DetailRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 130, child: Text(row.label, style: const TextStyle(color: Colors.grey))),
                    Expanded(child: Text(row.value)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;
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
                  Text('تعذر تحميل بيانات الرحلة: $message', textAlign: TextAlign.center),
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

String _formatTimestamp(DateTime dt) {
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');

  return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
}
