import '../../../app/startup_intro.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/family_live_notice.dart';
import '../../../app/family_live_refresh.dart';
import '../../family_tasks/application/family_tasks_providers.dart';
import 'notifications_provider.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../../auth/application/auth_state.dart';
import 'fcm_push_service.dart';

final fcmPushServiceProvider = Provider<FcmPushService>((ref) {
  final s = FcmPushService(ref.read(apiClientProvider));
  s.openInbox = () {
    if (!ref.read(startupIntroCompleteProvider)) {
      s.pendingOpen = true;
      return;
    }
    ref.read(routerProvider).push('/notifications');
  };
  s.onDataChanged = (id) async {
    final userId = ref.read(authControllerProvider).user?.id;
    if (userId == null) return;
    ref.invalidate(familyTaskOccurrencesProvider);
    ref.invalidate(todayFamilyTaskOccurrencesProvider);
      ref.invalidate(familyTasksProvider);
      ref.invalidate(familyRewardsProvider);
      ref.invalidate(pendingRedemptionsProvider);
      ref.invalidate(myRedemptionRequestsProvider);
    ref.invalidate(pendingApprovalOccurrencesProvider);
    ref.invalidate(notificationsProvider);
    ref.read(familyRefreshRevisionProvider.notifier).state++;
    if (id != null) {
      try {
        final rows = await ref.read(notificationsApiProvider).list();
        if (ref.read(authControllerProvider).user?.id != userId) return;
        for (final row in rows) {
          if (row.id == id && row.type == 'task') {
            familyMessengerKey.currentState?.showSnackBar(SnackBar(
                content: Text(row.body), duration: const Duration(seconds: 5)));
            break;
          }
        }
      } catch (_) {}
    }
  };
  ref.onDispose(s.dispose);
  return s;
});
final pushSessionListenerProvider = Provider<void>((ref) {
  final service = ref.watch(fcmPushServiceProvider);
  ref.listen(startupIntroCompleteProvider, (_, done) {
    if (done && service.pendingOpen) {
      service.pendingOpen = false;
      service.openInbox?.call();
    }
  });
  ref.listen(authControllerProvider, (previous, next) {
    if (next.status == AuthStatus.authenticated) {
      if (previous?.status != AuthStatus.authenticated ||
          previous?.user?.id != next.user?.id) {
        unawaited(service.attach());
      }
    } else if (previous?.status == AuthStatus.authenticated) {
      unawaited(service.detach(unregister: false));
    }
  }, fireImmediately: true);
});
