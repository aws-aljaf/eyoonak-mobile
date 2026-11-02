import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fleet_saas_driver/app/providers.dart';
import 'package:fleet_saas_driver/core/network/api_client.dart';
import 'package:fleet_saas_driver/core/storage/secure_token_store.dart';
import 'package:fleet_saas_driver/features/family_life/presentation/family_life_screen.dart';
class HomeStore extends SecureTokenStore {
 @override Future<String?> readToken() async => null;
}
class HomeApi extends ApiClient {
 HomeApi():super(getToken:()async=>null);
 @override Future<dynamic> get(String path,{Map<String,dynamic>? query,Map<String,dynamic>? headers}) async =>
 path == '/content' ? {'items': []} : {'viewer_role':'owner','can_manage':true,'shopping_pending':2,'meal_polls_open':1};
}
void main() {
 testWidgets('meal and shopping summaries have separate destinations', (tester) async {
  final router=GoRouter(routes:[
   GoRoute(path:'/',builder:(_,state)=>const FamilyLifeScreen()),
   GoRoute(path:'/our-home/meals',builder:(_,state)=>const Scaffold(body:Text('MEALS DESTINATION'))),
   GoRoute(path:'/our-home/shopping',builder:(_,state)=>const Scaffold(body:Text('SHOPPING DESTINATION'))),
  ]);
  await tester.pumpWidget(ProviderScope(overrides:[apiClientProvider.overrideWithValue(HomeApi()),secureTokenStoreProvider.overrideWithValue(HomeStore())],child:MaterialApp.router(routerConfig:router)));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('وجبات العائلة'), 250, scrollable: find.byType(Scrollable).first);
  expect(find.text('تصويتات الوجبات المفتوحة: 1'),findsOneWidget);
  expect(find.text('طلبات الشراء بانتظار المراجعة: 2'),findsOneWidget);
  await tester.ensureVisible(find.text('وجبات العائلة'));await tester.tap(find.text('وجبات العائلة'));await tester.pumpAndSettle();
  expect(find.text('MEALS DESTINATION'),findsOneWidget);
  router.pop();await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('احتياجات البيت'));await tester.tap(find.text('احتياجات البيت'));await tester.pumpAndSettle();
  expect(find.text('SHOPPING DESTINATION'),findsOneWidget);
  await tester.pumpWidget(const SizedBox());router.dispose();
  expect(tester.takeException(),isNull);
 });
}
