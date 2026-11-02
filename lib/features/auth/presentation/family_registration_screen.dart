import 'family_auth_layout.dart';
import '../../family/application/family_identity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../application/auth_state.dart';

class FamilyRegistrationScreen extends ConsumerStatefulWidget {
  const FamilyRegistrationScreen({super.key});
  @override
  ConsumerState<FamilyRegistrationScreen> createState() =>
      _FamilyRegistrationScreenState();
}

class _FamilyRegistrationScreenState
    extends ConsumerState<FamilyRegistrationScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      phone = TextEditingController(),
      email = TextEditingController(),
      family = TextEditingController(),
      password = TextEditingController(),
      confirmation = TextEditingController();
  bool obscure = true;
  String? kinship;
  @override
  void dispose() {
    for (final c in [name, phone, email, family, password, confirmation]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final busy = state.status == AuthStatus.authenticating;
    return FamilyAuthLayout(
        canGoBack: true,
        title: 'عائلتك تنوّر عيونك',
        subtitle: 'خلّونا نبني بيتاً يجمعكم، خطوة بخطوة.',
        child: Form(
            key: form,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                      'حدد دورك أولاً. الأب أو الأم ينشئون العائلة ويبدؤون ربط الأبناء؛ الابن والبنت ينضمون بدعوة الأهل.'),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                      initialValue: kinship,
                      isExpanded: true,
                      decoration:
                          const InputDecoration(labelText: 'أنا في العائلة'),
                      items: [
                        for (final e in founderKinships.entries)
                          DropdownMenuItem(value: e.key, child: Text(e.value))
                      ],
                      onChanged:
                          busy ? null : (v) => setState(() => kinship = v),
                      validator: (v) =>
                          v == null ? 'حدد صلتك بالعائلة أولاً' : null),
                  const SizedBox(height: 16),
                  TextFormField(
                      controller: name,
                      enabled: !busy,
                      decoration: const InputDecoration(labelText: 'اسمك'),
                      maxLength: 255,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'اكتب اسمك' : null),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: phone,
                      enabled: !busy,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                          labelText: 'رقم الهاتف',
                          hintText: '07701234567',
                          helperText:
                              'الرقم العراقي 11 رقماً، أو الصيغة الدولية مع +',
                          helperMaxLines: 2),
                      maxLength: 20,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'اكتب رقم الهاتف'
                          : null),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: email,
                      enabled: !busy,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                          labelText: 'البريد الإلكتروني (اختياري)'),
                      maxLength: 255,
                      validator: (v) => v != null &&
                              v.trim().isNotEmpty &&
                              !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                  .hasMatch(v.trim())
                          ? 'اكتب بريداً صحيحاً'
                          : null),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: family,
                      enabled: !busy,
                      decoration: const InputDecoration(
                          labelText: 'اسم العائلة (اختياري)'),
                      maxLength: 150),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: password,
                      enabled: !busy,
                      obscureText: obscure,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                          labelText: 'كلمة المرور',
                          suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => obscure = !obscure),
                              tooltip: obscure
                                  ? 'إظهار كلمة المرور'
                                  : 'إخفاء كلمة المرور',
                              icon: Icon(obscure
                                  ? Icons.visibility
                                  : Icons.visibility_off))),
                      validator: (v) => v == null || v.length < 8
                          ? 'ثمانية أحرف على الأقل'
                          : null),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: confirmation,
                      enabled: !busy,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration:
                          const InputDecoration(labelText: 'تأكيد كلمة المرور'),
                      validator: (v) => v != password.text
                          ? 'كلمتا المرور غير متطابقتين'
                          : null),
                  if (state.errorMessage != null)
                    Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(state.errorMessage!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error))),
                  const SizedBox(height: 24),
                  FilledButton(
                      onPressed: busy
                          ? null
                          : () {
                              if (form.currentState?.validate() != true) return;
                              ref
                                  .read(authControllerProvider.notifier)
                                  .registerFamily({
                                'name': name.text.trim(),
                                'kinship': kinship,
                                'phone': phone.text.trim(),
                                'email': email.text.trim().isEmpty
                                    ? null
                                    : email.text.trim(),
                                'family_name': family.text.trim().isEmpty
                                    ? null
                                    : family.text.trim(),
                                'password': password.text,
                                'password_confirmation': confirmation.text
                              });
                            },
                      child: Text(busy ? 'جارِ إنشاء الحساب…' : 'إنشاء حسابي')),
                ])));
  }
}
