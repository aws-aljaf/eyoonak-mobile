import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_saas_driver/app/providers.dart';
import 'package:fleet_saas_driver/core/network/api_client.dart';
import 'package:fleet_saas_driver/features/family_life/presentation/picture_story_reader.dart';

class StoryMediaApi extends ApiClient {
 StoryMediaApi():super(getToken:()async=>null);
 @override Future<List<int>> downloadBytes(String url,{Map<String,dynamic>? headers})async=>throw StateError('offline image');
}
Widget reader({int initial=1,List<int>? saved,Future<void> Function(int)? save, bool completed=false})=>ProviderScope(
 overrides:[apiClientProvider.overrideWithValue(StoryMediaApi())],
 child:MaterialApp(home:Scaffold(body:SingleChildScrollView(child:PictureStoryReader(
  headers:const {},initialPage:initial,completed:completed,
  pages:const [
   {'id':1,'url':'https://example.test/1','kind':'image','caption':'النص الأول'},
   {'id':2,'url':'https://example.test/2','kind':'image','caption':'النص الثاني'}],
  onPage:save??(p)async{saved?.add(p);},onFinish:()async{},
 )))));
void main(){
 testWidgets('reader turns RTL pages, preserves captions offline and saves the child page',(tester)async{
  tester.view.physicalSize=const Size(320,720);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  final saved=<int>[];
  await tester.pumpWidget(reader(saved:saved));await tester.pumpAndSettle();
  expect(find.text('النص الأول'),findsOneWidget);expect(find.text('أنهيت القصة'),findsNothing);
  await tester.tap(find.widgetWithText(FilledButton,'التالية'));await tester.pumpAndSettle();
  expect(find.text('النص الثاني'),findsOneWidget);expect(saved,[2]);
  expect(find.text('أنهيت القصة'),findsOneWidget);expect(tester.takeException(),isNull);
 });
 testWidgets('resume clamps to existing pages after editing and completed story stays completed',(tester)async{
  await tester.pumpWidget(reader(initial:30,completed:true));await tester.pumpAndSettle();
  expect(find.text('الصفحة 2 من 2'),findsOneWidget);
  expect(find.text('أحسنت! قرأت هذه القصة ✓'),findsOneWidget);
  expect(find.text('أنهيت القصة'),findsNothing);expect(tester.takeException(),isNull);
 });
 testWidgets('failed progress save is honest and can be retried',(tester)async{
  var attempts=0;
  await tester.pumpWidget(reader(save:(p)async{attempts++;if(attempts==1){throw StateError('offline');}}));await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton,'التالية'));await tester.pumpAndSettle();
  expect(find.textContaining('تعذر حفظ مكان القراءة'),findsOneWidget);
  await tester.tap(find.text('إعادة حفظ مكان القراءة'));await tester.pumpAndSettle();
  expect(attempts,2); expect(find.textContaining('تعذر حفظ مكان القراءة'),findsNothing);
  expect(tester.takeException(),isNull);
 });
}



