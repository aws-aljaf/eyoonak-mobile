import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_saas_driver/app/providers.dart';
import 'package:fleet_saas_driver/core/network/api_client.dart';
import 'package:fleet_saas_driver/features/family_life/presentation/managed_content_panel.dart';
class ContentApi extends ApiClient {
 ContentApi():super(getToken:()async=>null);bool published=true;int pageCalls=0;
 @override Future<dynamic> get(String path,{Map<String,dynamic>? query,Map<String,dynamic>? headers})async {
  expect(query?['platform'],'mobile');
  if(path=='/content')return {'items':published?[{'id':1,'kind':'section','title':'عالمنا','icon':'book'},{'id':2,'kind':'page','title':'صفحة جديدة','section_id':1,'icon':'plane'}]:[]};
  pageCalls++;return {'id':2,'kind':'page','title':'صفحة جديدة','body':'نص من السيرفر يتحدث بدون إصدار','icon':'plane'};
 }
}
void main(){testWidgets('server pages open natively and archived content disappears on refresh',(tester)async{
 final api=ContentApi();
 await tester.pumpWidget(ProviderScope(overrides:[apiClientProvider.overrideWithValue(api)],child:const MaterialApp(home:Scaffold(body:SingleChildScrollView(child:ManagedContentPanel())))));
 await tester.pumpAndSettle();expect(find.text('عالمنا'),findsOneWidget);
 await tester.tap(find.text('صفحة جديدة'));await tester.pumpAndSettle();expect(api.pageCalls,1);expect(find.text('نص من السيرفر يتحدث بدون إصدار'),findsOneWidget);
 await tester.pageBack();await tester.pumpAndSettle();api.published=false;
 await tester.tap(find.text('تحديث المحتوى'));await tester.pumpAndSettle();expect(find.text('عالمنا'),findsNothing);expect(find.text('صفحة جديدة'),findsNothing);expect(tester.takeException(),isNull);
 await tester.pumpWidget(const SizedBox());
});}
