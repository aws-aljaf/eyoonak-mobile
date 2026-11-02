import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/family_motion.dart';
import '../application/device_pairing_code.dart';
import '../application/family_identity.dart';

class DevicePairingRedeemScreen extends ConsumerStatefulWidget {
  const DevicePairingRedeemScreen({super.key});
  @override ConsumerState<DevicePairingRedeemScreen> createState()=>_PairingState();
}
class _PairingState extends ConsumerState<DevicePairingRedeemScreen> {
  final form=GlobalKey<FormState>(), correctionForm=GlobalKey<FormState>();
  final code=TextEditingController(), correctedName=TextEditingController();
  String? viewer, relationship, error, successName;
  Map<String,dynamic>? preview;
  bool busy=false, success=false;
  @override void dispose(){code.dispose();correctedName.dispose();super.dispose();}
  void reset(){setState((){preview=null;error=null;correctedName.clear();});}
  String message(Object e)=> e is ApiException
      ? (e.fieldErrors.isEmpty?e.message:e.fieldErrors.values.expand((v)=>v).join(' · '))
      : 'تعذر إتمام الربط. حاول مرة أخرى.';
  Future<void> inspect() async {
    if(busy || form.currentState?.validate()!=true)return;
    setState((){busy=true;error=null;});
    try{
      final data=await ref.read(familyApiProvider).previewDevicePairing(code:normalizePairingCode(code.text));
      if(mounted)setState(()=>preview=data);
    }catch(e){if(mounted)setState(()=>error=message(e));}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> confirm() async {
    if(busy || preview==null || correctionForm.currentState?.validate()!=true)return;
    setState((){busy=true;error=null;});
    try{
      final data=await ref.read(familyApiProvider).confirmDevicePairing(
        code:normalizePairingCode(code.text),familyMemberId:preview!['family_member_id'] as int,
        viewerKinship:viewer!,deviceRelationship:relationship!,
        correctedName:preview!['name_needs_review']==true?correctedName.text.trim():null);
      if(mounted)setState((){success=true;successName=data['family_member_name'] as String?;});
    }catch(e){if(mounted)setState(()=>error=message(e));}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context){
    final target=preview;
    return Scaffold(appBar:AppBar(title:const Text('ربط الجهاز بالعائلة')),
      body:SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(
        crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        const FamilyHero(playful:false,title:'نعرف أصحاب البيت أولاً',
          subtitle:'حدد من أنت وصاحب هذا الجهاز، ثم راجع الاسم قبل تأكيد الربط.'),
        if(error!=null)Padding(padding:const EdgeInsets.symmetric(vertical:12),
          child:Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),
        if(success)...[
          const Icon(Icons.check_circle_outline,size:60,color:Colors.teal),
          const SizedBox(height:16),
          Text(readableFamilyName(successName)?'تم ربط هذا الجهاز بـ «$successName» بنجاح':'تم ربط الجهاز بالفرد المحدد بنجاح',textAlign:TextAlign.center),
          Text('صاحب الجهاز: ${deviceRelationships[relationship]}',textAlign:TextAlign.center),
          const SizedBox(height:16),
          FilledButton.icon(onPressed:()=>context.push('/our-home/location-sharing'),icon:const Icon(Icons.location_on_outlined),label:const Text('إعداد مشاركة الموقع')),
          const Text('تم الربط فقط. مشاركة الموقع لا تبدأ إلا بموافقة صاحب الجهاز من شاشة المشاركة.',textAlign:TextAlign.center),
        ]else if(target==null) Form(key:form,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('📱 هذه الشاشة تُفتح على هاتف الابن أو البنت لإدخال الكود الذي أنشأه الأب أو الأم من بطاقة الطفل. سجّل هنا بحساب صاحب هذا الهاتف.', style: TextStyle(fontWeight: FontWeight.bold)))),
          const SizedBox(height:16),
          DropdownButtonFormField<String>(initialValue:viewer,isExpanded:true,
            decoration:const InputDecoration(labelText:'أنا في العائلة'),
            items:[for(final e in familyKinships.entries)DropdownMenuItem(value:e.key,child:Text(e.value))],
            onChanged:busy?null:(v)=>setState(()=>viewer=v),validator:(v)=>v==null?'حدد من أنت في العائلة':null),
          const SizedBox(height:16),
          DropdownButtonFormField<String>(initialValue:relationship,isExpanded:true,
            decoration:const InputDecoration(labelText:'صاحب هذا الجهاز بالنسبة إليّ'),
            items:[for(final e in deviceRelationships.entries)DropdownMenuItem(value:e.key,child:Text(e.value))],
            onChanged:busy?null:(v)=>setState(()=>relationship=v),validator:(v)=>v==null?'حدد صاحب الجهاز':null),
          const SizedBox(height:16),
          TextFormField(controller:code,enabled:!busy,textAlign:TextAlign.center,textCapitalization:TextCapitalization.characters,
            maxLength:16,decoration:const InputDecoration(labelText:'كود الربط',hintText:'ABCD1234'),
            validator:(v)=>isPlausiblePairingCode(normalizePairingCode(v??''))?null:'أدخل كود الربط من ثمانية أحرف وأرقام'),
          const SizedBox(height:16),
          FilledButton(onPressed:busy?null:inspect,child:Text(busy?'جارِ التحقق…':'معاينة قبل الربط')),
        ]))else Form(key:correctionForm,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Text('راجع الربط قبل التأكيد',style:Theme.of(context).textTheme.titleLarge),
          const SizedBox(height:12),
          Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('أنا: ${familyKinships[viewer]}'),Text('هذا الجهاز: ${deviceRelationships[relationship]}'),
            Text('الفرد المحدد: ${target['family_member_name']??'الاسم يحتاج تصحيحاً'}'),
            if(target['relationship']!=null)Text('صفته في العائلة: ${target['relationship']}'),
          ]))),
          if(target['name_needs_review']==true)...[
            const Text('الاسم المسجّل غير واضح. تصحيحه يحتاج صلاحية تعديل الفرد؛ الكود ما زال غير مستخدم.'),
            if(target['can_correct_name']==true)
              TextFormField(controller:correctedName,enabled:!busy,maxLength:150,
                decoration:const InputDecoration(labelText:'الاسم الصحيح للفرد'),
                validator:(v)=>readableFamilyName(v)?null:'اكتب الاسم الصحيح بدون علامات استفهام')
            else const Text('اطلب من ولي الأمر تصحيح الاسم من أفراد عائلتي، ثم أعد المعاينة.'),
          ],
          const SizedBox(height:20),
          FilledButton(onPressed:busy || (target['name_needs_review']==true && target['can_correct_name']!=true)?null:confirm,
            child:Text(busy?'جارِ الربط…':'أؤكد ربط هذا الجهاز بهذا الشخص')),
          TextButton(onPressed:busy?null:reset,child:const Text('رجوع وتعديل الاختيار')),
          const Text('هذا الاختيار يعرّف الجهاز فقط، ولا يغيّر صلاحيات الحساب ولا يفعّل الموقع تلقائياً.'),
        ])),
      ])));
  }
}
