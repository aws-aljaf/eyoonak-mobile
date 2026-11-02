import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationDisplay {
  static final instance = NotificationDisplay();
  final plugin = FlutterLocalNotificationsPlugin();
  bool initialized = false;
  Future<void>? initialization;
  VoidCallback? openInbox;
  VoidCallback? openHealth;
  Future<void> initialize() async {
    if (initialized || kIsWeb || ![TargetPlatform.android, TargetPlatform.iOS].contains(defaultTargetPlatform)) return;
    return initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    await plugin.initialize(
        const InitializationSettings(
            android: AndroidInitializationSettings('ic_stat_eyoonak'),
            iOS: DarwinInitializationSettings(
                requestAlertPermission: false,
                requestBadgePermission: false,
                requestSoundPermission: false)), onDidReceiveNotificationResponse: (r) {
      if (r.payload == 'inbox') openInbox?.call();
      if (r.payload == 'health') openHealth?.call();
    });
    final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(const AndroidNotificationChannel('eyoonak_updates', 'إشعارات عيونك',
        description: 'تحديثات الأسرة', importance: Importance.defaultImportance));
    await android?.createNotificationChannel(const AndroidNotificationChannel('eyoonak_urgent', 'تنبيهات عيونك المهمة',
        description: 'تنبيهات السلامة', importance: Importance.high));
    initialized = true;
  }

  Future<void> clearPush() async {
    if (!initialized) return;
    final rows = await plugin.getActiveNotifications();
    for (final n in rows) {
      if (n.id != null && const ['eyoonak_updates', 'eyoonak_urgent'].contains(n.channelId)) {
        await plugin.cancel(n.id!, tag: n.tag);
      }
    }
  }
}
