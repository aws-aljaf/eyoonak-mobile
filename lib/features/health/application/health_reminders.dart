import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../core/notifications/notification_display.dart';
import '../../family_life/application/prayer_reminders.dart';

List<DateTime> healthAlarmPlan(Map<String, dynamic> data, Map<String, dynamic>? cycle, DateTime now, int limit) {
  PrayerSchedule.initialize();
  final times = <DateTime>[];
  for (final raw in data['upcoming'] as List? ?? []) {
    final at = DateTime.tryParse((raw as Map)['scheduled_at'] as String? ?? '');
    if (at != null && at.isAfter(now)) times.add(at.toUtc());
  }
  if (cycle?['configured'] == true && cycle?['reminders'] == true) {
    final c = cycle!, date = DateTime.parse(cycle['next_start'] as String);
    final clock = (c['reminder_time'] as String).split(':').map(int.parse).toList();
    final at = tz.TZDateTime(tz.getLocation(c['timezone'] as String), date.year, date.month,
        date.day - (c['remind_days_before'] as int), clock[0], clock[1]);
    if (at.isAfter(now)) times.add(at.toUtc());
  }
  final sorted = times.toSet().toList()..sort();
  return sorted.take(limit).toList();
}

class HealthReminders {
  static final instance = HealthReminders();
  final plugin = NotificationDisplay.instance.plugin;
  Future<void> _tail = Future.value();
  int _generation = 0;
  int? activeUserId;
  Future<void> endSession() {
    activeUserId = null;
    return clear();
  }

  bool get supported => !kIsWeb && [TargetPlatform.android, TargetPlatform.iOS].contains(defaultTargetPlatform);
  Future<void> _queue(Future<void> Function() task) {
    final next = _tail.catchError((Object _) {}).then((_) => task());
    _tail = next;
    return next;
  }

  Future<void> _cancel() async {
    for (var id = 88000; id < 88050; id++) {
      await plugin.cancel(id);
    }
  }

  Future<void> clear() {
    _generation++;
    if (!supported) return Future.value();
    return _queue(() async {
      try {
        await NotificationDisplay.instance.initialize();
        await _cancel();
      } catch (_) {/* Logout must finish. */}
    });
  }

  Future<bool> requestPermission() async {
    if (!supported) return false;
    await NotificationDisplay.instance.initialize();
    final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    return await plugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, sound: true, badge: false) ??
        false;
  }

  Future<void> schedule(Map<String, dynamic> data, Map<String, dynamic>? cycle) {
    if (activeUserId == null || data['user_id'] != activeUserId) return Future.value();
    final generation = ++_generation;
    if (!supported) return Future.value();
    return _queue(() async {
      if (generation != _generation || data['user_id'] != activeUserId) return;
      await NotificationDisplay.instance.initialize();
      await _cancel();
      final plan = healthAlarmPlan(data, cycle, DateTime.now(), defaultTargetPlatform == TargetPlatform.iOS ? 24 : 48);
      for (var i = 0; i < plan.length; i++) {
        if (generation != _generation || data['user_id'] != activeUserId) return;
        await plugin.zonedSchedule(
            88000 + i,
            'تذكير خاص من عيونك',
            'افتح التطبيق للاطلاع على تذكيرك.',
            tz.TZDateTime.from(plan[i], tz.UTC),
            NotificationDetails(
                android: AndroidNotificationDetails('eyoonak_private_reminders_v2', 'تذكيراتي الخاصة',
                    channelDescription: 'نغمة تذكير تتكرر ثلاث مرات مع رجّاج متقطع',
                    importance: Importance.high, priority: Priority.high,
                    playSound: true,
                    sound: const RawResourceAndroidNotificationSound('eyoonak_reminder'),
                    enableVibration: true,
                    vibrationPattern: Int64List.fromList([0, 400, 300, 400, 1000, 400, 300, 400, 1000, 400, 300, 400]),
                    visibility: NotificationVisibility.private),
                iOS: const DarwinNotificationDetails()),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: 'health');
        if (generation != _generation) await plugin.cancel(88000 + i);
      }
    });
  }
}
