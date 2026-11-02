import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/widgets/family_motion.dart';
import '../../../core/network/api_exception.dart';
import '../../family/application/family_providers.dart';
import '../application/family_tasks_providers.dart';
import '../data/family_task_models.dart';
import '../data/suggested_task_library.dart';

/// "مهامي" — a plain family member (child included) sees their own
/// occurrences for the selected day here; an `owner`/`parent`/`admin`
/// instead sees the WHOLE family's occurrences for that day (the backend
/// decides which per account, see `FamilyTaskOccurrenceController::index()`'s
/// own docblock — this screen renders whatever comes back either way,
/// without trying to guess or duplicate that split). The "✅ تم الإنجاز"
/// button is this PR's other named deliverable — gated per-row purely by
/// `FamilyTaskOccurrenceModel.canComplete` (only ever true for a `pending`
/// row); the real authorization (self, or a manager acting for a
/// no-login member) is `FamilyTaskOccurrencePolicy::complete()`
/// server-side.
class MyFamilyTasksScreen extends ConsumerWidget {
  const MyFamilyTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final occurrencesAsync = ref.watch(familyTaskOccurrencesProvider);
    final date = ref.watch(myTasksDateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('مهامي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            tooltip: 'اختيار يوم',
            onPressed: () => _pickDate(context, ref, date),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(familyTaskOccurrencesProvider),
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
                data: (occurrences) => _OccurrenceList(occurrences: occurrences),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => _ErrorState(
                  message: error.toString(),
                  onRetry: () => ref.invalidate(familyTaskOccurrencesProvider),
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

    ref.read(myTasksDateProvider.notifier).state = _format(shifted);
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

    ref.read(myTasksDateProvider.notifier).state = _format(picked);
  }

  static String _format(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');

    return '$y-$m-$d';
  }
}

class _OccurrenceList extends ConsumerWidget {
  const _OccurrenceList({required this.occurrences});

  final List<FamilyTaskOccurrenceModel> occurrences;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (occurrences.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: const Center(child: Text('لا توجد مهام مستحقة في هذا اليوم.')),
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: occurrences.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) =>
          FamilyReveal(key: ValueKey(occurrences[index].id), child: _OccurrenceCard(occurrence: occurrences[index])),
    );
  }
}

class _OccurrenceCard extends ConsumerStatefulWidget {
  const _OccurrenceCard({required this.occurrence});

  final FamilyTaskOccurrenceModel occurrence;

  @override
  ConsumerState<_OccurrenceCard> createState() => _OccurrenceCardState();
}

class _OccurrenceCardState extends ConsumerState<_OccurrenceCard> {
  bool _busy = false;

  FamilyTaskOccurrenceModel get occurrence => widget.occurrence;

  @override
  Widget build(BuildContext context) {
    final task = occurrence.task;
    final statusLabel = familyTaskOccurrenceStatusLabels[occurrence.status] ?? occurrence.status;
    final categoryLabel = familyTaskCategoryLabels[task.category] ?? task.category;

    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text('${task.points}')),
        title: Text(task.title),
        subtitle: Text(
          [
            occurrence.member.fullName,
            categoryLabel,
            statusLabel,
            if (task.timeStart != null) 'الوقت: ${task.timeStart}${task.timeEnd != null ? '-${task.timeEnd}' : ''}',
            if (occurrence.status == 'rejected' && occurrence.rejectionReason != null)
              'السبب: ${occurrence.rejectionReason}',
          ].join(' • '),
        ),
        trailing: _busy
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : (occurrence.canComplete
                ? FilledButton.icon(
                    onPressed: _complete,
                    icon: const Icon(Icons.check),
                    label: const Text('تم الإنجاز'),
                  )
                : _StatusIcon(status: occurrence.status)),
      ),
    );
  }

  Future<void> _complete() async {
    setState(() => _busy = true);

    try {
      final familyId = ref.read(selectedFamilyIdProvider);

      await ref.read(familyTasksApiProvider).completeOccurrence(occurrenceId: occurrence.id, familyId: familyId);
      ref.invalidate(familyTaskOccurrencesProvider);

      if (mounted) {
        await showFamilySuccess(context);
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تسجيل الإنجاز: $error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      'pending_sync' => const Icon(Icons.cloud_upload_outlined, color: Colors.orange),
      'pending_approval' => const Icon(Icons.hourglass_top, color: Colors.orange),
      'approved' => Icon(Icons.check_circle, color: Colors.green.shade700),
      'rejected' => Icon(Icons.cancel_outlined, color: Colors.red.shade700),
      'missed' => const Icon(Icons.event_busy_outlined, color: Colors.grey),
      _ => const Icon(Icons.circle_outlined),
    };
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
                  Text('تعذر تحميل المهام: $message', textAlign: TextAlign.center),
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
