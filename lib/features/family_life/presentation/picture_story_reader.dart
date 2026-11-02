import 'package:flutter/material.dart';
import 'academy_screen.dart' show AcademyProtectedMedia;

class PictureStoryReader extends StatefulWidget {
  const PictureStoryReader(
      {super.key,
      required this.pages,
      required this.headers,
      this.initialPage = 1,
      this.completed = false,
      this.onPage,
      this.onFinish});
  final List<Map<String, dynamic>> pages;
  final Map<String, dynamic> headers;
  final int initialPage;
  final bool completed;
  final Future<void> Function(int page)? onPage;
  final Future<void> Function()? onFinish;
  @override
  State<PictureStoryReader> createState() => _PictureStoryReaderState();
}

class _PictureStoryReaderState extends State<PictureStoryReader> {
  late int page;
  bool saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    page = (widget.initialPage - 1).clamp(0, widget.pages.isEmpty ? 0 : widget.pages.length - 1);
  }

  Future<void> turn(int delta) async {
    final next = page + delta;
    if (saving || next < 0 || next >= widget.pages.length) return;
    setState(() {
      page = next;
      error = null;
    });
    await save();
  }

  Future<void> save() async {
    if (widget.onPage == null) return;
    setState(() { saving = true; error = null; });
    try {
      await widget.onPage!(page + 1);
    } catch (_) {
      if (mounted) setState(() => error = 'تغيّرت الصفحة؛ تعذر حفظ مكان القراءة. تأكد من الاتصال.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pages.isEmpty) return const Padding(padding: EdgeInsets.all(24), child: Text('القصة قيد التجهيز.'));
    final current = widget.pages[page];
    return Card(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 240),
                  child: DefaultTextStyle.merge(
                      key: ValueKey(current['id']),
                      style: const TextStyle(fontSize: 20, height: 1.8),
                      child: AcademyProtectedMedia(
                          key: ValueKey(current['id']), media: current, headers: widget.headers, imageHeight: 260))),
              Semantics(
                  liveRegion: true,
                  child: Text('الصفحة ${page + 1} من ${widget.pages.length}', textAlign: TextAlign.center)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: OutlinedButton(
                        onPressed: page == 0 || saving ? null : () => turn(-1), child: const Text('السابقة'))),
                const SizedBox(width: 12),
                Expanded(
                    child: FilledButton(
                        onPressed: page + 1 == widget.pages.length || saving ? null : () => turn(1),
                        child: const Text('التالية'))),
              ]),
              if (error != null) ...[
                Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                TextButton(onPressed: saving ? null : save, child: const Text('إعادة حفظ مكان القراءة'))
              ],
              if (page + 1 == widget.pages.length) ...[
                const SizedBox(height: 12),
                if (widget.completed)
                  const Text('أحسنت! قرأت هذه القصة ✓', textAlign: TextAlign.center)
                else if (widget.onFinish != null)
                  FilledButton.icon(
                      onPressed: saving ? null : widget.onFinish,
                      icon: const Icon(Icons.star_rounded),
                      label: const Text('أنهيت القصة')),
                const Text('احكِ لأهلك: شنو أكثر شي عجبك بالقصة؟', textAlign: TextAlign.center),
              ],
            ])));
  }
}

