import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_saas_driver/app/providers.dart';
import 'package:fleet_saas_driver/app/theme.dart';
import 'package:fleet_saas_driver/app/startup_intro.dart';
import 'package:fleet_saas_driver/app/splash_screen.dart';
import 'package:fleet_saas_driver/core/network/api_client.dart';
import 'package:fleet_saas_driver/core/network/api_envelope.dart';
import 'package:fleet_saas_driver/core/storage/secure_token_store.dart';
import 'package:fleet_saas_driver/features/family_life/presentation/family_life_screen.dart';

class QuickStore extends SecureTokenStore {
  @override
  Future<String?> readToken() async => null;
}

class QuickApi extends ApiClient {
  QuickApi() : super(getToken: () async => null);
  Map<String, dynamic>? sent;
  @override
  Future<dynamic> get(String path,
          {Map<String, dynamic>? query, Map<String, dynamic>? headers}) async =>
      {'viewer_role': 'owner', 'can_manage': true};
  @override
  Future<ApiEnvelope> getPaginated(String path,
          {Map<String, dynamic>? query, Map<String, dynamic>? headers}) async =>
      const ApiEnvelope(data: [], meta: {});
  @override
  Future<dynamic> post(String path,
      {dynamic data, Map<String, dynamic>? headers}) async {
    sent = Map<String, dynamic>.from(data as Map);
    return {'id': 1};
  }
}

void main() {
  test(
      'child palette applies throughout app theme; parent brand stays unchanged',
      () {
    expect(buildAppTheme(familyGender: 'male').colorScheme.primary,
        const Color(0xFF1768B4));
    expect(buildAppTheme(familyGender: 'female').colorScheme.primary,
        const Color(0xFFBE185D));
    expect(buildAppTheme().colorScheme.primary, const Color(0xFF087F8C));
    expect(buildAppTheme(familyGender: 'female').scaffoldBackgroundColor,
        buildAppTheme(familyGender: 'female').colorScheme.surface);
  });
  testWidgets('quick shopping asks quantity and posts only after confirmation',
      (tester) async {
    final api = QuickApi();
    await tester.pumpWidget(ProviderScope(overrides: [
      apiClientProvider.overrideWithValue(api),
      secureTokenStoreProvider.overrideWithValue(QuickStore())
    ], child: const MaterialApp(home: FamilyLifeScreen(section: 'shopping'))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ActionChip, 'حليب'));
    await tester.tap(find.widgetWithText(ActionChip, 'حليب'));
    await tester.pumpAndSettle();
    expect(api.sent, isNull);
    expect(find.text('إضافة حليب'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, '2 علبة');
    await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
    await tester.pumpAndSettle();
    expect(api.sent?['name'], 'حليب');
    expect(api.sent?['quantity'], '2 علبة');
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'reduced motion bypasses intro video and leaves authentication gating separate',
      (tester) async {
    final container = ProviderContainer();
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
            home: MediaQuery(
                data: MediaQueryData(disableAnimations: true),
                child: SplashScreen()))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds:50));
    expect(container.read(startupIntroCompleteProvider), true);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    expect(tester.takeException(), isNull);
  });
}
