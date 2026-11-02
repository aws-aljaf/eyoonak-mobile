import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_exception.dart';
import '../application/family_providers.dart';
import '../data/family_models.dart';

/// The SOS incident list — where the SOS button on `FamilyHomeScreen`'s
/// member cards (see `_MemberCard._triggerSos`) actually goes once
/// triggered. Deliberately reads `GET /sos-events`, not `GET /alerts`:
/// `FamilySosNotifier` raises a critical `Alert` too, but that resource
/// carries none of what this screen needs (structured lat/lng, battery
/// level, a separate acknowledge step with its own actor/timestamp) —
/// verified directly against both resources on the backend, not assumed.
/// Reference: the web app's own `resources/js/pages/SosPage.vue` uses the
/// same endpoint for the same reason.
///
/// Status filter mirrors that Vue page's default (`active` first — the
/// most actionable status) with `all`/`acknowledged`/`resolved` also
/// offered via `sosEventsStatusFilterProvider`. No pagination beyond
/// `FamilyApi.sosEvents()`'s own `per_page: 50`, same first-pass reasoning
/// as `FamilyAlertsScreen`.
class SosEventsScreen extends ConsumerWidget {
  const SosEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(sosEventsProvider);
    final user = ref.watch(authControllerProvider).user;
    // Verified directly against SosEventPolicy — two separate permissions,
    // not one gating both actions.
    final canAcknowledge = user != null && user.permissions.contains('sos.acknowledge');
    final canResolve = user != null && user.permissions.contains('sos.resolve');

    return Scaffold(
      appBar: AppBar(
        title: const Text('حالات الاستغاثة (SOS)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: () => ref.invalidate(sosEventsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          const _StatusFilterBar(),
          Expanded(
            child: eventsAsync.when(
              data: (events) => _EventsList(events: events, canAcknowledge: canAcknowledge, canResolve: canResolve),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _ErrorState(
                message: error.toString(),
                onRetry: () => ref.invalidate(sosEventsProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusFilterBar extends ConsumerWidget {
  const _StatusFilterBar();

  static const _options = [
    (null, 'الكل'),
    ('active', 'نشطة'),
    ('acknowledged', 'قيد المعالجة'),
    ('resolved', 'مغلقة'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(sosEventsStatusFilterProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final option in _options)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ChoiceChip(
                  label: Text(option.$2),
                  selected: selected == option.$1,
                  onSelected: (_) => ref.read(sosEventsStatusFilterProvider.notifier).state = option.$1,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EventsList extends ConsumerWidget {
  const _EventsList({required this.events, required this.canAcknowledge, required this.canResolve});

  final List<SosEventModel> events;
  final bool canAcknowledge;
  final bool canResolve;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (events.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(sosEventsProvider),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: const Center(child: Text('لا توجد حالات استغاثة بهذا الفلتر.')),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(sosEventsProvider),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: events.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) =>
            _EventCard(event: events[index], canAcknowledge: canAcknowledge, canResolve: canResolve),
      ),
    );
  }
}

class _EventCard extends ConsumerStatefulWidget {
  const _EventCard({required this.event, required this.canAcknowledge, required this.canResolve});

  final SosEventModel event;
  final bool canAcknowledge;
  final bool canResolve;

  @override
  ConsumerState<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends ConsumerState<_EventCard> {
  bool _busy = false;

  Future<void> _acknowledge() => _run(() {
        final familyId = ref.read(selectedFamilyIdProvider);

        return ref.read(familyApiProvider).acknowledgeSosEvent(sosEventId: widget.event.id, familyId: familyId);
      });

  Future<void> _resolve() => _run(() {
        final familyId = ref.read(selectedFamilyIdProvider);

        return ref.read(familyApiProvider).resolveSosEvent(sosEventId: widget.event.id, familyId: familyId);
      });

  Future<void> _run(Future<Map<String, dynamic>> Function() action) async {
    setState(() => _busy = true);

    try {
      await action();
      ref.invalidate(sosEventsProvider);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyCoordinates() async {
    final event = widget.event;
    await Clipboard.setData(ClipboardData(text: '${event.latitude},${event.longitude}'));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الإحداثيات')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final statusColor = _statusColor(event.status);
    final memberLabel = event.familyMemberName ?? 'فرد #${event.familyMemberId}';

    return Card(
      color: event.isActive ? statusColor.withValues(alpha: 0.06) : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                  child: Icon(Icons.sos, color: statusColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(memberLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(_formatTimestamp(event.createdAt), style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Chip(
                  label: Text(_statusLabel(event.status), style: TextStyle(color: statusColor)),
                  backgroundColor: statusColor.withValues(alpha: 0.1),
                  side: BorderSide.none,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.place_outlined, size: 16, color: Theme.of(context).colorScheme.outline),
                const SizedBox(width: 4),
                Text('${event.latitude.toStringAsFixed(5)}, ${event.longitude.toStringAsFixed(5)}'),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  tooltip: 'نسخ الإحداثيات',
                  onPressed: _copyCoordinates,
                ),
                if (event.batteryLevel case final battery?) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.battery_alert, size: 16, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(width: 4),
                  Text('$battery%'),
                ],
              ],
            ),
            if (event.notifiedEmergencyContactIds != null && event.notifiedEmergencyContactIds!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'تم إشعار ${event.notifiedEmergencyContactIds!.length} من جهات الاتصال الطارئة',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 8),
            if (_busy)
              const Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (event.isActive && widget.canAcknowledge)
                    TextButton(onPressed: _acknowledge, child: const Text('تأكيد الاستلام')),
                  if (!event.isResolved && widget.canResolve)
                    TextButton(onPressed: _resolve, child: const Text('إغلاق')),
                ],
              ),
          ],
        ),
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
                  Text('تعذر تحميل حالات الاستغاثة: $message', textAlign: TextAlign.center),
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

Color _statusColor(String status) {
  switch (status) {
    case 'active':
      return Colors.red.shade700;
    case 'acknowledged':
      return Colors.amber.shade800;
    default:
      return Colors.green.shade700;
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'active':
      return 'نشطة';
    case 'acknowledged':
      return 'قيد المعالجة';
    default:
      return 'مغلقة';
  }
}

/// Same dependency-free "dd/MM HH:mm" formatter pattern used elsewhere in
/// this feature (e.g. FamilyAlertsScreen) — not extracted into a shared
/// util per that same established convention for a one-line, single-use
/// formatter.
String _formatTimestamp(String isoTimestamp) {
  final parsed = DateTime.tryParse(isoTimestamp);

  if (parsed == null) {
    return isoTimestamp;
  }

  final local = parsed.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');

  return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
}
