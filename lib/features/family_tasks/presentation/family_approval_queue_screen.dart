import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_exception.dart';
import '../../family/application/family_providers.dart';
import '../application/family_tasks_providers.dart';
import '../data/family_task_models.dart';
import '../data/suggested_task_library.dart';

/// PR-66: "قائمة انتظار موافقة الوالد" — every `pending_approval` occurrence
/// for the selected day, with "اعتماد"/"رفض" actions. Manager-only, same
/// `canManageFamilyTasksProvider` client-side signal PR-65 introduced (the
/// HTTP request itself, gated by `FamilyTaskOccurrencePolicy::approve()`/
/// `::reject()`, remains the real boundary — see that policy's docblock:
/// unlike `complete()`, there is no self-decision branch at all here). Only
/// reachable from `FamilyTasksListScreen`'s own app-bar icon, which is
/// itself only rendered when `canManageFamilyTasksProvider` is true.
class FamilyApprovalQueueScreen extends ConsumerWidget {
  const FamilyApprovalQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final occurrencesAsync = ref.watch(pendingApprovalOccurrencesProvider);
    final date = ref.watch(approvalQueueDateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات الموافقة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            tooltip: 'اختيار يوم',
            onPressed: () => _pickDate(context, ref, date),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(pendingApprovalOccurrencesProvider),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'اليوم السابق',
                    onPressed: () => _shiftDate(ref, date, -1),
                  ),
                  Expanded(child: Center(child: Text(date, style: const TextStyle(fontWeight: FontWeight.bold)))),
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'اليوم التالي',
                    onPressed: () => _shiftDate(ref, date, 1),
                  ),
                ],
              ),
            ),
            Expanded(
              child: occurrencesAsync.when(
                data: (occurrences) => _QueueList(occurrences: occurrences),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => _ErrorState(
                  message: error.toString(),
                  onRetry: () => ref.invalidate(pendingApprovalOccurrencesProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _shiftDate(WidgetRef ref, String currentDate, int days) {
    final parsed = DateTime.tryParse(currentDate) ?? DateTime.now();
    final shifted = parsed.add(Duration(days: days));

    ref.read(approvalQueueDateProvider.notifier).state = _format(shifted);
  }

  Future<void> _pickDate(BuildContext context, WidgetRef ref, String currentDate) async {
    final initial = DateTime.tryParse(currentDate) ?? DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );

    if (picked == null) return;

    ref.read(approvalQueueDateProvider.notifier).state = _format(picked);
  }

  static String _format(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');

    return '$y-$m-$d';
  }
}

class _QueueList extends StatelessWidget {
  const _QueueList({required this.occurrences});

  final List<FamilyTaskOccurrenceModel> occurrences;

  @override
  Widget build(BuildContext context) {
    if (occurrences.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: const Center(child: Text('لا توجد طلبات بانتظار الموافقة في هذا اليوم.')),
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: occurrences.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _QueueCard(occurrence: occurrences[index]),
    );
  }
}

class _QueueCard extends ConsumerStatefulWidget {
  const _QueueCard({required this.occurrence});

  final FamilyTaskOccurrenceModel occurrence;

  @override
  ConsumerState<_QueueCard> createState() => _QueueCardState();
}

class _QueueCardState extends ConsumerState<_QueueCard> {
  bool _busy = false;

  FamilyTaskOccurrenceModel get occurrence => widget.occurrence;

  @override
  Widget build(BuildContext context) {
    final task = occurrence.task;
    final categoryLabel = familyTaskCategoryLabels[task.category] ?? task.category;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text('${task.points}')),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        [
                          occurrence.member.fullName,
                          categoryLabel,
                          if (occurrence.completedAt != null) 'أُنجزت: ${occurrence.completedAt}',
                        ].join(' • '),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_busy)
              const Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)))
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
                      onPressed: _reject,
                      icon: const Icon(Icons.close),
                      label: const Text('رفض'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _approve,
                      icon: const Icon(Icons.check),
                      label: const Text('اعتماد'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _approve() async {
    setState(() => _busy = true);

    try {
      final familyId = ref.read(selectedFamilyIdProvider);

      await ref.read(familyTasksApiProvider).approveOccurrence(occurrenceId: occurrence.id, familyId: familyId);
      ref.invalidate(pendingApprovalOccurrencesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم اعتماد الإنجاز')));
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر اعتماد الإنجاز: $error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('رفض الإنجاز'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('سيتم رفض إنجاز "${occurrence.task.title}" لـ ${occurrence.member.fullName}.'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'سبب الرفض (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('رفض'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);

    try {
      final familyId = ref.read(selectedFamilyIdProvider);
      final reason = reasonController.text.trim();

      await ref.read(familyTasksApiProvider).rejectOccurrence(
            occurrenceId: occurrence.id,
            reason: reason.isEmpty ? null : reason,
            familyId: familyId,
          );
      ref.invalidate(pendingApprovalOccurrencesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفض الإنجاز')));
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر رفض الإنجاز: $error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
                  Text('تعذر تحميل الطلبات: $message', textAlign: TextAlign.center),
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
