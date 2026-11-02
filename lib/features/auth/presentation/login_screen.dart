import 'family_auth_layout.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../application/auth_state.dart';

/// Module 25 — real `/auth/login` call only, never a mock/demo login
/// shortcut. "Remember Device" is handled transparently by
/// AuthController persisting the Sanctum token + device_uuid on success.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  bool obscurePassword = true;
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.status == AuthStatus.authenticating;

    return FamilyAuthLayout(
      title: 'هلا بيكم في عيونك',
      subtitle: 'بيت يجمع العائلة… أمان ومحبة وتفاصيل حلوة كل يوم.',
      child: AutofillGroup(
          child: Form(
        key: _formKey,
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('تسجيل الدخول',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 20),
              TextFormField(
                controller: _identifierController,
                enabled: !isLoading,
                decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني أو رقم الهاتف',
                    prefixIcon: Icon(Icons.person_outline)),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.username],
                textInputAction: TextInputAction.next,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'اكتب البريد الإلكتروني أو رقم الهاتف'
                    : null,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _passwordController,
                enabled: !isLoading,
                obscureText: obscurePassword,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  if (!isLoading) _submit();
                },
                decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => obscurePassword = !obscurePassword),
                        tooltip: obscurePassword
                            ? 'إظهار كلمة المرور'
                            : 'إخفاء كلمة المرور',
                        icon: Icon(obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined))),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'اكتب كلمة المرور'
                    : null,
              ),
              if (authState.errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(authState.errorMessage!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                    textAlign: TextAlign.center),
              ],
              const SizedBox(height: 24),
              FilledButton(
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('دخول إلى بيتنا')),
              const SizedBox(height: 12),
              TextButton(
                  onPressed:
                      isLoading ? null : () => context.push('/register-family'),
                  child: const Text('جديد ويانا؟ أنشئ حساب عائلة')),
            ]),
      )),
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    ref.read(authControllerProvider.notifier).login(
          identifier: _identifierController.text.trim(),
          password: _passwordController.text,
        );
  }
}
