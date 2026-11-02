import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';

class CompleteMembershipScreen extends ConsumerWidget {
  const CompleteMembershipScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('إكمال ربط الحساب')),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          const Icon(Icons.family_restroom, size: 72),
          const SizedBox(height: 24),
          const Text('أهلاً بك في عيونك', style: TextStyle(fontSize: 24)),
          const Text(
              'حسابك مسجّل، لكنه غير مرتبط بعائلة أو ملف مستخدم بعد. اطلب من مالك العائلة أو مسؤول النظام ربط حسابك. لن تظهر بيانات عائلة قبل اعتماد عضويتك.'),
          if (ref.watch(authControllerProvider).errorMessage
              case final String message)
            Text(message),
          const SizedBox(height: 24),
          FilledButton.icon(
              onPressed: () => context.push('/family/membership'),
              icon: const Icon(Icons.mail_outline),
              label: const Text('دعوة الأب أو الأم للانضمام')),
          FilledButton(
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).refreshMembership(),
              child: const Text('تحقّق من العضوية')),
          TextButton(
              onPressed: () => context.push('/profile'),
              child: const Text('حسابي وأجهزتي وحذف الحساب')),
          TextButton(
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).logout(),
              child: const Text('تسجيل الخروج')),
        ]),
      );
}
