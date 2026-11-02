import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fleet_saas_driver/app/providers.dart';
import 'package:fleet_saas_driver/core/network/api_client.dart';
import 'package:fleet_saas_driver/core/storage/secure_token_store.dart';
import 'package:fleet_saas_driver/features/family_life/presentation/managed_content_panel.dart';
import 'package:fleet_saas_driver/features/family_life/presentation/managed_banner_carousel.dart';
import 'package:fleet_saas_driver/features/family/presentation/family_home_screen.dart';
import 'package:fleet_saas_driver/features/family/application/family_providers.dart';
import 'package:fleet_saas_driver/features/family/data/family_models.dart';
import 'package:fleet_saas_driver/features/family_tasks/application/family_tasks_providers.dart';

class EmptyStore extends SecureTokenStore {
  @override
  Future<String?> readToken() async => null;
}
class Feed extends ApiClient {
  Feed({this.published = false}): super(getToken: () async => null);
  final bool published;
  @override
  Future<dynamic> get(String path, {Map<String,dynamic>? query, Map<String,dynamic>? headers}) async => {'items': published ? [{'id': 10, 'kind': 'banner', 'revision': 1, 'title': 'إعلان الإدارة', 'body': 'وصف الإعلان'}] : []};
}
void main() {
  for (final published in [false, true]) {
    testWidgets(published ? 'CMS replaces welcome slides' : 'first login shows welcome with safe navigation', (tester) async {
      final router = GoRouter(routes: [GoRoute(path: '/', builder: (_, state) => const Scaffold(body: SingleChildScrollView(child: ManagedContentPanel()))), GoRoute(path: '/family', builder: (_, state) => const Scaffold(body: Text('FAMILY DESTINATION')))]);
      await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(Feed(published: published))], child: MaterialApp.router(routerConfig: router)));
      await tester.pumpAndSettle();
      expect(find.byType(ManagedBannerCarousel), findsOneWidget);
      if (published) {
        expect(find.text('إعلان الإدارة'), findsOneWidget);
        expect(find.text('هلا بأهل البيت'), findsNothing);
      } else {
        expect(find.text('هلا بأهل البيت'), findsOneWidget);
        await tester.tap(find.text('اعرف أكثر'));
        await tester.pumpAndSettle();
        expect(find.text('FAMILY DESTINATION'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox()); router.dispose();
    });
  }
  testWidgets('small family screen scrolls and keeps compact tools', (tester) async {
    tester.view.physicalSize = const Size(320, 568); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(overrides: [
      apiClientProvider.overrideWithValue(Feed()), secureTokenStoreProvider.overrideWithValue(EmptyStore()),
      myFamiliesProvider.overrideWith((ref) async => [const FamilyModel(id: 1, name: 'بيتنا', status: 'active', ownerUserId: 1)]),
      familyMembersProvider.overrideWith((ref) async => []),
      todayFamilyTaskOccurrencesProvider.overrideWith((ref) async => []),
      canManageFamilyTasksProvider.overrideWithValue(false),
    ], child: const MaterialApp(home: FamilyHomeScreen())));
    await tester.pumpAndSettle();
    expect(find.byTooltip('أدوات العائلة'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('بعدنا ببداية حكاية العائلة'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('بعدنا ببداية حكاية العائلة'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
