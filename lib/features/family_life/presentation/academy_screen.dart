import 'package:go_router/go_router.dart';
import 'dart:io';
import 'picture_story_reader.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import '../../../app/providers.dart';
import '../../family/application/family_providers.dart';
import 'family_life_screen.dart' show lifeError;

class AcademyScreen extends ConsumerStatefulWidget {
  const AcademyScreen({super.key, this.courseKey});
  final String? courseKey;
  @override
  ConsumerState<AcademyScreen> createState() => _AcademyScreenState();
}

class _AcademyScreenState extends ConsumerState<AcademyScreen> {
  final search = TextEditingController();
  List<dynamic> items = [], categories = [];
  Map<String, dynamic>? article, attempt;
  List<dynamic>? feedback;
  List<int?> answers = [];
  int page = 1, lastPage = 1, generation = 0;
  int? category;
  bool loading = true,
      busy = false,
      completed = false,
      canTrack = false,
      canManage = false;
  int storyPage = 1;
  String? error, viewerGender;
  Map<String, dynamic> get headers {
    final id = ref.read(selectedFamilyIdProvider);
    return id == null ? {} : {'X-Family-Id': '$id'};
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  @override
  void dispose() {
    generation++;
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final g = ++generation;
    if (mounted) setState(() => loading = true);
    try {
      final client = ref.read(apiClientProvider);
      final result = await client
          .getPaginated('/family-life/academy', headers: headers, query: {
        'page': page,
        if (widget.courseKey != null) 'course_key': widget.courseKey,
        if (search.text.trim().isNotEmpty) 'search': search.text.trim(),
        if (category != null) 'category_id': category
      });
      final c =
          await client.get('/family-life/academy/categories', headers: headers);
      final h = await client.get('/family-life/home', headers: headers);
      if (mounted && g == generation) {
        setState(() {
          canManage = h['can_manage'] == true;
          viewerGender = h['viewer_role'] == 'child'
              ? h['viewer_gender'] as String?
              : null;
          items = result.data;
          categories = c as List;
          lastPage = result.meta['last_page'] as int;
          error = null;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted && g == generation) {
        setState(() {
          error = lifeError(e);
          loading = false;
        });
      }
    }
  }

  Future<void> open(int id) async {
    final g = ++generation;
    setState(() => loading = true);
    try {
      final r = await ref
          .read(apiClientProvider)
          .get('/family-life/academy/$id', headers: headers);
      if (mounted && g == generation) {
        setState(() {
          article = Map<String, dynamic>.from(r['article'] as Map);
          completed = r['completed'] == true;
          storyPage = (r['last_page'] as num?)?.toInt() ?? 1;
          canTrack = r['can_track'] == true;
          attempt = r['attempt'] == null
              ? null
              : Map<String, dynamic>.from(r['attempt'] as Map);
          answers = List.filled((article!['questions'] as List).length, null);
          feedback = null;
          loading = false;
          error = null;
        });
      }
    } catch (e) {
      if (mounted && g == generation) {
        setState(() {
          error = lifeError(e);
          loading = false;
        });
      }
    }
  }

  Future<void> complete() async {
    if (busy || !canTrack) return;
    final g = generation;
    setState(() => busy = true);
    try {
      await ref.read(apiClientProvider).post(
          '/family-life/academy/${article!['id']}/complete',
          headers: headers,
          data: {});
      if (mounted && g == generation) setState(() => completed = true);
    } catch (e) {
      if (mounted && g == generation) setState(() => error = lifeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submit() async {
    if (busy || !canTrack) return;
    final g = generation;
    setState(() => busy = true);
    try {
      final r = await ref.read(apiClientProvider).post(
          '/family-life/academy/${article!['id']}/quiz',
          headers: headers,
          data: {'answers': answers});
      if (mounted && g == generation) {
        setState(() {
          attempt = Map<String, dynamic>.from(r['attempt'] as Map);
          feedback = r['feedback'] as List;
          error = null;
        });
      }
    } catch (e) {
      if (mounted && g == generation) setState(() => error = lifeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(selectedFamilyIdProvider, (previous, next) {
      if (previous != next) {
        setState(() {
          article = null;
          page = 1;
          category = null;
          search.clear();
        });
        load();
      }
    });
    final base = Theme.of(context);
    final seed = viewerGender == 'female'
        ? const Color(0xFFDB2777)
        : viewerGender == 'male'
            ? const Color(0xFF2563EB)
            : base.colorScheme.primary;
    return Theme(
        data: base.copyWith(
            colorScheme: ColorScheme.fromSeed(seedColor: seed),
            scaffoldBackgroundColor: viewerGender == 'female'
                ? const Color(0xFFFFF1F7)
                : viewerGender == 'male'
                    ? const Color(0xFFEFF6FF)
                    : base.scaffoldBackgroundColor),
        child: PopScope(
            canPop: article == null,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop) {
                setState(() {
                  generation++;
                  article = null;
                  error = null;
                  loading = false;
                });
              }
            },
            child: Scaffold(
                appBar: AppBar(
                    title: Text(widget.courseKey == 'etiquette' ? 'الإتيكيت وآداب التعامل' : widget.courseKey == 'interests'
                        ? 'معلومات تناسب اهتماماتي'
                        : widget.courseKey == 'stories'
                            ? 'قصص مصوّرة'
                            : widget.courseKey == 'english'
                                ? 'نتعلّم إنجليزي'
                                : 'أكاديمية عيونك'),
                    actions: [
                      IconButton(
                          tooltip: 'تحديث المحتوى',
                          onPressed: loading
                              ? null
                              : () => article == null
                                  ? load()
                                  : open(article!['id'] as int),
                          icon: const Icon(Icons.refresh))
                    ],
                    leading: article == null
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.arrow_back),
                            tooltip: 'الرجوع للمكتبة',
                            onPressed: () => setState(() {
                                  generation++;
                                  article = null;
                                  error = null;
                                  loading = false;
                                }))),
                body: RefreshIndicator(
                    onRefresh: article == null
                        ? load
                        : () => open(article!['id'] as int),
                    child:
                        ListView(padding: const EdgeInsets.all(16), children: [
                      if (error != null)
                        Text(error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      if (loading) const LinearProgressIndicator(),
                      if (article == null) ...[
                        const Text(
                            'نتعلم ونسأل ونكتشف. المحتوى مناسب للعمر والجمهور.'),
                        TextField(
                            controller: search,
                            maxLength: 150,
                            decoration: const InputDecoration(
                                labelText: 'ابحث في الأكاديمية',
                                suffixIcon: Icon(Icons.search)),
                            onSubmitted: (_) {
                              page = 1;
                              load();
                            }),
                        DropdownButtonFormField<int>(
                            initialValue: category,
                            decoration:
                                const InputDecoration(labelText: 'التصنيف'),
                            items: [
                              const DropdownMenuItem<int>(
                                  value: null, child: Text('كل التصنيفات')),
                              for (final c in categories)
                                DropdownMenuItem<int>(
                                    value: c['id'] as int,
                                    child: Text('${c['name']}'))
                            ],
                            onChanged: (v) {
                              setState(() => category = v);
                              page = 1;
                              load();
                            }),
                        if (items.isEmpty && !loading && error == null)
                          Card(
                              child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(children: [
                                    Icon(
                                        widget.courseKey == 'stories'
                                            ? Icons.auto_stories_outlined
                                            : Icons.menu_book_outlined,
                                        size: 48),
                                    const SizedBox(height: 12),
                                    Text(
                                        search.text.trim().isNotEmpty ||
                                                category != null
                                            ? 'ماكو محتوى مطابق لهذا البحث.'
                                            : widget.courseKey == 'stories'
                                                ? 'مكتبة القصص بانتظار نشر القصص المصوّرة المناسبة.'
                                                : 'يظهر المحتوى المناسب هنا بعد نشره من الإدارة.',
                                        textAlign: TextAlign.center),
                                    if (search.text.trim().isNotEmpty ||
                                        category != null)
                                      TextButton(
                                          onPressed: () {
                                            search.clear();
                                            category = null;
                                            page = 1;
                                            load();
                                          },
                                          child: const Text('عرض كل المحتوى')),
                                    if (widget.courseKey != null)
                                      TextButton(
                                          onPressed: () =>
                                              context.push('/our-home/academy'),
                                          child:
                                              const Text('استكشف الأكاديمية')),
                                  ]))),
                        for (final a in items)
                          Card(
                              child: Column(children: [
                            if (widget.courseKey == 'stories' &&
                                (a['media'] as List? ?? []).isNotEmpty)
                              AcademyProtectedMedia(media: {
                                ...Map<String, dynamic>.from(
                                    a['media'][0] as Map),
                                'caption': null
                              }, headers: headers, imageHeight: 150),
                            ListTile(
                                title: Text('${a['title']}'),
                                subtitle: Text('${a['summary'] ?? ''}'),
                                leading: Icon(a['featured'] == true
                                    ? Icons.auto_awesome
                                    : Icons.menu_book_outlined),
                                trailing: const Icon(Icons.chevron_left),
                                onTap: () => open(a['id'] as int))
                          ])),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                  onPressed: page <= 1 || loading
                                      ? null
                                      : () {
                                          page--;
                                          load();
                                        },
                                  child: const Text('السابق')),
                              Text('$page / $lastPage'),
                              TextButton(
                                  onPressed: page >= lastPage || loading
                                      ? null
                                      : () {
                                          page++;
                                          load();
                                        },
                                  child: const Text('التالي'))
                            ]),
                      ] else ...[
                        Text('${article!['title']}',
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 16),
                        SelectableText('${article!['body']}',
                            style: const TextStyle(height: 1.8, fontSize: 17)),
                        if (article!['course_key'] == 'stories')
                          PictureStoryReader(
                              key: ValueKey(article!['id']),
                              pages: (article!['media'] as List)
                                  .where((m) => m['kind'] == 'image')
                                  .map((m) =>
                                      Map<String, dynamic>.from(m as Map))
                                  .toList(),
                              headers: headers,
                              initialPage: storyPage,
                              completed: completed,
                              onPage: canTrack
                                  ? (page) async {
                                      await ref.read(apiClientProvider).put(
                                          '/family-life/academy/${article!['id']}/reading-progress',
                                          headers: headers,
                                          data: {'page': page});
                                    }
                                  : null,
                              onFinish: canTrack && !busy ? complete : null),
                        for (final m in article!['course_key'] == 'stories'
                            ? []
                            : article!['media'] as List)
                          AcademyProtectedMedia(
                              key: ValueKey('${article!['id']}-${m['id']}'),
                              media: Map<String, dynamic>.from(m as Map),
                              headers: headers),
                        if (!canTrack &&
                            (article!['course_key'] == 'english' || article!['course_key'] == 'etiquette' ||
                                (article!['questions'] as List).isNotEmpty))
                          Card(
                              child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(children: [
                                    const Text(
                                        'معاينة الدرس متاحة. لحفظ الإنجاز والنتيجة، لازم حساب المتعلّم يكون مربوطاً بملف فرد من العائلة.'),
                                    if (canManage)
                                      TextButton.icon(
                                          onPressed: () =>
                                              context.push('/family'),
                                          icon: const Icon(
                                              Icons.family_restroom_rounded),
                                          label:
                                              const Text('إعداد أفراد العائلة'))
                                  ]))),
                        if (article!['course_key'] == 'english' && canTrack)
                          completed
                              ? const Text('أحسنت! أنجزت هذا الدرس ✓')
                              : FilledButton(
                                  onPressed: busy ? null : complete,
                                  child: const Text('تعلّمت الدرس')),
                        if (article!['sources'] != null)
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: SelectableText(
                                  'المصادر: ${article!['sources']}')),
                        if ((article!['questions'] as List).isNotEmpty) ...[
                          const Divider(),
                          Text('اختبر فهمك',
                              style: Theme.of(context).textTheme.titleLarge),
                          for (var i = 0; i < answers.length; i++)
                            Card(
                                child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                              '${i + 1}. ${article!['questions'][i]['question']}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium),
                                          for (var j = 0;
                                              j <
                                                  (article!['questions'][i]
                                                          ['options'] as List)
                                                      .length;
                                              j++)
                                            Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 8),
                                                child: OutlinedButton(
                                                    onPressed: busy || !canTrack
                                                        ? null
                                                        : () => setState(() =>
                                                            answers[i] = j),
                                                    style: OutlinedButton.styleFrom(
                                                        backgroundColor: answers[i] == j
                                                            ? Theme.of(context)
                                                                .colorScheme
                                                                .secondaryContainer
                                                            : null),
                                                    child:
                                                        Text('${answers[i] == j ? '✓ ' : ''}${article!['questions'][i]['options'][j]}'))),
                                          if (feedback != null)
                                            Text(
                                                '${feedback![i]['correct'] == true ? 'إجابة موفقة ✓' : 'نراجع الفكرة سوا'} · ${feedback![i]['explanation'] ?? ''}',
                                                style: const TextStyle(
                                                    height: 1.7)),
                                        ]))),
                          if (canTrack)
                            FilledButton(
                                onPressed: busy || answers.contains(null)
                                    ? null
                                    : submit,
                                child:
                                    Text(busy ? 'جارِ الحفظ…' : 'اعرض نتيجتي')),
                          if (attempt != null)
                            Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                    'آخر نتيجة: ${attempt!['last_score']} / ${attempt!['total']} · أفضل نتيجة: ${attempt!['best_score']} / ${attempt!['total']}\nنقاط مُنحت مرة واحدة: ${attempt!['awarded_points']}')),
                        ],
                      ],
                    ])))));
  }
}

