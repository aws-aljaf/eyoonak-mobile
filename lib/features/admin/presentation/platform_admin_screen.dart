import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_exception.dart';

class PlatformAdminScreen extends ConsumerStatefulWidget {
  const PlatformAdminScreen({super.key});
  @override
  ConsumerState<PlatformAdminScreen> createState() => _PlatformAdminScreenState();
}

class _PlatformAdminScreenState extends ConsumerState<PlatformAdminScreen> {
  static const sections = {
    'overview': 'نظرة عامة',
    'families': 'العوائل',
    'accounts': 'الحسابات',
    'companies': 'الشركات',
    'health': 'التشغيل',
    'audit': 'سجل الإدارة'
  };
  static const metrics = {
    'families': 'العوائل',
    'families_active': 'عوائل نشطة',
    'families_suspended': 'عوائل موقوفة',
    'members': 'ملفات الأفراد',
    'accounts': 'الحسابات',
    'articles': 'مواد منشورة',
    'fact_bank': 'معلومات بالبنك'
  };
  String section = 'overview', search = '';
  int page = 1, last = 1, generation = 0;
  bool loading = true, busy = false;
  String? error;
  Map<String, dynamic> data = {};
  List<dynamic> rows = [];
  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  @override
  void dispose() {
    generation++;
    super.dispose();
  }

