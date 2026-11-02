import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_exception.dart';
import '../../family/application/family_providers.dart';
import '../../family/data/family_models.dart';
import '../application/family_tasks_providers.dart';
import '../data/family_task_models.dart';
import '../data/suggested_task_library.dart';

/// Create/edit form for a single `FamilyTask` — reached only from an
/// account `canManageFamilyTasksProvider` already confirmed true (the FAB
/// on `FamilyTasksListScreen`, or the "تعديل" menu item on
/// `FamilyTaskDetailScreen`); the actual authorization boundary is still
/// `FamilyTaskPolicy::create()`/`::update()` server-side — this screen
/// never assumes its own client-side gate is sufficient, it just surfaces
/// whatever `ApiException` a 403 carries if reached anyway (same "the
/// request is the real gate" convention as every other write in this
/// app).
///
/// `existing == null` is "create"; non-null is "edit", pre-filling every
/// field from that task's own detail. The "اقتراحات" (suggestions)
/// section only ever pre-fills `title`/`points`/`category` from
/// `suggestedTaskLibrary` — nothing here is auto-activated, matching plan
/// judgment call #6: a parent may freely edit or entirely ignore a
/// suggestion before saving.
class FamilyTaskFormScreen extends ConsumerStatefulWidget {
  const FamilyTaskFormScreen({this.existing, super.key});

  final FamilyTaskModel? existing;

  @override
  ConsumerState<FamilyTaskFormScreen> createState() => _FamilyTaskFormScreenState();
}

class _FamilyTaskFormScreenState extends ConsumerState<FamilyTaskFormScreen> {
  late final _titleController = TextEditingController(text: widget.existing?.title ?? '');
  late final _descriptionController = TextEditingController(text: widget.existing?.description ?? '');
  late final _notesController = TextEditingController(text: widget.existing?.notes ?? '');
  late final _pointsController = TextEditingController(text: '${widget.existing?.points ?? 10}');

  late String _category = widget.existing?.category ?? 'custom';
  late bool _requiresApproval = widget.existing?.requiresApproval ?? false;
  late bool _assignToAll = widget.existing?.assignToAll ?? true;
  late Set<int> _assigneeIds = widget.existing?.assignees.map((a) => a.id).toSet() ?? <int>{};
  late String _recurrenceType = widget.existing?.recurrenceType ?? 'daily';
  late Set<int> _recurrenceDays = widget.existing?.recurrenceDays?.toSet() ?? <int>{};
  late DateTime _startDate = _parseDate(widget.existing?.startDate) ?? DateTime.now();
  DateTime? _endDate;
  TimeOfDay? _timeStart;
  TimeOfDay? _timeEnd;
  late String _status = widget.existing?.status ?? 'active';

  bool _saving = false;
  String? _errorMessage;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;

    if (existing != null) {
      _endDate = _parseDate(existing.endDate);
      _timeStart = _parseTime(existing.timeStart);
      _timeEnd = _parseTime(existing.timeEnd);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  static DateTime? _parseDate(String? value) => value == null ? null : DateTime.tryParse(value);

  static TimeOfDay? _parseTime(String? value) {
    if (value == null) return null;

    final parts = value.split(':');
    if (parts.length < 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;

    return TimeOfDay(hour: hour, minute: minute);
  }

  static String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');

    return '$y-$m-$d';
  }

  static String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  int _minutesOf(TimeOfDay time) => time.hour * 60 + time.minute;

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );

    if (picked == null || !mounted) return;

    setState(() {
      _startDate = picked;
      // A stale end date before the new start date would fail server-side
      // validation (`after_or_equal:start_date`) silently until submit —
      // clearing it here surfaces the conflict immediately instead.
      if (_endDate != null && _endDate!.isBefore(_startDate)) {
        _endDate = null;
      }
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );

    if (picked == null || !mounted) return;

    setState(() => _endDate = picked);
  }

  Future<void> _pickTimeStart() async {
    final picked = await showTimePicker(context: context, initialTime: _timeStart ?? TimeOfDay.now());

    if (picked == null || !mounted) return;

    setState(() => _timeStart = picked);
  }

  Future<void> _pickTimeEnd() async {
    final picked = await showTimePicker(context: context, initialTime: _timeEnd ?? TimeOfDay.now());

    if (picked == null || !mounted) return;

    setState(() => _timeEnd = picked);
  }

  Future<void> _pickSuggestion() async {
    final selection = await showModalBottomSheet<({String category, SuggestedTask task})>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _SuggestionSheet(),
    );

    if (selection == null || !mounted) return;

    setState(() {
      _titleController.text = selection.task.title;
      _pointsController.text = '${selection.task.defaultPoints}';
      _category = selection.category;
    });
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final points = int.tryParse(_pointsController.text.trim());

