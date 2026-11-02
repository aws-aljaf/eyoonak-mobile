import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_saas_driver/app/providers.dart';
import 'package:fleet_saas_driver/core/network/api_client.dart';
import 'package:fleet_saas_driver/core/network/api_envelope.dart';
import 'package:fleet_saas_driver/features/family_life/presentation/academy_screen.dart';
import 'package:fleet_saas_driver/features/family_life/presentation/family_subscription_screen.dart';

class LearningApi extends ApiClient {
  LearningApi({this.canTrack = true}) : super(getToken: () async => null);
  final bool canTrack;
  Map<String, dynamic>? lastQuery, lastHeaders;
  int completions = 0;
  @override
  Future<ApiEnvelope> getPaginated(String path,
      {Map<String, dynamic>? query, Map<String, dynamic>? headers}) async {
    lastQuery = query;
    lastHeaders = headers;
    return const ApiEnvelope(data: [
      {'id': 10, 'title': 'Hello', 'summary': 'مرحبا'}
    ], meta: {
      'last_page': 1
    });
  }

  @override
  Future<dynamic> get(String path,
      {Map<String, dynamic>? query, Map<String, dynamic>? headers}) async {
    if (path.endsWith('/categories')) return [];
    if (path.endsWith('/home')) {
      return {
        'viewer_role': canTrack ? 'child' : 'owner',
        'viewer_gender': canTrack ? 'female' : null,
        'can_manage': !canTrack
      };
    }
    if (path.endsWith('/subscription')) return {'terms': [], 'requests': []};
    return {
      'article': {
        'id': 10,
        'title': 'Hello',
        'body': 'Hello = مرحباً',
        'course_key': 'english',
        'questions': [],
        'media': []
      },
      'attempt': null,
      'completed': false,
      'can_track': canTrack
    };
  }

  @override
  Future<dynamic> post(String path,
      {dynamic data, Map<String, dynamic>? headers}) async {
    completions++;
    return {'completed': true};
  }
}

void main() {
  testWidgets(
      'unlinked parent previews English without an unusable completion action',
      (tester) async {
    final api = LearningApi(canTrack: false);
    await tester.pumpWidget(ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: const MaterialApp(home: AcademyScreen(courseKey: 'english'))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hello'));
    await tester.pumpAndSettle();
    expect(find.textContaining('معاينة الدرس متاحة'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'تعلّمت الدرس'), findsNothing);
    expect(api.completions, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('English filter and private completion work at narrow width',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = LearningApi();
    await tester.pumpWidget(ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: const MaterialApp(home: AcademyScreen(courseKey: 'english'))));
    await tester.pumpAndSettle();
    expect(api.lastQuery?['course_key'], 'english');
    expect(api.lastHeaders?.containsKey('X-Family-Id'), false);
    await tester.tap(find.text('Hello'));
    await tester.pumpAndSettle();
    final complete = find.widgetWithText(FilledButton, 'تعلّمت الدرس');
    await tester.ensureVisible(complete);
    await tester.tap(complete);
    await tester.pumpAndSettle();
    expect(api.completions, 1);
    expect(find.text('أحسنت! أنجزت هذا الدرس ✓'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('retired subscription page has no price or purchase prompt',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(LearningApi())],
        child: const MaterialApp(home: FamilySubscriptionScreen())));
    await tester.pumpAndSettle();
    expect(find.text('هذه الصفحة غير متاحة.'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