  String message(Object e) => e is ApiException ? e.message : 'تعذر إتمام العملية. حاول مرة أخرى.';
  Future<void> load() async {
    if (!mounted) return;
    final current = ++generation, selected = section;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final path = selected == 'overview'
          ? '/admin/platform/overview'
          : selected == 'health'
              ? '/admin/system-health'
              : selected == 'companies'
                  ? '/admin/companies'
                  : '/admin/platform/$selected';
      if (['overview', 'health'].contains(selected)) {
        final result = await api.get(path);
        if (mounted && current == generation) setState(() => data = Map<String, dynamic>.from(result as Map));
      } else {
        final result = await api.getPaginated(path, query: {'page': page, if (search.isNotEmpty) 'q': search});
        if (mounted && current == generation) {
          setState(() {
            rows = result.data;
            last = (result.meta['last_page'] as num?)?.toInt() ?? 1;
          });
        }
      }
    } catch (e) {
      if (mounted && current == generation) setState(() => error = message(e));
    } finally {
      if (mounted && current == generation) setState(() => loading = false);
    }
  }

  String rowName(Map<String, dynamic> row) {
    final arabic = (row['name_ar'] as String?)?.trim();
    return arabic != null && arabic.isNotEmpty
        ? arabic
        : (row['name'] ?? row['action'] ?? 'سجل #${row['id']}').toString();
  }

  Future<void> changeStatus(Map<String, dynamic> row) async {
    final targetSection = section;
    final status = row['status'] == 'suspended' ? 'active' : 'suspended';
    String reason = '';
    final value = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
                title: Text(status == 'active' ? 'إعادة تفعيل' : 'إيقاف مؤقت'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(rowName(row)),
                  const SizedBox(height: 12),
                  TextField(
                      onChanged: (value) => reason = value,
                      maxLength: 500,
                      decoration: const InputDecoration(labelText: 'سبب الإجراء (٥ أحرف على الأقل)'))
                ]),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
                  FilledButton(
                      onPressed: () {
                        if (reason.trim().length >= 5) Navigator.pop(dialogContext, reason.trim());
                      },
                      child: const Text('تأكيد'))
                ]));
    if (value == null || !mounted) return;
    setState(() => busy = true);
    try {
      final api = ref.read(apiClientProvider);
      if (targetSection == 'companies') {
        await api.post('/admin/companies/${row['id']}/${status == 'active' ? 'activate' : 'suspend'}',
            data: {'reason': value});
      } else {
        await api.put('/admin/platform/$targetSection/${row['id']}/status', data: {'status': status, 'reason': value});
      }
      await load();
    } catch (e) {
      if (mounted) setState(() => error = message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('إدارة عيونك'), actions: [
        IconButton(tooltip: 'تحديث', onPressed: busy ? null : load, icon: const Icon(Icons.refresh)),
        IconButton(
            tooltip: 'تسجيل الخروج',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout))
      ]),
      body: Column(children: [
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              for (final entry in sections.entries)
                Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                        label: Text(entry.value),
                        selected: section == entry.key,
                        onSelected: busy
                            ? null
                            : (_) {
                                setState(() {
                                  section = entry.key;
                                  page = 1;
                                  search = '';
                                  rows = [];
                                  data = {};
                                });
                                load();
                              }))
            ])),
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Padding(
              padding: const EdgeInsets.all(12),
              child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        if (['families', 'accounts', 'companies'].contains(section))
          Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                  key: ValueKey(section),
                  decoration: const InputDecoration(labelText: 'بحث بالاسم', suffixIcon: Icon(Icons.search)),
                  onSubmitted: (value) {
                    search = value;
                    page = 1;
                    load();
                  })),
        Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: load,
                    child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (section == 'overview') ...[
                            for (final entry in metrics.entries)
                              Card(
                                  child: ListTile(
                                      title: Text(entry.value),
                                      trailing: Text('${data[entry.key] ?? '—'}',
                                          style: Theme.of(context).textTheme.titleLarge))),
                            Card(
                                child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(data['push_available'] == true
                                        ? 'إرسال الهاتف مفعّل في إعدادات السيرفر؛ يحتاج تجربة تسليم على جهاز.'
                                        : 'إرسال إشعارات الهاتف غير مفعّل بعد.'))),
                            const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                    'إدارة المقالات وبنك المعلومات والتمارين متاحة في لوحة الويب. إحصاءات المنصة لا تعرض المذكرات الخاصة أو المواقع الحية.'))
                          ],
                          if (section == 'health')
                            Card(
                                child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                        'قاعدة البيانات: ${data['database']?['connected'] == true ? 'متصلة' : 'غير متصلة'}\nالطابور: ${data['queue']?['driver']}\nPHP: ${data['php_version']}\nLaravel: ${data['laravel_version']}\nهذا فحص اتصال وإعدادات، وليس اختبار تسليم إشعار.'))),
                          if (!['overview', 'health'].contains(section)) ...[
                            if (rows.isEmpty)
                              const Padding(padding: EdgeInsets.all(20), child: Text('لا توجد سجلات مطابقة.')),
                            for (final raw in rows) rowCard(Map<String, dynamic>.from(raw as Map)),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              TextButton(
                                  onPressed: busy || page <= 1
                                      ? null
                                      : () {
                                          page--;
                                          load();
                                        },
                                  child: const Text('السابق')),
                              Text('$page / $last'),
                              TextButton(
                                  onPressed: busy || page >= last
                                      ? null
                                      : () {
                                          page++;
                                          load();
                                        },
                                  child: const Text('التالي'))
                            ])
                          ]
                        ])))
      ]));
  Widget rowCard(Map<String, dynamic> row) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(rowName(row), style: Theme.of(context).textTheme.titleMedium),
            if (section != 'audit')
              Text(row['status'] == 'active'
                  ? 'نشط'
                  : row['status'] == 'suspended'
                      ? 'موقوف'
                      : '${row['status']}'),
            if (section == 'families') Text('${row['members_count']} ملف فرد · ${row['relationships_count']} حساب نشط'),
            if (section == 'accounts')
              Text(row['is_super_admin'] == true ? 'أدمن رئيسي' : '${row['email'] ?? 'حساب عائلي'}'),
            if (section == 'audit') Text('المنفذ #${row['user_id']} · ${row['created_at']}'),
            if (['families', 'accounts', 'companies'].contains(section) && row['is_super_admin'] != true)
              TextButton(
                  onPressed: busy ? null : () => changeStatus(row),
                  child: Text(row['status'] == 'suspended' ? 'إعادة تفعيل' : 'إيقاف مؤقت'))
          ])));
}
