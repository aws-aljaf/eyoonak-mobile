import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_exception.dart';

class AccountDeletionScreen extends ConsumerStatefulWidget {
  const AccountDeletionScreen({super.key});
  @override
  ConsumerState<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}
class _AccountDeletionScreenState extends ConsumerState<AccountDeletionScreen> {
  final password = TextEditingController();
  final form = GlobalKey<FormState>();
  bool confirmed = false, busy = false, loading = true, loadFailed = false;
  bool deleteFamilies = false, confirmFamilies = false;
  Map<String, dynamic>? request;
  List<dynamic> families = [];
  String? error, warning;
  @override
  void initState() { super.initState(); Future.microtask(load); }
  @override
  void dispose() { password.dispose(); super.dispose(); }
  String message(Object e) => e is ApiException
      ? (e.fieldErrors.isEmpty ? e.message : e.fieldErrors.values.expand((v) => v).join(' '))
      : 'تعذر الاتصال. حاول مجدداً.';
  Future<void> load() async {
    if (!mounted) return;
    setState(() { loading = true; loadFailed = false; error = null; });
    try {
      final data = await ref.read(apiClientProvider).get('/auth/account-deletion-request') as Map;
      if (!mounted) return;
      setState(() {
        request = data['request'] == null ? null : Map<String, dynamic>.from(data['request'] as Map);
        families = data['owned_families'] as List? ?? [];
        warning = data['eligibility_warning'] as String?;
        deleteFamilies = false; confirmFamilies = false; confirmed = false;
      });
      if (request != null) password.clear();
    } catch (e) {
      if (mounted) setState(() { error = message(e); loadFailed = true; });
    } finally { if (mounted) setState(() => loading = false); }
  }
  Future<void> submit() async {
    if (!confirmed || busy || !(form.currentState?.validate() ?? false)) return;
    if (deleteFamilies && !confirmFamilies) return;
    setState(() { busy = true; error = null; });
    try {
      final data = await ref.read(apiClientProvider).post('/auth/account-deletion-request', data: {
        'password': password.text, 'confirmed': true,
        'delete_owned_families': deleteFamilies,
        if (deleteFamilies) 'family_deletion_confirmed': confirmFamilies,
      }) as Map;
      password.clear();
      if (mounted) setState(() => request = Map<String, dynamic>.from(data['request'] as Map));
    } catch (e) { if (mounted) setState(() => error = message(e)); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> cancel() async {
    final accepted = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('إلغاء طلب الحذف؟'),
      content: const Text('يبقى حسابك وبياناتك كما هي، وتُلغى مراجعة طلب الحذف الحالي.'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('رجوع')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('إلغاء الطلب'))],
    ));
    if (accepted != true || !mounted) return;
    setState(() { busy = true; error = null; });
    try {
      await ref.read(apiClientProvider).delete('/auth/account-deletion-request');
      if (mounted) setState(() { request = null; confirmed = false; deleteFamilies = false; confirmFamilies = false; });
    } catch (e) { if (mounted) setState(() => error = message(e)); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> transfer(Map family) async {
    final result = await showDialog<Map<String, dynamic>>(context: context,
      builder: (_) => _TransferFamilyDialog(family: family));
    if (result == null || !mounted) return;
    setState(() { busy = true; error = null; });
    try {
      await ref.read(apiClientProvider).post('/auth/account-deletion-request/transfer-family',
        data: {...result, 'family_id': family['id'], 'confirmed': true});
      await load();
    } catch (e) { if (mounted) setState(() => error = message(e)); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('حذف الحساب وبياناتي')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('إرسال الطلب لا يحذف الحساب فوراً. تراجع الإدارة ملكية الحساب والبيانات المشتركة قبل التنفيذ النهائي.'),
      const SizedBox(height: 16),
      const SelectableText('للمتابعة أو إذا تعذر الدخول: info@baghdad-host.com'),
      const SizedBox(height: 16),
      if (!loading && !loadFailed && families.isNotEmpty) ...[
        const Text('العوائل التي تملكها حالياً'),
        for (final f in families) ListTile(
          title: Text((f as Map)['name'] as String),
          trailing: (f['transfer_candidates'] as List? ?? []).isEmpty ? null
            : TextButton(onPressed: busy ? null : () => transfer(f), child: const Text('نقل الملكية')),
        ),
        if (families.every((f) => ((f as Map)['transfer_candidates'] as List? ?? []).isEmpty))
          const Text('نقل الملكية يحتاج حساب أب أو أم آخر فعالاً ومنضماً إلى العائلة.'),
      ],
      if (loading) const Center(child: CircularProgressIndicator())
      else if (loadFailed) ...[
        Text(error!),
        FilledButton(onPressed: load, child: const Text('إعادة المحاولة')),
      ] else if (request != null) ...[
        Text(request!['status'] == 'reviewing' ? 'طلبك قيد المراجعة. لم يُحذف الحساب بعد.' : 'طلبك مسجّل بانتظار المراجعة. لم يُحذف الحساب بعد.'),
        if (request!['delete_owned_families'] == true) const Text('يتضمن الطلب حذف العوائل التي كنت تملكها عند تقديمه وبياناتها المشتركة.'),
        if (request!['requires_renewal'] == true) const Text('تغيّرت الملكية منذ تقديم الطلب. ألغِ الطلب وقدّم طلباً جديداً بالنطاق الصحيح.'),
        if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        OutlinedButton(onPressed: busy ? null : cancel, child: const Text('إلغاء طلب الحذف')),
      ] else Form(key: form, child: Column(children: [
        if (warning != null) Text(warning!),
        if (families.isNotEmpty) ...[
          const Text('إذا كنت تملك عائلة، يلزم نقل ملكيتها قبل حذف حسابك، أو اختيار حذفها صراحةً مع الحساب.'),
          CheckboxListTile(value: deleteFamilies,
            onChanged: busy ? null : (v) => setState(() { deleteFamilies = v ?? false; confirmFamilies = false; }),
            title: const Text('أطلب حذف العوائل التي أملكها مع الحساب')),
          if (deleteFamilies) CheckboxListTile(value: confirmFamilies,
            onChanged: busy ? null : (v) => setState(() => confirmFamilies = v ?? false),
            title: const Text('أفهم أن ملفات العائلة ومواقعها وأنشطتها المشتركة ستُحذف. حسابات الأشخاص الآخرين لا تُحذف بهذا الطلب')),
        ],
        TextFormField(controller: password, obscureText: true, enableSuggestions: false, autocorrect: false,
          validator: (v) => v == null || v.isEmpty ? 'أدخل كلمة المرور الحالية' : null,
          decoration: const InputDecoration(labelText: 'كلمة المرور الحالية')),
        CheckboxListTile(value: confirmed, onChanged: busy ? null : (v) => setState(() => confirmed = v ?? false),
          title: const Text('أؤكد أنني أطلب حذف حسابي وبياناتي المرتبطة به')),
        if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        FilledButton(onPressed: confirmed && !busy && (!deleteFamilies || confirmFamilies) ? submit : null,
          child: Text(busy ? 'جارٍ الإرسال…' : 'إرسال طلب الحذف')),
      ])),
    ]),
  );
}

