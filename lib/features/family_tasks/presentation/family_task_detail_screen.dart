import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_exception.dart';
import '../../family/application/family_providers.dart';
import '../application/family_tasks_providers.dart';
import '../data/family_task_models.dart';
import '../data/suggested_task_library.dart';

/// One task's full detail — reached by tapping a card on
/// `FamilyTasksListScreen`. Edit/delete are gated the same way that
/// screen's FAB is (`canManageFamilyTasksProvider`); the actual
/// authorization boundary stays `FamilyTaskPolicy::update()`/`::delete()`
/// server-side (see that provider's own docblock).
class FamilyTaskDetailScreen extends ConsumerWidget {
  const FamilyTaskDetailScreen({required this.taskId, super.key});

  final int taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAsync = ref.watch(familyTaskDetailProvider(taskId));
    final canManage = ref.watch(canManageFamilyTasksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل المهمة'),
        actions: [
          if (canManage)
            taskAsync.when(
              data: (task) => PopupMenuButton<String>(
                tooltip: 'المزيد',
                onSelected: (value) {
                  if (value == 'edit') {
                    context.push('/family/tasks/${task.id}/edit', extra: task);
                  } else if (value == 'delete') {
                    _delete(context, ref, task);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('حذف', style: TextStyle(color: Colors.red.shade700)),
                  ),
                ],
              ),
              loading: () => const SizedBox.shrink(),
              error: (error, stack) => const SizedBox.shrink(),
            ),
        ],
      ),
      body: taskAsync.when(
        data: (task) => _TaskDetailBody(task: task),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(familyTaskDetailProvider(taskId)),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, FamilyTaskModel task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المهمة'),
        content: Text('سيتم حذف مهمة "${task.title}" نهائيًا من لوحة المهام. هل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final familyId = ref.read(selectedFamilyIdProvider);

      await ref.read(familyTasksApiProvider).deleteTask(taskId: task.id, familyId: familyId);
      ref.invalidate(familyTasksProvider);

      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف المهمة')));
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حذف المهمة: $error')));
      }
    }
  }
}

class _TaskDetailBody extends StatelessWidget {
  const _TaskDetailBody({required this.task});

  final FamilyTaskModel task;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(task.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        if (task.description != null && task.description!.isNotEmpty) ...[
          Text(task.description!),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text(familyTaskCategoryLabels[task.category] ?? task.category)),
            Chip(label: Text('${task.points} نقطة')),
            Chip(label: Text(familyTaskRecurrenceLabels[task.recurrenceType] ?? task.recurrenceType)),
            Chip(label: Text(familyTaskStatusLabels[task.status] ?? task.status)),
            if (task.requiresApproval) const Chip(label: Text('يتطلب موافقة الوالد')),
          ],
        ),
        const SizedBox(height: 16),
        _InfoRow(
          icon: Icons.group_outlined,
          label: 'مسندة إلى',
          value: task.assignToAll
              ? 'كل أفراد العائلة'
              : (task.assignees.isEmpty
                  ? 'لا يوجد إسناد'
                  : task.assignees.map((a) => a.fullName).join('، ')),
        ),
        _InfoRow(icon: Icons.event_outlined, label: 'تاريخ البدء', value: task.startDate),
        if (task.endDate != null) _InfoRow(icon: Icons.event_busy_outlined, label: 'تاريخ الانتهاء', value: task.endDate!),
        if (task.recurrenceType == 'specific_days' && (task.recurrenceDays?.isNotEmpty ?? false))
          _InfoRow(
            icon: Icons.calendar_view_week_outlined,
            label: 'أيام التكرار',
            value: task.recurrenceDays!.map((d) => weekdayLabels[d] ?? '$d').join('، '),
          ),
        if (task.timeStart != null || task.timeEnd != null)
          _InfoRow(
            icon: Icons.schedule_outlined,
            label: 'الوقت',
            value: '${task.timeStart ?? '--'} حتى ${task.timeEnd ?? '--'}',
          ),
        if (task.notes != null && task.notes!.isNotEmpty)
          _InfoRow(icon: Icons.notes_outlined, label: 'ملاحظات', value: task.notes!),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value),
              ],
            ),
          ),
        ],
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
                  Text('تعذر تحميل المهمة: $message', textAlign: TextAlign.center),
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
