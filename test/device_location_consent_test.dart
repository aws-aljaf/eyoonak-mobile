import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_saas_driver/core/network/api_client.dart';
import 'package:fleet_saas_driver/features/family/application/device_location_sharing.dart';
import 'package:fleet_saas_driver/features/family/presentation/device_location_screen.dart';

class ConsentProbe extends DeviceLocationSharing {
  ConsentProbe() : super(ApiClient(getToken: () async => null));
  int starts = 0, stops = 0;
  bool running = false;
  @override
  bool get active => running;
  @override
  Future<void> start() async { starts++; running = true; changed(); }
  @override
  Future<void> stop() async { stops++; running = false; changed(); }
}
Future<void> showScreen(WidgetTester tester, ConsentProbe probe) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [deviceLocationSharingProvider.overrideWith((ref) => probe)],
    child: const MaterialApp(home: Directionality(textDirection: TextDirection.rtl, child: DeviceLocationScreen())),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'بدء مشاركة موقعي مع العائلة'));
  await tester.pumpAndSettle();
}
void main() {
  testWidgets('declining disclosure never starts location access', (tester) async {
    final probe = ConsentProbe();
    await showScreen(tester, probe);
    expect(probe.starts, 0);
    expect(find.textContaining('قد تستمر التحديثات عند استخدام تطبيق آخر'), findsOneWidget);
    await tester.tap(find.text('ليس الآن'));
    await tester.pumpAndSettle();
    expect(probe.starts, 0);
    expect(probe.active, isFalse);
  });
  testWidgets('back dismisses disclosure without consent', (tester) async {
    final probe = ConsentProbe();
    await showScreen(tester, probe);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(probe.starts, 0);
  });
  testWidgets('explicit consent starts once and stop stays immediate', (tester) async {
    final probe = ConsentProbe();
    await showScreen(tester, probe);
    await tester.tap(find.text('أوافق وأبدأ المشاركة'));
    await tester.pumpAndSettle();
    expect(probe.starts, 1);
    expect(probe.active, isTrue);
    await tester.tap(find.widgetWithText(FilledButton, 'إيقاف المشاركة'));
    await tester.pumpAndSettle();
    expect(probe.stops, 1);
    expect(probe.active, isFalse);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
