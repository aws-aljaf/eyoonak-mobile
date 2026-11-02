import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/audit_logs_providers.dart';
import '../data/audit_log_models.dart';

/// "سجل العمليات" — `AuditLogController::index()`
/// (backend/app/Http/Controllers/Api/V1/AuditLogController.php), verified
/// directly against that controller/`AuditLogPolicy`/`AuditLogResource`
/// before building this.
///
/// **No permission gate on this screen or route itself** — same
/// "the request is the gate" convention as every family screen in this
/// app: `AuditLogPolicy::viewAny()` (`audit_logs.view`) is what actually
/// enforces access, and the only entry point (`AdminHomeScreen`) never
/// renders the tile that reaches here unless that permission is already
/// present.
///
/// **Real prev/next pagination**, mirroring `FamilyTimelineScreen` exactly
/// (see that screen's docblock for why: an office-wide audit trail can
/// grow large, unlike a single driver's own small history lists) rather
/// than a flatten-and-forget `per_page`-and-done fetch.
class AuditLogsScreen extends ConsumerWidget {
  const AuditLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(auditLogsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل العمليات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: () => ref.invalidate(auditLogsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          const _FilterBar(),
          Expanded(
            child: logsAsync.when(
              data: (envelope) {
                final items = envelope.data
                    .map((e) => AuditLog.fromJson(Map<String, dynamic>.from(e as Map)))
                    .toList();

                return _LogsBody(items: items, currentPage: envelope.currentPage, lastPage: envelope.lastPage);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _ErrorState(
                message: error.toString(),
                onRetry: () => ref.invalidate(auditLogsProvider),
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
  final _actionController = TextEditingController();

  @override
  void dispose() {
    _actionController.dispose();
    super.dispose();
  }

  /// Every filter change also resets the page back to 1 — otherwise a
  /// narrower filter could leave the screen stuck on a now out-of-range
  /// page (see `auditLogsProvider`'s own docblock).
  void _applyAction(String value) {
    ref.read(auditLogsActionFilterProvider.notifier).state = value.trim().isEmpty ? null : value.trim();
    ref.read(auditLogsPageProvider.notifier).state = 1;
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final initial = isFrom
        ? ref.read(auditLogsFromFilterProvider) ?? now
        : ref.read(auditLogsToFilterProvider) ?? now;

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
      ref.read(auditLogsFromFilterProvider.notifier).state = picked;
    } else {
      ref.read(auditLogsToFilterProvider.notifier).state = picked;
    }

    ref.read(auditLogsPageProvider.notifier).state = 1;
  }

  void _clearFilters() {
    _actionController.clear();
    ref.read(auditLogsActionFilterProvider.notifier).state = null;
    ref.read(auditLogsFromFilterProvider.notifier).state = null;
    ref.read(auditLogsToFilterProvider.notifier).state = null;
    ref.read(auditLogsPageProvider.notifier).state = 1;
  }

  @override
  Widget build(BuildContext context) {
    final from = ref.watch(auditLogsFromFilterProvider);
    final to = ref.watch(auditLogsToFilterProvider);
    final hasAnyFilter = ref.watch(auditLogsActionFilterProvider) != null || from != null || to != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        children: [
          TextField(
            controller: _actionController,
            decoration: InputDecoration(
              labelText: 'نوع الإجراء',
              hintText: 'مثال: vehicle.update',
              isDense: true,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                tooltip: 'بحث',
                onPressed: () => _applyAction(_actionController.text),
              ),
            ),
            onSubmitted: _applyAction,
          ),
          const SizedBox(height: 8),
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
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _LogsBody extends ConsumerWidget {
  const _LogsBody({required this.items, required this.currentPage, required this.lastPage});

  final List<AuditLog> items;
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
                    onRefresh: () async => ref.invalidate(auditLogsProvider),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: const Center(child: Text('لا توجد سجلات مطابقة.')),
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async => ref.invalidate(auditLogsProvider),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _LogCard(log: items[index]),
                  ),
                ),
        ),
        _PagerBar(currentPage: currentPage, lastPage: lastPage),
      ],
    );
  }
}

/// Mirrors `FamilyTimelineScreen`'s `_PagerBar` exactly (see that screen's
/// docblock on why simple prev/next beats an infinite-scroll list here).
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
                  ? () => ref.read(auditLogsPageProvider.notifier).state = currentPage - 1
                  : null,
              icon: const Icon(Icons.chevron_right),
              label: const Text('السابق'),
            ),
            Text('صفحة $currentPage من $lastPage', style: Theme.of(context).textTheme.bodySmall),
            TextButton(
              onPressed: currentPage < lastPage
                  ? () => ref.read(auditLogsPageProvider.notifier).state = currentPage + 1
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

class _LogCard extends StatelessWidget {
  const _LogCard({required this.log});

  final AuditLog log;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(log.action, style: Theme.of(context).textTheme.titleSmall),
                ),
                if (log.createdAt != null)
                  Text(_formatTimestamp(log.createdAt!), style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            if (log.modelType != null) ...[
              const SizedBox(height: 4),
              Text(
                'على: ${log.modelType}${log.modelId != null ? ' #${log.modelId}' : ''}',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
            const SizedBox(height: 4),
            Text('بواسطة: ${log.userName ?? 'غير معروف'}', style: const TextStyle(color: Colors.grey)),
            if (log.ipAddress != null) ...[
              const SizedBox(height: 2),
              Text(log.ipAddress!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
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
                  Text('تعذر تحميل سجل العمليات: $message', textAlign: TextAlign.center),
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
  final d = local.day.toString().padLeft(2, '0');
  final m = local.month.toString().padLeft(2, '0');
  final h = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');

  return '$d/$m $h:$min';
}

String _formatDate(DateTime dt) {
  final d = dt.day.toString().padLeft(2, '0');
  final m = dt.month.toString().padLeft(2, '0');

  return '$d/$m/${dt.year}';
}
