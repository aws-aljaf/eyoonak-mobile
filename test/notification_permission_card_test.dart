import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_saas_driver/core/notifications/notification_permission_card.dart';

void main() {
  testWidgets('blocked notifications offer settings and refresh after resume',
      (tester) async {
    bool granted = false;
    int opens = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: NotificationPermissionCard(
      checkPermission: () async => granted,
      openSettings: () async {
        opens++;
        return true;
      },
    ))));
    await tester.pumpAndSettle();
    expect(find.textContaining('الإشعارات محظورة'), findsOneWidget);
    await tester.tap(find.text('إعدادات إشعارات الهاتف'));
    await tester.pumpAndSettle();
    expect(opens, 1);
    granted = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.textContaining('مسموح من النظام'), findsOneWidget);
    expect(find.textContaining('الإشعارات محظورة'), findsNothing);
  });
  testWidgets('permission read failure never reports permission granted',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: NotificationPermissionCard(
      checkPermission: () async => throw StateError('unavailable'),
      openSettings: () async => false,
    ))));
    await tester.pumpAndSettle();
    expect(find.textContaining('تعذر تحديد الإذن'), findsOneWidget);
    await tester.tap(find.text('إعدادات إشعارات الهاتف'));
    await tester.pumpAndSettle();
    expect(find.text('افتح إعدادات الهاتف ثم عيونك ثم الإشعارات.'),
        findsOneWidget);
  });
}
