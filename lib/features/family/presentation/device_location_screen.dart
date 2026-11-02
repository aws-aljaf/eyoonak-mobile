import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../application/device_location_sharing.dart';

class DeviceLocationScreen extends ConsumerWidget {
  const DeviceLocationScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(deviceLocationSharingProvider);
    return Scaffold(
        appBar: AppBar(title: const Text('مشاركة موقع جهازي')),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          const Icon(Icons.location_on_outlined, size: 60),
          const SizedBox(height: 18),
          Text(service.active ? 'المشاركة مفعّلة' : 'المشاركة متوقفة',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 14),
          const Text(
              'عند التشغيل يرسل هذا الجهاز موقعه إلى ملف الفرد المرتبط به في عائلتك، ويظهر إشعار دائم أثناء المشاركة على أندرويد. تستطيع إيقافها هنا أو بتسجيل الخروج.'),
          const SizedBox(height: 12),
          const Text(
              'ابدأ المشاركة والتطبيق مفتوح. قد يوقف النظام التحديثات إذا أُغلق التطبيق بالقوة أو قُيّد عمله. تحتاج مشاركة الموقع اتصالاً بالشبكة.'),
          if (service.error != null)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(service.error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error))),
          if (service.permissionBlocked || service.locationDisabled)
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  final opened = service.permissionBlocked
                      ? await service.openPermissionSettings()
                      : await service.openLocationSettings();
                  if (!opened && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'افتح إعدادات الهاتف يدوياً لتغيير الإذن أو تشغيل الموقع.')));
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'تعذر فتح الإعدادات. افتحها من إعدادات الهاتف.')));
                  }
                }
              },
              icon: const Icon(Icons.settings_outlined),
              label: Text(service.permissionBlocked
                  ? 'فتح إعدادات إذن الموقع'
                  : 'فتح إعدادات الموقع'),
            ),
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
            OutlinedButton.icon(
              icon: const Icon(Icons.battery_charging_full),
              label: const Text('إعدادات بطارية عيونك'),
              onPressed: () async {
                bool opened = false;
                try {
                  opened = await const MethodChannel(
                              'com.eyoonak.app/device_settings')
                          .invokeMethod<bool>('openBatterySettings') ??
                      false;
                } catch (_) {}
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(opened
                          ? 'من إعدادات عيونك افتح البطارية واختر غير مقيّد. القرار يبقى إلك؛ الإيقاف القسري قد يوقف التتبع.'
                          : 'افتح إعدادات الهاتف ← التطبيقات ← عيونك ← البطارية ← غير مقيّد.')));
                }
              },
            ),
          if (service.active && service.approximate == true)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                    'الموقع التقريبي مفعّل؛ قد تتأثر دقة المناطق الآمنة. يمكنك السماح بالموقع الدقيق من إعدادات التطبيق.')),
          if (service.active && service.accuracyMeters != null)
            Text(
                'هامش دقة آخر قراءة: نحو ${service.accuracyMeters!.round()} متر؛ الموقع ليس قياساً مضموناً.'),
          if (service.active)
            TextButton(
                onPressed: () async {
                  try {
                    await service.openPermissionSettings();
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content:
                              Text('افتح إعدادات الهاتف لتغيير دقة الموقع.')));
                    }
                  }
                },
                child: const Text('إعدادات دقة الموقع')),
          if (service.active)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                    'لاستمرار المشاركة عند قفل الشاشة، افتح إعدادات الهاتف ← التطبيقات ← عيونك ← البطارية واختر غير مقيّد عند الحاجة. قد يوقف النظام المشاركة عند فرض إيقاف التطبيق؛ افتحه لبدئها مجدداً.')),
          if (service.lastSent != null)
            Text(
                'آخر إرسال ناجح: ${TimeOfDay.fromDateTime(service.lastSent!).format(context)}'),
          const SizedBox(height: 20),
          FilledButton.icon(
              onPressed: service.starting
                  ? null
                  : () async {
                      if (service.active) {
                        await service.stop();
                        return;
                      }
                      final accepted = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('مشاركة موقع هذا الجهاز'),
                          content: const SingleChildScrollView(
                            child: Text(
                              'يجمع عيونك موقع هذا الجهاز ويرسله إلى خادم عيونك ليظهر للأشخاص المصرّح لهم في عائلتك، من أجل متابعة الموقع والمناطق الآمنة.\n\n'
                              'قد تستمر التحديثات عند استخدام تطبيق آخر ما دامت خدمة الموقع تعمل، ويظهر إشعار دائم أثناء المشاركة على أندرويد. يمكنك إيقاف المشاركة هنا أو بتسجيل الخروج، وسحب صلاحية الموقع من إعدادات الهاتف.\n\n'
                              'لن تبدأ المشاركة أو يُطلب إذن الموقع قبل موافقتك.',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: const Text('ليس الآن'),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              child: const Text('أوافق وأبدأ المشاركة'),
                            ),
                          ],
                        ),
                      );
                      if (accepted == true && context.mounted) {
                        await service.start();
                      }
                    },
              icon: Icon(service.active
                  ? Icons.stop_circle_outlined
                  : Icons.play_circle_outline),
              label: Text(service.starting
                  ? 'جارٍ التشغيل…'
                  : service.active
                      ? 'إيقاف المشاركة'
                      : 'بدء مشاركة موقعي مع العائلة')),
          TextButton(
              onPressed: service.active
                  ? null
                  : () => context.push('/family/pair-device'),
              child: const Text('ربط هذا الجهاز بفرد في العائلة'))
        ]));
  }
}
