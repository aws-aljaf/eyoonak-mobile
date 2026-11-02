import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_exception.dart';
import '../../family/application/family_providers.dart';
import '../application/family_tasks_providers.dart';
import '../data/family_task_models.dart';
import '../data/suggested_task_library.dart';

/// PR-67: create/edit form for a single `FamilyReward` — reached only from
/// an account `canManageFamilyTasksProvider` already confirmed true (the
/// FAB on `FamilyRewardsListScreen`, or the "تعديل" menu item on each
/// card); the actual authorization boundary is still
/// `FamilyRewardPolicy::create()`/`::update()` server-side — this screen
/// never assumes its own client-side gate is sufficient, it just surfaces
/// whatever `ApiException` a 403 carries if reached anyway (same "the
/// request is the real gate" convention as `FamilyTaskFormScreen`).
///
/// `existing == null` is "create"; non-null is "edit", pre-filling every
/// field from that reward. Deliberately far simpler than
/// `FamilyTaskFormScreen` — a reward has no recurrence/assignment/schedule
/// at all, just `name`/`description`/`points_cost`/`icon` (+ `status` once
/// editing, mirroring that form's own `_isEditing`-only status dropdown).
class FamilyRewardFormScreen extends ConsumerStatefulWidget {
  const FamilyRewardFormScreen({this.existing, super.key});

  final FamilyRewardModel? existing;

  @override
  ConsumerState<FamilyRewardFormScreen> createState() => _FamilyRewardFormScreenState();
}

class _FamilyRewardFormScreenState extends ConsumerState<FamilyRewardFormScreen> {
  late final _nameController = TextEditingController(text: widget.existing?.name ?? '');
  late final _descriptionController = TextEditingController(text: widget.existing?.description ?? '');
  late final _pointsController = TextEditingController(text: '${widget.existing?.pointsCost ?? 100}');
  late final _iconController = TextEditingController(text: widget.existing?.icon ?? '');

  late String _status = widget.existing?.status ?? 'active';

  bool _saving = false;
  String? _errorMessage;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _pointsController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final pointsCost = int.tryParse(_pointsController.text.trim());

    if (name.isEmpty) {
      setState(() => _errorMessage = 'الرجاء إدخال اسم المكافأة.');
      return;
    }

    if (pointsCost == null || pointsCost < 1) {
      setState(() => _errorMessage = 'الرجاء إدخال عدد نقاط صحيح (رقم موجب).');
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
      final icon = _iconController.text.trim();

      if (_isEditing) {
        await api.updateReward(
          rewardId: widget.existing!.id,
          name: name,
          description: description.isEmpty ? null : description,
          pointsCost: pointsCost,
          icon: icon.isEmpty ? null : icon,
          status: _status,
          familyId: familyId,
        );
      } else {
        await api.createReward(
          name: name,
          description: description.isEmpty ? null : description,
          pointsCost: pointsCost,
          icon: icon.isEmpty ? null : icon,
          familyId: familyId,
        );
      }

      ref.invalidate(familyRewardsProvider);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditing ? 'تم تحديث المكافأة بنجاح' : 'تمت إضافة المكافأة بنجاح')),
      );
    } on ApiException catch (error) {
      setState(() => _errorMessage = error.message);
    } catch (error) {
      setState(() => _errorMessage = 'تعذر حفظ المكافأة: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'تعديل المكافأة' : 'إضافة مكافأة')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'اسم المكافأة', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'الوصف (اختياري)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pointsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'تكلفة النقاط', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _iconController,
              maxLength: 30,
              decoration: const InputDecoration(
                labelText: 'رمز/أيقونة (اختياري، مثل 🎁)',
                border: OutlineInputBorder(),
              ),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'الحالة', border: OutlineInputBorder()),
                items: [
                  for (final entry in familyRewardStatusLabels.entries)
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
                    : Text(_isEditing ? 'حفظ التعديلات' : 'إضافة المكافأة'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
