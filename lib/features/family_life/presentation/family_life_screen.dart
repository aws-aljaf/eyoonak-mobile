import '../../../app/family_live_refresh.dart';
import '../../../core/notifications/notification_permission_card.dart';
import 'parent_titles_panel.dart';
import 'managed_content_panel.dart';
import '../../notifications/application/push_providers.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'diary_media.dart';
import 'child_learning_panel.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/family_motion.dart';
import '../../family/application/family_providers.dart';

String lifeError(Object e) => e is StateError
    ? e.message.toString()
    : e is ApiException
        ? ([e.message, ...e.fieldErrors.values.expand((v) => v)]).join('\n')
        : 'تعذر إتمام العملية. حاول مرة أخرى.';

class LifeField {
  const LifeField(this.key, this.label,
      {this.initial = '',
      this.required = false,
      this.choices,
      this.lines = 1,
      this.kind = 'text'});
  final String key, label, kind;
  final dynamic initial;
  final bool required;
  final Map<String, String>? choices;
  final int lines;
}

class LifeForm extends StatefulWidget {
  const LifeForm(
      {super.key,
      required this.title,
      required this.fields,
      required this.submit});
  final String title;
  final List<LifeField> fields;
  final Future<void> Function(Map<String, dynamic>) submit;
  @override
  State<LifeForm> createState() => _LifeFormState();
}

class _LifeFormState extends State<LifeForm> {
  final key = GlobalKey<FormState>();
  late final values = {for (final f in widget.fields) f.key: f.initial};
  bool busy = false;
  String? error;
  Future<void> save() async {
    if (!key.currentState!.validate() || busy) return;
    setState(() => busy = true);
    try {
      await widget.submit(Map.from(values));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = lifeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: Text(widget.title),
          content: SizedBox(
              width: 440,
              child: Form(
                  key: key,
                  child: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    for (final f in widget.fields)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: f.kind == 'bool'
                              ? SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(f.label),
                                  value: values[f.key] as bool,
                                  onChanged: busy
                                      ? null
                                      : (v) =>
                                          setState(() => values[f.key] = v))
                              : f.kind == 'datetime'
                                  ? TextButton(
                                      onPressed: busy
                                          ? null
                                          : () async {
                                              final date = await showDatePicker(
                                                  context: context,
                                                  firstDate: DateTime.now(),
                                                  lastDate: DateTime.now().add(
                                                      const Duration(
                                                          days: 365)),
                                                  initialDate: DateTime.now());
                                              if (date == null ||
                                                  !context.mounted) {
                                                return;
                                              }
                                              final time = await showTimePicker(
                                                  context: context,
                                                  initialTime: TimeOfDay.now());
                                              if (time != null && mounted) {
                                                setState(() => values[f.key] =
                                                    DateTime(
                                                            date.year,
                                                            date.month,
                                                            date.day,
                                                            time.hour,
                                                            time.minute)
                                                        .toUtc()
                                                        .toIso8601String());
                                              }
                                            },
                                      child: Text(values[f.key] == ''
                                          ? f.label
                                          : '${f.label}: ${DateTime.parse(values[f.key] as String).toLocal()}'))
                                  : f.choices != null
                                      ? DropdownButtonFormField<String>(
                                          initialValue: values[f.key] as String,
                                          decoration: InputDecoration(
                                              labelText: f.label),
                                          items: f.choices!.entries
                                              .map((e) => DropdownMenuItem(
                                                  value: e.key,
                                                  child: Text(e.value)))
                                              .toList(),
                                          onChanged: busy
                                              ? null
                                              : (v) => values[f.key] = v)
                                      : TextFormField(
                                          initialValue: '${values[f.key]}',
                                          maxLines: f.lines,
                                          maxLength: f.lines > 1 ? 5000 : 255,
                                          keyboardType: f.kind == 'number'
                                              ? TextInputType.number
                                              : TextInputType.text,
                                          decoration: InputDecoration(
                                              labelText: f.label),
                                          validator: (v) => f.required &&
                                                  (v ?? '').trim().isEmpty
                                              ? 'هذا الحقل مطلوب'
                                              : null,
                                          onChanged: (v) => values[f.key] = v)),
                    if (error != null)
                      Text(error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                  ])))),
          actions: [
            TextButton(
                onPressed: busy ? null : () => Navigator.pop(context),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: busy ? null : save,
                child: Text(busy ? 'جارِ الحفم' : 'حفظ'))
          ]);
}

class FamilyLifeScreen extends ConsumerStatefulWidget {
  const FamilyLifeScreen({super.key, this.section = 'home'});
  final String section;
  @override
  ConsumerState<FamilyLifeScreen> createState() => _FamilyLifeScreenState();
}

