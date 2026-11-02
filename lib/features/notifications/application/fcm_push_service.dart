import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../../core/network/api_client.dart';
import '../../../core/notifications/notification_display.dart';

@pragma('vm:entry-point')
Future<void> eyoonakBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Android displays the generic notification. Private details are fetched only after authenticated open.
}

class FcmPushService {
  FcmPushService(this.client);
  final ApiClient client;
  bool ready = false, attached = false, enabled = false, pendingOpen = false;
  int generation = 0;
  VoidCallback? openInbox;
  Future<void> Function(int? notificationId)? onDataChanged;
  StreamSubscription<String>? tokenRefresh;
  StreamSubscription<RemoteMessage>? foreground, opened;
  Future<bool>? initializing;
  Future<bool> initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    if (ready) return true;
    return initializing ??= _initialize();
  }

  Future<bool> _initialize() async {
    try {
      await Firebase.initializeApp();
      await NotificationDisplay.instance.initialize();
      FirebaseMessaging.onBackgroundMessage(eyoonakBackgroundMessage);
      NotificationDisplay.instance.openInbox = _open;
      foreground = FirebaseMessaging.onMessage.listen((m) async {
        if (!attached || !enabled) return;
        unawaited(onDataChanged
                ?.call(int.tryParse(m.data['notification_id'] ?? '')) ??
            Future<void>.value());
        final urgent = m.notification?.android?.channelId == 'eyoonak_urgent';
        final id = (int.tryParse(m.data['notification_id'] ?? '') ??
                    m.messageId.hashCode.abs()) %
                80000 +
            100000;
        await NotificationDisplay.instance.plugin.show(
            id,
            'عيونك',
            urgent
                ? 'عندك تنبيه مهم، افتح عيونك للاطلاع عليه.'
                : 'عندك تحديث جديد، افتح عيونك للاطلاع عليه.',
            NotificationDetails(
                android: AndroidNotificationDetails(
                    urgent ? 'eyoonak_urgent' : 'eyoonak_updates',
                    urgent ? 'تنبيهات عيونك المهمة' : 'إشعارات عيونك',
                    importance:
                        urgent ? Importance.high : Importance.defaultImportance,
                    priority: urgent ? Priority.high : Priority.defaultPriority,
                    visibility: NotificationVisibility.private)),
            payload: 'inbox');
      });
      opened = FirebaseMessaging.onMessageOpenedApp.listen((_) => _open());
      if (await FirebaseMessaging.instance.getInitialMessage() != null) { pendingOpen = true; }
      tokenRefresh =
          FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
        if (attached && enabled) {
          try {
            await client.put('/auth/push-token', data: {'push_token': token});
          } catch (_) {
            /* Refreshed tokens are retried on the next authenticated app start. */
          }
        }
      });
      ready = true;
      return true;
    } catch (_) {
      initializing = null;
      return false;
    }
  }

  void _open() {
    if (attached) unawaited(onDataChanged?.call(null) ?? Future<void>.value());
    if (attached) {
      openInbox?.call();
    } else {
      pendingOpen = true;
    }
  }

  Future<void> attach() async {
    final current = ++generation;
    attached = true;
    try {
      final p = await client.get('/notification-preferences');
      if (current != generation) return;
      enabled =
          (p as Map)['push_enabled'] == true && p['push_available'] == true;
      if (await initialize() && enabled && current == generation) {
        final permission =
            await FirebaseMessaging.instance.getNotificationSettings();
        if (permission.authorizationStatus == AuthorizationStatus.authorized ||
            permission.authorizationStatus == AuthorizationStatus.provisional) {
          await FirebaseMessaging.instance.setAutoInitEnabled(true);
          final token = await FirebaseMessaging.instance.getToken();
          if (token != null && current == generation) { await client.put('/auth/push-token', data: {'push_token': token}); }
        }
      }
      if (current == generation && pendingOpen) {
        pendingOpen = false;
        openInbox?.call();
      }
    } catch (_) {
      /* An unavailable push provider must never block authentication. */
    }
  }

  Future<void> setEnabled(bool value) async {
    generation++;
    if (value) {
      final preferences = await client.get('/notification-preferences') as Map;
      if (preferences['push_available'] != true) { throw StateError('إرسال إشعارات الهاتف قيد التجهيز.'); }
      if (!await initialize()) { throw StateError('تعذر تشغيل Firebase على هذه النسخة.'); }
      final settings = await FirebaseMessaging.instance
          .requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        throw StateError('اسمح بالإشعارات من إعدادات جهازك.');
      }
      await FirebaseMessaging.instance.setAutoInitEnabled(true);
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) throw StateError('تعذر تسجيل الجهاز للإشعارات.');
      await client.put('/auth/push-token', data: {'push_token': token});
      await client
          .put('/notification-preferences', data: {'push_enabled': true});
      enabled = true;
      attached = true;
    } else {
      enabled = false;
      await client
          .put('/notification-preferences', data: {'push_enabled': false});
      try {
        await client.put('/auth/push-token', data: {'push_token': null});
      } catch (_) {}
      if (ready) {
        await FirebaseMessaging.instance.setAutoInitEnabled(false);
        await FirebaseMessaging.instance.deleteToken();
        await NotificationDisplay.instance.clearPush();
      }
    }
  }

  Future<void> detach({bool unregister = true}) async {
    generation++;
    attached = false;
    enabled = false;
    pendingOpen = false;
    if (unregister) {
      try {
        await client.put('/auth/push-token', data: {'push_token': null});
      } catch (_) {}
    }
    if (ready) {
      try {
        await FirebaseMessaging.instance.setAutoInitEnabled(false);
        await FirebaseMessaging.instance.deleteToken();
        await NotificationDisplay.instance.clearPush();
      } catch (_) {}
    }
  }

  void dispose() {
    attached = false;
    enabled = false;
    generation++;
    onDataChanged = null;
    openInbox = null;
    tokenRefresh?.cancel();
    foreground?.cancel();
    opened?.cancel();
    NotificationDisplay.instance.openInbox = null;
  }
}