class _TransferFamilyDialog extends StatefulWidget {
  const _TransferFamilyDialog({required this.family});
  final Map family;
  @override
  State<_TransferFamilyDialog> createState() => _TransferFamilyDialogState();
}
class _TransferFamilyDialogState extends State<_TransferFamilyDialog> {
  final password = TextEditingController();
  final form = GlobalKey<FormState>();
  int? target;
  bool confirmed = false;
  @override
  void dispose() { password.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('نقل ملكية العائلة'),
    content: SingleChildScrollView(child: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('سيحصل المالك الجديد على إدارة كاملة لعائلة ${widget.family['name']}، بما فيها إدارة الأفراد وبيانات المشاركة. يصبح دورك أباً أو أماً داخل العائلة.'),
      DropdownButtonFormField<int>(
        initialValue: target, isExpanded: true,
        decoration: const InputDecoration(labelText: 'المالك الجديد'),
        items: [for (final u in widget.family['transfer_candidates'] as List)
          DropdownMenuItem<int>(value: (u['id'] as num).toInt(), child: Text(u['name'] as String))],
        onChanged: (v) => setState(() => target = v),
        validator: (v) => v == null ? 'اختر المالك الجديد' : null,
      ),
      TextFormField(controller: password, obscureText: true, enableSuggestions: false, autocorrect: false,
        decoration: const InputDecoration(labelText: 'كلمة مرور حسابك الحالية'),
        validator: (v) => v == null || v.isEmpty ? 'أدخل كلمة المرور' : null),
      CheckboxListTile(value: confirmed, onChanged: (v) => setState(() => confirmed = v ?? false),
        title: const Text('أؤكد نقل الإدارة الكاملة إلى الحساب المختار')),
    ]))),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('رجوع')),
      FilledButton(onPressed: !confirmed ? null : () {
        if (form.currentState!.validate()) Navigator.pop(context, {'new_owner_id': target, 'password': password.text});
      }, child: const Text('تأكيد نقل الملكية'))],
  );
}
