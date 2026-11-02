import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../application/trips_providers.dart';
import '../data/trip_models.dart';

/// Module 26's core screen: "شاشة الرحلة الرئيسية بكل الأزرار (Start Trip
/// → Complete Trip)". The button set is never hard-coded here — it's
/// rendered directly from `trip.nextPossibleStatuses`, which the backend
/// computes from TripStateMachine (see TripResource). This screen never
/// re-implements the state machine; it just displays whatever the
/// backend says is currently valid.
class TripDetailScreen extends ConsumerStatefulWidget {
  const TripDetailScreen({super.key, required this.tripId});

  final int tripId;

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripDetailProvider(widget.tripId));

    ref.listen(tripDetailProvider(widget.tripId), (previous, next) {
      final trip = next.valueOrNull;

      if (trip == null) {
        return;
      }

      final locationService = ref.read(locationServiceProvider);

      if (trip.isActivelyTracked) {
        locationService.ensurePermission().then((granted) {
          if (granted) {
            locationService.start(tripId: trip.id);
          }
        });
      } else {
        locationService.stop();
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(tripAsync.valueOrNull?.tripNumber ?? 'الرحلة')),
      body: tripAsync.when(
        data: (trip) => _TripBody(
          trip: trip,
          submitting: _submitting,
          onStatusChange: (status) => _changeStatus(trip, status),
          onCancel: () => _cancel(trip),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('تعذر تحميل الرحلة: $error')),
      ),
    );
  }

  Future<void> _changeStatus(Trip trip, String status) async {
    setState(() => _submitting = true);

    try {
      Position? position;

      try {
        position = await Geolocator.getCurrentPosition();
      } catch (_) {
        // GPS not available right now — the status change still proceeds
        // without lat/lng (both optional on UpdateTripStatusRequest);
        // only POD requires GPS to be mandatory.
      }

      await ref.read(tripsRepositoryProvider).updateStatus(
            trip.id,
            status: status,
            lat: position?.latitude,
            lng: position?.longitude,
          );
      ref.invalidate(tripDetailProvider(trip.id));
      ref.invalidate(myTripsProvider);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _cancel(Trip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء الرحلة'),
        content: const Text('هل أنت متأكد من إلغاء هذه الرحلة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('تراجع')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إلغاء الرحلة')),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _submitting = true);

    try {
      await ref.read(tripsRepositoryProvider).cancel(trip.id);
      ref.invalidate(tripDetailProvider(trip.id));
      ref.invalidate(myTripsProvider);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}

class _TripBody extends StatelessWidget {
  const _TripBody({
    required this.trip,
    required this.submitting,
    required this.onStatusChange,
    required this.onCancel,
  });

  final Trip trip;
  final bool submitting;
  final void Function(String status) onStatusChange;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('الحالة الحالية: ${trip.status}', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text('${trip.originAddress} → ${trip.destinationAddress}'),
        if (trip.cargoDescription != null) ...[
          const SizedBox(height: 4),
          Text('الحمولة: ${trip.cargoDescription}'),
        ],
        const SizedBox(height: 24),
        if (trip.nextPossibleStatuses.isNotEmpty) ...[
          Text('تحديث الحالة', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: trip.nextPossibleStatuses
                .map(
                  (status) => ElevatedButton(
                    onPressed: submitting ? null : () => onStatusChange(status),
                    child: Text(status),
                  ),
                )
                .toList(),
          ),
        ],
        if (trip.canCancel) ...[
          const SizedBox(height: 12),
          OutlinedButton(onPressed: submitting ? null : onCancel, child: const Text('إلغاء الرحلة')),
        ],
        const SizedBox(height: 24),
        Text('المحطات', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ...trip.stops.map((stop) => _StopTile(tripId: trip.id, stop: stop)),
        const SizedBox(height: 24),
        _TripEventsSection(tripId: trip.id),
      ],
    );
  }
}

/// `TripController::events()` (`GET /trips/{trip}/events`) — jobs and
/// models for this existed since the Phase-3 baseline (`Trip.events`,
/// `TripEvent`) but `show()` never eager-loads that relation, so this was
/// silently unreachable from the app until this section was added. Every
/// event recorded today is a `status_change` (see `TripEvent`'s own
/// docblock: an append-only status-change log, nothing else writes to
/// it), so this renders "old → new" directly rather than branching on
/// `eventType` for other kinds that don't exist yet.
class _TripEventsSection extends ConsumerWidget {
  const _TripEventsSection({required this.tripId});

  final int tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(tripEventsProvider(tripId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('سجل الأحداث', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        eventsAsync.when(
          data: (events) {
            if (events.isEmpty) {
              return const Text('لا توجد أحداث مسجَّلة بعد.', style: TextStyle(color: Colors.grey));
            }

            // Latest first — a status history is most useful read
            // newest-on-top, and the server itself imposes no ordering
            // guarantee (plain `$trip->events()->get()`, no `orderBy`).
            final sorted = [...events]..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));

            return Column(children: sorted.map(_EventTile.new).toList());
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (error, stack) => Text('تعذر تحميل سجل الأحداث: $error', style: const TextStyle(color: Colors.red)),
        ),
      ],
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

/// Same dependency-free "dd/MM HH:mm" formatter pattern used throughout
/// this app (e.g. FamilyAlertsScreen) — not worth a shared util for a
/// one-line, single-use formatter.
String _formatTimestamp(DateTime dateTime) {
  final local = dateTime.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');

  return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
}

class _StopTile extends StatelessWidget {
  const _StopTile({required this.tripId, required this.stop});

  final int tripId;
  final TripStop stop;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text('${stop.sequenceNo}')),
        title: Text(stop.address),
        subtitle: Text(stop.status),
        trailing: stop.hasPod
            ? const Icon(Icons.check_circle, color: Colors.green)
            : TextButton(
                onPressed: () => context.push('/trips/$tripId/stops/${stop.id}/pod'),
                child: const Text('توثيق التسليم'),
              ),
      ),
    );
  }
}
