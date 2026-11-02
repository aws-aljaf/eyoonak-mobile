import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../application/auth_state.dart';

class TwoFactorScreen extends ConsumerStatefulWidget {
  const TwoFactorScreen({super.key});

  @override
  ConsumerState<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends ConsumerState<TwoFactorScreen> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.status == AuthStatus.authenticating;

    return Scaffold(
      appBar: AppBar(title: const Text('رمز التحقق الثنائي')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('أدخل رمز التحقق الثنائي (2FA) لإتمام تسجيل الدخول.'),
            const SizedBox(height: 16),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: 'الرمز', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            if (authState.errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(authState.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () => ref.read(authControllerProvider.notifier).verifyTwoFactor(_codeController.text.trim()),
              child: isLoading ? const CircularProgressIndicator() : const Text('تأكيد'),
            ),
          ],
        ),
      ),
    );
  }
}
