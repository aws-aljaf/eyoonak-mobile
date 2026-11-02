import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../../core/widgets/family_motion.dart';
import '../../family/application/family_providers.dart';
import '../../family_tasks/application/family_tasks_providers.dart';
import '../application/exercises_providers.dart';
import 'exercises_screen.dart';

class ExerciseDetailScreen extends ConsumerStatefulWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseId, required this.memberId});
  final int exerciseId, memberId;
  @override
  ConsumerState<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends ConsumerState<ExerciseDetailScreen> {
  bool _saving = false;
  @override
  Widget build(BuildContext context) {
    final manager = ref.watch(canManageFamilyTasksProvider);
    final assigned = ref
            .watch(exerciseAssignmentsProvider(widget.memberId))
            .valueOrNull
            ?.any((a) => a['exercise']?['id'] == widget.exerciseId) ??
        false;
    return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل التمرين')),
        body: ref.watch(exerciseDetailProvider(widget.exerciseId)).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(exerciseError(e)),
                TextButton(
                    onPressed: () => ref.invalidate(exerciseDetailProvider(widget.exerciseId)),
                    child: const Text('إعادة المحاولة'))
              ])),
              data: (e) => ListView(padding: const EdgeInsets.all(20), children: [
                FamilyHero(
                    playful: ref.watch(currentFamilyRelationshipProvider)?.role == 'child',
                    title: 'وقت النشاط!',
                    subtitle: 'اتبع الخطوات وخذ راحتك بين المجموعات'),
                if (e['image_url'] != null)
                  Image.network(e['image_url'] as String,
                      height: 220, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Text('تعذر تحميل الصورة')),
                const SizedBox(height: 16),
                Text(e['name'] as String, style: Theme.of(context).textTheme.headlineSmall),
                Text('${e['category']?['name'] ?? ''} · ${exerciseDifficultyLabels[e['difficulty']] ?? ''}'),
                if (e['description'] != null)
                  Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(e['description'] as String)),
                Wrap(spacing: 8, children: [
                  if (e['duration_seconds'] != null) Chip(label: Text('${e['duration_seconds']} ثانية')),
                  if (e['reps'] != null) Chip(label: Text('${e['reps']} تكرار')),
                  if (e['sets'] != null) Chip(label: Text('${e['sets']} مجموعة')),
                  if (e['rest_seconds'] != null) Chip(label: Text('راحة ${e['rest_seconds']} ثانية')),
                ]),
                if (e['adult_supervision_recommended'] == true)
                  const ListTile(leading: Icon(Icons.supervisor_account), title: Text('يوصى بإشراف شخص بالغ')),
                for (final key in ['safety_notes', 'warnings'])
                  if (e[key] != null && (e[key] as String).isNotEmpty)
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text('${key == 'warnings' ? 'تحذيرات' : 'إرشادات السلامة'}: ${e[key]}'))),
                if (e['video_url'] != null) ExerciseVideo(key: ValueKey(e['video_url']), url: e['video_url'] as String),
                const SizedBox(height: 16),
                Text('خطوات التمرين', style: Theme.of(context).textTheme.titleLarge),
                for (final entry in ((e['steps'] as List?) ?? []).indexed)
                  ListTile(leading: CircleAvatar(child: Text('${entry.$1 + 1}')), title: Text(entry.$2 as String)),
                const SizedBox(height: 16),
                if (manager)
                  FilledButton.icon(
                      onPressed: _saving || assigned ? null : _assign,
                      icon: const Icon(Icons.add_task),
                      label: Text(assigned ? 'مفعّل لهذا الفرد' : 'تفعيل لهذا الفرد')),
                if (_saving) const LinearProgressIndicator(),
              ]),
            ));
  }

  Future<void> _assign() async {
    final payload = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => const _AssignDialog());
    if (payload == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(exercisesApiProvider)
          .assign(widget.memberId, widget.exerciseId, ref.read(selectedFamilyIdProvider), payload);
      ref.invalidate(memberExercisesProvider(widget.memberId));
      ref.invalidate(exerciseAssignmentsProvider(widget.memberId));
      ref.invalidate(familyTasksProvider);
      ref.invalidate(familyTaskOccurrencesProvider);
      ref.invalidate(todayFamilyTaskOccurrencesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تفعيل التمرين')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exerciseError(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class ExerciseVideo extends StatefulWidget {
  const ExerciseVideo({super.key, required this.url});
  final String url;
  @override
  State<ExerciseVideo> createState() => _ExerciseVideoState();
}

class _ExerciseVideoState extends State<ExerciseVideo> {
  late final VideoPlayerController controller;
  bool failed = false;
  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await controller.initialize();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return const Padding(padding: EdgeInsets.all(16), child: Text('تعذر تشغيل الفيديو. أعد فتح التمرين للمحاولة.'));
    }
    if (!controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(children: [
      AspectRatio(aspectRatio: controller.value.aspectRatio, child: VideoPlayer(controller)),
      VideoProgressIndicator(controller, allowScrubbing: true),
      ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: controller,
          builder: (context, value, _) => IconButton(
              tooltip: value.isPlaying ? 'إيقاف مؤقت' : 'تشغيل',
              icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: () => value.isPlaying ? controller.pause() : controller.play())),
    ]);
  }
}

