import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_saas_driver/features/family_life/presentation/child_learning_panel.dart';

void main() {
  testWidgets('learning requires an option and displays gentle answer feedback', (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: ChildLearningPanel(
      learning: const {
        'date': '2026-10-14',
        'age': 7,
        'fact': {'text': 'الشمس نجم', 'topic': 'الفلك'},
        'exercises': [
          {
            'key': 'junior-sum',
            'question': 'كم مجموع ٢ و٢؟',
            'options': ['٣', '٤', '٥'],
            'solved': false
          }
        ]
      },
      answer: (key, choice) async {
        calls++;
        expect(key, 'junior-sum');
        expect(choice, 0);
        return {'correct': false, 'message': 'محاولة حلوة', 'explanation': '٢ + ٢ = ٤'};
      },
    )))));
    final button = find.widgetWithText(FilledButton, 'جرّب إجابتي');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.tap(find.widgetWithText(OutlinedButton, '٣'));
    await tester.pump();
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.textContaining('محاولة حلوة'), findsOneWidget);
    expect(find.textContaining('٢ + ٢ = ٤'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('missing age shows setup guidance and no guessed exercise', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ChildLearningPanel(
      learning: const {
        'date': '2026-10-14',
        'age': null,
        'fact': {'text': 'المثلث له ثلاثة أضلاع', 'topic': 'الهندسة'},
        'message': 'أضيفوا تاريخ الميلاد',
        'exercises': []
      },
      answer: (key, choice) async => throw StateError('No exercise expected'),
    ))));
    expect(find.text('أضيفوا تاريخ الميلاد'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected skill shows its personal activity without inventing a score', (tester) async {
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(child:ChildLearningPanel(
      learning:const {'age':5,'fact':{'text':'معلومة','topic':'اليوم'},'exercises':[],
        'skills':[{'key':'drawing','title':'الرسم','activity':'ارسم شكلاً تحبه'}]},
      answer:(key,choice) async => throw StateError('No quiz expected'),
    )))));
    expect(find.text('🎨 مهارتي: الرسم'),findsOneWidget);
    expect(find.text('ارسم شكلاً تحبه'),findsOneWidget);
    expect(find.byType(FilledButton),findsNothing);
    expect(tester.takeException(),isNull);
  });
}
