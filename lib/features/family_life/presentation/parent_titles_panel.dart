import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../family/application/family_providers.dart';
import 'family_life_screen.dart' show lifeError;
class ParentTitlesPanel extends ConsumerStatefulWidget {
 const ParentTitlesPanel({super.key,this.onSaved});
 final Future<void> Function()? onSaved;
 @override
 ConsumerState<ParentTitlesPanel> createState()=>_ParentTitlesPanelState();
}
class _ParentTitlesPanelState extends ConsumerState<ParentTitlesPanel> {
 final title=TextEditingController();
 Map<String,dynamic>? data;
 String? error,notice;
 bool busy=false;
 int generation=0;
 @override
 void initState(){super.initState();Future.microtask(load);}
 @override
 void dispose(){generation++;title.dispose();super.dispose();}
 Map<String,dynamic> headers(int? id)=>id==null?{}:{'X-Family-Id':'$id'};
 Future<void> load() async {
  final g=++generation;
  if(mounted)setState(()=>error=null);
  try{
   final result=await ref.read(apiClientProvider).get('/family-life/parent-titles',headers:headers(ref.read(selectedFamilyIdProvider))) as Map;
   if(!mounted||g!=generation)return;
   setState((){data=Map<String,dynamic>.from(result);final target=data!['can_edit'];title.text=target==null?'':data!['${target}_title'] as String? ?? '';});
  }catch(e){if(mounted&&g==generation)setState(()=>error=lifeError(e));}
 }
 Future<void> save({bool reset=false}) async {
  if(busy||data?['can_edit']==null||(!reset&&title.text.trim().isEmpty))return;
  final g=generation,id=(data!['family_id'] as num).toInt(),target=data!['can_edit'];
  setState((){busy=true;error=null;notice=null;});
  try{
   await ref.read(apiClientProvider).put('/family-life/parent-titles',headers:headers(id),data:{'target':target,'title':reset?null:title.text.trim()});
   if(!mounted||g!=generation)return;
   await load();
   if(!mounted)return;
   setState(()=>notice='حُفظ اللقب لعائلتكم.');
   await widget.onSaved?.call();
  }catch(e){if(mounted&&g==generation)setState(()=>error=lifeError(e));}
  finally{if(mounted)setState(()=>busy=false);}
 }
 @override
 Widget build(BuildContext context){
  ref.listen<int?>(selectedFamilyIdProvider,(old,next){if(old!=next){setState((){data=null;notice=null;});load();}});
  final target=data?['can_edit'];
  return Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
   Text('ألقاب أهل البيت',style:Theme.of(context).textTheme.titleLarge),
   const Text('الأب يختار لقب الأم، والأم تختار لقب الأب. يبقى اللقب محفوظاً للعائلة وتبقى الأسماء الأصلية كما هي.'),
   if(error!=null) Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
   if(error!=null&&data==null) TextButton(onPressed:load,child:const Text('إعادة المحاولة')),
   if(data==null&&error==null)const Center(child:CircularProgressIndicator()),
   if(data!=null)...[
    ListTile(leading:const Icon(Icons.favorite_outline),title:Text('الأم: ${data!['mother_title']??'الأم'}')),
    ListTile(leading:const Icon(Icons.home_outlined),title:Text('الأب: ${data!['father_title']??'الأب'}')),
    if(target!=null)...[
     Text(target=='mother'?'شنو تحبون تنادون الأم؟':'شنو تحبون تنادون الأب؟'),
     Wrap(spacing:8,children:[for(final option in data!['${target}_options'] as List? ?? []) ChoiceChip(label:Text('$option'),selected:title.text==option,onSelected:busy?null:(_)=>setState(()=>title.text='$option'))]),
     TextField(controller:title,maxLength:40,enabled:!busy,decoration:const InputDecoration(labelText:'أو لقب من ذوقكم'),onChanged:(_)=>setState((){})),
     FilledButton(onPressed:busy||title.text.trim().isEmpty?null:()=>save(),child:Text(busy?'جارٍ الحفظ…':'حفظ اللقب')),
     TextButton(onPressed:busy?null:()=>save(reset:true),child:const Text('إعادة للاسم الأساسي')),
    ]else const Text('اختيار الألقاب متاح لحساب الأب أو الأم المحدد في عضوية العائلة.'),
   ],
   if(notice!=null)Text(notice!),
  ])));
 }
}
