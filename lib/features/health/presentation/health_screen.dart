import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../family_life/presentation/family_life_screen.dart' show lifeError;
import '../application/health_reminders.dart';

const healthDays = {1: 'الاثنين', 2: 'الثلاثاء', 3: 'الأربعاء', 4: 'الخميس', 5: 'الجمعة', 6: 'السبت', 7: 'الأحد'};
String healthDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class HealthScreen extends ConsumerStatefulWidget {
  const HealthScreen({super.key, this.cycleOnly = false});
  final bool cycleOnly;
  @override
  ConsumerState<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends ConsumerState<HealthScreen> with WidgetsBindingObserver {
  Map<String, dynamic>? data, cycle;
  bool busy = false;
  String? error, notice;
  int generation = 0;
  Timer? refreshTimer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && !busy && (ModalRoute.of(context)?.isCurrent ?? false)) load();
    });
    load();
  }

  @override
  void dispose() {
    generation++;
    refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) load();
  }

  Future<void> load() async {
    final current = ++generation;
    try {
      final api = ref.read(apiClientProvider);
      final d = Map<String, dynamic>.from(await api.get('/personal/health/reminders') as Map);
      final c =
          d['can_use_cycle'] == true ? Map<String, dynamic>.from(await api.get('/personal/health/cycle') as Map) : null;
      if (!mounted || current != generation) return;
      setState(() {
        data = d;
        cycle = c;
        error = null;
      });
      try {
        await HealthReminders.instance.schedule(d, c);
      } catch (_) {
        if (mounted) {
          setState(() => notice = 'حُفظت المواعيد، وتعذرت جدولة التنبيهات. راجع إذن الإشعارات وأعد المحاولة.');
        }
      }
    } catch (e) {
      if (mounted && current == generation) {
        setState(() {
          data = null;
          cycle = null;
          error = lifeError(e);
        });
      }
    }
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      await load();
    } catch (e) {
      if (mounted) setState(() => error = lifeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<bool> confirm(String text) async =>
      await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(title: Text(text), actions: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
                FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('تأكيد'))
              ])) ??
      false;
  Future<void> edit([Map<String, dynamic>? row, String? initialKind]) async {
    final value = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => HealthEditor(initial: widget.cycleOnly ? cycle : (row ?? {'kind': initialKind ?? 'medicine'}), cycle: widget.cycleOnly));
    if (value == null) return;
    await run(() async {
      final api = ref.read(apiClientProvider);
      if (widget.cycleOnly) {
        await api.put('/personal/health/cycle', data: value);
      } else if (row == null) {
        await api.post('/personal/health/reminders', data: value);
      } else {
        await api.put('/personal/health/reminders/${row['id']}', data: value);
      }
    });
  }

  Future<void> permission() async {
    try {
      final ok = await HealthReminders.instance.requestPermission();
      if (mounted) {
        setState(() => notice = ok ? 'تم السماح بالتنبيهات.' : 'التنبيهات غير مسموحة؛ فعّلها من إعدادات الهاتف.');
      }
      await load();
    } catch (_) {
      if (mounted) setState(() => notice = 'تعذر تفعيل التنبيه على هذا الجهاز.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = data?['reminders'] as List? ?? [], today = data?['today'] as List? ?? [];
    return Scaffold(
        appBar: AppBar(title: Text(widget.cycleOnly ? 'مساحتي الخاصة' : 'مذكّري اليومي')),
        body: RefreshIndicator(
            onRefresh: load,
            child: ListView(padding: const EdgeInsets.all(20), children: [
              Text(widget.cycleOnly ? 'مواعيد دورتي' : 'كل موعد بمكانه',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 10),
              Text(widget.cycleOnly
                  ? 'مساحة خاصة بالأم وحدها، لا تظهر بياناتها لبقية العائلة.'
                  : 'مواعيد خاصة بحسابك. سجّل تعليمات الدواء كما وصفها المختص.'),
              if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              if (notice != null) Text(notice!),
              OutlinedButton.icon(
                  onPressed: busy ? null : permission,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('السماح بتنبيهات الهاتف')),
              const Text(
                  'التنبيه يعرض عبارة عامة لحماية الخصوصية وقد يتأخر حسب إعدادات الجهاز. يتجدد جدول الهاتف عند فتح التطبيق: حتى ٧ أيام للتذكيرات، والأقرب أولاً (٤٨ تنبيهاً على أندرويد و٢٤ على iOS).'),
              const SizedBox(height: 18),
              if (data == null && error == null) const Center(child: CircularProgressIndicator()),
              if (widget.cycleOnly && data != null && data!['can_use_cycle'] != true)
                const Text('هذا القسم لحساب الأم فقط.'),
              if (widget.cycleOnly && data?['can_use_cycle'] == true) ...[
                FilledButton.icon(
                    onPressed: busy ? null : () => edit(),
                    icon: const Icon(Icons.calendar_month),
                    label: const Text('تسجيل بداية أو تعديل المواعيد')),
                if (cycle?['configured'] == true)
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('آخر بداية: ${cycle!['last_start']}'),
                            Text(
                                'الفاصل المسجل: ${cycle!['cycle_length']} يوماً · المدة: ${cycle!['period_length']} أيام'),
                            const Divider(),
                            Text('البداية التالية التقريبية: ${cycle!['next_start']}',
                                style: Theme.of(context).textTheme.titleMedium),
                            const Text('حساب تقريبي حسب تسجيلك، وقد يختلف الموعد الفعلي.'),
                            Text(cycle!['reminders'] == true
                                ? 'التذكير قبل الموعد بـ ${cycle!['remind_days_before']} أيام الساعة ${cycle!['reminder_time']}'
                                : 'التذكير متوقف'),
                            const SizedBox(height: 10),
                            const Text('البدايات المسجلة'),
                            for (final day in cycle!['history'] as List? ?? []) Text('$day'),
                            TextButton(
                                onPressed: busy
                                    ? null
                                    : () async {
                                        if (await confirm('حذف كل بيانات الدورة من حسابك؟')) {
                                          await run(() async {
                                            await ref.read(apiClientProvider).delete('/personal/health/cycle');
                                          });
                                        }
                                      },
                                child: const Text('حذف بياناتي'))
                          ]))),
                if (cycle?['configured'] != true) const Text('ابدئي بتسجيل تاريخ البداية والفاصل المعتاد عندك.')
              ],
              if (!widget.cycleOnly && data != null) ...[
                Card(color: Theme.of(context).colorScheme.primaryContainer, child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('العناية بنفسي', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const Text('وقت صغير لي… تذكيرات خاصة أختارها حسب يومي.'), FilledButton.icon(onPressed: busy ? null : () => edit(null, 'self_care'), icon: const Icon(Icons.spa_outlined), label: const Text('موعد للعناية بنفسي')), for(final row in rows.where((r) => r['kind'] == 'self_care')) Text(row['title'] as String? ?? '')]))),
                if (data?['can_use_cycle'] == true)
                  OutlinedButton(
                      onPressed: () => context.push('/our-home/mother-cycle'), child: const Text('مساحتي الخاصة')),
                FilledButton.icon(
                    onPressed: busy ? null : () => edit(),
                    icon: const Icon(Icons.add_alarm),
                    label: const Text('إضافة تذكير')),
                const SizedBox(height: 18),
                Text('مواعيد اليوم', style: Theme.of(context).textTheme.titleLarge),
                if (today.isEmpty) const Text('لا توجد مواعيد مجدولة لليوم.'),
                for (final raw in today)
                  Builder(builder: (context) {
                    final slot = raw as Map, row = rows.cast<Map>().firstWhere((v) => v['id'] == slot['reminder_id']);
                    final due = !DateTime.parse(slot['scheduled_at'] as String).isAfter(DateTime.now());
                    return Card(
                        child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${slot['time']} · ${row['title']}', style: Theme.of(context).textTheme.titleMedium),
                              if ((row['instructions'] as String? ?? '').isNotEmpty)
                                Text(row['instructions'] as String),
                              Text(slot['status'] == 'done'
                                  ? (row['kind'] == 'medicine' ? 'تم أخذ الجرعة' : 'تم الإنجاز')
                                  : slot['status'] == 'skipped'
                                      ? 'تم التخطي'
                                      : 'بانتظار الموعد أو التسجيل'),
                              if (due)
                                Wrap(spacing: 8, children: [
                                  for (final status in ['done', 'skipped'])
                                    TextButton(
                                        onPressed: busy
                                            ? null
                                            : () => run(() async {
                                                  await ref.read(apiClientProvider).put(
                                                      '/personal/health/reminders/${row['id']}/record',
                                                      data: {'scheduled_at': slot['scheduled_at'], 'status': status});
                                                }),
                                        child: Text(status == 'skipped'
                                            ? 'تخطي'
                                            : row['kind'] == 'medicine'
                                                ? 'أخذت الجرعة'
                                                : 'تم الإنجاز'))
                                ])
                            ])));
                  }),
                const SizedBox(height: 18),
                Text('جدولي', style: Theme.of(context).textTheme.titleLarge),
                for (final raw in rows)
                  Builder(builder: (context) {
                    final row = Map<String, dynamic>.from(raw as Map);
                    return Card(
                        child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(row['title'] as String, style: Theme.of(context).textTheme.titleMedium),
                              Text('${(row['times'] as List).join('، ')} · ${row['timezone']}'),
                              Text((row['weekdays'] as List).map((d) => healthDays[d]).join('، ')),
                              Text('من ${row['starts_on']}${row['ends_on'] == null ? '' : ' إلى ${row['ends_on']}'}'),
                              Wrap(spacing: 8, children: [
                                TextButton(onPressed: busy ? null : () => edit(row), child: const Text('تعديل')),
                                TextButton(
                                    onPressed: busy
                                        ? null
                                        : () => run(() async {
                                              await ref.read(apiClientProvider).put(
                                                  '/personal/health/reminders/${row['id']}',
                                                  data: {...row, 'enabled': row['enabled'] != true});
                                            }),
                                    child: Text(row['enabled'] == true ? 'إيقاف' : 'استئناف')),
                                TextButton(
                                    onPressed: busy
                                        ? null
                                        : () async {
                                            if (await confirm('حذف التذكير وسجله؟')) {
                                              await run(() async {
                                                await ref
                                                    .read(apiClientProvider)
                                                    .delete('/personal/health/reminders/${row['id']}');
                                              });
                                            }
                                          },
                                    child: const Text('حذف'))
                              ])
                            ])));
                  })
              ]
            ])));
  }
}

