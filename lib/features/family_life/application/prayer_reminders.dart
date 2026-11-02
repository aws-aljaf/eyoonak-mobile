import '../../../core/notifications/notification_display.dart';
import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as zones;
import 'package:timezone/timezone.dart' as tz;

class PrayerSchedule {
  static bool ready = false;
  static void initialize() {
    if (!ready) {
      zones.initializeTimeZones();
      ready = true;
    }
  }

  static Map<String, DateTime> times(Map<String, dynamic> prefs, DateTime date) {
    final params = switch (prefs['method']) {
      'karachi' => CalculationMethodParameters.karachi(),
      'umm_al_qura' => CalculationMethodParameters.ummAlQura(),
      'egyptian' => CalculationMethodParameters.egyptian(),
      _ => CalculationMethodParameters.muslimWorldLeague()
    };
    params.madhab = prefs['madhab'] == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
    final t = PrayerTimes(
        date: DateTime.utc(date.year, date.month, date.day),
        coordinates: Coordinates((prefs['latitude'] as num).toDouble(), (prefs['longitude'] as num).toDouble()),
        calculationParameters: params);
    return {'fajr': t.fajr, 'dhuhr': t.dhuhr, 'asr': t.asr, 'maghrib': t.maghrib, 'isha': t.isha};
  }

  static tz.Location zone(Map<String, dynamic> prefs) {
    initialize();
    return tz.getLocation(prefs['timezone'] as String);
  }
}

class PrayerReminders {
  static final instance = PrayerReminders();
  final plugin = NotificationDisplay.instance.plugin;
  bool initialized = false;
  Future<void> initialize() async {
    await NotificationDisplay.instance.initialize();
    initialized = true;
  }

  Future<void> clear() async {
    if (kIsWeb || (![TargetPlatform.android, TargetPlatform.iOS].contains(defaultTargetPlatform))) return;
    try {
      await initialize();
      for (var id = 87000; id < 87035; id++) {
        await plugin.cancel(id);
      }
    } catch (_) {/* A missing native plugin must never prevent logout. */}
  }

  Future<void> schedule(Map<String, dynamic> prefs, {required bool hideDetails, bool requestPermission = false}) async {
    if (kIsWeb || (![TargetPlatform.android, TargetPlatform.iOS].contains(defaultTargetPlatform))) return;
    await initialize();
    await clear();
    if (prefs['enabled'] != true || prefs['reminders'] != true) return;
    if (requestPermission) {
      final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final ios = plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final granted = android != null
          ? await android.requestNotificationsPermission()
          : await ios?.requestPermissions(alert: true, sound: true, badge: false);
      if (granted == false) throw StateError('اسمح بالإشعارات من إعدادات الجهاز.');
    }
    final zone = PrayerSchedule.zone(prefs), now = DateTime.now();
    final local = tz.TZDateTime.now(zone);
    var id = 87000;
    const labels = {'fajr': 'الفجر', 'dhuhr': 'الظهر', 'asr': 'العصر', 'maghrib': 'المغرب', 'isha': 'العشاء'};
    for (var day = 0; day < 7; day++) {
      final date = DateTime(local.year, local.month, local.day + day);
      for (final entry in PrayerSchedule.times(prefs, date).entries) {
        final current = id++;
        if (!entry.value.isAfter(now)) continue;
        await plugin.zonedSchedule(
            current,
            hideDetails ? 'تذكير من عيونك' : 'حان وقت صلاة ${labels[entry.key]}',
            hideDetails ? 'افتح التطبيق للاطلاع على تذكيرك.' : 'لحظة هدوء وطمأنينة 🕌',
            tz.TZDateTime.from(entry.value, zone),
            const NotificationDetails(
                android: AndroidNotificationDetails('eyoonak_prayer', 'تذكيرات صلاتي',
                    channelDescription: 'تذكيرات اختيارية خاصة بالمستخدم',
                    visibility: NotificationVisibility.private,
                    importance: Importance.defaultImportance),
                iOS: DarwinNotificationDetails()),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: '/our-home/prayer');
      }
    }
  }
}
