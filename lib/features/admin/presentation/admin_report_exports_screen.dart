import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/providers.dart';
import '../application/admin_report_exports_providers.dart';
import '../data/admin_report_export_models.dart';
import '../data/admin_report_models.dart' show adminReportTypeLabels;

/// "سجل التصدير" — `ReportController::exportsIndex()`/`::exportsShow()`,
/// verified directly against that controller/`ReportExportPolicy` before
/// building this. Reached from `AdminReportsScreen`'s app bar (its own
/// "تصدير" action, gated there on `reports.export`, is what actually starts
/// a new export — this screen only lists what's already been requested).
///
/// No permission gate of its own beyond that entry point, same convention
/// as `AdminRoleUsersScreen`: `GET /reports/exports` itself only requires
/// `reports.view` server-side (`ReportController::exportsIndex()` narrows
/// the *rows* to the caller's own requests unless they also hold
/// `reports.export`, rather than blocking the endpoint outright) — so
/// anyone who can already see `AdminReportsScreen` can see this history,
/// they just won't have anything to export a *new* one from without the
/// stronger permission.
class AdminReportExportsScreen extends ConsumerWidget {
  const AdminReportExportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exportsAsync = ref.watch(adminReportExportsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل التصدير'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: () => ref.invalidate(adminReportExportsProvider),
          ),
        ],
      ),
      body: exportsAsync.when(
        data: (envelope) {
          final items = envelope.data
              .map((e) => AdminReportExport.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();

          return _ExportsBody(items: items, currentPage: envelope.currentPage, lastPage: envelope.lastPage);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(adminReportExportsProvider),
        ),
      ),
    );
  }
}

class _ExportsBody extends ConsumerWidget {
  const _ExportsBody({required this.items, required this.currentPage, required this.lastPage});

  final List<AdminReportExport> items;
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
                    onRefresh: () async => ref.invalidate(adminReportExportsProvider),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: const Center(child: Text('لا توجد طلبات تصدير حتى الآن.')),
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async => ref.invalidate(adminReportExportsProvider),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _ExportCard(export: items[index]),
                  ),
                ),
        ),
        _PagerBar(currentPage: currentPage, lastPage: lastPage),
      ],
    );
  }
}

class _ExportCard extends ConsumerStatefulWidget {
  const _ExportCard({required this.export});

  final AdminReportExport export;

  @override
  ConsumerState<_ExportCard> createState() => _ExportCardState();
}

class _ExportCardState extends ConsumerState<_ExportCard> {
  bool _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);

    try {
      final file = await ref.read(adminReportExportsApiProvider).download(widget.export);
      await Share.shareXFiles([XFile(file.path)]);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تنزيل الملف: $error')));
      }
    } finally {
      if (mounted) {
        setState(() => _sharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final export = widget.export;
    final typeLabel = adminReportTypeLabels[export.type] ?? export.type;
    final formatLabel = adminReportExportFormatLabels[export.format] ?? export.format;
    final statusLabel = adminReportExportStatusLabels[export.status] ?? export.status;

    return Card(
      child: ListTile(
        leading: Icon(_statusIcon(export.status), color: _statusColor(export.status)),
        title: Text('$typeLabel — $formatLabel'),
        subtitle: Text(
          export.status == 'failed' && export.errorMessage != null
              ? '${_formatDateTime(export.createdAt)}\n${export.errorMessage}'
              : _formatDateTime(export.createdAt),
        ),
        isThreeLine: export.status == 'failed' && export.errorMessage != null,
        trailing: export.isReady
            ? (_sharing
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : IconButton(icon: const Icon(Icons.ios_share), tooltip: 'مشاركة/حفظ', onPressed: _share))
            : Chip(label: Text(statusLabel), visualDensity: VisualDensity.compact),
      ),
    );
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle_outline;
      case 'failed':
        return Icons.error_outline;
      case 'processing':
        return Icons.hourglass_top_outlined;
      default:
        return Icons.schedule_outlined;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'failed':
        return Colors.red;
      case 'processing':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }
}

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
                  ? () => ref.read(adminReportExportsPageProvider.notifier).state = currentPage - 1
                  : null,
              icon: const Icon(Icons.chevron_right),
              label: const Text('السابق'),
            ),
            Text('صفحة $currentPage من $lastPage', style: Theme.of(context).textTheme.bodySmall),
            TextButton(
              onPressed: currentPage < lastPage
                  ? () => ref.read(adminReportExportsPageProvider.notifier).state = currentPage + 1
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
                  Text('تعذر تحميل سجل التصدير: $message', textAlign: TextAlign.center),
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

String _formatDateTime(DateTime dt) {
  final local = dt.toLocal();
  final date = '${local.day}/${local.month}/${local.year}';
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');

  return '$date $hour:$minute';
}
