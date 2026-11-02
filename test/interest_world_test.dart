import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_saas_driver/app/providers.dart';
import 'package:fleet_saas_driver/core/network/api_client.dart';
import 'package:fleet_saas_driver/features/family_life/presentation/interest_world_screen.dart';

class InterestsApi extends ApiClient {
  InterestsApi() : super(getToken: () async => null);
  Map<String, dynamic>? saved;
  final calls = <String>[];
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query, Map<String, dynamic>? headers}) async {
    calls.add(path);
    if (path.endsWith('/child-profiles')) {
      return [
        {'id': 10, 'name': 'طفل الاختبار', 'age': 8, 'knowledge_topic_ids': <int>[]}
      ];
    }
    if (path.endsWith('/interest-topics')) {
      return [
        {'id': 1, 'name': 'الطيران'},
        {'id': 2, 'name': 'الفضاء'}
      ];
    }
    if (path.endsWith('/home')) return {'viewer_role': 'child', 'viewer_gender': 'female'};
    throw StateError('Unexpected request $path');
  }

  @override
  Future<dynamic> put(String path, {dynamic data, Map<String, dynamic>? headers}) async {
    calls.add(path);
    saved = Map<String, dynamic>.from(data as Map);
    return {'id': 10};
  }
}

void main() {
  testWidgets('child can choose aviation and save knowledge interests independently from skills', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = InterestsApi();
    await tester.pumpWidget(ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)], child: const MaterialApp(home: InterestWorldScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'الطيران'));
    await tester.pump();
    final save = find.widgetWithText(FilledButton, 'حفظ اهتماماتي');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(api.saved, {
      'knowledge_topic_ids': [1]
    });
    expect(find.text('حفظنا اهتمامات طفل الاختبار'), findsOneWidget);
    expect(api.calls.any((p) => p.contains('openai') || p.contains('generate')), false);
    expect(tester.takeException(), isNull);
  });
}