class HealthEditor extends StatefulWidget {
  const HealthEditor({super.key, this.initial, this.cycle = false});
  final Map<String, dynamic>? initial;
  final bool cycle;
  @override
  State<HealthEditor> createState() => _HealthEditorState();
}

class _HealthEditorState extends State<HealthEditor> {
  final form = GlobalKey<FormState>();
  late final title = TextEditingController(text: widget.initial?['title'] as String? ?? '');
  late final notes = TextEditingController(text: widget.initial?['instructions'] as String? ?? '');
  late final zone = TextEditingController(text: widget.initial?['timezone'] as String? ?? 'Asia/Baghdad');
  late final length = TextEditingController(text: widget.initial?['cycle_length']?.toString() ?? '');
  late final period = TextEditingController(text: widget.initial?['period_length']?.toString() ?? '');
  late final before = TextEditingController(text: widget.initial?['remind_days_before']?.toString() ?? '1');
  late String start =
      widget.initial?[widget.cycle ? 'last_start' : 'starts_on'] as String? ?? healthDate(DateTime.now());
  late String? end = widget.initial?['ends_on'] as String?;
  late String kind = widget.initial?['kind'] as String? ?? 'medicine';
  late bool reminders = widget.initial?['reminders'] == true;
  late final times = List<String>.from(
      widget.cycle ? [widget.initial?['reminder_time'] ?? '09:00'] : widget.initial?['times'] as List? ?? ['08:00']);
  late final days = Set<int>.from(widget.initial?['weekdays'] as List? ?? [1, 2, 3, 4, 5, 6, 7]);
  String? error;
  @override
  void dispose() {
    for (final c in [title, notes, zone, length, period, before]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget number(TextEditingController c, String label, int min, int max) => TextFormField(
      controller: c,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        final n = int.tryParse(v ?? '');
        return n == null || n < min || n > max ? 'أدخل رقماً بين $min و$max' : null;
      });
  Future<void> date(bool ending) async {
    final v = await showDatePicker(
        context: context,
        initialDate: DateTime.parse(ending ? (end ?? start) : start),
        firstDate: DateTime(2000),
        lastDate: widget.cycle ? DateTime.now() : DateTime(2100));
    if (v != null && mounted) {
      setState(() {
        if (ending) {
          end = healthDate(v);
        } else {
          start = healthDate(v);
        }
      });
    }
  }

  Future<void> clock(int i) async {
    final p = times[i].split(':').map(int.parse).toList();
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: p[0], minute: p[1]));
    if (t != null && mounted) {
      setState(() => times[i] = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
    }
  }