    if (title.isEmpty) {
      setState(() => _errorMessage = 'الرجاء إدخال عنوان المهمة.');
      return;
    }

    if (points == null || points < 1) {
      setState(() => _errorMessage = 'الرجاء إدخال عدد نقاط صحيح (رقم موجب).');
      return;
    }

    if (!_assignToAll && _assigneeIds.isEmpty) {
      setState(() => _errorMessage = 'حدّد فردًا واحدًا على الأقل، أو فعّل "كل أفراد العائلة".');
      return;
    }

    if (_recurrenceType == 'specific_days' && _recurrenceDays.isEmpty) {
      setState(() => _errorMessage = 'حدّد أيام الأسبوع المطلوبة لهذا النوع من التكرار.');
      return;
    }

    if (_timeStart != null && _timeEnd != null && _minutesOf(_timeEnd!) <= _minutesOf(_timeStart!)) {
      setState(() => _errorMessage = 'وقت النهاية يجب أن يكون بعد وقت البداية.');
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final familyId = ref.read(selectedFamilyIdProvider);
      final api = ref.read(familyTasksApiProvider);
      final description = _descriptionController.text.trim();
      final notes = _notesController.text.trim();
      final sortedDays = _recurrenceDays.toList()..sort();

      if (_isEditing) {
        await api.updateTask(
          taskId: widget.existing!.id,
          title: title,
          description: description.isEmpty ? null : description,
          category: _category,
          points: points,
          requiresApproval: _requiresApproval,
          assignToAll: _assignToAll,
          assigneeIds: _assigneeIds.toList(),
          recurrenceType: _recurrenceType,
          recurrenceDays: sortedDays,
          startDate: _formatDate(_startDate),
          endDate: _endDate == null ? null : _formatDate(_endDate!),
          timeStart: _timeStart == null ? null : _formatTime(_timeStart!),
          timeEnd: _timeEnd == null ? null : _formatTime(_timeEnd!),
          notes: notes.isEmpty ? null : notes,
          status: _status,
          familyId: familyId,
        );
        ref.invalidate(familyTaskDetailProvider(widget.existing!.id));
      } else {
        await api.createTask(
          title: title,
          description: description.isEmpty ? null : description,
          category: _category,
          points: points,
          requiresApproval: _requiresApproval,
          assignToAll: _assignToAll,
          assigneeIds: _assigneeIds.toList(),
          recurrenceType: _recurrenceType,
          recurrenceDays: sortedDays,
          startDate: _formatDate(_startDate),
          endDate: _endDate == null ? null : _formatDate(_endDate!),
          timeStart: _timeStart == null ? null : _formatTime(_timeStart!),
          timeEnd: _timeEnd == null ? null : _formatTime(_timeEnd!),
          notes: notes.isEmpty ? null : notes,
          familyId: familyId,
        );
      }

      ref.invalidate(familyTasksProvider);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditing ? 'تم تحديث المهمة بنجاح' : 'تمت إضافة المهمة بنجاح')),
      );
    } on ApiException catch (error) {
      setState(() => _errorMessage = error.message);
    } catch (error) {
      setState(() => _errorMessage = 'تعذر حفظ المهمة: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(familyMembersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'تعديل المهمة' : 'إضافة مهمة')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            OutlinedButton.icon(
              onPressed: _pickSuggestion,
              icon: const Icon(Icons.lightbulb_outline),
              label: const Text('اختر من مكتبة الاقتراحات'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'عنوان المهمة', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'الوصف (اختياري)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'التصنيف', border: OutlineInputBorder()),
              items: [
                for (final entry in familyTaskCategoryLabels.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) => setState(() => _category = value ?? _category),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pointsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'عدد النقاط', border: OutlineInputBorder()),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('تتطلب موافقة الوالد'),
              subtitle: const Text('بدون هذا الخيار يُعتمد الإنجاز فور الضغط على "تم الإنجاز"'),
              value: _requiresApproval,
              onChanged: (value) => setState(() => _requiresApproval = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('كل أفراد العائلة'),
              value: _assignToAll,
              onChanged: (value) => setState(() => _assignToAll = value),
            ),
            if (!_assignToAll) ...[
              const SizedBox(height: 4),
              _AssigneePicker(
                membersAsync: membersAsync,
                selectedIds: _assigneeIds,
                onChanged: (ids) => setState(() => _assigneeIds = ids),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _recurrenceType,
              decoration: const InputDecoration(labelText: 'التكرار', border: OutlineInputBorder()),
              items: [
                for (final entry in familyTaskRecurrenceLabels.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) => setState(() => _recurrenceType = value ?? _recurrenceType),
            ),
            if (_recurrenceType == 'specific_days') ...[
              const SizedBox(height: 8),
              _WeekdayPicker(
                selectedDays: _recurrenceDays,
                onChanged: (days) => setState(() => _recurrenceDays = days),
              ),
            ],
            const SizedBox(height: 12),
            _DateField(label: 'تاريخ البدء', value: _startDate, onTap: _pickStartDate),
            const SizedBox(height: 8),
            _NullableDateField(
              label: 'تاريخ الانتهاء (اختياري)',
              value: _endDate,
              onTap: _pickEndDate,
              onClear: () => setState(() => _endDate = null),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _NullableTimeField(
                    label: 'وقت البدء (اختياري)',
                    value: _timeStart,
                    onTap: _pickTimeStart,
                    onClear: () => setState(() => _timeStart = null),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _NullableTimeField(
                    label: 'وقت الانتهاء (اختياري)',
                    value: _timeEnd,
                    onTap: _pickTimeEnd,
                    onClear: () => setState(() => _timeEnd = null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)', border: OutlineInputBorder()),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'الحالة', border: OutlineInputBorder()),
                items: [
                  for (final entry in familyTaskStatusLabels.entries)
                    DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                ],
                onChanged: (value) => setState(() => _status = value ?? _status),
              ),
            ],
            if (_errorMessage case final message?) ...[
              const SizedBox(height: 12),
              Text(message, style: TextStyle(color: Colors.red.shade700)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_isEditing ? 'حفظ التعديلات' : 'إضافة المهمة'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssigneePicker extends StatelessWidget {
  const _AssigneePicker({required this.membersAsync, required this.selectedIds, required this.onChanged});

  final AsyncValue<List<FamilyMemberModel>> membersAsync;
  final Set<int> selectedIds;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    return membersAsync.when(
      data: (members) {
        if (members.isEmpty) {
          return const Text('لا يوجد أفراد بهذه العائلة بعد.');
        }

        return Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final member in members)
              FilterChip(
                label: Text(member.fullName),
                selected: selectedIds.contains(member.id),
                onSelected: (selected) {
                  final next = Set<int>.from(selectedIds);
                  if (selected) {
                    next.add(member.id);
                  } else {
                    next.remove(member.id);
                  }
                  onChanged(next);
                },
              ),
          ],
        );
      },
      loading: () => const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      error: (error, stack) => Text('تعذر تحميل أفراد العائلة: $error'),
    );
  }
}

class _WeekdayPicker extends StatelessWidget {
  const _WeekdayPicker({required this.selectedDays, required this.onChanged});

  final Set<int> selectedDays;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final entry in weekdayLabels.entries)
          FilterChip(
            label: Text(entry.value),
            selected: selectedDays.contains(entry.key),
            onSelected: (selected) {
              final next = Set<int>.from(selectedDays);
              if (selected) {
                next.add(entry.key);
              } else {
                next.remove(entry.key);
              }
              onChanged(next);
            },
          ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onTap});

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        child: Text(_FamilyTaskFormScreenState._formatDate(value)),
      ),
    );
  }
}