class _FamilyLifeScreenState extends ConsumerState<FamilyLifeScreen>
    with WidgetsBindingObserver {
  Timer? timer;
  Map<String, dynamic>? home;
  dynamic data;
  Map<String, dynamic> meta = {};
  bool loading = true, busy = false, resumed = true;
  String? error;
  int page = 1;
  String status = '';
  String search = '';
  bool onThisDay = false;
  String cardBox = 'received';
  List<dynamic> childProfiles = [];
  int generation = 0;
  static const titles = {
    'occasions': 'مناسباتنا 🎂',
    'diary': 'مذكراتي وذكرياتي',
    'memories': 'ذكريات أسرتنا',
    'kind-cards': 'أهدي كلمة حلوة ❤️',
    'home': 'بيتنا ❤️',
    'meals': 'شنو نطبخ اليوم؟',
    'shopping': 'احتياجات البيت',
    'settings': 'إعدادات بيتنا'
  };
  Map<String, dynamic>? get headers =>
      ref.read(selectedFamilyIdProvider) == null
          ? null
          : {'X-Family-Id': '${ref.read(selectedFamilyIdProvider)}'};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(load);
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
    resumed = state == AppLifecycleState.resumed;
    if (resumed) load(quiet: true);
  }

  Future<void> load({bool quiet = false}) async {
    final current = ++generation;
    if (!mounted) return;
    if (!quiet) setState(() => loading = true);
    try {
      final client = ref.read(apiClientProvider);
      final h = await client.get('/family-life/home', headers: headers);
      dynamic d;
      Map<String, dynamic> m = {};
      List<dynamic> profiles = [];
      if (widget.section == 'home') {
        d = h;
      } else if (widget.section == 'occasions') {
        d = await client.get('/family-life/occasions', headers: headers);
      } else if (widget.section == 'settings') {
        d = await client.get('/notification-preferences');
        profiles = (await client.get('/family-life/child-profiles',
            headers: headers)) as List;
      } else {
        final result = await client.getPaginated(
            widget.section == 'diary'
                ? '/personal/diary'
                : '/family-life/${widget.section == 'meals' ? 'meal-polls' : widget.section}',
            headers: headers,
            query: {
              'page': page,
              if (status.isNotEmpty) 'status': status,
              if (search.isNotEmpty) 'search': search,
              if (onThisDay) 'on_this_day': true,
              if (widget.section == 'kind-cards') 'box': cardBox
            });
        d = result.data;
        m = result.meta;
      }
      if (mounted && current == generation) {
        setState(() {
          home = Map<String, dynamic>.from(h as Map);
          data = d;
          childProfiles = profiles;
          meta = m;
          error = null;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted && current == generation) {
        setState(() {
          error = lifeError(e);
          loading = false;
        });
      }
    }
  }

  Future<void> action(Future<dynamic> Function() run) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await run();
      await load(quiet: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(lifeError(e))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> form(String title, List<LifeField> fields,
      Future<void> Function(Map<String, dynamic>) submit) async {
    final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => LifeForm(title: title, fields: fields, submit: submit));
    if (saved == true) await load(quiet: true);
  }

  bool get childView => home?['viewer_role'] == 'child';
  bool get manager => home?['can_manage'] == true;
  @override
  Widget build(BuildContext context) {
    ref.listen(familyRefreshRevisionProvider, (_, next) {
      if (!busy && (ModalRoute.of(context)?.isCurrent ?? false)) {
        load(quiet: true);
      }
    });
    ref.listen(selectedFamilyIdProvider, (_, next) {
      page = 1;
      load();
    });
    final gender = childView ? (home?['viewer_gender']) : null;
    final seed = gender == 'female'
        ? const Color(0xFFBE185D)
        : gender == 'male'
            ? const Color(0xFF1D4ED8)
            : null;
    return Theme(
        data: seed == null
            ? Theme.of(context)
            : Theme.of(context).copyWith(
                colorScheme: ColorScheme.fromSeed(
                    seedColor: seed, brightness: Theme.of(context).brightness),
                scaffoldBackgroundColor: gender == 'female'
                    ? const Color(0xFFFFF1F7)
                    : const Color(0xFFEFF6FF)),
        child: Scaffold(
            appBar: AppBar(
                title: Text(titles[widget.section] ?? 'بيتنا'),
                actions: [
                  IconButton(
                      onPressed: () => context.push('/profile'),
                      icon: const Icon(Icons.person_outline),
                      tooltip: 'حسابي وأجهزتي'),
                  IconButton(
                      onPressed: () => context.push('/notifications'),
                      icon: const Icon(Icons.notifications_outlined),
                      tooltip: 'الإشعارات'),
                  IconButton(
                      onPressed: busy ? null : () => load(),
                      icon: const Icon(Icons.refresh),
                      tooltip: 'تحديث')
                ]),
            floatingActionButton: loading || home == null
                ? null
                : widget.section == 'meals' && manager
                    ? FloatingActionButton.extended(
                        onPressed: busy ? null : createPoll,
                        icon: const Icon(Icons.restaurant),
                        label: const Text('تصويت جديد'))
                    : widget.section == 'shopping'
                        ? FloatingActionButton.extended(
                            onPressed: busy ? null : () => shoppingForm(),
                            icon: const Icon(Icons.add_shopping_cart),
                            label: Text(manager ? 'إضافة طلب' : 'اقتراح طلب'))
                        : widget.section == 'diary'
                            ? FloatingActionButton.extended(
                                onPressed: busy ? null : () => diaryForm(),
                                icon: const Icon(Icons.edit_note),
                                label: const Text('مذكرة جديدة'))
                            : widget.section == 'kind-cards'
                                ? FloatingActionButton.extended(
                                    onPressed: busy ? null : composeCard,
                                    icon: const Icon(Icons.favorite),
                                    label: const Text('أهدي كلمة حلوة'))
                                : null,
            body: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null && data == null
                    ? Center(
                        child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(error!, textAlign: TextAlign.center),
                                  TextButton(
                                      onPressed: () => load(),
                                      child: const Text('إعادة المحاولة'))
                                ])))
                    : RefreshIndicator(
                        onRefresh: load,
                        child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                            children: [
                              if (error != null)
                                Text(error!,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error)),
                              if (busy) const LinearProgressIndicator(),
                              if (widget.section == 'home') ...homeWidgets(),
                              if (widget.section == 'occasions')
                                ...occasionWidgets(),
                              if (widget.section == 'meals') ...mealWidgets(),
                              if (widget.section == 'shopping')
                                ...shoppingWidgets(),
                              if (widget.section == 'diary' ||
                                  widget.section == 'memories')
                                ...diaryWidgets(),
                              if (widget.section == 'kind-cards')
                                ...kindCardWidgets(),
                              if (widget.section == 'settings')
                                ...settingsWidgets(),
                              if (widget.section != 'home' &&
                                  widget.section != 'settings' &&
                                  widget.section != 'occasions' &&
                                  data is List &&
                                  (data as List).isNotEmpty)
                                Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      TextButton(
                                          onPressed: page > 1
                                              ? () {
                                                  page--;
                                                  load();
                                                }
                                              : null,
                                          child: const Text('السابق')),
                                      Text('$page / ${meta['last_page'] ?? 1}'),
                                      TextButton(
                                          onPressed: page <
                                                  (meta['last_page'] as int? ??
                                                      1)
                                              ? () {
                                                  page++;
                                                  load();
                                                }
                                              : null,
                                          child: const Text('التالي'))
                                    ]),
                            ]))));
  }

  Widget homeCard(Widget child) =>
      childView ? FamilyReveal(child: child) : child;
  List<Widget> homeWidgets() => [
        const ManagedContentPanel(),
        if (manager)
          Card(
              child: ListTile(
                  leading: const Icon(Icons.family_restroom_rounded),
                  title: const Text('أفراد عائلتي وأجهزتهم'),
                  subtitle: const Text(
                      'أضف أفراد الأسرة وتواريخ ميلادهم، ثم اربط الأجهزة للتتبع والأنشطة.'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => context.push('/family'))),
        if (home?['parent_titles']?['mother_title'] != null ||
            home?['parent_titles']?['father_title'] != null)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    if (home?['parent_titles']?['mother_title'] != null)
                      Text('الأم: ${home!['parent_titles']['mother_title']}'),
                    if (home?['parent_titles']?['father_title'] != null)
                      Text('الأب: ${home!['parent_titles']['father_title']}'),
                  ]))),
        FamilyHero(
            playful: childView,
            title: home?['greeting']?['text'] as String? ??
                (childView ? 'هلا ببطل بيتنا!' : 'متابعة الأسرة'),
            subtitle: childView
                ? 'عيوني وياك… نتحرك ونتعلم ونفرح سوا'
                : 'متابعة يومية واضحة لاحتياجات الأسرة وأنشطتها'),
        if (childView && home?['greeting']?['dream'] != null)
          Padding(
              padding: const EdgeInsets.all(12),
              child: Text('${home!['greeting']['dream']}',
                  style: Theme.of(context).textTheme.titleLarge)),
        if (childView)
          TextButton(
              onPressed: () => context.push('/our-home/settings'),
              child: const Text('من تكبر شنو تريد تصير؟ عدّل حلمك')),
        if (childView && home?['learning'] != null)
          ChildLearningPanel(
              key: ValueKey(
                  '${ref.watch(selectedFamilyIdProvider)}-${home!['learning']['date']}'),
              learning: Map<String, dynamic>.from(home!['learning'] as Map),
              answer: (key, choice) async {
                final familyHeaders = headers;
                final result = await ref.read(apiClientProvider).post(
                    '/family-life/learning/answer',
                    headers: familyHeaders,
                    data: {
                      'date': home!['learning']['date'],
                      'key': key,
                      'answer': choice
                    });
                await load(quiet: true);
                return Map<String, dynamic>.from(result as Map);
              }),
        if (childView && home?['learning']?['dream_step'] != null)
          Card(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('🚀 خطوة نحو حلمي',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 12),
                        Text('${home!['learning']['dream_step']['text']}',
                            style: const TextStyle(height: 1.8)),
                        Text('${home!['learning']['dream_step']['note']}',
                            style: const TextStyle(fontSize: 12)),
                        if (home!['learning']['dream_step']['completed'] ==
                            true)
                          const Text('أحسنت! خطوتك اليوم محفوظة ✓')
                        else
                          FilledButton(
                              onPressed: busy
                                  ? null
                                  : () => action(() => ref
                                          .read(apiClientProvider)
                                          .post(
                                              '/family-life/learning/dream-step',
                                              headers: headers,
                                              data: {
                                            'date': home!['learning']['date'],
                                            'key': home!['learning']
                                                ['dream_step']['key']
                                          })),
                              child: const Text('سويتها ويا أهلي')),
                      ]))),
        if (!childView) ...[
          if (ref
                  .watch(authControllerProvider)
                  .user
                  ?.permissions
                  .contains('family_tracking.view') ??
              false)
            Card(
                child: ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: const Text('التتبع والسلامة'),
                    subtitle:
                        const Text('مواقع الأسرة والتنبيهات حسب صلاحياتك'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => context.push('/family/map'))),
          Card(
              child: ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('مركز التنبيهات'),
                  subtitle: const Text('راجع الإشعارات والتحديثات'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => context.push('/notifications'))),
          if (manager)
            Card(
                child: ListTile(
                    leading: const Icon(Icons.fact_check_outlined),
                    title: const Text('اعتماد مهام الأطفال'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => context.push('/family/tasks/approvals'))),
          Card(
              child: ListTile(
                  leading: const Icon(Icons.restaurant_menu_rounded),
                  title: const Text('وجبات العائلة'),
                  subtitle: Text((home?['meal_polls_open'] ?? 0) == 0
                      ? 'ماكو تصويت مفتوح حالياً… شنو نطبخ اليوم؟'
                      : 'تصويتات الوجبات المفتوحة: ${home?['meal_polls_open']}'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => context.push('/our-home/meals'))),
          Card(
              child: ListTile(
                  leading: const Icon(Icons.shopping_basket_outlined),
                  title: const Text('احتياجات البيت'),
                  subtitle: Text((home?['shopping_pending'] ?? 0) == 0
                      ? 'قائمة البيت مرتبة… ماكو طلبات بانتظار المراجعة'
                      : 'طلبات الشراء بانتظار المراجعة: ${home?['shopping_pending']}'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => context.push('/our-home/shopping'))),
        ],
        if (manager)
          Card(
              child: ListTile(
                  leading: const Icon(Icons.insights_outlined),
                  title: const Text('تقدّم الأسرة هذا الأسبوع'),
                  subtitle: const Text('راجع إنجازات الأنشطة والنقاط'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => context.push('/family/tasks/weekly-report'))),
        if (childView) ...[
          Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: ListTile(
                  leading: const Icon(Icons.sports_gymnastics_rounded),
                  title: const Text('يلا نتحرك!'),
                  subtitle: const Text('تمارينك المنزلية وإنجازاتك'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => context.push('/exercises'))),
          Card(
              child: ListTile(
                  leading: const Icon(Icons.checklist_rounded),
                  title: const Text('مهماتي اليوم'),
                  subtitle: const Text('كل خطوة صغيرة تسوي فرق'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => context.push('/family/tasks/mine'))),
        ],
        Card(
            child: ListTile(
                leading: const Icon(Icons.alarm_rounded),
                title: const Text('مذكّري اليومي'),
                subtitle: const Text('مواعيد الدواء والتذكيرات الخاصة'),
                onTap: () => context.push('/our-home/reminders'))),
        if (home?['can_use_cycle'] == true)
          Card(
              child: ListTile(
                  leading: const Icon(Icons.calendar_month_rounded),
                  title: const Text('مساحتي الخاصة'),
                  subtitle: const Text('مواعيد دورتي'),
                  onTap: () => context.push('/our-home/mother-cycle'))),
        Card(
            child: ListTile(
                leading: const Icon(Icons.my_location),
                title: const Text('مشاركة موقع جهازي'),
                onTap: () => context.push('/our-home/location-sharing'))),
        for (final tile in [
          if (manager)
            (
              '/our-home/interests',
              'عالم اهتماماتي',
              'معلومات عن المواضيع اللي أحبها',
              Icons.explore_rounded
            ),
          (
            '/our-home/stories',
            'قصص مصوّرة',
            'نقرأ ونكتشف سوا',
            Icons.auto_stories_rounded
          ),
          (
            '/our-home/etiquette',
            'الإتيكيت وآداب التعامل',
            'تصرفات حلوة واحترام وثقة',
            Icons.handshake_outlined
          ),
          (
            '/our-home/english',
            'نتعلّم إنجليزي',
            'دروس بسيطة حسب عمري',
            Icons.translate_rounded
          ),
          (
            '/our-home/academy',
            'أكاديمية عيونك',
            'مكتبة واختبارات نتعلم بيها',
            Icons.auto_stories_rounded
          ),
          (
            '/our-home/prayer',
            'صلاتي اليوم',
            'مساحة خاصة للطمأنينة',
            Icons.mosque_rounded
          ),
          (
            '/our-home/occasions',
            'مناسباتنا',
            'يوم حلو يفرّح أهلنا',
            Icons.cake_rounded
          ),
          (
            '/our-home/diary',
            'مذكراتي وذكرياتي',
            'مساحة خاصة بيك',
            Icons.menu_book_rounded
          ),
          (
            '/our-home/memories',
            'ذكريات أسرتنا',
            'لحظات شاركناها برضانا',
            Icons.photo_library_rounded
          ),
          (
            '/our-home/kind-cards',
            'أهدي كلمة حلوة',
            'بطاقة صغيرة… ومحبة كبيرة',
            Icons.favorite_rounded
          ),
          (
            '/our-home/meals',
            'شنو نطبخ اليوم؟',
            'اختيارات نشارك بيها كلنا',
            Icons.restaurant_rounded
          ),
          (
            '/family/rewards',
            'بنك المكافآت',
            'إنجازات صغيرة وفرحة كبيرة',
            Icons.emoji_events_rounded
          ),
          (
            '/our-home/shopping',
            'احتياجات البيت',
            'كل احتياجاتنا بمكان واحد',
            Icons.shopping_basket_rounded
          ),
          (
            '/exercises',
            'رياضة اليوم',
            'تمارين إلك ولجهالك، حسب عمر كل فرد',
            Icons.sports_gymnastics_rounded
          ),
          (
            '/family/map',
            'وين أهلي؟',
            'خريطة العائلة حسب الصلاحيات',
            Icons.location_on_rounded
          ),
          (
            '/our-home/settings',
            'إعدادات بيتنا',
            'تنبيهات على راحتك',
            Icons.tune_rounded
          )
        ])
          if ((childView ||
                  !const ['/our-home/meals', '/our-home/shopping']
                      .contains(tile.$1)) &&
              (tile.$1 != '/family/map' ||
                  (ref
                          .watch(authControllerProvider)
                          .user
                          ?.permissions
                          .contains('family_tracking.view') ??
                      false)))
            homeCard(Card(
                child: ListTile(
                    leading: CircleAvatar(child: Icon(tile.$4)),
                    title: Text(tile.$2),
                    subtitle: Text(tile.$3),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => context.push(tile.$1)))),
      ];
  List<Widget> mealWidgets() => [
        FamilyHero(
            playful: childView,
            title: 'شنو نتغدى اليوم؟',
            subtitle: 'كل صوت إله قيمة… نختارها سوا'),
        if ((data as List? ?? []).isEmpty)
          const Padding(
              padding: EdgeInsets.all(24),
              child: Text('ما عدنا تصويت بعد. أول وجبة حلوة تبدأ باقتراح!')),
        for (final raw in data as List? ?? []) ...[
          FamilyReveal(
              child: Card(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(raw['question'] as String,
                                style: Theme.of(context).textTheme.titleLarge),
                            Text(raw['is_closed'] == true
                                ? 'انتهى التصويت'
                                : raw['expires_at'] == null
                                    ? 'التصويت مفتوح'
                                    : 'ينتهي ${DateTime.tryParse(raw['expires_at'] as String)?.toLocal()}'),
                            for (final o in raw['options'] as List)
                              ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(raw['my_option_id'] == o['id'] ? Icons.check_circle : Icons.radio_button_unchecked,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary),
                                  title: Text(o['name'] as String),
                                  subtitle: Text(
                                      '${o['votes']} صوت${o['status'] == 'pending' ? ' · اقتراح بانتظار الاعتماد' : ''}${(raw['winner_ids'] as List).contains(o['id']) ? ' · من الخيارات الفائزة 🌟' : ''}'),
                                  onTap: busy ||
                                          raw['is_closed'] == true ||
                                          o['status'] != 'active'
                                      ? null
                                      : () => action(() => ref
                                              .read(apiClientProvider)
                                              .put('/family-life/meal-polls/${raw['id']}/vote',
                                                  headers: headers,
                                                  data: {
                                                'option_id': o['id']
                                              })),
                                  trailing: manager &&
                                          o['status'] == 'pending' &&
                                          raw['is_closed'] != true
                                      ? TextButton(onPressed: busy ? null : () => action(() => ref.read(apiClientProvider).post('/family-life/meal-polls/${raw['id']}/options/${o['id']}/approve', headers: headers)), child: const Text('اعتماد'))
                                      : null),
                            if (raw['is_closed'] != true)
                              Wrap(children: [
                                TextButton.icon(
                                    onPressed: () => form('اقتراح أكلة', const [
                                          LifeField('name', 'اسم الأكلة',
                                              required: true)
                                        ], (d) async {
                                          await ref.read(apiClientProvider).post(
                                              '/family-life/meal-polls/${raw['id']}/options',
                                              headers: headers,
                                              data: d);
                                        }),
                                    icon: const Icon(Icons.add),
                                    label: const Text('أقترح أكلة')),
                                if (manager)
                                  TextButton(
                                      onPressed: busy
                                          ? null
                                          : () => action(() => ref
                                              .read(apiClientProvider)
                                              .post(
                                                  '/family-life/meal-polls/${raw['id']}/close',
                                                  headers: headers)),
                                      child: const Text('إنهاء التصويت'))
                              ]),
                          ])))),
        ],
      ];
  Future<void> createPoll() => form('نسوي تصويت للوجبة', const [
        LifeField('question', 'السؤال',
            initial: 'حبايبي شنو تحبون نتغدى؟', required: true),
        LifeField('meal_type', 'الوجبة',
            initial: 'lunch', choices: {'lunch': 'الغداء', 'dinner': 'العشاء'}),
        LifeField('options_text', 'كل أكلة بسطر', required: true, lines: 4),
        LifeField('expires_at', 'موعد انتهاء التصويت (اختياري)',
            kind: 'datetime')
      ], (d) async {
        final options = (d.remove('options_text') as String)
            .split('\n')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        d['options'] = options;
        if (d['expires_at'] == '') d.remove('expires_at');
        await ref
            .read(apiClientProvider)
            .post('/family-life/meal-polls', headers: headers, data: d);
      });
  static const categories = {
    'food': 'غذائية',
    'home': 'منزلية',
    'school': 'مدرسية',
    'other': 'أخرى'
  };
  static const priorities = {
    'low': 'منخفضة',
    'normal': 'عادية',
    'high': 'مهمة'
  };
  static const statuses = {
    'pending': 'بانتظار الاعتماد',
    'approved': 'جاهز للشراء',
    'completed': 'تم شراؤه',
    'rejected': 'غير معتمد'
  };
  Future<void> shoppingForm([Map<String, dynamic>? item]) =>
      form(item == null ? 'احتياج جديد' : 'تعديل الطلب', [
        LifeField('name', 'شنو نحتاج؟',
            initial: item?['name'] ?? '', required: true),
        LifeField('quantity', 'الكمية',
            initial: item?['quantity'] ?? '1', required: true),
        LifeField('category', 'التصنيف',
            initial: item?['category'] ?? 'food', choices: categories),
        LifeField('priority', 'الأولوية',
            initial: item?['priority'] ?? 'normal', choices: priorities),
        LifeField('notes', 'ملاحظات', initial: item?['notes'] ?? '', lines: 2),
      ], (d) async {
        final client = ref.read(apiClientProvider);
        if (item == null) {
          await client.post('/family-life/shopping', headers: headers, data: d);
        } else {
          await client.put('/family-life/shopping/${item['id']}',
              headers: headers, data: d);
        }
      });
  Future<void> quickShopping(String name) => form('إضافة $name', [
        const LifeField('quantity', 'الكمية', initial: '1', required: true),
      ], (d) async {
        await ref
            .read(apiClientProvider)
            .post('/family-life/shopping', headers: headers, data: {
          'name': name,
          'quantity': d['quantity'],
          'category': name == 'كلينكس' ? 'other' : 'food',
          'priority': 'normal'
        });
      });
  List<Widget> shoppingWidgets() => [
        const Text('نحتاجها دائماً',
            style: TextStyle(fontWeight: FontWeight.bold)),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final name in [
            'صمون',
            'حليب',
            'بيض',
            'طماطة',
            'معجون',
            'كلينكس'
          ])
            ActionChip(
                label: Text(name),
                avatar: const Icon(Icons.add_shopping_cart, size: 18),
                onPressed: busy ? null : () => quickShopping(name))
        ]),
        FamilyHero(
            playful: childView,
            title: 'نتعاون على بيتنا',
            subtitle: 'ضيفوا احتياجاتكم… واللي يروح للسوق يلكاها جاهزة'),
        DropdownButtonFormField<String>(
            initialValue: status,
            decoration: const InputDecoration(labelText: 'عرض الطلبات'),
            items: [
              const DropdownMenuItem(value: '', child: Text('كل الطلبات')),
              for (final e in statuses.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value))
            ],
            onChanged: (v) {
              status = v ?? '';
              page = 1;
              load();
            }),
        if ((data as List? ?? []).isEmpty)
          const Padding(
              padding: EdgeInsets.all(24),
              child: Text('قائمة البيت مرتبة… ماكو طلبات هنا بعد.')),
        for (final raw in data as List? ?? [])
          FamilyReveal(
              child: Card(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${raw['name']} · ${raw['quantity']}',
                                style: Theme.of(context).textTheme.titleMedium),
                            Text(
                                '${categories[raw['category']]} · ${priorities[raw['priority']]} · ${statuses[raw['status']]}'),
                            if (raw['notes'] != null)
                              Text(raw['notes'] as String),
                            if (manager)
                              Wrap(spacing: 4, children: [
                                if (raw['status'] == 'pending') ...[
                                  TextButton(
                                      onPressed: busy
                                          ? null
                                          : () => decide(
                                              raw['id'] as int, 'approved'),
                                      child: const Text('اعتماد')),
                                  TextButton(
                                      onPressed: busy
                                          ? null
                                          : () => decide(
                                              raw['id'] as int, 'rejected'),
                                      child: const Text('رفض'))
                                ],
                                if (raw['status'] == 'approved')
                                  FilledButton.icon(
                                      onPressed: busy
                                          ? null
                                          : () => decide(
                                              raw['id'] as int, 'completed'),
                                      icon: const Icon(Icons.check),
                                      label: const Text('اشتريناه')),
                                if (raw['status'] != 'completed')
                                  TextButton(
                                      onPressed: busy
                                          ? null
                                          : () => shoppingForm(
                                              Map<String, dynamic>.from(
                                                  raw as Map)),
                                      child: const Text('تعديل')),
                              ]),
                          ])))),
      ];
  Future<void> decide(int id, String status) => action(() => ref
      .read(apiClientProvider)
      .post('/family-life/shopping/$id/decide',
          headers: headers, data: {'status': status}));
  List<Widget> settingsWidgets() {
    final prefs = Map<String, dynamic>.from(data as Map? ?? {});
    final selected =
        Map<String, dynamic>.from(prefs['categories'] as Map? ?? {});
    return [
      Card(
          child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('حسابي وأجهزتي'),
              subtitle:
                  const Text('بيانات الحساب، الأجهزة النشطة وتسجيل الخروج'),
              onTap: () => context.push('/profile'))),
      if (manager)
        Card(
            child: ListTile(
                leading: const Icon(Icons.family_restroom_rounded),
                title: const Text('إدارة أفراد عائلتي'),
                subtitle:
                    const Text('إضافة أفراد الأسرة وربط الحسابات والأجهزة'),
                onTap: () => context.push('/family'))),
      Card(
          child: ListTile(
              leading: Icon(Icons.person_remove_outlined,
                  color: Theme.of(context).colorScheme.error),
              title: const Text('حذف الحساب وبياناتي'),
              subtitle: const Text(
                  'فتح طلب الحذف ومتابعته، مع حماية بيانات بقية العائلة'),
              onTap: () => context.push('/profile/account-deletion'))),
      ParentTitlesPanel(onSaved: () => load()),
      Text('حلم المستقبل والعمر',
          style: Theme.of(context).textTheme.titleLarge),
      const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
              'مثال: طيّار، طبيبة، مهندس. لقب المستقبل يظهر لحد عمر ١٥ سنة فقط. تاريخ الميلاد يحدد تحديات التفكير.')),
      if (childProfiles.isEmpty)
        const Padding(
            padding: EdgeInsets.all(12),
            child:
                Text('أكملوا ملف الطفل واربطوه بحسابه من إدارة الأسرة أولاً.')),
      for (final p in childProfiles)
        Card(
            child: ListTile(
                title: Text('${p['name']}'),
                subtitle: Text(
                    '${p['dream_title'] ?? 'من تكبر شنو تريد تصير؟'} · العمر: ${p['age'] ?? 'غير مسجّل'}'),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => form('حلم المستقبل واهتماماتي', [
                      for (final item in const {
                        'drawing': 'الرسم',
                        'reading': 'القراءة',
                        'music': 'الموسيقى والإيقاع',
                        'building': 'التركيب والتصميم',
                        'sports': 'الحركة',
                        'science': 'الاستكشاف'
                      }.entries)
                        LifeField('interest_${item.key}', item.value,
                            initial: (p['interests'] as List? ?? [])
                                .contains(item.key),
                            kind: 'bool'),
                      LifeField('dream_title', 'من تكبر شنو تريد تصير؟',
                          initial: p['dream_title'] ?? ''),
                      LifeField('show_dream', 'إظهار لقب المستقبل',
                          initial: p['show_dream'] == true, kind: 'bool'),
                      if (manager)
                        LifeField('birth_date', 'تاريخ الميلاد (YYYY-MM-DD)',
                            initial: p['birth_date'] ?? ''),
                    ], (d) async {
                      d['interests'] = [
                        for (final key in const [
                          'drawing',
                          'reading',
                          'music',
                          'building',
                          'sports',
                          'science'
                        ])
                          if (d.remove('interest_$key') == true) key,
                      ];
                      if (d['birth_date'] == '') d['birth_date'] = null;
                      await ref.read(apiClientProvider).put(
                          '/family-life/child-profiles/${p['id']}',
                          headers: headers,
                          data: d);
                    }))),
      const NotificationPermissionCard(),
      SwitchListTile(
          title: const Text('إشعارات الهاتف'),
          subtitle: Text(prefs['push_available'] == true
              ? 'تنبيه عام من عيونك، وتفاصيلك تبقى داخل التطبيق'
              : 'الإرسال للهاتف قيد التجهيز؛ التنبيهات داخل التطبيق متاحة'),
          value:
              prefs['push_available'] == true && prefs['push_enabled'] == true,
          onChanged: busy || prefs['push_available'] != true
              ? null
              : (v) =>
                  action(() => ref.read(fcmPushServiceProvider).setEnabled(v))),
      if (manager)
        Card(
            child: ListTile(
                title: const Text('توقيت الأسرة وحد النقاط'),
                subtitle: Text(
                    '${home?['family']['timezone']} · الحد اليومي: ${home?['family']['daily_points_cap'] ?? 'بلا حد'}'),
                trailing: const Icon(Icons.edit),
                onTap: () => form('إعدادات الأسرة', [
                      LifeField('timezone', 'المنطقة الزمنية',
                          initial:
                              home?['family']['timezone'] ?? 'Asia/Baghdad',
                          required: true),
                      LifeField(
                          'daily_points_cap', 'أقصى نقاط يومياً (فارغ بلا حد)',
                          initial: home?['family']['daily_points_cap'] ?? '',
                          kind: 'number'),
                      LifeField('academy_points_enabled',
                          'السماح بنقاط الاختبارات التعليمية',
                          initial:
                              home?['family']['academy_points_enabled'] == true,
                          kind: 'bool')
                    ], (d) async {
                      d['daily_points_cap'] = '${d['daily_points_cap']}'.isEmpty
                          ? null
                          : int.tryParse('${d['daily_points_cap']}');
                      await ref.read(apiClientProvider).put(
                          '/family-life/settings',
                          headers: headers,
                          data: d);
                    }))),
      Text('إشعاراتك على راحتك', style: Theme.of(context).textTheme.titleLarge),
      for (final entry in const {
        'safety': 'تنبيهات سلامة الأسرة',
        'birthday': 'مناسبات الأسرة',
        'kind_card': 'الكلمات الحلوة',
        'meal_poll': 'تصويت الوجبات',
        'task': 'المهام',
        'reward': 'المكافآت',
        'shopping': 'احتياجات البيت',
        'prayer': 'الصلاة',
        'academy': 'الأكاديمية',
        'kind_prompt': 'اقتراح كلمة حلوة'
      }.entries)
        SwitchListTile(
            title: Text(entry.value),
            value: selected[entry.key] != false,
            onChanged: busy
                ? null
                : (v) => action(() => ref
                        .read(apiClientProvider)
                        .put('/notification-preferences', data: {
                      'categories': {entry.key: v}
                    }))),
      SwitchListTile(
          title: const Text('إخفاء تفاصيل إشعارات شاشة القفل'),
          value: prefs['hide_lock_screen_content'] != false,
          onChanged: busy
              ? null
              : (v) => action(() => ref.read(apiClientProvider).put(
                  '/notification-preferences',
                  data: {'hide_lock_screen_content': v}))),
    ];
  }

  Future<bool> confirm(String title, String body) async =>
      await showDialog<bool>(
          context: context,
          builder: (c) =>
              AlertDialog(title: Text(title), content: Text(body), actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('إلغاء')),
                FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('موافق'))
              ])) ??
      false;
  Future<void> diaryForm([Map<String, dynamic>? entry]) =>
      form(entry == null ? 'مذكرة جديدة' : 'تعديل مذكرتي', [
        LifeField('title', 'عنوان الذكرى',
            initial: entry?['title'] ?? '', required: true),
        LifeField('entry_date', 'التاريخ YYYY-MM-DD',
            initial: entry?['entry_date'] ??
                DateTime.now().toIso8601String().split('T').first,
            required: true),
        LifeField('body', 'اكتب اللي بخاطرك',
            initial: entry?['body'] ?? '', required: true, lines: 6),
        LifeField('mood', 'مزاجي اليوم',
            initial: entry?['mood'] ?? 'calm',
            choices: const {
              'happy': 'فرحان',
              'calm': 'هادئ',
              'sad': 'حزين',
              'tired': 'تعبان',
              'grateful': 'ممتن',
              'anxious': 'قلقان'
            }),
      ], (d) async {
        final client = ref.read(apiClientProvider);
        if (entry == null) {
          await client.post('/personal/diary', data: d);
        } else {
          await client.put('/personal/diary/${entry['id']}', data: d);
        }
      });
  Future<void> uploadDiary(int id, bool voice) async {
    String? path;
    if (voice) {
      path = await showDialog<String>(
          context: context, builder: (_) => const DiaryRecorderDialog());
    } else {
      path = (await ImagePicker().pickImage(
              source: ImageSource.gallery,
              maxWidth: 1800,
              maxHeight: 1800,
              imageQuality: 85))
          ?.path;
    }
    if (path == null) return;
    final selectedPath = path;
    try {
      await action(() => ref.read(apiClientProvider).postMultipart(
          '/personal/diary/$id/attachments',
          FormData.fromMap(
              {'file': MultipartFile.fromFileSync(selectedPath)})));
    } finally {
      if (voice) {
        final temporary = File(selectedPath);
        if (await temporary.exists()) await temporary.delete();
      }
    }
  }

  List<Widget> diaryWidgets() => [
        FamilyHero(
            playful: childView,
            title: widget.section == 'diary'
                ? 'حكايتك إلها مكان'
                : 'لحظات تبقى بالقلب',
            subtitle: widget.section == 'diary'
                ? 'مذكراتك خاصة بيك. المشاركة تصير فقط إذا تختارها.'
                : 'ذكريات شاركها أصحابها مع الأسرة'),
        if (widget.section == 'diary')
          TextField(
              decoration: const InputDecoration(
                  labelText: 'ابحث في مذكراتك', prefixIcon: Icon(Icons.search)),
              onSubmitted: (v) {
                search = v;
                page = 1;
                load();
              }),
        SwitchListTile(
            title: const Text('في مثل هذا اليوم'),
            value: onThisDay,
            onChanged: (v) {
              onThisDay = v;
              page = 1;
              load();
            }),
        if ((data as List? ?? []).isEmpty)
          Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                Text(widget.section == 'memories'
                    ? 'ماكو ذكريات مشتركة بعد. اكتب ذكرى بمذكراتك، وشارك فقط اللي تحب تظهره للأسرة.'
                    : 'ماكو مذكرات مطابقة. اكتب أول ذكرى من زر مذكرة جديدة.'),
                if (widget.section == 'memories')
                  TextButton.icon(
                      onPressed: () => context.push('/our-home/diary'),
                      icon: const Icon(Icons.edit_note),
                      label: const Text('افتح مذكراتي'))
              ])),
        for (final raw in data as List? ?? [])
          FamilyReveal(
              child: Card(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(raw['title'] as String,
                                style: Theme.of(context).textTheme.titleLarge),
                            Text(
                                '${raw['entry_date']}${raw['author'] != null ? ' · ${raw['author']['name']}' : ''}'),
                            const SizedBox(height: 8),
                            Text(raw['body'] as String),
                            if (widget.section == 'diary')
                              Chip(
                                  label: Text(raw['shared_at'] == null
                                      ? 'خاصة بي'
                                      : 'مشتركة مع الأسرة')),
                            for (final media
                                in raw['attachments'] as List? ?? [])
                              media['kind'] == 'image'
                                  ? PrivateDiaryImage(
                                      key: ValueKey('image-${media['id']}'),
                                      url: media['url'] as String)
                                  : PrivateDiaryAudio(
                                      key: ValueKey('audio-${media['id']}'),
                                      url: media['url'] as String),
                            if (widget.section == 'diary')
                              Wrap(spacing: 4, children: [
                                TextButton(
                                    onPressed: busy
                                        ? null
                                        : () => diaryForm(
                                            Map<String, dynamic>.from(
                                                raw as Map)),
                                    child: const Text('تعديل')),
                                TextButton.icon(
                                    onPressed: busy
                                        ? null
                                        : () => uploadDiary(
                                            raw['id'] as int, false),
                                    icon: const Icon(Icons.add_photo_alternate),
                                    label: const Text('صورة')),
                                TextButton.icon(
                                    onPressed: busy
                                        ? null
                                        : () =>
                                            uploadDiary(raw['id'] as int, true),
                                    icon: const Icon(Icons.mic),
                                    label: const Text('تسجيل صوتي')),
                                TextButton(
                                    onPressed: busy
                                        ? null
                                        : () async {
                                            if (raw['shared_at'] != null) {
                                              await action(() => ref
                                                  .read(apiClientProvider)
                                                  .post(
                                                      '/personal/diary/${raw['id']}/unshare'));
                                            } else if (await confirm(
                                                'مشاركة هذه الذكرى؟',
                                                'كل أعضاء الأسرة المحددة يگدرون يقرون هذه المذكرة ويشوفون مرفقاتها. باقي مذكراتك تبقى خاصة.')) {
                                              await action(() => ref
                                                  .read(apiClientProvider)
                                                  .post(
                                                      '/family-life/diary/${raw['id']}/share',
                                                      headers: headers,
                                                      data: {'confirm': true}));
                                            }
                                          },
                                    child: Text(raw['shared_at'] == null
                                        ? 'أشارك مع أسرتي'
                                        : 'إلغاء المشاركة')),
                                TextButton(
                                    onPressed: busy
                                        ? null
                                        : () async {
                                            if (await confirm('حذف المذكرة؟',
                                                'ستختفي هذه المذكرة ومرفقاتها من العرض.')) {
                                              await action(() => ref
                                                  .read(apiClientProvider)
                                                  .delete(
                                                      '/personal/diary/${raw['id']}'));
                                            }
                                          },
                                    child: const Text('حذف')),
                              ]),
                          ])))),
      ];
  Future<void> composeCard() async {
    try {
      final raw = await ref
          .read(apiClientProvider)
          .get('/family-life/kind-templates', headers: headers);
      if (!mounted) return;
      final templates = (raw as List).cast<Map<String, dynamic>>();
      final chosen = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (c) =>
              SimpleDialog(title: const Text('اختار كلمة من القلب'), children: [
                SimpleDialogOption(
                    onPressed: () => Navigator.pop(c, <String, dynamic>{
                          'body': '',
                          'category': 'custom',
                          'style': 'mint'
                        }),
                    child: const Text('أكتب كلمتي الخاصة')),
                for (final t in templates)
                  SimpleDialogOption(
                      onPressed: () => Navigator.pop(c, t),
                      child: Text(t['title'] as String))
              ]));
      if (chosen == null || !mounted) return;
      final userId = ref.read(authControllerProvider).user?.id;
      final recipients = {
        for (final p in home?['recipients'] as List? ?? [])
          if (p['user_id'] != userId) '${p['user_id']}': '${p['name']}'
      };
      if (recipients.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('اربط حساب فرد آخر من أسرتك حتى تهديه بطاقة.')));
        return;
      }
      await form('أهدي كلمة حلوة', [
        LifeField('recipient_user_id', 'إلى من؟',
            initial: recipients.keys.first, choices: recipients),
        LifeField('body', 'كلمتك',
            initial: chosen['body'], required: true, lines: 4),
        LifeField('category', 'نوع الكلمة',
            initial: chosen['category'],
            choices: const {
              'gratitude': 'شكر ومحبة',
              'apology': 'اعتذار',
              'encouragement': 'تشجيع',
              'custom': 'كلمة خاصة'
            }),
        LifeField('style', 'شكل البطاقة',
            initial: chosen['style'],
            choices: const {'mint': 'نعناعي', 'rose': 'وردي', 'sky': 'سماوي'}),
      ], (d) async {
        d['recipient_user_id'] = int.parse(d['recipient_user_id'] as String);
        await ref
            .read(apiClientProvider)
            .post('/family-life/kind-cards', headers: headers, data: d);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(lifeError(e))));
      }
    }
  }

  List<Widget> kindCardWidgets() => [
        FamilyHero(
            playful: childView,
            title: 'كلمة حلوة… تغيّر يوم',
            subtitle: 'شكر، اعتذار، أو تشجيع… بطاقة محبة بدون محادثات'),
        SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'received', label: Text('وصلتني')),
              ButtonSegment(value: 'saved', label: Text('محفوظة')),
              ButtonSegment(value: 'sent', label: Text('أهديتها'))
            ],
            selected: {
              cardBox
            },
            onSelectionChanged: (v) {
              cardBox = v.first;
              page = 1;
              load();
            }),
        if ((data as List? ?? []).isEmpty)
          const Padding(
              padding: EdgeInsets.all(24),
              child: Text('ماكو بطاقات هنا بعد. أهدي أول كلمة حلوة!')),
        for (final raw in data as List? ?? [])
          FamilyReveal(
              child: Card(
                  color: raw['style'] == 'rose'
                      ? const Color(0xFFFFEDF1)
                      : raw['style'] == 'sky'
                          ? const Color(0xFFEAF5FF)
                          : const Color(0xFFECF8EF),
                  child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'من ${raw['sender']?['name'] ?? ''} إلى ${raw['recipient']?['name'] ?? ''}',
                                style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 12),
                            Text(raw['body'] as String,
                                style: Theme.of(context).textTheme.titleMedium),
                            if (cardBox != 'sent')
                              Wrap(children: [
                                TextButton.icon(
                                    onPressed: busy
                                        ? null
                                        : () => action(() => ref
                                                .read(apiClientProvider)
                                                .put(
                                                    '/family-life/kind-cards/${raw['id']}/saved',
                                                    headers: headers,
                                                    data: {
                                                  'saved':
                                                      raw['saved_at'] == null
                                                })),
                                    icon: Icon(raw['saved_at'] == null
                                        ? Icons.bookmark_border
                                        : Icons.bookmark),
                                    label: const Text('حفظ')),
                                TextButton(
                                    onPressed: busy
                                        ? null
                                        : () => form(
                                                'الإبلاغ عن البطاقة', const [
                                              LifeField('reason', 'سبب البلاغ',
                                                  required: true, lines: 3)
                                            ], (d) async {
                                              await ref
                                                  .read(apiClientProvider)
                                                  .post(
                                                      '/family-life/kind-cards/${raw['id']}/report',
                                                      headers: headers,
                                                      data: d);
                                            }),
                                    child: const Text('إبلاغ')),
                                TextButton(
                                    onPressed: busy
                                        ? null
                                        : () async {
                                            if (await confirm('حذف البطاقة؟',
                                                'راح تختفي البطاقة من صندوقك.')) {
                                              await action(() => ref
                                                  .read(apiClientProvider)
                                                  .delete(
                                                      '/family-life/kind-cards/${raw['id']}',
                                                      headers: headers));
                                            }
                                          },
                                    child: const Text('حذف')),
                              ]),
                          ])))),
      ];

  List<Widget> occasionWidgets() {
    final d = data as Map? ?? {};
    return [
      Card(
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                  'نذكّركم قبل المناسبة بيوم ويومها فقط، بعد ٩ صباحاً بتوقيت ${d['timezone']}. تگدر توقف تنبيهات المناسبات من إعداداتك.'))),
      const Text('مواليد ٢٩ شباط نحتفل بيهم ٢٨ شباط بالسنة غير الكبيسة.'),
      for (final m in d['birthdays'] as List? ?? [])
        Card(
            child: ListTile(
                leading: const Icon(Icons.cake_rounded),
                title: Text(m['full_name'] as String),
                subtitle: Text((m['birth_date'] as String).substring(5, 10)))),
      if (d['anniversary_date'] != null)
        Card(
            child: ListTile(
                leading: const Icon(Icons.favorite),
                title: Text(d['anniversary_label'] as String? ?? 'ذكرى زواج'),
                subtitle:
                    Text((d['anniversary_date'] as String).substring(5, 10)))),
      if (manager)
        FilledButton(
            onPressed: busy
                ? null
                : () => form('مناسبة أسرتنا', [
                      LifeField('anniversary_date',
                          'التاريخ YYYY-MM-DD (فارغ للإلغاء)',
                          initial: (d['anniversary_date'] as String?)
                                  ?.substring(0, 10) ??
                              ''),
                      LifeField('anniversary_label', 'اسم المناسبة',
                          initial:
                              d['anniversary_label'] as String? ?? 'ذكرى زواج')
                    ], (v) async {
                      await ref.read(apiClientProvider).put(
                          '/family-life/occasions',
                          headers: headers,
                          data: {
                            ...v,
                            'anniversary_date': v['anniversary_date'] == ''
                                ? null
                                : v['anniversary_date']
                          });
                    }),
            child: const Text('إعداد المناسبة الاختيارية')),
      const Text('تواريخ الميلاد تنضاف من ملف الفرد بمركز العائلة.'),
    ];
  }
}
