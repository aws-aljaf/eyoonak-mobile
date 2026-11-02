import 'package:go_router/go_router.dart';
import 'managed_banner_carousel.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';

// Local welcome content keeps the first visit useful before CMS publication.
// Published mobile banners replace these cards without an app update.
const welcomeBanners = <Map<String, dynamic>>[
  {'id': 'welcome-home', 'revision': 1, 'title': 'هلا بأهل البيت',
    'body': 'كل عائلتك بمكان واحد… ضيف أفراد بيتك ونبدأ المشوار سوا.',
    'local_route': '/family'},
  {'id': 'welcome-learn', 'revision': 1, 'title': 'كل يوم خطوة حلوة',
    'body': 'تمارين وتعلّم يناسب عمر كل طفل، وتشجيع على كل إنجاز.',
    'local_route': '/exercises'},
  {'id': 'welcome-safe', 'revision': 1, 'title': 'قريبين… ومطمئنين',
    'body': 'اربط جهازك بالعائلة، وشارك موقعك بموافقتك. أنت تتحكم بالمشاركة.',
    'local_route': '/our-home/location-sharing'},
];

const contentIcons = {
  'star': Icons.star_outline,
  'book': Icons.menu_book,
  'heart': Icons.favorite_outline,
  'plane': Icons.flight,
  'gift': Icons.card_giftcard,
  'home': Icons.home_outlined,
  'light': Icons.lightbulb_outline,
  'art': Icons.palette_outlined,
  'news': Icons.newspaper
};

class ManagedContentPanel extends ConsumerStatefulWidget {
  const ManagedContentPanel({super.key});
  @override
  ConsumerState<ManagedContentPanel> createState() =>
      _ManagedContentPanelState();
}

class _ManagedContentPanelState extends ConsumerState<ManagedContentPanel>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> rows = [];
  Timer? timer;
  int newsIndex = 0, generation = 0;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(load);
    timer = Timer.periodic(const Duration(seconds: 60), (_) => load());
  }

  @override
  void dispose() {
    generation++;
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) load();
  }

  Future<void> load() async {
    final g = ++generation;
    try {
      final data = await ref
          .read(apiClientProvider)
          .get('/content', query: {'platform': 'mobile'}) as Map;
      if (!mounted || g != generation) return;
      final incoming = [
        for (final row in data['items'] as List)
          Map<String, dynamic>.from(row as Map)
      ];
      setState(() {
        rows = incoming;
        final newsCount = incoming.where((x) => x['kind'] == 'news').length;
        newsIndex = newsCount == 0 ? 0 : newsIndex % newsCount;
        error = null;
      });
    } catch (_) {
      if (mounted && g == generation) {
        setState(() => error = 'تعذر تحديث المحتوى.');
      }
    }
  }

  List<Map<String, dynamic>> kind(String value) =>
      rows.where((x) => x['kind'] == value).toList();
  void open(Map<String, dynamic> row) {
    const destinations = {'/family', '/exercises', '/our-home/location-sharing'};
    final local = row['local_route'];
    if (local is String && destinations.contains(local)) {
      context.push(local);
      return;
    }

    final id = row['page_id'] ?? (row['kind'] == 'page' ? row['id'] : null);
    if (id is num) {
      Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => ManagedContentPage(id: id.toInt())));
    }
  }

  Widget tile(Map<String, dynamic> row) => ListTile(
      leading: Icon(contentIcons[row['icon']] ?? Icons.star_outline),
      title: Text(row['title'] as String),
      trailing: row['page_id'] != null || row['kind'] == 'page'
          ? const Icon(Icons.chevron_left)
          : null,
      onTap: () => open(row));
  @override
  Widget build(BuildContext context) {
    final publishedBanners = kind('banner');
    final banners = publishedBanners.isEmpty ? welcomeBanners : publishedBanners;
    final
        news = kind('news'),
        sections = kind('section'),
        pages = kind('page');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (error != null)
        Row(children: [
          Expanded(child: Text(error!)),
          TextButton(onPressed: load, child: const Text('إعادة المحاولة'))
        ]),
      if (rows.isNotEmpty)
        Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
                onPressed: load, child: const Text('تحديث المحتوى'))),
      if (banners.isNotEmpty)
        ManagedBannerCarousel(
            key: ValueKey(
                banners.map((x) => '${x['id']}:${x['revision']}').join(',')),
            rows: banners,
            onOpen: open),
      if (news.isNotEmpty)
        Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Column(children: [
              const Padding(
                  padding: EdgeInsets.only(top: 8), child: Text('آخر الأخبار')),
              tile(news[newsIndex]),
              if (news.length > 1)
                TextButton(
                    onPressed: () => setState(
                        () => newsIndex = (newsIndex + 1) % news.length),
                    child: const Text('الخبر التالي'))
            ])),
      for (final section in sections)
        Card(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              tile(section),
              if (section['body'] != null)
                Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(section['body'] as String)),
              for (final page
                  in pages.where((x) => x['section_id'] == section['id']))
                tile(page)
            ])),
      for (final page in pages.where((x) => x['section_id'] == null))
        Card(child: tile(page)),
    ]);
  }
}

class ManagedContentPage extends ConsumerStatefulWidget {
  const ManagedContentPage({super.key, required this.id});
  final int id;
  @override
  ConsumerState<ManagedContentPage> createState() => _ManagedContentPageState();
}

class _ManagedContentPageState extends ConsumerState<ManagedContentPage> {
  Map<String, dynamic>? row;
  String? error;
  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    setState(() => error = null);
    try {
      final value = await ref
          .read(apiClientProvider)
          .get('/content/${widget.id}', query: {'platform': 'mobile'}) as Map;
      if (mounted) setState(() => row = Map<String, dynamic>.from(value));
    } catch (_) {
      if (mounted) {
        setState(() {
          row = null;
          error = 'هذه الصفحة غير متاحة حالياً.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar:
          AppBar(title: Text(row?['title'] as String? ?? 'عيونك'), actions: [
        IconButton(
            onPressed: load,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث الصفحة')
      ]),
      body: SafeArea(
          child: error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(error!),
                  TextButton(
                      onPressed: load, child: const Text('إعادة المحاولة'))
                ]))
              : row == null
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(row!['title'] as String,
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                            if (row!['image_url'] != null)
                              Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  child: Image.network(
                                      row!['image_url'] as String,
                                      errorBuilder: (_, e, s) => const Icon(
                                          Icons.broken_image_outlined))),
                            SelectableText(row!['body'] as String? ?? ''),
                            if (row!['page_id'] is num)
                              TextButton(
                                  onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                          builder: (_) => ManagedContentPage(
                                              id: (row!['page_id'] as num)
                                                  .toInt()))),
                                  child: const Text('المزيد'))
                          ]))));
}
