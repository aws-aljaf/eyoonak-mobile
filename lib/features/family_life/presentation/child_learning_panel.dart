import 'package:flutter/material.dart';

class ChildLearningPanel extends StatefulWidget {
  const ChildLearningPanel({super.key, required this.learning, required this.answer});
  final Map<String, dynamic> learning;
  final Future<Map<String, dynamic>> Function(String key, int choice) answer;
  @override
  State<ChildLearningPanel> createState() => _ChildLearningPanelState();
}

class _ChildLearningPanelState extends State<ChildLearningPanel> {
  final choices = <String, int>{};
  final feedback = <String, Map<String, dynamic>>{};
  bool busy = false;
  String? error;
  Future<void> submit(String key) async {
    if (busy || choices[key] == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.answer(key, choices[key]!);
      if (mounted) setState(() => feedback[key] = result);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'تعذر حفظ المحاولة. حدّث الصفحة وجرب مرة ثانية.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final learning = widget.learning;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Card(
          color: const Color(0xfffff4d9),
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('💡 معلومة اليوم', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text('${learning['fact']['text']}', style: const TextStyle(fontSize: 18, height: 1.7)),
                const SizedBox(height: 8),
                Text('${learning['fact']['topic']}'),
              ]))),
      for (final skill in learning['skills'] as List? ?? [])
        Card(
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('🎨 مهارتي: ${skill['title']}', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Text('${skill['activity']}', style: const TextStyle(height: 1.7)),
                  const Text('أتعلّم على راحتي ويا أهلي، بلا مقارنة بالآخرين.'),
                ]))),
      Padding(
          padding: const EdgeInsets.all(12),
          child: Text('🧩 تحديات التفكير${learning['age'] == null ? '' : ' · لعمر ${learning['age']} سنة'}',
              style: Theme.of(context).textTheme.titleLarge)),
      const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('ألعاب نتعلم بيها. كل محاولة فرصة جديدة، وتتجدد حسب يوم الأسرة.')),
      if (learning['message'] != null)
        Padding(padding: const EdgeInsets.all(12), child: Text('${learning['message']}')),
      if (error != null)
        Padding(
            padding: const EdgeInsets.all(12),
            child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
      for (final q in learning['exercises'] as List)
        Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (q['solved'] == true)
                    const Text('أحسنت! أنجزت هذا التحدي ✓',
                        style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                  Text('${q['question']}', style: Theme.of(context).textTheme.titleMedium),
                  for (var i = 0; i < (q['options'] as List).length; i++)
                    Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: OutlinedButton(
                            onPressed: busy || q['solved'] == true ? null : () => setState(() => choices[q['key']] = i),
                            style: OutlinedButton.styleFrom(
                                backgroundColor:
                                    choices[q['key']] == i ? Theme.of(context).colorScheme.secondaryContainer : null),
                            child: Text('${choices[q['key']] == i ? '✓ ' : ''}${q['options'][i]}',
                                textAlign: TextAlign.center))),
                  if (q['solved'] != true)
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: FilledButton(
                            onPressed: busy || choices[q['key']] == null ? null : () => submit(q['key'] as String),
                            child: const Text('جرّب إجابتي'))),
                  if (feedback[q['key']] != null)
                    Semantics(
                        liveRegion: true,
                        child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text('${feedback[q['key']]!['message']}\n${feedback[q['key']]!['explanation']}',
                                style: const TextStyle(height: 1.7)))),
                ]))),
    ]);
  }
}
