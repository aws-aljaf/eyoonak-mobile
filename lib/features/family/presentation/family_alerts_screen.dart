import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_exception.dart';
import '../application/family_providers.dart';
import '../data/family_models.dart';

/// The Alerts Center — what the notification bell on `FamilyHomeScreen`
/// actually opens now, rather than just re-polling the unread count in
/// place (that badge-refresh behavior was the whole motivating gap: a bell
/// that never showed *which* alerts were behind the number). Mobile
/// equivalent of the alert rows the web app's `AppLayout.vue` bell
/// dropdown shows, but as its own full screen with a mark-read action per
/// row and, for accounts holding the separate `alerts.resolve`
/// permission, a resolve action too.
///
/// Deliberately differs from the web dropdown in one way: a per-type icon
/// (`_typeIcon` below) instead of one generic 🔔 for everything. The web
/// app has no dedicated alerts page to begin with (just the dropdown), so
/// there was no existing convention to match here, and a full screen with
/// room to breathe is exactly where per-type icons earn their keep.
///
/// Filter UI (by status/severity/type) added on top of that first pass —
/// the web dropdown still has none (it's a small "last few" popover, not a
/// browsing screen), but a dedicated full screen with a real backend list
/// behind it (`AlertController::index()`'s three independent filters,
/// verified directly against that controller) is exactly the kind of place
/// a filter earns its keep, so this mobile screen deliberately goes beyond
/// the web convention here rather than matching it. Still no pagination
/// beyond `FamilyApi.alerts()`'s own `per_page: 50` (see that method's
/// docblock) — filtering narrows within that same one page server-side, it
/// doesn't add paging.
class FamilyAlertsScreen extends ConsumerWidget {
  const FamilyAlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(familyAlertsProvider);
    final user = ref.watch(authControllerProvider).user;
    // Mirrors AlertPolicy's separate, stricter resolve() check — verified
    // directly against the backend policy, not assumed from alerts.view.
    final canResolve = user != null && user.permissions.contains('alerts.resolve');
    final filter = ref.watch(alertsFilterProvider);
    final hasActiveFilter = filter.status != null || filter.severity != null || filter.type != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('التنبيهات'),
        actions: [
          IconButton(
            icon: Icon(hasActiveFilter ? Icons.filter_alt : Icons.filter_alt_outlined),
            tooltip: 'فلترة',
            onPressed: () => _showFilterSheet(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: () => ref.invalidate(familyAlertsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          if (hasActiveFilter) _ActiveFilterBanner(filter: filter),
          Expanded(
            child: alertsAsync.when(
              data: (alerts) => _AlertsList(alerts: alerts, canResolve: canResolve),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _ErrorState(
                message: error.toString(),
                onRetry: () => ref.invalidate(familyAlertsProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFilterSheet(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _AlertsFilterSheet(),
    );
  }
}

/// A dismissible one-line strip above the list summarizing the active
/// filter, so a user who opened this screen later doesn't mistake "no
/// results because of a forgotten filter" for "no alerts at all" — the same
/// concern `alertsFilterProvider`'s docblock raises about not persisting
/// filters silently across visits, addressed here on the visible side too.
class _ActiveFilterBanner extends ConsumerWidget {
  const _ActiveFilterBanner({required this.filter});

  final AlertsFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parts = <String>[
      if (filter.status != null) _statusLabel(filter.status!),
      if (filter.severity != null) _severityLabel(filter.severity!),
      if (filter.type != null) _typeLabel(filter.type!),
    ];

    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text('فلترة: ${parts.join(' · ')}')),
          TextButton(
            onPressed: () => ref.read(alertsFilterProvider.notifier).state = noAlertsFilter,
            child: const Text('مسح'),
          ),
        ],
      ),
    );
  }
}

/// The filter picker itself — three independent dropdowns (status,
/// severity, type) mirroring `AlertController::index()`'s three filters
/// exactly. A local `ConsumerStatefulWidget` holding a draft selection
/// (only committed to `alertsFilterProvider` on "تطبيق") rather than
/// writing straight through on every dropdown change — avoids re-fetching
/// the alerts list three times in a row while someone is still picking.
class _AlertsFilterSheet extends ConsumerStatefulWidget {
  const _AlertsFilterSheet();

  @override
  ConsumerState<_AlertsFilterSheet> createState() => _AlertsFilterSheetState();
}

class _AlertsFilterSheetState extends ConsumerState<_AlertsFilterSheet> {
  late AlertsFilter _draft;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(alertsFilterProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('فلترة التنبيهات', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            initialValue: _draft.status,
            decoration: const InputDecoration(labelText: 'الحالة', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: null, child: Text('الكل')),
              for (final status in _alertStatuses) DropdownMenuItem(value: status, child: Text(_statusLabel(status))),
            ],
            onChanged: (value) =>
                setState(() => _draft = (status: value, severity: _draft.severity, type: _draft.type)),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _draft.severity,
            decoration: const InputDecoration(labelText: 'الخطورة', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: null, child: Text('الكل')),
              for (final severity in _alertSeverities)
                DropdownMenuItem(value: severity, child: Text(_severityLabel(severity))),
            ],
            onChanged: (value) => setState(() => _draft = (status: _draft.status, severity: value, type: _draft.type)),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _draft.type,
            decoration: const InputDecoration(labelText: 'النوع', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: null, child: Text('الكل')),
              for (final type in _alertTypes) DropdownMenuItem(value: type, child: Text(_typeLabel(type))),
            ],
            onChanged: (value) =>
                setState(() => _draft = (status: _draft.status, severity: _draft.severity, type: value)),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _draft = noAlertsFilter),
                  child: const Text('مسح الفلاتر'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    ref.read(alertsFilterProvider.notifier).state = _draft;
                    Navigator.of(context).pop();
                  },
                  child: const Text('تطبيق'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlertsList extends ConsumerWidget {
  const _AlertsList({required this.alerts, required this.canResolve});

  final List<FamilyAlertModel> alerts;
  final bool canResolve;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (alerts.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(familyAlertsProvider),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: const Center(child: Text('لا توجد تنبيهات حتى الآن.')),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(familyAlertsProvider),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: alerts.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _AlertCard(alert: alerts[index], canResolve: canResolve),
      ),
    );
  }
}

