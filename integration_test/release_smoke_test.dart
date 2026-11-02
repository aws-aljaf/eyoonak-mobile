import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:fleet_saas_driver/app/app.dart';
import 'package:fleet_saas_driver/app/providers.dart';
import 'package:fleet_saas_driver/core/storage/secure_token_store.dart';

class SmokeStore extends SecureTokenStore {
  @override
  Future<String?> readToken() async => null;
  @override
  Future<String?> readDeviceUuid() async => '00000000-0000-4000-8000-000000000001';
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Arabic login and family registration start on Android without creating an account', (tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [secureTokenStoreProvider.overrideWithValue(SmokeStore())], child: const FleetSaasDriverApp()));
    await tester.pumpAndSettle();
    expect(find.text('تسجيل الدخول إلى عيونك'), findsOneWidget);
    expect(find.text('تسجيل دخول السائق'), findsNothing);
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('eyoonak-android-login');
    await tester.tap(find.text('إنشاء حساب عائلة'));
    await tester.pumpAndSettle();
    expect(find.text('هلا بعائلتك بعيونك'), findsOneWidget);
    final create = find.widgetWithText(FilledButton, 'إنشاء حساب العائلة');
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(find.text('اكتب اسمك'), findsOneWidget);
    expect(find.text('ثمانية أحرف على الأقل'), findsOneWidget);
    await binding.takeScreenshot('eyoonak-android-family-registration');
  });
}
