import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_saas_driver/app/providers.dart';
import 'package:fleet_saas_driver/core/network/api_client.dart';
import 'package:fleet_saas_driver/core/network/api_envelope.dart';
import 'package:fleet_saas_driver/features/admin/presentation/platform_admin_screen.dart';

class PlatformFake extends ApiClient {
  PlatformFake() : super(getToken: () async => null);
  final paths = <String>[];
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query, Map<String, dynamic>? headers}) async {
    paths.add(path);
    return {
      'families': 2,
      'families_active': 2,
      'families_suspended': 0,
      'members': 3,
      'accounts': 4,
      'articles': 14,
      'fact_bank': 10,
      'push_available': false
    };
  }

  @override
  Future<ApiEnvelope> getPaginated(String path, {Map<String, dynamic>? query, Map<String, dynamic>? headers}) async {
    paths.add(path);
    return ApiEnvelope(
        data: path.endsWith('/families')
            ? [
                {'id': 1, 'name': 'عائلة اختبار', 'status': 'active', 'members_count': 3, 'relationships_count': 2}
              ]
            : [
                {'id': 7, 'name': 'الأدمن الرئيسي', 'is_super_admin': true, 'status': 'active'}
              ],
        meta: {'last_page': 1});
  }
}

void main() {
  testWidgets('platform overview and family list use admin endpoints', (tester) async {
    final api = PlatformFake();
    await tester.pumpWidget(ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)], child: const MaterialApp(home: PlatformAdminScreen())));
    await tester.pumpAndSettle();
    expect(find.text('إدارة عيونك'), findsOneWidget);
    expect(api.paths, contains('/admin/platform/overview'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'العوائل'));
    await tester.pumpAndSettle();
    expect(find.text('عائلة اختبار'), findsOneWidget);
    expect(api.paths, contains('/admin/platform/families'));
  });
  testWidgets('root account has no suspension control', (tester) async {
    final api = PlatformFake();
    await tester.pumpWidget(ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)], child: const MaterialApp(home: PlatformAdminScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'الحسابات'));
    await tester.pumpAndSettle();
    expect(find.text('الأدمن الرئيسي'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'إيقاف مؤقت'), findsNothing);
  });
}
