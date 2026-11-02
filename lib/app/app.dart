import '../core/widgets/family_live_notice.dart';
import 'family_live_refresh.dart';
import '../features/family/application/device_location_sharing.dart';
import '../features/health/application/health_session.dart';
import '../features/notifications/application/push_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'router.dart';
import 'theme.dart';

class FleetSaasDriverApp extends ConsumerWidget {
  const FleetSaasDriverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps the offline-queue-flush-on-reconnect listener alive for the
    // whole app lifetime — see providers.dart's docblock.
    ref.watch(connectivityFlushListenerProvider);
    ref.watch(pushSessionListenerProvider);
    ref.watch(healthSessionProvider);
    ref.watch(deviceLocationSharingProvider);

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'عيونك',
      scaffoldMessengerKey:familyMessengerKey,
      builder:(context,child)=>FamilyLiveRefresh(child:child ?? const SizedBox.shrink()),
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(familyGender:ref.watch(authControllerProvider).user?.familyGender),
      routerConfig: router,
      // Arabic-first (section 84's platform-wide ar/en/ku requirement) —
      // the driver app defaults to ar/RTL; en/ku are added the same way
      // once translated string tables exist (a cross-cutting concern
      // shared with the backend/web localization work, not unique to
      // mobile).
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
