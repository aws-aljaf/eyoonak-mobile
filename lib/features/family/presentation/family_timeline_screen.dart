import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/family_providers.dart';
import '../data/family_models.dart';

/// A read-only merged activity feed for the family — geofence entry/exit,
/// safe-zone additions, SOS events, and member additions, all in one
/// chronological list. Mobile counterpart of the web app's
/// `FamilyTimelinePage.vue` reference page.
///
/// **No permission gate on this screen or its entry point**: verified
/// directly against `FamilyTimelineController::index()` — the only blanket
/// gate is `FamilyMemberPolicy::viewAny()` (`family_tracking.view`), the
/// exact same permission already required to see anything on
/// `FamilyHomeScreen` at all (its member roster), so by the time this
/// screen is reachable the account is already known to pass it — same
/// reasoning `FamilyMapScreen`'s docblock gives for `familyGeofencesProvider`.
/// Per-row visibility (geofence rows need the `geofence_events` tracking
/// capability, SOS rows need `sos.view`, and a `supervisor` role is scoped
/// to only their `supervises` list) is all enforced **server-side** inside
/// the controller itself — this screen never re-implements that filtering,
/// it just renders whatever rows the backend decided to include.
///
/// **Real pagination, unlike every other family list screen so far**: the
/// backend has no date-range filter at all (verified directly — only
/// `page`/`per_page` exist), and merges up to 200 rows per source before
/// paginating in PHP, so a family with real history needs actual page
/// navigation rather than one `per_page: 50`-and-done fetch like
/// `FamilyAlertsScreen`/`SosEventsScreen`. This screen mirrors the web
/// reference's own simple prev/next buttons + "صفحة X من Y" label rather
/// than a scrolling infinite-list — the web page this mirrors uses the
/// exact same simple pattern, and family-scale timelines don't need more.
class FamilyTimelineScreen extends ConsumerWidget {
  const FamilyTimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timelineAsync = ref.watch(familyTimelineProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('نشاط العائلة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: () => ref.invalidate(familyTimelineProvider),
          ),
        ],
      ),
      body: timelineAsync.when(
        data: (envelope) {
          final items =
              envelope.data.map((e) => FamilyTimelineItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();

          return _TimelineBody(items: items, currentPage: envelope.currentPage, lastPage: envelope.lastPage);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(familyTimelineProvider),
        ),
      ),
    );
  }
}

class _TimelineBody extends ConsumerWidget {
  const _TimelineBody({required this.items, required this.currentPage, required this.lastPage});

  final List<FamilyTimelineItem> items;
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
                    onRefresh: () async => ref.invalidate(familyTimelineProvider),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: const Center(child: Text('لا يوجد نشاط لعرضه حتى الآن.')),
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async => ref.invalidate(familyTimelineProvider),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _TimelineCard(item: items[index]),
                  ),
                ),
        ),
        _PagerBar(currentPage: currentPage, lastPage: lastPage),
      ],
    );
  }
}

/// Mirrors the web reference's own "< السابق  صفحة X من Y  التالي >" bar
/// exactly — same simple prev/next shape, no page-number jump list.
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
              onPressed:
                  currentPage > 1 ? () => ref.read(familyTimelinePageProvider.notifier).state = currentPage - 1 : null,
              icon: const Icon(Icons.chevron_right),
              label: const Text('السابق'),
            ),
            Text('صفحة $currentPage من $lastPage', style: Theme.of(context).textTheme.bodySmall),
            TextButton(
              onPressed: currentPage < lastPage
                  ? () => ref.read(familyTimelinePageProvider.notifier).state = currentPage + 1
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

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.item});

  final FamilyTimelineItem item;

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(item.type);

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(_typeIcon(item.type), color: color),
        ),
        title: Text(item.title),
        subtitle: Text(
          item.occurredAt != null ? _formatTimestamp(item.occurredAt!) : '',
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
                  Text('تعذر تحميل نشاط العائلة: $message', textAlign: TextAlign.center),
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

/// Mirrors the web reference's `TYPE_META` color-per-type mapping exactly
/// (sos=red, geofence_enter=teal→blue, geofence_exit=amber, geofence_added
/// and member_added=neutral gray), covering every value
/// `FamilyTimelineController` currently emits, plus a gray fallback for
/// any future type this app doesn't know about yet.
Color _typeColor(String type) {
  switch (type) {
    case 'sos':
      return Colors.red.shade700;
    case 'geofence_enter':
      return Colors.teal.shade700;
    case 'geofence_exit':
      return Colors.amber.shade800;
    case 'geofence_added':
    case 'member_added':
      return Colors.blueGrey;
    default:
      return Colors.grey;
  }
}

/// Icon counterpart to `_typeColor` above — same five known types plus a
/// generic fallback, mirroring `FamilyAlertsScreen`'s own `_typeIcon`
/// convention (a per-type icon map local to the screen file, not shared).
IconData _typeIcon(String type) {
  switch (type) {
    case 'sos':
      return Icons.sos;
    case 'geofence_enter':
      return Icons.login;
    case 'geofence_exit':
      return Icons.logout;
    case 'geofence_added':
      return Icons.shield_outlined;
    case 'member_added':
      return Icons.person_add_alt_1_outlined;
    default:
      return Icons.circle_notifications_outlined;
  }
}

/// Same dependency-free "dd/MM HH:mm" formatter used by
/// `FamilyAlertsScreen`/`FamilyMemberLocationHistoryScreen` — duplicated
/// rather than shared, matching this feature's established convention for
/// small single-use formatters (see those screens' own docblocks).
String _formatTimestamp(String isoTimestamp) {
  final parsed = DateTime.tryParse(isoTimestamp);

  if (parsed == null) {
    return isoTimestamp;
  }

  final local = parsed.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');

  return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
}
