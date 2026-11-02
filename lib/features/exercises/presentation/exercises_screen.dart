import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/widgets/family_motion.dart';
import '../../../core/network/api_exception.dart';
import '../../family/application/family_providers.dart';
import '../../family/data/family_models.dart';
import '../../family_tasks/application/family_tasks_providers.dart';
import '../application/exercises_providers.dart';

const exerciseDifficultyLabels = {
  'easy': 'سهل',
  'medium': 'متوسط',
  'hard': 'صعب'
};
String exerciseError(Object e) =>
    e is ApiException ? e.message : 'تعذر تحميل البيانات. حاول مرة أخرى.';

class ExercisesScreen extends ConsumerStatefulWidget {
  const ExercisesScreen({super.key});
  @override
  ConsumerState<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends ConsumerState<ExercisesScreen> {
  int? _memberId, _categoryId;
  String? _difficulty;
  String _search = '';
  bool _progress = false, _busy = false;

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(familyMembersProvider);
    final canManage = ref.watch(canManageFamilyTasksProvider);
    final userId = ref.watch(authControllerProvider).user?.id;
    ref.listen(selectedFamilyIdProvider, (_, next) {
      setState(() {
        _memberId = null;
        _categoryId = null;
      });
    });
    return Scaffold(
      appBar: AppBar(title: const Text('رياضة اليوم'), actions: [
        IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث')
      ]),
      body: members.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _error(e, () => ref.invalidate(familyMembersProvider)),
        data: (all) {
          final visible =
              all.where((m) => canManage || m.linkedUserId == userId).toList();
          if (visible.isEmpty) {
            return Center(
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.family_restroom_rounded, size: 56),
                      const SizedBox(height: 16),
                      const Text('نجهّز التمارين المناسبة لعائلتك',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text(
                          canManage
                              ? 'أضف فرداً وتاريخ ميلاده من إدارة العائلة حتى تظهر التمارين المناسبة لعمره.'
                              : 'اطلب من أحد الوالدين ربط حسابك بملفك وتسجيل تاريخ ميلادك حتى تظهر تمارينك.',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      if (canManage)
                        FilledButton.icon(
                            onPressed: () => context.push('/family'),
                            icon: const Icon(Icons.person_add_alt),
                            label: const Text('إعداد أفراد العائلة')),
                      TextButton(
                          onPressed: _refresh,
                          child: const Text('إعادة تحميل الملفات'))
                    ])));
          }
          final selected =
              visible.where((m) => m.id == _memberId).firstOrNull ??
                  visible.first;
          final memberId = selected.id;
          return Column(children: [
            const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                    'تمارين إلك ولجهالك حسب العمر. اختار فرد العائلة وافتح التمرين حتى تشوف نبذة وخطواته وتتابع الإنجاز.')),
            Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  DropdownButtonFormField<int>(
                    key: ValueKey(
                        '${ref.watch(selectedFamilyIdProvider)}-$memberId'),
                    initialValue: memberId,
                    decoration: const InputDecoration(labelText: 'فرد العائلة'),
                    items: visible
                        .map((m) => DropdownMenuItem(
                            value: m.id, child: Text(m.fullName)))
                        .toList(),
                    onChanged: (id) => setState(() {
                      _memberId = id;
                      _categoryId = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                            value: false, label: Text('التمارين المتاحة')),
                        ButtonSegment(value: true, label: Text('اليوم والتقدم'))
                      ],
                      selected: {
                        _progress
                      },
                      onSelectionChanged: (v) =>
                          setState(() => _progress = v.first)),
                ])),
            Expanded(
                child: _progress
                    ? _assignments(selected, canManage, userId)
                    : _catalog(selected, canManage)),
          ]);
        },
      ),
    );
  }

  Widget _catalog(FamilyMemberModel member, bool canManage) {
    return ref.watch(memberExercisesProvider(member.id)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _error(
              e, () => ref.invalidate(memberExercisesProvider(member.id))),
          data: (data) {
            final reason = data['unavailable_reason'];
            if (reason != null) {
              return Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                          reason == 'birth_date_missing'
                              ? 'أكمل تاريخ ميلاد ${member.fullName} من تعديل بيانات الفرد لعرض التمارين المناسبة.'
                              : 'لا توجد فئة تمارين متاحة لهذا العمر حالياً.',
                          textAlign: TextAlign.center)));
            }
            final all =
                (data['exercises'] as List).cast<Map<String, dynamic>>();
            final categories = <int, String>{};
            for (final e in all) {
              if (e['category'] is Map) {
                categories[e['category']['id'] as int] =
                    e['category']['name'] as String;
              }
            }
            final filtered = all
                .where((e) =>
                    (_categoryId == null || e['category_id'] == _categoryId) &&
                    (_difficulty == null || e['difficulty'] == _difficulty) &&
                    (e['name'] as String).contains(_search))
                .toList();
            return RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(memberExercisesProvider(member.id)),
                child: ListView(
                    padding: const EdgeInsets.all(12),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      FamilyHero(
                          playful: ref
                                  .watch(currentFamilyRelationshipProvider)
                                  ?.role ==
                              'child',
                          title: 'يلا نتحرك!',
                          subtitle: 'نشاط ممتع لكل فرد في العائلة'),
                      Text(data['age_group']?['name'] ?? '',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      TextField(
                          decoration: const InputDecoration(
                              labelText: 'بحث بالاسم',
                              prefixIcon: Icon(Icons.search)),
                          onChanged: (s) => setState(() => _search = s)),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, children: [
                        DropdownButton<int>(
                            value: categories.containsKey(_categoryId)
                                ? _categoryId
                                : null,
                            hint: const Text('كل التصنيفات'),
                            items: [
                              const DropdownMenuItem<int>(
                                  value: null, child: Text('كل التصنيفات')),
                              ...categories.entries.map((c) => DropdownMenuItem(
                                  value: c.key, child: Text(c.value)))
                            ],
                            onChanged: (id) =>
                                setState(() => _categoryId = id)),
                        DropdownButton<String>(
                            value: _difficulty,
                            hint: const Text('كل المستويات'),
                            items: [
                              const DropdownMenuItem<String>(
                                  value: null, child: Text('كل المستويات')),
                              ...exerciseDifficultyLabels.entries.map((e) =>
                                  DropdownMenuItem(
                                      value: e.key, child: Text(e.value)))
                            ],
                            onChanged: (v) => setState(() => _difficulty = v)),
                      ]),
                      if (filtered.isEmpty)
                        const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('لا توجد تمارين مطابقة.')),
                      for (final e in filtered)
                        FamilyReveal(
                            key: ValueKey(e['id']),
                            child: Card(
                                child: ListTile(
                              leading: e['image_url'] == null
                                  ? const Icon(Icons.fitness_center)
                                  : Image.network(e['image_url'] as String,
                                      width: 52,
                                      height: 52,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.fitness_center)),
                              title: Text(e['name'] as String),
                              subtitle: Text(
                                  '${exerciseDifficultyLabels[e['difficulty']] ?? ''}${e['assigned'] == true ? ' · مفعّل' : ''}'),
                              trailing: const Icon(Icons.chevron_left),
                              onTap: () => context.push(
                                  '/exercises/${e['id']}?memberId=${member.id}'),
                            ))),
                    ]));
          },
        );
  }

  Widget _assignments(FamilyMemberModel member, bool manager, int? userId) {
    return ref.watch(exerciseAssignmentsProvider(member.id)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _error(
              e, () => ref.invalidate(exerciseAssignmentsProvider(member.id))),
          data: (items) => RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(exerciseAssignmentsProvider(member.id)),
              child: ListView(
                  padding: const EdgeInsets.all(12),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    FamilyHero(
                        playful: ref
                                .watch(currentFamilyRelationshipProvider)
                                ?.role ==
                            'child',
                        title: 'نجوم النشاط',
                        subtitle: 'كل تمرين صغير يضيف خطوة جميلة ليومك'),
                    if (items.isEmpty)
                      const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('لا توجد تمارين مفعّلة بعد.')),
                    for (final item in items)
                      Card(
                          child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        item['exercise']?['name'] ??
                                            'تمرين سابق',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium),
                                    Text(
                                        'آخر 7 أيام: ${item['progress']['completed_last_7_days']} · مجموع الإنجاز: ${item['progress']['completed_total']} · فائت: ${item['progress']['missed_total']}'),
                                    Text('النقاط: ${item['points']}'),
                                    if (item['today_occurrence'] == null)
                                      const Text('لا يوجد تمرين مستحق اليوم')
                                    else
                                      Text(_statusLabel(item['today_occurrence']
                                          ['status'] as String)),
                                    Wrap(spacing: 8, children: [
                                      if (item['today_occurrence']?['status'] ==
                                              'pending' &&
                                          (manager ||
                                              member.linkedUserId == userId))
                                        FilledButton(
                                            onPressed: _busy
                                                ? null
                                                : () => _action(
                                                    member.id,
                                                    () => ref
                                                        .read(
                                                            familyTasksApiProvider)
                                                        .completeOccurrence(
                                                            occurrenceId: item[
                                                                    'today_occurrence']
                                                                ['id'] as int,
                                                            familyId: ref.read(
                                                                selectedFamilyIdProvider)),
                                                    celebrate: true),
                                            child: const Text('تم التمرين')),
                                      if (manager &&
                                          item['today_occurrence']?['status'] ==
                                              'pending_approval') ...[
                                        FilledButton(
                                            onPressed: _busy
                                                ? null
                                                : () => _action(
                                                    member.id,
                                                    () =>
                                                        ref
                                                            .read(
                                                                familyTasksApiProvider)
                                                            .approveOccurrence(
                                                                occurrenceId:
                                                                    item['today_occurrence']
                                                                            [
                                                                            'id']
                                                                        as int,
                                                                familyId: ref.read(
                                                                    selectedFamilyIdProvider))),
                                            child: const Text('اعتماد')),
                                        TextButton(
                                            onPressed: _busy
                                                ? null
                                                : () => _action(
                                                    member.id,
                                                    () => ref
                                                        .read(
                                                            familyTasksApiProvider)
                                                        .rejectOccurrence(
                                                            occurrenceId: item[
                                                                    'today_occurrence']
                                                                ['id'] as int,
                                                            familyId: ref.read(
                                                                selectedFamilyIdProvider))),
                                            child: const Text('رفض')),
                                      ],
                                      if (manager)
                                        TextButton(
                                            onPressed: _busy
                                                ? null
                                                : () async {
                                                    final confirm = await showDialog<
                                                            bool>(
                                                        context: context,
                                                        builder: (c) =>
                                                            AlertDialog(
                                                                title: const Text(
                                                                    'إيقاف التمرين؟'),
                                                                content: const Text(
                                                                    'سيبقى سجل الإنجازات محفوظاً.'),
                                                                actions: [
                                                                  TextButton(
                                                                      onPressed: () =>
                                                                          Navigator.pop(
                                                                              c,
                                                                              false),
                                                                      child: const Text(
                                                                          'إلغاء')),
                                                                  TextButton(
                                                                      onPressed: () =>
                                                                          Navigator.pop(
                                                                              c,
                                                                              true),
                                                                      child: const Text(
                                                                          'إيقاف'))
                                                                ]));
                                                    if (confirm == true) {
                                                      await _action(
                                                          member.id,
                                                          () => ref
                                                              .read(
                                                                  exercisesApiProvider)
                                                              .archive(
                                                                  item['task_id']
                                                                      as int,
                                                                  ref.read(
                                                                      selectedFamilyIdProvider)));
                                                    }
                                                  },
                                            child: const Text('إيقاف التفعيل')),
                                    ]),
                                  ]))),
                  ])),
        );
  }

  String _statusLabel(String status) =>
      {
        'pending': 'بانتظار الإنجاز',
        'pending_approval': 'بانتظار اعتماد ولي الأمر',
        'approved': 'مكتمل ومعتمد',
        'rejected': 'مرفوض',
        'missed': 'فات موعده'
      }[status] ??
      status;
  Widget _error(Object e, VoidCallback retry) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(exerciseError(e), textAlign: TextAlign.center),
        TextButton(onPressed: retry, child: const Text('إعادة المحاولة'))
      ]));
  void _refresh() {
    ref.invalidate(familyMembersProvider);
    ref.invalidate(memberExercisesProvider);
    ref.invalidate(exerciseAssignmentsProvider);
  }

  Future<void> _action(int memberId, Future<dynamic> Function() action,
      {bool celebrate = false}) async {
    setState(() => _busy = true);
    try {
      await action();
      if (celebrate && mounted) {
        await showDialog<void>(
            context: context, builder: (_) => const FamilyCelebration());
      }
      ref.invalidate(exerciseAssignmentsProvider(memberId));
      ref.invalidate(memberExercisesProvider(memberId));
      ref.invalidate(familyTaskOccurrencesProvider);
      ref.invalidate(todayFamilyTaskOccurrencesProvider);
      ref.invalidate(familyTasksProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(exerciseError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