class _AlertCard extends ConsumerStatefulWidget {
  const _AlertCard({required this.alert, required this.canResolve});

  final FamilyAlertModel alert;
  final bool canResolve;

  @override
  ConsumerState<_AlertCard> createState() => _AlertCardState();
}

class _AlertCardState extends ConsumerState<_AlertCard> {
  bool _busy = false;

  Future<void> _markRead() => _run(() {
        final familyId = ref.read(selectedFamilyIdProvider);

        return ref.read(familyApiProvider).markAlertRead(alertId: widget.alert.id, familyId: familyId);
      });

  Future<void> _resolve() => _run(() {
        final familyId = ref.read(selectedFamilyIdProvider);

        return ref.read(familyApiProvider).resolveAlert(alertId: widget.alert.id, familyId: familyId);
      });

  Future<void> _run(Future<Map<String, dynamic>> Function() action) async {
    setState(() => _busy = true);

    try {
      await action();
      ref.invalidate(familyAlertsProvider);
      ref.invalidate(unreadAlertsCountProvider);
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

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;
    final severityColor = _severityColor(alert.severity);

    return Card(
      color: alert.isUnread ? severityColor.withValues(alpha: 0.06) : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: severityColor.withValues(alpha: 0.15),
              child: Icon(_typeIcon(alert.type), color: severityColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.title,
                    style: TextStyle(fontWeight: alert.isUnread ? FontWeight.bold : FontWeight.normal),
                  ),
                  if (alert.body case final body?) ...[
                    const SizedBox(height: 4),
                    Text(body, style: Theme.of(context).textTheme.bodySmall),
                  ],
                  const SizedBox(height: 4),
                  Text(_formatTimestamp(alert.createdAt), style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildTrailing(),
          ],
        ),
      ),
    );
  }

  Widget _buildTrailing() {
    if (_busy) {
      return const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (widget.alert.isResolved) {
      return const Text('تم الإغلاق', style: TextStyle(fontSize: 12));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.alert.isUnread) TextButton(onPressed: _markRead, child: const Text('تعليم كمقروء')),
        if (widget.canResolve) TextButton(onPressed: _resolve, child: const Text('إغلاق')),
      ],
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
                  Text('تعذر تحميل التنبيهات: $message', textAlign: TextAlign.center),
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

/// Colors mirror the web app's own severity palette in `AppLayout.vue`'s
/// bell dropdown (info=blue, warning=amber, critical=red) — kept
/// consistent rather than inventing a separate mobile palette.
Color _severityColor(String severity) {
  switch (severity) {
    case 'critical':
      return Colors.red.shade700;
    case 'warning':
      return Colors.amber.shade800;
    default:
      return Colors.blue.shade700;
  }
}

/// Per-type icon differentiation — a deliberate mobile-only addition over
/// the web dropdown's single generic bell icon (see this file's docblock).
/// Covers every value in the backend's `Alert::TYPES`, including the ones
/// nothing raises yet today, so a newly-enabled type never falls through
/// to the default icon by omission.
IconData _typeIcon(String type) {
  switch (type) {
    case 'geofence_enter':
      return Icons.login;
    case 'geofence_exit':
      return Icons.logout;
    case 'sos':
      return Icons.sos;
    case 'low_battery':
      return Icons.battery_alert;
    case 'gps_disabled':
      return Icons.gps_off;
    case 'device_removed':
      return Icons.phonelink_erase;
    case 'offline':
      return Icons.wifi_off;
    default:
      return Icons.notifications;
  }
}

/// Filter option lists — literal copies of the backend's `Alert::STATUSES`
/// / `Alert::SEVERITIES` / `Alert::TYPES` constants (verified directly
/// against `Alert.php`), not fetched from any endpoint. There's no
/// "list valid alert statuses" API — these are closed enums baked into the
/// migration/model, so a plain literal list here is the same convention
/// already used for `FamilyMember.STATUSES` in `_MemberFormDialog` over in
/// `family_home_screen.dart`.
const _alertStatuses = ['unread', 'read', 'resolved'];
const _alertSeverities = ['info', 'warning', 'critical'];
const _alertTypes = [
  'geofence_enter',
  'geofence_exit',
  'sos',
  'low_battery',
  'gps_disabled',
  'device_removed',
  'offline',
];

String _statusLabel(String status) {
  switch (status) {
    case 'unread':
      return 'غير مقروء';
    case 'read':
      return 'مقروء';
    case 'resolved':
      return 'مغلق';
    default:
      return status;
  }
}

String _severityLabel(String severity) {
  switch (severity) {
    case 'info':
      return 'معلومة';
    case 'warning':
      return 'تحذير';
    case 'critical':
      return 'حرج';
    default:
      return severity;
  }
}

/// Text counterpart to `_typeIcon` above — same seven `Alert::TYPES`
/// values, used only by the filter sheet/banner (alert cards themselves
/// show the backend's own `title` text, not a client-side type label).
String _typeLabel(String type) {
  switch (type) {
    case 'geofence_enter':
      return 'دخول منطقة آمنة';
    case 'geofence_exit':
      return 'خروج من منطقة آمنة';
    case 'sos':
      return 'استغاثة';
    case 'low_battery':
      return 'بطارية منخفضة';
    case 'gps_disabled':
      return 'GPS معطّل';
    case 'device_removed':
      return 'إزالة جهاز';
    case 'offline':
      return 'غير متصل';
    default:
      return type;
  }
}

/// Same dependency-free "dd/MM HH:mm" formatter pattern used elsewhere in
/// this feature (e.g. FamilyMemberLocationHistoryScreen) — not extracted
/// into a shared util per that same established convention for a
/// one-line, single-use formatter.
String _formatTimestamp(String isoTimestamp) {
  final parsed = DateTime.tryParse(isoTimestamp);

  if (parsed == null) {
    return isoTimestamp;
  }

  final local = parsed.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');

  return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
}
