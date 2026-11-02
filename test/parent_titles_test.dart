import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_saas_driver/app/providers.dart';
import 'package:fleet_saas_driver/core/network/api_client.dart';
import 'package:fleet_saas_driver/features/family_life/presentation/parent_titles_panel.dart';
class TitlesApi extends ApiClient {
 TitlesApi():super(getToken:()async=>null);
 String? saved; int writes=0;
 @override Future<dynamic> get(String path,{Map<String,dynamic>? query,Map<String,dynamic>? headers})async=>{'family_id':1,'can_edit':'mother','mother_title':saved,'father_title':null,'mother_options':['ملكتنا','شمعة البيت'],'father_options':['الملك']};
 @override Future<dynamic> put(String path,{dynamic data,Map<String,dynamic>? headers})async {expect(headers?['X-Family-Id'],'1');expect(data['target'],'mother');saved=data['title'] as String?;writes++;return {};}
}
void main(){testWidgets('father chooses, persists and resets mother title',(tester)async{
 final api=TitlesApi();
 await tester.pumpWidget(ProviderScope(overrides:[apiClientProvider.overrideWithValue(api)],child:const MaterialApp(home:Scaffold(body:SingleChildScrollView(child:ParentTitlesPanel())))));
 await tester.pumpAndSettle();
 await tester.tap(find.text('شمعة البيت'));await tester.pumpAndSettle();
 await tester.ensureVisible(find.text('حفظ اللقب'));await tester.tap(find.text('حفظ اللقب'));await tester.pumpAndSettle();
 expect(api.saved,'شمعة البيت');expect(api.writes,1);
 await tester.ensureVisible(find.text('إعادة للاسم الأساسي'));await tester.tap(find.text('إعادة للاسم الأساسي'));await tester.pumpAndSettle();
 expect(api.saved,isNull);expect(api.writes,2);expect(tester.takeException(),isNull);
});}
