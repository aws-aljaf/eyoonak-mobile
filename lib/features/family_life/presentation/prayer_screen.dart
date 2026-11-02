import '../../../app/family_live_refresh.dart';
import '../../../core/widgets/family_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../app/providers.dart';
import '../application/prayer_reminders.dart';
import 'family_life_screen.dart';

class PrayerScreen extends ConsumerStatefulWidget {
  const PrayerScreen({super.key});
  @override
  ConsumerState<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends ConsumerState<PrayerScreen> {
  Map<String, dynamic>? data;
  String? error;
  bool busy = false;
  String period = 'week';
  String dhikrPeriod = 'morning';
  List<dynamic> adhkar = [];
  int generation = 0;
  static const labels = {
    'fajr': 'الفجر',
    'dhuhr': 'الظهر',
    'asr': 'العصر',
    'maghrib': 'المغرب',
    'isha': 'العشاء'
  };
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final current = ++generation;
    try {
      final d = await ref
          .read(apiClientProvider)
          .get('/personal/prayer', query: {'period': period});
      final a = await ref
          .read(apiClientProvider)
          .get('/personal/adhkar', query: {'period': dhikrPeriod});
      if (mounted && current == generation) {
        setState(() {
          adhkar = a as List;
          data = Map<String, dynamic>.from(d as Map);
          if (data!['_offline'] == true) {
            final prefs =
                Map<String, dynamic>.from(data!['preferences'] as Map);
            final now = tz.TZDateTime.now(PrayerSchedule.zone(prefs));
            final date =
                '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
            if (data!['date'] != date) {
              data!['date'] = date;
              data!['records'] = [];
            }
          }
          error = null;
        });
        final prefs = Map<String, dynamic>.from(d['preferences'] as Map);
        if (prefs['reminders'] == true) {
          try {
            final n = await ref
                .read(apiClientProvider)
                .get('/notification-preferences');
            if (mounted && current == generation) {
              await PrayerReminders.instance.schedule({
                ...prefs,
                'reminders': (n as Map)['categories']?['prayer'] != false
              },
                  hideDetails: n['hide_lock_screen_content'] != false,
                  requestPermission: false);
            }
          } catch (_) {
            /* Reminder failure must not hide the personal record. */
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => error = lifeError(e));
    }
  }

  Future<void> update(Map<String, dynamic> changes) async {
    setState(() => busy = true);
    try {
      final client = ref.read(apiClientProvider);
      final p = await client.put('/personal/prayer/settings', data: changes);
      await load();
      final n = await client.get('/notification-preferences');
      try {
        await PrayerReminders.instance.schedule({
          ...Map<String, dynamic>.from(p as Map),
          'reminders': p['reminders'] == true &&
              (n as Map)['categories']?['prayer'] != false
        },
            hideDetails: n['hide_lock_screen_content'] != false,
            requestPermission: changes['reminders'] == true);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'حُفظت إعداداتك؛ تعذر تفعيل تنبيهات الجهاز. راجع إذن الإشعارات.')));
        }
      }
    } catch (e) {
      if (mounted) setState(() => error = lifeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> settings() async {
    final p = data!['preferences'] as Map;
    await showDialog(
        context: context,
        builder: (_) => LifeForm(
            title: 'مواقيت صلاتي',
            fields: [
              LifeField('city', 'المدينة',
                  initial: p['city'] as String, required: true),
              LifeField('latitude', 'خط العرض',
                  initial: p['latitude'].toString(), required: true),
              LifeField('longitude', 'خط الطول',
                  initial: p['longitude'].toString(), required: true),
              LifeField('timezone', 'المنطقة الزمنية',
                  initial: p['timezone'] as String, required: true),
              LifeField('method', 'طريقة الحساب',
                  initial: p['method'] as String,
                  choices: const {
                    'muslim_world_league': 'رابطة العالم الإسلامي',
                    'karachi': 'كراتشي',
                    'umm_al_qura': 'أم القرى',
                    'egyptian': 'الهيئة المصرية'
                  }),
              LifeField('madhab', 'حساب العصر',
                  initial: p['madhab'] as String,
                  choices: const {'shafi': 'الجمهور', 'hanafi': 'حنفي'})
            ],
            submit: (d) async {
              final lat = double.tryParse(d['latitude']),
                  lng = double.tryParse(d['longitude']);
              if (lat == null || lng == null) {
                throw StateError('أدخل إحداثيات صحيحة');
              }
              await update({...d, 'latitude': lat, 'longitude': lng});
            }));
  }

  Future<void> city(String city, double lat, double lng) async => update({
        'city': city,
        'latitude': lat,
        'longitude': lng,
        'timezone': 'Asia/Baghdad'
      });
  @override
  Widget build(BuildContext context) {
    ref.listen(familyRefreshRevisionProvider, (_, next) {
      if (!busy && (ModalRoute.of(context)?.isCurrent ?? false)) { load(); }
    });
    final p = data?['preferences'] as Map?;
    Map<String, DateTime> times = {};
    if (p != null && p['enabled'] == true) {
      times = PrayerSchedule.times(Map<String, dynamic>.from(p),
          DateTime.parse(data!['date'] as String));
    }
    final records = data?['records'] as List? ?? [];
    return Scaffold(
        appBar: AppBar(title: const Text('صلاتي اليوم 🕌')),
        body: RefreshIndicator(
            onRefresh: load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                    'مساحتك الخاصة للطمأنينة. سجلك يخصك وحدك، وتگدر توقف القسم بأي وقت.'),
                if (error != null) Text(error!),
                if (data == null)
                  const Center(child: CircularProgressIndicator()),
                if (p != null) ...[
                  SwitchListTile(
                      title: const Text('تفعيل صلاتي'),
                      value: p['enabled'] == true,
                      onChanged: busy ? null : (v) => update({'enabled': v})),
                  if (p['enabled'] == true) ...[
                    Wrap(spacing: 8, children: [
                      ActionChip(
                          label: const Text('بغداد'),
                          onPressed: busy
                              ? null
                              : () => city('بغداد', 33.3152, 44.3661)),
                      ActionChip(
                          label: const Text('البصرة'),
                          onPressed: busy
                              ? null
                              : () => city('البصرة', 30.5085, 47.7804)),
                      ActionChip(
                          label: const Text('أربيل'),
                          onPressed: busy
                              ? null
                              : () => city('أربيل', 36.1911, 44.0092))
                    ]),
                    ListTile(
                        title: Text(p['city'] as String),
                        subtitle: Text(p['timezone'] as String),
                        trailing: TextButton(
                            onPressed: busy ? null : settings,
                            child: const Text('مدينتي وطريقة الحساب'))),
                    const Text(
                        'المواقيت محسوبة حسب الطريقة المختارة؛ راجع تقويم مسجدك لضبط الاختيار.'),
                    SwitchListTile(
                        title: const Text('تذكير على هذا الجهاز'),
                        subtitle: const Text(
                            'تجدد مواعيد الأيام السبعة القادمة عند فتح القسم. قد يتأخر التنبيه حسب إعدادات بطارية الجهاز.'),
                        value: p['reminders'] == true,
                        onChanged:
                            busy ? null : (v) => update({'reminders': v})),
                    for (final entry in times.entries)
                      Card(
                          child: CheckboxListTile(
                              title: Text(labels[entry.key]!),
                              subtitle: Text(_time(tz.TZDateTime.from(
                                  entry.value,
                                  PrayerSchedule.zone(
                                      Map<String, dynamic>.from(p))))),
                              value: records.any((r) =>
                                  r['prayer'] == entry.key &&
                                  r['completed'] == true),
                              onChanged: busy
                                  ? null
                                  : (v) async {
                                      setState(() => busy = true);
                                      try {
                                        await ref.read(apiClientProvider).put(
                                            '/personal/prayer/record',
                                            data: {
                                              'date': data!['date'],
                                              'prayer': entry.key,
                                              'completed': v
                                            });
                                        await load();
                                        if (v == true && context.mounted) {
                                          await showFamilySuccess(context);
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          setState(() => error = lifeError(e));
                                        }
                                      } finally {
                                        if (mounted) {
                                          setState(() => busy = false);
                                        }
                                      }
                                    })),
                    const Divider(),
                    Text('أذكار الصباح والمساء',
                        style: Theme.of(context).textTheme.titleLarge),
                    SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                              value: 'morning', label: Text('الصباح')),
                          ButtonSegment(value: 'evening', label: Text('المساء'))
                        ],
                        selected: {
                          dhikrPeriod
                        },
                        onSelectionChanged: (v) {
                          setState(() => dhikrPeriod = v.first);
                          load();
                        }),
                    if (adhkar.isEmpty)
                      const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                              'تظهر الأذكار هنا بعد مراجعتها وتفعيلها من الإدارة.')),
                    for (final a in adhkar)
                      Card(
                          child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${a['body']}',
                                        style: const TextStyle(height: 1.8)),
                                    Text('${a['source'] ?? ''}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall)
                                  ]))),
                    const Divider(),
                    SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                              value: 'week', label: Text('هذا الأسبوع')),
                          ButtonSegment(
                              value: 'month', label: Text('هذا الشهر'))
                        ],
                        selected: {
                          period
                        },
                        onSelectionChanged: (v) {
                          setState(() => period = v.first);
                          load();
                        }),
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                                'سجلّك الشخصي: ${data!['stats']['completed']} صلاة من ${data!['stats']['possible']} منذ ${data!['stats']['from']}'))),
                  ]
                ]
              ],
            )));
  }

  String _time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
