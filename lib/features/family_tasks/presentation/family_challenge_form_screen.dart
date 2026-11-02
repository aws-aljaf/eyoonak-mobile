import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_exception.dart';
import '../../family/application/family_providers.dart';
import '../application/family_tasks_providers.dart';
import '../data/family_task_models.dart';
import '../data/suggested_task_library.dart';

/// PR-68: create/edit form for a single `FamilyChallenge` — reached only
/// from an account `canManageFamilyTasksProvider` already confirmed true
/// (the FAB on `FamilyChallengesListScreen`, or the "تعديل" menu item on
/// `FamilyChallengeDetailScreen`); the actual authorization boundary is
/// still `FamilyChallengePolicy::create()`/`::update()` server-side — this
/// screen never assumes its own client-side gate is sufficient, it just
/// surfaces whatever `ApiException` a 403 carries if reached anyway (same
/// "the request is the real gate" convention as `FamilyTaskFormScreen`/
/// `FamilyRewardFormScreen`).
///
/// `existing == null` is "create"; non-null is "edit", pre-filling every
/// field from that challenge. `categoryFilter` reuses the same
/// `familyTaskCategoryLabels` picker `FamilyTaskFormScreen` uses for a
/// task's own `category`, but with an extra leading "كل التصنيفات" option
/// (`null`) — a challenge with no filter counts every approved task
/// toward its goal, per `FamilyChallenge::matches()`'s own check on the
/// backend (verified directly). `startDate`/`endDate` reuse the same
/// date-picker pattern as `FamilyTaskFormScreen`'s own start/end fields,
/// except both are required here (never optional) — `end_date` is a
/// `required date` on `StoreFamilyChallengeRequest`, unlike a task's
/// optional one.
class FamilyChallengeFormScreen extends ConsumerStatefulWidget {
  const FamilyChallengeFormScreen({this.existing, super.key});

  final FamilyChallengeModel? existing;

  @override
  ConsumerState<FamilyChallengeFormScreen> createState() => _FamilyChallengeFormScreenState();
}

class _FamilyChallengeFormScreenState extends ConsumerState<FamilyChallengeFormScreen> {
  late final _titleController = TextEditingController(text: widget.existing?.title ?? '');
  late final _descriptionController = TextEditingController(text: widget.existing?.description ?? '');
  late final _goalController = TextEditingController(text: '${widget.existing?.goalTarget ?? 5}');
  late final _bonusController = TextEditingController(text: '${widget.existing?.bonusPoints ?? 20}');

  // `late` is required here (not just on the `TextEditingController` fields
  // above) because a plain instance-field initializer runs before `widget`
  // is available at all — referencing it there is
  // `implicit_this_reference_in_initializer`, a real `flutter analyze`
  // error caught by CI on this exact line before this fix.
  late String? _categoryFilter = widget.existing?.categoryFilter;
  late DateTime _startDate = _parseDate(widget.existing?.startDate) ?? DateTime.now();
  late DateTime _endDate =
      _parseDate(widget.existing?.endDate) ?? DateTime.now().add(const Duration(days: 7));
  late String _status = widget.existing?.status ?? 'active';

  bool _saving = false;
  String? _errorMessage;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _goalController.dispose();
    _bonusController.dispose();
    super.dispose();
  }

  static DateTime? _parseDate(String? value) => value == null ? null : DateTime.tryParse(value);

  static String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');

    return '$y-$m-$d';
  }

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
      // `end_date` is required (never null here, unlike a task's optional
      // one) — bump it forward with the new start date instead of leaving
      // a stale end that would fail server-side validation
      // (`after_or_equal:start_date`) silently until submit.
      if (_endDate.isBefore(_startDate)) {
        _endDate = _startDate;
      }
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(_startDate) ? _startDate : _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );

    if (picked == null || !mounted) return;

    setState(() => _endDate = picked);
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final goalTarget = int.tryParse(_goalController.text.trim());
    final bonusPoints = int.tryParse(_bonusController.text.trim());

    if (title.isEmpty) {
      setState(() => _errorMessage = 'الرجاء إدخال عنوان التحدي.');
      return;
    }

    if (goalTarget == null || goalTarget < 1) {
      setState(() => _errorMessage = 'الرجاء إدخال هدف صحيح (عدد مهام موجب).');
      return;
    }

    if (bonusPoints == null || bonusPoints < 0) {
      setState(() => _errorMessage = 'الرجاء إدخال عدد نقاط إضافية صحيح (صفر أو أكثر).');
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

      if (_isEditing) {
        await api.updateChallenge(
          challengeId: widget.existing!.id,
          title: title,
          description: description.isEmpty ? null : description,
          categoryFilter: _categoryFilter,
          goalTarget: goalTarget,
          bonusPoints: bonusPoints,
          startDate: _formatDate(_startDate),
          endDate: _formatDate(_endDate),
          status: _status,
          familyId: familyId,
        );
        ref.invalidate(familyChallengeDetailProvider(widget.existing!.id));
      } else {
        await api.createChallenge(
          title: title,
          description: description.isEmpty ? null : description,
          categoryFilter: _categoryFilter,
          goalTarget: goalTarget,
          bonusPoints: bonusPoints,
          startDate: _formatDate(_startDate),
          endDate: _formatDate(_endDate),
          familyId: familyId,
        );
      }

      ref.invalidate(familyChallengesProvider);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditing ? 'تم تحديث التحدي بنجاح' : 'تمت إضافة التحدي بنجاح')),
      );
    } on ApiException catch (error) {
      setState(() => _errorMessage = error.message);
    } catch (error) {
      setState(() => _errorMessage = 'تعذر حفظ التحدي: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'تعديل التحدي' : 'إنشاء تحدٍ')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'عنوان التحدي', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'الوصف (اختياري)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _categoryFilter,
              decoration: const InputDecoration(
                labelText: 'التصنيف (اختياري)',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('كل التصنيفات (أي مهمة تحتسب)')),
                for (final entry in familyTaskCategoryLabels.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) => setState(() => _categoryFilter = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _goalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'الهدف (عدد المهام المطلوبة)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bonusController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'نقاط إضافية عند بلوغ الهدف',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            _DateField(label: 'تاريخ البدء', value: _startDate, onTap: _pickStartDate),
            const SizedBox(height: 8),
            _DateField(label: 'تاريخ الانتهاء', value: _endDate, onTap: _pickEndDate),
            if (_isEditing) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'الحالة', border: OutlineInputBorder()),
                items: [
                  for (final entry in familyChallengeStatusLabels.entries)
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
                    : Text(_isEditing ? 'حفظ التعديلات' : 'إنشاء التحدي'),
              ),
            ),
          ],
        ),
      ),
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
        child: Text(_FamilyChallengeFormScreenState._formatDate(value)),
      ),
    );
  }
}
