import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'notification_display.dart';

/// Reads system permission only; never requests permission on opening settings.
class NotificationPermissionCard extends StatefulWidget {
  const NotificationPermissionCard(
      {super.key, this.checkPermission, this.openSettings});
  final Future<bool?> Function()? checkPermission;
  final Future<bool> Function()? openSettings;
  @override
  State<NotificationPermissionCard> createState() =>
      _NotificationPermissionCardState();
}

class _NotificationPermissionCardState extends State<NotificationPermissionCard>
    with WidgetsBindingObserver {
  bool? allowed;
  bool loading = true;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  @override
  void dispose() {
    generation++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> refresh() async {
    final current = ++generation;
    if (mounted) setState(() => loading = true);
    bool? result;
    try {
      if (widget.checkPermission != null) {
        result = await widget.checkPermission!();
      } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await NotificationDisplay.instance.initialize();
        result = await NotificationDisplay.instance.plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.areNotificationsEnabled();
      }
    } catch (_) {/* Unknown must not be displayed as granted. */}
    if (!mounted || current != generation) return;
    setState(() {
      allowed = result;
      loading = false;
    });
  }

  Future<void> openSettings() async {
    try {
      final opened =
          await (widget.openSettings?.call() ?? Geolocator.openAppSettings());
      if (!opened) throw StateError('settings unavailable');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('افتح إعدادات الهاتف ثم عيونك ثم الإشعارات.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Card(
          child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('إذن الإشعارات في هذا الجهاز',
              style: Theme.of(context).textTheme.titleMedium),
          Text(loading
              ? 'جارٍ فحص إذن النظام…'
              : allowed == true
                  ? 'مسموح من النظام؛ وصول التنبيهات يعتمد أيضاً على تفعيلها واتصال الجهاز وإعدادات قنوات الإشعارات.'
                  : allowed == false
                      ? 'الإشعارات محظورة من إعدادات الهاتف. فعّلها ثم ارجع إلى عيونك.'
                      : 'تعذر تحديد الإذن. راجع الإشعارات في إعدادات الهاتف.'),
          const Text(
              'قد تتأخر تذكيرات الدواء والصلاة بسبب وضع توفير الطاقة؛ لا نضمن وصولها في الدقيقة المحددة.'),
          Wrap(spacing: 8, children: [
            TextButton.icon(
                onPressed: openSettings,
                icon: const Icon(Icons.settings_outlined),
                label: const Text('إعدادات إشعارات الهاتف')),
            TextButton(
                onPressed: loading ? null : refresh,
                child: const Text('إعادة فحص الإذن')),
          ]),
        ]),
      ));
}
