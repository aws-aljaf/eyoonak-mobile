import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_saas_driver/app/providers.dart';
import 'package:fleet_saas_driver/core/network/api_client.dart';
import 'package:fleet_saas_driver/core/network/api_exception.dart';
import 'package:fleet_saas_driver/features/profile/presentation/account_deletion_screen.dart';
class DeletionApi extends ApiClient {
  DeletionApi() : super(getToken: () async => null);
  Map<String,dynamic>? current;
  List<dynamic> families=[];
  bool failRead=false;
  int reads=0,deletes=0;
  final posts=<Map<String,dynamic>>[];
  @override
  Future<dynamic> get(String path,{Map<String,dynamic>? query,Map<String,dynamic>? headers}) async {
    reads++;
    if(failRead) throw const ApiException(message:'Synthetic network error');
    return {'request':current,'owned_families':families};
  }
  @override
  Future<dynamic> post(String path,{dynamic data,Map<String,dynamic>? headers}) async {
    posts.add(Map<String,dynamic>.from(data as Map));
    if(path.endsWith('transfer-family')) { families=[]; return {'request':current,'owned_families':families}; }
    current={'status':'pending','delete_owned_families':data['delete_owned_families']==true};
    return {'request':current,'owned_families':families};
  }
  @override
  Future<dynamic> delete(String path,{Map<String,dynamic>? headers}) async {deletes++;current=null;return {'cancelled':true};}
}
Future<void> open(WidgetTester tester,DeletionApi api) async {
  await tester.pumpWidget(ProviderScope(overrides:[apiClientProvider.overrideWithValue(api)],child:const MaterialApp(home:AccountDeletionScreen())));
  await tester.pumpAndSettle();
}
void main(){
 testWidgets('reopening shows authoritative review status instead of a new password form',(tester) async {
  final api=DeletionApi()..current={'status':'reviewing','delete_owned_families':false};
  await open(tester,api);
  expect(find.text('طلبك قيد المراجعة. لم يُحذف الحساب بعد.'),findsOneWidget);
  expect(find.byType(TextFormField),findsNothing);expect(api.posts,isEmpty);
 });
 testWidgets('failed status read can be retried and never enables an unknown request',(tester) async {
  final api=DeletionApi()..failRead=true;await open(tester,api);
  expect(find.text('إعادة المحاولة'),findsOneWidget);expect(find.byType(TextFormField),findsNothing);
  api.failRead=false;await tester.tap(find.text('إعادة المحاولة'));await tester.pumpAndSettle();
  expect(find.byType(TextFormField),findsOneWidget);expect(api.reads,2);
 });
 testWidgets('password is validated and saved request survives reopening',(tester) async {
  final api=DeletionApi();await open(tester,api);
  await tester.tap(find.byType(CheckboxListTile));await tester.pumpAndSettle();
  final submit=find.widgetWithText(FilledButton,'إرسال طلب الحذف');await tester.ensureVisible(submit);await tester.tap(submit);await tester.pumpAndSettle();
  expect(find.text('أدخل كلمة المرور الحالية'),findsOneWidget);expect(api.posts,isEmpty);
  await tester.enterText(find.byType(TextFormField),'SyntheticPass123!');await tester.ensureVisible(submit);await tester.tap(submit);await tester.pumpAndSettle();
  expect(api.posts.single['confirmed'],true);expect(api.posts.single['delete_owned_families'],false);
  await tester.pumpWidget(const SizedBox());await tester.pumpAndSettle();await open(tester,api);
  expect(find.text('طلبك مسجّل بانتظار المراجعة. لم يُحذف الحساب بعد.'),findsOneWidget);expect(find.byType(TextFormField),findsNothing);
 });
 testWidgets('family erasure needs two explicit scopes and sends their confirmation',(tester) async {
  final api=DeletionApi()..families=[{'id':1,'name':'Synthetic family','transfer_candidates':[]}];await open(tester,api);
  final scope=find.widgetWithText(CheckboxListTile,'أطلب حذف العوائل التي أملكها مع الحساب');await tester.ensureVisible(scope);await tester.tap(scope);await tester.pumpAndSettle();
  final general=find.widgetWithText(CheckboxListTile,'أؤكد أنني أطلب حذف حسابي وبياناتي المرتبطة به');await tester.ensureVisible(general);await tester.tap(general);await tester.pumpAndSettle();
  final submit=find.widgetWithText(FilledButton,'إرسال طلب الحذف');expect(tester.widget<FilledButton>(submit).onPressed,isNull);
  final familyConfirm=find.widgetWithText(CheckboxListTile,'أفهم أن ملفات العائلة ومواقعها وأنشطتها المشتركة ستُحذف. حسابات الأشخاص الآخرين لا تُحذف بهذا الطلب');await tester.ensureVisible(familyConfirm);await tester.tap(familyConfirm);await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField),'SyntheticPass123!');await tester.ensureVisible(submit);await tester.tap(submit);await tester.pumpAndSettle();
  expect(api.posts.single['delete_owned_families'],true);expect(api.posts.single['family_deletion_confirmed'],true);
 });
 testWidgets('cancel dialog dismissal preserves request; explicit cancel withdraws it',(tester) async {
  final api=DeletionApi()..current={'status':'pending','delete_owned_families':false};await open(tester,api);
  await tester.tap(find.text('إلغاء طلب الحذف'));await tester.pumpAndSettle();await tester.tap(find.text('رجوع'));await tester.pumpAndSettle();expect(api.deletes,0);
  await tester.tap(find.text('إلغاء طلب الحذف'));await tester.pumpAndSettle();await tester.tap(find.widgetWithText(FilledButton,'إلغاء الطلب'));await tester.pumpAndSettle();expect(api.deletes,1);expect(find.byType(TextFormField),findsOneWidget);
 });
 testWidgets('pending owner request still allows explicit ownership transfer',(tester) async {
  final api=DeletionApi()..current={'status':'pending','delete_owned_families':false}
    ..families=[{'id':1,'name':'Synthetic family','transfer_candidates':[{'id':12,'name':'Parent two'}]}];
  await open(tester,api);
  await tester.tap(find.text('نقل الملكية'));await tester.pumpAndSettle();
  await tester.tap(find.byType(DropdownButtonFormField<int>));await tester.pumpAndSettle();
  await tester.tap(find.text('Parent two').last);await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField),'SyntheticPass123!');
  final consent=find.widgetWithText(CheckboxListTile,'أؤكد نقل الإدارة الكاملة إلى الحساب المختار');
  await tester.ensureVisible(consent);await tester.tap(consent);await tester.pumpAndSettle();
  final confirm=find.widgetWithText(FilledButton,'تأكيد نقل الملكية');await tester.ensureVisible(confirm);await tester.tap(confirm);await tester.pumpAndSettle();
  expect(api.posts.single['new_owner_id'],12);expect(api.posts.single['confirmed'],true);
  expect(find.text('طلبك مسجّل بانتظار المراجعة. لم يُحذف الحساب بعد.'),findsOneWidget);
  expect(find.text('نقل الملكية'),findsNothing);
 });
}