class _NullableDateField extends StatelessWidget {
  const _NullableDateField({required this.label, required this.value, required this.onTap, required this.onClear});

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: value == null ? null : IconButton(icon: const Icon(Icons.clear), onPressed: onClear),
        ),
        child: Text(value == null ? 'بلا تاريخ انتهاء' : _FamilyTaskFormScreenState._formatDate(value!)),
      ),
    );
  }
}

class _NullableTimeField extends StatelessWidget {
  const _NullableTimeField({required this.label, required this.value, required this.onTap, required this.onClear});

  final String label;
  final TimeOfDay? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: value == null ? null : IconButton(icon: const Icon(Icons.clear), onPressed: onClear),
        ),
        child: Text(value == null ? '--:--' : _FamilyTaskFormScreenState._formatTime(value!)),
      ),
    );
  }
}

/// The "اقتراحات" bottom sheet — one section per suggestable category
/// (`suggestedTaskLibrary`), each item a tappable chip that pops back the
/// chosen `SuggestedTask`. Purely a picker: nothing here writes anything,
/// the caller (`_pickSuggestion`) decides what to do with the result.
/// Plain `SafeArea` + scrollable `Column`, same shape
/// `_AlertsFilterSheet` (`family_alerts_screen.dart`) already establishes
/// for a `showModalBottomSheet` body in this codebase, rather than a
/// `DraggableScrollableSheet` this app has no existing precedent for.
class _SuggestionSheet extends StatelessWidget {
  const _SuggestionSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('مكتبة الاقتراحات', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final entry in suggestedTaskLibrary.entries) ...[
              Text(
                familyTaskCategoryLabels[entry.key] ?? entry.key,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final suggestion in entry.value)
                    ActionChip(
                      label: Text('${suggestion.title} (${suggestion.defaultPoints})'),
                      onPressed: () => Navigator.of(context).pop((category: entry.key, task: suggestion)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