  void save() {
    if (!form.currentState!.validate()) return;
    if (widget.cycle) {
      if (int.parse(period.text) > int.parse(length.text)) {
        setState(() => error = 'المدة لا تتجاوز الفاصل بين البدايات.');
        return;
      }
      Navigator.pop(context, {
        'last_start': start,
        'cycle_length': int.parse(length.text),
        'period_length': int.parse(period.text),
        'timezone': zone.text.trim(),
        'reminders': reminders,
        'reminder_time': times.first,
        'remind_days_before': int.parse(before.text)
      });
    } else {
      if (days.isEmpty || times.toSet().length != times.length || (end != null && end!.compareTo(start) < 0)) {
        setState(() => error = 'اختر أياماً ومواعيد مختلفة ونهاية بعد البداية.');
        return;
      }
      Navigator.pop(context, {
        'title': title.text.trim(),
        'instructions': notes.text.trim(),
        'timezone': zone.text.trim(),
        'kind': kind,
        'starts_on': start,
        'ends_on': end,
        'times': times,
        'weekdays': days.toList()..sort(),
        'enabled': widget.initial?['enabled'] ?? true
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: Text(widget.cycle ? 'مواعيدي الخاصة' : 'تذكيري اليومي'),
          content: SizedBox(
              width: 450,
              child: Form(
                  key: form,
                  child: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (!widget.cycle) ...[
                      TextFormField(
                          controller: title,
                          maxLength: 120,
                          decoration: const InputDecoration(labelText: 'اسم الدواء أو التذكير'),
                          validator: (v) => (v ?? '').trim().isEmpty ? 'أدخل الاسم' : null),
                      DropdownButtonFormField<String>(
                          initialValue: kind,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'النوع'),
                          items: const [
                            DropdownMenuItem(value: 'medicine', child: Text('دواء')),
                            DropdownMenuItem(value: 'daily', child: Text('تذكير يومي')),
                            DropdownMenuItem(value: 'self_care', child: Text('العناية بنفسي'))
                          ],
                          onChanged: (v) => kind = v!),
                      TextFormField(
                          controller: notes,
                          maxLength: 500,
                          maxLines: 2,
                          decoration: const InputDecoration(labelText: 'تعليماتك المسجلة (اختياري)'))
                    ],
                    TextButton(
                        onPressed: () => date(false), child: Text('${widget.cycle ? 'آخر بداية' : 'البداية'}: $start')),
                    if (widget.cycle) ...[
                      number(length, 'الفاصل المعتاد بين البدايات بالأيام', 15, 90),
                      number(period, 'مدة الدورة المسجلة بالأيام', 1, 20),
                      SwitchListTile(
                          title: const Text('تذكير خاص بالموعد التقريبي'),
                          value: reminders,
                          onChanged: (v) => setState(() => reminders = v)),
                      number(before, 'التذكير قبل الموعد بعدد أيام', 0, 7)
                    ] else ...[
                      Row(children: [
                        Expanded(
                            child:
                                TextButton(onPressed: () => date(true), child: Text('النهاية: ${end ?? 'بلا نهاية'}'))),
                        if (end != null)
                          IconButton(onPressed: () => setState(() => end = null), icon: const Icon(Icons.clear))
                      ]),
                      Wrap(spacing: 4, children: [
                        for (final d in healthDays.entries)
                          FilterChip(
                              label: Text(d.value),
                              selected: days.contains(d.key),
                              onSelected: (v) => setState(() => v ? days.add(d.key) : days.remove(d.key)))
                      ])
                    ],
                    TextFormField(
                        controller: zone,
                        decoration: const InputDecoration(labelText: 'المنطقة الزمنية'),
                        validator: (v) => (v ?? '').trim().isEmpty ? 'أدخل المنطقة الزمنية' : null),
                    for (var i = 0; i < times.length; i++)
                      Row(children: [
                        Expanded(child: TextButton(onPressed: () => clock(i), child: Text('الوقت: ${times[i]}'))),
                        if (!widget.cycle && times.length > 1)
                          IconButton(
                              onPressed: () => setState(() => times.removeAt(i)),
                              icon: const Icon(Icons.remove_circle_outline))
                      ]),
                    if (!widget.cycle && times.length < 4)
                      TextButton(onPressed: () => setState(() => times.add('12:00')), child: const Text('إضافة وقت')),
                    if (widget.cycle)
                      const Text('الموعد التالي تقديري حسب تسجيلك، ويمكنك تعديل البيانات أو حذفها بأي وقت.'),
                    if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))
                  ])))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(onPressed: save, child: const Text('حفظ'))
          ]);
}
