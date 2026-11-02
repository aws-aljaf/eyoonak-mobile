import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_saas_driver/app/theme.dart';
import 'package:fleet_saas_driver/features/family/application/family_providers.dart';
import 'package:fleet_saas_driver/features/family/data/family_models.dart';
import 'package:fleet_saas_driver/features/family_tasks/application/family_tasks_providers.dart';
import 'package:fleet_saas_driver/features/exercises/application/exercises_providers.dart';
import 'package:fleet_saas_driver/features/exercises/presentation/exercises_screen.dart';

void main() {
  testWidgets('activity catalog remains readable on a narrow Arabic phone', (tester) async {
    if (const bool.fromEnvironment('CAPTURE_PREVIEW')) {
      await (FontLoader('Cairo')
            ..addFont(rootBundle.load('assets/fonts/Cairo-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/Cairo-Bold.ttf')))
          .load();
      await (FontLoader('MaterialIcons')
            ..addFont(Future.value(ByteData.sublistView(
                File('E:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytesSync()))))
          .load();
    }
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          familyMembersProvider.overrideWith((ref) async => [
                const FamilyMemberModel(
                    id: 1, fullName: 'سارة', relationship: 'الابنة', status: 'active', birthDate: '2018-06-01')
              ]),
          canManageFamilyTasksProvider.overrideWith((ref) => true),
          memberExercisesProvider(1).overrideWith((ref) async => {
                'age_group': {'name': 'من 6 إلى 8 سنوات'},
                'unavailable_reason': null,
                'exercises': [
                  {
                    'id': 1,
                    'name': 'قفزات النجوم',
                    'difficulty': 'easy',
                    'category_id': 1,
                    'category': {'id': 1, 'name': 'الحركة والنشاط'},
                    'assigned': false
                  },
                  {
                    'id': 2,
                    'name': 'توازن الفراشة',
                    'difficulty': 'easy',
                    'category_id': 2,
                    'category': {'id': 2, 'name': 'المرونة والتوازن'},
                    'assigned': true
                  },
                ]
              }),
        ],
        child: MaterialApp(
            theme: buildAppTheme(),
            debugShowCheckedModeBanner: false,
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate
            ],
            home: const ExercisesScreen())));
    // The cartoon has an intentional continuous idle animation.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('قفزات النجوم'), findsOneWidget);
    expect(find.text('توازن الفراشة'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Golden generation is opt-in; the normal suite validates layout without a machine-specific font snapshot.
    if (const bool.fromEnvironment('CAPTURE_PREVIEW')) {
      await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile(
              Uri.file('C:/Users/MSI/Documents/Codex/2026-10-13/new-chat/outputs/eyoonak-exercises-preview.png')));
    }
  });
}
