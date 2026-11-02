import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_saas_driver/app/providers.dart';
import 'package:fleet_saas_driver/core/network/api_client.dart';
import 'package:fleet_saas_driver/features/health/presentation/health_screen.dart';

class HealthFake extends ApiClient {
  HealthFake(this.mother) : super(getToken: () async => null);
  final bool mother;
  final calls = <String>[];
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query, Map<String, dynamic>? headers}) async {
    calls.add(path);
    if (path.endsWith('/cycle')) {
      return {
        'configured': true,
        'last_start': '2026-10-01',
        'next_start': '2026-10-29',
        'cycle_length': 28,
        'period_length': 5,
        'reminders': false,
        'history': ['2026-10-01'],
        'timezone': 'Asia/Baghdad',
        'reminder_time': '09:00',
        'remind_days_before': 1
      };
    }
    return {'reminders': [], 'today': [], 'upcoming': [], 'can_use_cycle': mother};
  }
}

Widget screen(HealthFake api, {bool cycle = false}) => ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(api)],
    child: MaterialApp(home: Directionality(textDirection: TextDirection.rtl, child: HealthScreen(cycleOnly: cycle))));
void main() {
  testWidgets('father is denied mother section and no cycle API is requested', (tester) async {
    final api = HealthFake(false);
    await tester.pumpWidget(screen(api, cycle: true));
    await tester.pumpAndSettle();
    expect(find.text('هذا القسم لحساب الأم فقط.'), findsOneWidget);
    expect(api.calls, isNot(contains('/personal/health/cycle')));
    expect(find.textContaining('2026-10-01'), findsNothing);
  });
  testWidgets('mother sees own saved dates and the approximate next date', (tester) async {
    final api = HealthFake(true);
    await tester.pumpWidget(screen(api, cycle: true));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('البداية التالية التقريبية: 2026-10-29'), 200);
    expect(find.text('البداية التالية التقريبية: 2026-10-29'), findsOneWidget);
    expect(api.calls, contains('/personal/health/cycle'));
    expect(tester.takeException(), isNull);
  });
  testWidgets('reminder editor renders at narrow width and requires a title', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = HealthFake(false);
    await tester.pumpWidget(screen(api));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('إضافة تذكير'), 150);
    await tester.tap(find.text('إضافة تذكير'));
    await tester.pumpAndSettle();
    expect(find.byType(HealthEditor), findsOneWidget);
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(find.text('أدخل الاسم'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('self care opens a dedicated reminder category', (tester) async {
    await tester.pumpWidget(screen(HealthFake(false)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('موعد للعناية بنفسي'), 150);
    await tester.tap(find.text('موعد للعناية بنفسي'));
    await tester.pumpAndSettle();
    expect(tester.widget<DropdownButtonFormField<String>>(find.byType(DropdownButtonFormField<String>)).initialValue, 'self_care');
    expect(tester.takeException(), isNull);
  });
}
