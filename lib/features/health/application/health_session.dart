import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/notifications/notification_display.dart';
import '../../auth/application/auth_state.dart';
import 'health_reminders.dart';

bool _openedLaunch = false;
final healthSessionProvider = Provider<void>((ref) {
  var generation = 0;
  Future<void> refresh() async {
    final user = ref.read(authControllerProvider).user;
    if (ref.read(authControllerProvider).status != AuthStatus.authenticated || user == null || user.isSuperAdmin) {
      return;
    }
    final current = ++generation;
    try {
      final client = ref.read(apiClientProvider);
      final data = Map<String, dynamic>.from(await client.get('/personal/health/reminders') as Map);
      final cycle = data['can_use_cycle'] == true
          ? Map<String, dynamic>.from(await client.get('/personal/health/cycle') as Map)
          : null;
      if (current != generation ||
          ref.read(authControllerProvider).user?.id != user.id ||
          ref.read(authControllerProvider).status != AuthStatus.authenticated) {
        return;
      }
      await HealthReminders.instance.schedule(data, cycle);
      final display = NotificationDisplay.instance;
      display.openHealth = () {
        final state = ref.read(authControllerProvider);
        if (state.status == AuthStatus.authenticated && state.user?.isSuperAdmin != true) {
          ref.read(routerProvider).push('/our-home/reminders');
        }
      };
      if (HealthReminders.instance.supported) {
        final launch = await display.plugin.getNotificationAppLaunchDetails();
        if (launch?.didNotificationLaunchApp == true &&
            launch?.notificationResponse?.payload == 'health' &&
            !_openedLaunch) {
          _openedLaunch = true;
          display.openHealth?.call();
        }
      }
    } on ApiException catch (e) {
      if ((e.statusCode == 401 || e.statusCode == 403) && current == generation) await HealthReminders.instance.clear();
    } catch (_) {/* Offline: preserve previously scheduled private reminders. */}
  }

  final observer = _HealthLifecycle(() => unawaited(refresh()));
  WidgetsBinding.instance.addObserver(observer);
  ref.listen(authControllerProvider, (previous, next) {
    if (next.status == AuthStatus.authenticated && next.user?.isSuperAdmin != true) {
      HealthReminders.instance.activeUserId = next.user?.id;
      if (previous?.status != AuthStatus.authenticated || previous?.user?.id != next.user?.id) {
        unawaited(HealthReminders.instance.clear());
        unawaited(refresh());
      }
    } else {
      generation++;
      unawaited(HealthReminders.instance.endSession());
    }
  }, fireImmediately: true);
  ref.onDispose(() {
    generation++;
    WidgetsBinding.instance.removeObserver(observer);
    NotificationDisplay.instance.openHealth = null;
  });
});

class _HealthLifecycle extends WidgetsBindingObserver {
  _HealthLifecycle(this.refresh);
  final VoidCallback refresh;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }
}
