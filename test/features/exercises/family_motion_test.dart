import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_saas_driver/core/widgets/family_motion.dart';

void main() {
  testWidgets('reduced motion keeps the activity card immediately readable', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(body: FamilyHero(title: 'نشاط اليوم', subtitle: 'خطوة صغيرة')))));
    expect(find.text('نشاط اليوم'), findsOneWidget);
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('celebration closes normally with reduced motion enabled', (tester) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
                builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () => showDialog<void>(context: context, builder: (_) => const FamilyCelebration()),
                        child: const Text('فتح')))))));
    await tester.tap(find.text('فتح'));
    await tester.pumpAndSettle();
    expect(find.text('أحسنت يا بطل! 🌟'), findsOneWidget);
    await tester.tap(find.text('نكمل المشوار'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
