import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../application/admin_reports_providers.dart';
import '../data/admin_report_export_models.dart';
import '../data/admin_report_models.dart';

/// "التقارير" — `ReportController::fleet()`/`drivers()`/`trips()`/`fuel()`/
/// `maintenance()`/`financial()`, verified directly against that
/// controller/`ReportDataService` before building this.
///
/// **No permission gate on the screen itself for viewing** — same
/// "the request is the gate" convention as every other admin screen in
/// this app: the `reports.view` middleware on the whole `reports/*` route
/// group is what actually enforces access, and the only entry point
/// (`AdminHomeScreen`) never renders the "التقارير" tile unless that
/// permission is already present.
///
/// The one exception is the "تصدير" app bar action added here: `POST
/// /reports/export` is gated by the separate `reports.export` permission
/// (verified directly against `routes/api_v1.php` before building this),
/// which someone with plain `reports.view` may not hold — so, unlike every
/// other action in this screen, that button checks
/// `permissions.contains('reports.export')` itself rather than trusting
/// the entry point alone.
///
/// One generic screen serves all six report types (`adminReportTypeLabels`)
/// instead of six near-identical ones, because `ReportDataService` itself
/// hands back the exact same `{summary, columns, rows}` shape for every
/// type — see `AdminReport`'s own docblock. A row is rendered as a small
/// card of "label: value" pairs (built from `columns` + that row's map) —
/// deliberately not a `DataTable` (no precedent for one anywhere in this
/// app, and a wide table forces awkward horizontal scrolling on a phone
/// screen for reports with 5-6 columns), mirroring how every other admin
/// list screen in this app (`AdminVehiclesScreen`, `AdminTripsScreen`, …)
/// renders one card per item instead.
class AdminReportsScreen extends ConsumerWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(adminReportProvider);
    final permissions = ref.watch(authControllerProvider).user?.permissions ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير'),
        actions: [
          if (permissions.contains('reports.export'))
            IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: 'تصدير',
              onPressed: () => _showExportSheet(context, ref),
            ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'سجل التصدير',
            onPressed: () => context.push('/admin/reports/exports'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: () => ref.invalidate(adminReportProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          const _TypeSelector(),
          const _DateRangeBar(),
          const Divider(height: 1),
          Expanded(
            child: reportAsync.when(
              data: (report) => _ReportBody(report: report),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _ErrorState(
                message: error.toString(),
                onRetry: () => ref.invalidate(adminReportProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeSelector extends ConsumerWidget {
  const _TypeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(adminReportTypeProvider);

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: [
          for (final entry in adminReportTypeLabels.entries)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ChoiceChip(
                label: Text(entry.value),
                selected: selected == entry.key,
                onSelected: (_) => ref.read(adminReportTypeProvider.notifier).state = entry.key,
              ),
            ),
        ],
      ),
    );
  }
}

class _DateRangeBar extends ConsumerWidget {
  const _DateRangeBar();

  Future<void> _pickDate(BuildContext context, WidgetRef ref, {required bool isFrom}) async {
    final now = DateTime.now();
    final initial = isFrom
        ? ref.read(adminReportsFromFilterProvider) ?? now
        : ref.read(adminReportsToFilterProvider) ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
    );

    if (picked == null || !context.mounted) {
      return;
    }

    if (isFrom) {
      ref.read(adminReportsFromFilterProvider.notifier).state = picked;
    } else {
      ref.read(adminReportsToFilterProvider.notifier).state = picked;
    }
  }

  void _clear(WidgetRef ref) {
    ref.read(adminReportsFromFilterProvider.notifier).state = null;
    ref.read(adminReportsToFilterProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final from = ref.watch(adminReportsFromFilterProvider);
    final to = ref.watch(adminReportsToFilterProvider);
    final hasAnyFilter = from != null || to != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pickDate(context, ref, isFrom: true),
              icon: const Icon(Icons.date_range_outlined, size: 18),
              label: Text(from == null ? 'من تاريخ' : _formatDate(from)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pickDate(context, ref, isFrom: false),
              icon: const Icon(Icons.date_range_outlined, size: 18),
              label: Text(to == null ? 'إلى تاريخ' : _formatDate(to)),
            ),
          ),
          if (hasAnyFilter)
            IconButton(
              tooltip: 'مسح الفلترة (الشهر الحالي)',
              icon: const Icon(Icons.filter_alt_off_outlined),
              onPressed: () => _clear(ref),
            ),
        ],
      ),
    );
  }
}

class _ReportBody extends ConsumerWidget {
  const _ReportBody({required this.report});

  final AdminReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(adminReportProvider),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          if (report.filterFrom != null && report.filterTo != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'الفترة: ${report.filterFrom} — ${report.filterTo}',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          if (report.summary.isNotEmpty) _SummaryGrid(summary: report.summary),
          const SizedBox(height: 12),
          if (report.rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('لا توجد بيانات ضمن هذه الفترة.')),
            )
          else
            for (final row in report.rows) _RowCard(row: row, columns: report.columns),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});

  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in summary.entries)
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${entry.value}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(entry.key, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _RowCard extends StatelessWidget {
  const _RowCard({required this.row, required this.columns});

  final Map<String, dynamic> row;
  final Map<String, String> columns;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entry in columns.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(entry.value, style: const TextStyle(color: Colors.grey)),
                    ),
                    Expanded(child: Text(_displayValue(row[entry.key]))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _displayValue(dynamic value) {
    if (value == null) {
      return '—';
    }

    return value.toString();
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
                  Text('تعذر تحميل التقرير: $message', textAlign: TextAlign.center),
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

/// Opens the format-picker sheet, pre-filled with whatever type/date-range
/// this screen currently has selected (`adminReportTypeProvider`/
/// `adminReportsFromFilterProvider`/`adminReportsToFilterProvider`) — the
/// export a user is looking at on screen is the one they almost always mean
/// to export, so there's no separate type/date picker duplicated inside the
/// sheet itself.
Future<void> _showExportSheet(BuildContext context, WidgetRef ref) async {
  final type = ref.read(adminReportTypeProvider);
  final from = ref.read(adminReportsFromFilterProvider);
  final to = ref.read(adminReportsToFilterProvider);

  final requested = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _ExportSheet(type: type, from: from, to: to),
  );

  if (requested == true && context.mounted) {
    // Mirrors `ReportController::export()`'s own success message
    // verbatim (verified directly against that controller) rather than a
    // generic "تم الإرسال" — the backend's copy already explains what
    // happens next (a completed export shows up in the history screen,
    // there's no push notification wired to actually message the user).
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إنشاء طلب التصدير، ستصلك رسالة عند اكتماله')),
    );
    context.push('/admin/reports/exports');
  }
}

class _ExportSheet extends ConsumerStatefulWidget {
  const _ExportSheet({required this.type, required this.from, required this.to});

  final String type;
  final DateTime? from;
  final DateTime? to;

  @override
  ConsumerState<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<_ExportSheet> {
  String _format = 'pdf';
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(adminReportExportsApiProvider).create(
            type: widget.type,
            format: _format,
            from: widget.from,
            to: widget.to,
          );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      setState(() {
        _submitting = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeLabel = adminReportTypeLabels[widget.type] ?? widget.type;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('تصدير تقرير "$typeLabel"', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              widget.from != null && widget.to != null
                  ? 'الفترة: ${_formatDate(widget.from!)} — ${_formatDate(widget.to!)}'
                  : 'الفترة: الشهر الحالي (الافتراضي)',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final entry in adminReportExportFormatLabels.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _format == entry.key,
                    onSelected: (_) => setState(() => _format = entry.key),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('طلب التصدير'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