String _date(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class _AssignDialog extends StatefulWidget {
  const _AssignDialog();
  @override
  State<_AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends State<_AssignDialog> {
  final formKey = GlobalKey<FormState>();
  final points = TextEditingController(text: '5'), notes = TextEditingController();
  String recurrence = 'daily';
  DateTime start = DateTime.now();
  DateTime? end;
  TimeOfDay? time;
  bool approval = true;
  final days = <int>{};
  String? error;
  @override
  void dispose() {
    points.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> pickDate(bool isEnd) async {
    final selected = await showDatePicker(
        context: context,
        initialDate: isEnd ? end ?? start : start,
        firstDate: isEnd ? DateTime(start.year, start.month, start.day) : DateTime(1900, 1, 2),
        lastDate: DateTime(2100));
    if (selected != null) {
      setState(() {
        if (isEnd) {
          end = selected;
        } else {
          start = selected;
          if (end != null && end!.isBefore(start)) end = null;
        }
      });
    }
  }

  void submit() {
    if (!formKey.currentState!.validate()) return;
    if (recurrence == 'specific_days' && days.isEmpty) {
      setState(() => error = 'حدد يوماً واحداً على الأقل.');
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      'recurrence_type': recurrence,
      if (recurrence == 'specific_days') 'recurrence_days': days.toList()..sort(),
      'start_date': _date(start),
      if (end != null) 'end_date': _date(end!),
      'points': int.parse(points.text),
      'requires_approval': approval,
      if (time != null)
        'time_start': '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}',
      if (notes.text.trim().isNotEmpty) 'notes': notes.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('جدولة التمرين'),
          content: SizedBox(
              width: 420,
              child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    DropdownButtonFormField<String>(
                        initialValue: recurrence,
                        decoration: const InputDecoration(labelText: 'التكرار'),
                        items: const [
                          DropdownMenuItem(value: 'once', child: Text('مرة واحدة')),
                          DropdownMenuItem(value: 'daily', child: Text('يومياً')),
                          DropdownMenuItem(value: 'weekly', child: Text('أسبوعياً في يوم البداية')),
                          DropdownMenuItem(value: 'specific_days', child: Text('أيام محددة'))
                        ],
                        onChanged: (v) => setState(() => recurrence = v!)),
                    if (recurrence == 'specific_days')
                      Wrap(spacing: 4, children: [
                        for (final d in const {
                          1: 'اثنين',
                          2: 'ثلاثاء',
                          3: 'أربعاء',
                          4: 'خميس',
                          5: 'جمعة',
                          6: 'سبت',
                          7: 'أحد'
                        }.entries)
                          FilterChip(
                              label: Text(d.value),
                              selected: days.contains(d.key),
                              onSelected: (v) => setState(() {
                                    if (v) {
                                      days.add(d.key);
                                    } else {
                                      days.remove(d.key);
                                    }
                                  }))
                      ]),
                    TextButton(onPressed: () => pickDate(false), child: Text('البداية: ${_date(start)}')),
                    Row(children: [
                      Expanded(
                          child: TextButton(
                              onPressed: () => pickDate(true),
                              child: Text(end == null ? 'تحديد نهاية (اختياري)' : 'النهاية: ${_date(end!)}'))),
                      if (end != null)
                        IconButton(onPressed: () => setState(() => end = null), icon: const Icon(Icons.clear))
                    ]),
                    TextButton(
                        onPressed: () async {
                          final t = await showTimePicker(context: context, initialTime: time ?? TimeOfDay.now());
                          if (t != null) setState(() => time = t);
                        },
                        child: Text(time == null ? 'تحديد الوقت (اختياري)' : time!.format(context))),
                    TextFormField(
                        controller: points,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'النقاط (1–1000)'),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          return n == null || n < 1 || n > 1000 ? 'أدخل رقماً من 1 إلى 1000' : null;
                        }),
                    SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('يتطلب اعتماد ولي الأمر'),
                        value: approval,
                        onChanged: (v) => setState(() => approval = v)),
                    TextFormField(
                        controller: notes, maxLength: 2000, decoration: const InputDecoration(labelText: 'ملاحظات')),
                    if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ])))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(onPressed: submit, child: const Text('تفعيل'))
          ]);
}
