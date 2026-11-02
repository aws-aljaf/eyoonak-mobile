import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../family/application/family_providers.dart';
import 'family_life_screen.dart' show lifeError;

class InterestWorldScreen extends ConsumerStatefulWidget {
  const InterestWorldScreen({super.key});
  @override
  ConsumerState<InterestWorldScreen> createState() =>
      _InterestWorldScreenState();
}

class _InterestWorldScreenState extends ConsumerState<InterestWorldScreen> {
  List<Map<String, dynamic>> profiles = [], topics = [];
  bool loading = true, busy = false;
  String? error, message, gender;
  int generation = 0;
  Map<String, dynamic> get headers {
    final id = ref.read(selectedFamilyIdProvider);
    return id == null ? {} : {'X-Family-Id': '$id'};
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    final g = ++generation;
    setState(() {
      loading = true;
      error = null;
      message = null;
      profiles = [];
      topics = [];
    });
    try {
      final client = ref.read(apiClientProvider);
      final p =
          await client.get('/family-life/child-profiles', headers: headers);
      final t =
          await client.get('/family-life/interest-topics', headers: headers);
      final h = await client.get('/family-life/home', headers: headers);
      if (!mounted || g != generation) return;
      setState(() {
        gender =
            h['viewer_role'] == 'child' ? h['viewer_gender'] as String? : null;
        profiles = (p as List)
            .map((p) => Map<String, dynamic>.from(p as Map))
            .toList();
        topics = (t as List)
            .map((t) => Map<String, dynamic>.from(t as Map))
            .toList();
      });
    } catch (e) {
      if (mounted && g == generation) setState(() => error = lifeError(e));
    } finally {
      if (mounted && g == generation) setState(() => loading = false);
    }
  }

  Future<void> save(Map<String, dynamic> p) async {
    if (busy) return;
    final g = generation;
    setState(() {
      busy = true;
      message = null;
      error = null;
    });
    try {
      final selected = (p['knowledge_topic_ids'] as List? ?? [])
          .where((id) => topics.any((t) => t['id'] == id))
          .toList();
      await ref.read(apiClientProvider).put(
          '/family-life/child-profiles/${p['id']}',
          headers: headers,
          data: {'knowledge_topic_ids': selected});
      if (mounted && g == generation) {
        setState(() => message = 'حفظنا اهتمامات ${p['name']}');
      }
    } catch (e) {
      if (mounted && g == generation) setState(() => error = lifeError(e));
    } finally {
      if (mounted && g == generation) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int?>(selectedFamilyIdProvider, (old, next) {
      if (old != next) load();
    });
    final base = Theme.of(context);
    final seed = gender == 'female'
        ? const Color(0xFFDB2777)
        : gender == 'male'
            ? const Color(0xFF2563EB)
            : base.colorScheme.primary;
    return Theme(
        data: base.copyWith(
            colorScheme: ColorScheme.fromSeed(seedColor: seed),
            scaffoldBackgroundColor: gender == 'female'
                ? const Color(0xFFFFF1F7)
                : gender == 'male'
                    ? const Color(0xFFEFF6FF)
                    : base.scaffoldBackgroundColor),
        child: Scaffold(
            appBar: AppBar(title: const Text('عالم اهتماماتي ✈️')),
            body: RefreshIndicator(
                onRefresh: load,
                child: ListView(padding: const EdgeInsets.all(20), children: [
                  const Text('شنو تحب تكتشف؟',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text(
                      'اختار المواضيع اللي تحبها حتى تظهر لك معلومات تناسب اهتمامك وعمرك. تكدر تغيّرها بأي وقت.'),
                  if (loading) const Center(child: CircularProgressIndicator()),
                  if (error != null)
                    Text(error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  if (message != null)
                    Semantics(liveRegion: true, child: Text(message!)),
                  if (!loading && error == null && profiles.isEmpty)
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(children: [
                              const Text(
                                  'أكمل ملف الطفل واربط حسابه حتى نحفظ اهتماماته ونختار له محتوى مناسباً.'),
                              TextButton.icon(
                                  onPressed: () =>
                                      context.push('/our-home/settings'),
                                  icon:
                                      const Icon(Icons.family_restroom_rounded),
                                  label: const Text('إعداد ملفات العائلة'))
                            ]))),
                  for (final p in profiles)
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text('${p['name']}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge),
                                  if (p['age'] == null)
                                    const Text(
                                        'أكمل تاريخ الميلاد من إعدادات بيتنا حتى نختار المحتوى المناسب.'),
                                  const SizedBox(height: 12),
                                  Wrap(spacing: 8, runSpacing: 8, children: [
                                    for (final t in topics)
                                      FilterChip(
                                          label: Text('${t['name']}'),
                                          selected: (p['knowledge_topic_ids']
                                                      as List? ??
                                                  [])
                                              .contains(t['id']),
                                          onSelected: busy
                                              ? null
                                              : (selected) {
                                                  setState(() {
                                                    final ids = List<
                                                            dynamic>.from(
                                                        p['knowledge_topic_ids']
                                                                as List? ??
                                                            []);
                                                    selected
                                                        ? ids.add(t['id'])
                                                        : ids.remove(t['id']);
                                                    p['knowledge_topic_ids'] =
                                                        ids;
                                                  });
                                                })
                                  ]),
                                  const SizedBox(height: 12),
                                  FilledButton(
                                      onPressed: busy ? null : () => save(p),
                                      child: const Text('حفظ اهتماماتي')),
                                ]))),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () => context.push('/our-home/interest-library'),
                      icon: const Icon(Icons.explore_rounded),
                      label: const Text('معلومات تناسب اهتماماتي')),
                  const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('معلومات جديدة راح تظهر هنا بعد تجهيزها.')),
                ]))));
  }
}
