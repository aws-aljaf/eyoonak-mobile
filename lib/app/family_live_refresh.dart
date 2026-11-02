import 'package:connectivity_plus/connectivity_plus.dart';
import '../features/auth/application/auth_state.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers.dart';
import 'router.dart';
import '../features/family/application/family_providers.dart';
import '../features/family_tasks/application/family_tasks_providers.dart';

final familyRefreshRevisionProvider = StateProvider<int>((ref) => 0);

class FamilyLiveRefresh extends ConsumerStatefulWidget {
  const FamilyLiveRefresh({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<FamilyLiveRefresh> createState() => _FamilyLiveRefreshState();
}

class _FamilyLiveRefreshState extends ConsumerState<FamilyLiveRefresh>
    with WidgetsBindingObserver {
  Timer? timer, debounce;
  GoRouter? router;
  bool resumed = true, refreshing = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      if (!mounted) return;
      router = ref.read(routerProvider);
      router!.routerDelegate.addListener(changed);
      changed();
    });
    timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (resumed) refresh();
    });
  }

  void changed() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 200), refresh);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    resumed = state == AppLifecycleState.resumed;
    if (resumed) refresh();
  }

  Future<void> refresh() async {
    if (!mounted ||
        !resumed ||
        refreshing ||
        ref.read(authControllerProvider).status != AuthStatus.authenticated) {
      return;
    }
    final owner = ref.read(authControllerProvider).user?.id;
    refreshing = true;
    try {
      try {
        final connection = await Connectivity().checkConnectivity();
        if (!mounted) return;
        ref.read(familyOfflineProvider).hasConnection =
            connection != ConnectivityResult.none;
      } catch (_) {
        /* Platforms without connectivity channels can still use the network. */
      }
      await ref.read(apiClientProvider).flushFamilyOffline();
      if (!mounted || ref.read(authControllerProvider).user?.id != owner) {
        return;
      }
      ref.invalidate(familyTaskOccurrencesProvider);
      ref.invalidate(todayFamilyTaskOccurrencesProvider);
      ref.invalidate(familyTasksProvider);
      ref.invalidate(familyRewardsProvider);
      ref.invalidate(pendingRedemptionsProvider);
      ref.invalidate(myRedemptionRequestsProvider);
      ref.invalidate(pendingApprovalOccurrencesProvider);
      ref.invalidate(myFamilyInvitationsProvider);
      ref.read(familyRefreshRevisionProvider.notifier).state++;
    } catch (_) {
      // A refresh never interrupts navigation; local pending actions remain retryable.
    } finally {
      refreshing = false;
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    debounce?.cancel();
    router?.routerDelegate.removeListener(changed);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(familyOfflineProvider);
    final auth = ref.watch(authControllerProvider);
    store.setUser(
        auth.status == AuthStatus.authenticated ? auth.user?.id : null);
    ref.listen(connectivityStreamProvider, (_, next) {
      final connection = next.valueOrNull;
      if (connection != null) {
        store.hasConnection = connection != ConnectivityResult.none;
        if (connection != ConnectivityResult.none) refresh();
      }
    });
    return AnimatedBuilder(
        animation: store,
        builder: (context, _) => Column(children: [
              if (store.offline ||
                  store.pendingCount > 0 ||
                  store.syncError != null)
                Material(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: SafeArea(
                        bottom: false,
                        child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child: Row(children: [
                              const Icon(Icons.cloud_sync_outlined, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(store.syncError ??
                                      (store.pendingCount > 0
                                          ? '${store.pendingCount} إنجاز محفوظ على الجهاز، بانتظار المزامنة. النقاط تُعتمد بعد الاتصال.'
                                          : 'بدون اتصال: نعرض آخر بيانات محفوظة، وقد تكون تغيّرت.'))),
                              if (store.syncError != null)
                                IconButton(
                                    tooltip: 'إغلاق الملاحظة',
                                    onPressed: store.dismissSyncError,
                                    icon: const Icon(Icons.close)),
                              TextButton(
                                  onPressed: store.syncing ? null : refresh,
                                  child: Text(
                                      store.syncing ? 'مزامنة…' : 'حاول الآن')),
                            ])))),
              Expanded(child: widget.child),
            ]));
  }
}