class AcademyProtectedMedia extends ConsumerStatefulWidget {
  const AcademyProtectedMedia(
      {super.key,
      required this.media,
      required this.headers,
      this.imageHeight = 220});
  final double imageHeight;
  final Map<String, dynamic> media, headers;
  @override
  ConsumerState<AcademyProtectedMedia> createState() =>
      _AcademyProtectedMediaState();
}

class _AcademyProtectedMediaState extends ConsumerState<AcademyProtectedMedia> {
  Uint8List? image;
  File? file;
  VideoPlayerController? video;
  AudioPlayer? audio;
  String? error, viewerGender;
  bool loaded = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final bytes = await ref.read(apiClientProvider).downloadBytes(
          widget.media['url'] as String,
          headers: widget.headers);
      if (!mounted) return;
      if (widget.media['kind'] == 'image') {
        setState(() => image = Uint8List.fromList(bytes));
        return;
      }
      final dir = await getTemporaryDirectory();
      final extension = widget.media['kind'] == 'video'
          ? 'mp4'
          : (widget.media['mime_type'] == 'audio/mpeg' ? 'mp3' : 'm4a');
      final temp = File(
          '${dir.path}/academy-${widget.media['id']}-${DateTime.now().microsecondsSinceEpoch}.$extension');
      await temp.writeAsBytes(bytes);
      if (!mounted) {
        await temp.delete();
        return;
      }
      file = temp;
      if (widget.media['kind'] == 'video') {
        final controller = VideoPlayerController.file(temp);
        video = controller;
        await controller.initialize();
      } else {
        final player = AudioPlayer();
        audio = player;
        await player.setFilePath(temp.path);
      }
      if (mounted) setState(() => loaded = true);
    } catch (_) {
      if (mounted) setState(() => error = 'تعذر تحميل الوسيط.');
    }
  }

  @override
  void dispose() {
    video?.dispose();
    audio?.dispose();
    file?.delete().catchError((_) => file!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(children: [
        if (error != null)
          Text(error!)
        else if (image != null)
          Image.memory(image!,
              height: widget.imageHeight,
              fit: BoxFit.contain,
              semanticLabel: 'صورة من القصة أو الدرس')
        else if (!loaded)
          const CircularProgressIndicator()
        else if (video != null) ...[
          AspectRatio(
              aspectRatio: video!.value.aspectRatio,
              child: VideoPlayer(video!)),
          IconButton(
              tooltip: video!.value.isPlaying ? 'إيقاف مؤقت' : 'تشغيل الفيديو',
              onPressed: () {
                setState(() {
                  video!.value.isPlaying ? video!.pause() : video!.play();
                });
              },
              icon: Icon(video!.value.isPlaying
                  ? Icons.pause_circle
                  : Icons.play_circle)),
        ] else if (audio != null)
          StreamBuilder<PlayerState>(
              stream: audio!.playerStateStream,
              builder: (context, snapshot) => IconButton(
                  tooltip: audio!.playing ? 'إيقاف مؤقت' : 'تشغيل الصوت',
                  onPressed: () async {
                    if (audio!.playing) {
                      await audio!.pause();
                    } else {
                      if (audio!.processingState == ProcessingState.completed) {
                        await audio!.seek(Duration.zero);
                      }
                      audio!.play();
                    }
                  },
                  icon: Icon(audio!.playing
                      ? Icons.pause_circle
                      : Icons.play_circle))),
        if (widget.media['caption'] != null) Text('${widget.media['caption']}'),
      ]));
}
