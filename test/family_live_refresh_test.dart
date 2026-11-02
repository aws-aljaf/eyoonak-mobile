import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:fleet_saas_driver/app/family_live_refresh.dart';
import 'package:fleet_saas_driver/app/providers.dart';
import 'package:fleet_saas_driver/app/router.dart';
import 'package:fleet_saas_driver/core/network/api_client.dart';
import 'package:fleet_saas_driver/core/storage/secure_token_store.dart';
import 'package:fleet_saas_driver/features/auth/data/auth_api.dart';
import 'package:fleet_saas_driver/features/auth/data/driver_user.dart';
import 'package:fleet_saas_driver/features/family/application/family_providers.dart';
import 'package:fleet_saas_driver/features/family_tasks/application/family_tasks_providers.dart';

class Store extends SecureTokenStore {
  @override
  Future<String?> readToken() async => 'synthetic-session';
  @override
  Future<void> saveDriverId(int? id) async {}
}

class Client extends ApiClient {
  Client() : super(getToken: () async => null);
  int flushes = 0;
  @override
  Future<void> flushFamilyOffline() async {
    flushes++;
  }
}

class Auth extends AuthApi {
  Auth(super.c);
  @override
  Future<DriverUser> me() async =>
      const DriverUser(id: 7, name: 'Parent', hasFamilyMembership: true);
}

void main() {
  testWidgets(
      'returning from background and another route refreshes without polling in background',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/connectivity'),(call)async=>'wifi');
    addTearDown(()=>tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/connectivity'),null));
    final client = Client();
    final router = GoRouter(routes: [
      GoRoute(
          path: '/', builder: (_, state) => const Scaffold(body: Text('HOME'))),
      GoRoute(
          path: '/other',
          builder: (_, state) => const Scaffold(body: Text('OTHER')))
    ]);
    final container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(client),
      authApiProvider.overrideWithValue(Auth(client)),
      secureTokenStoreProvider.overrideWithValue(Store()),
      routerProvider.overrideWithValue(router),
      connectivityStreamProvider.overrideWith((ref) => const Stream.empty()),
      familyTaskOccurrencesProvider.overrideWith((ref) async => []),
      todayFamilyTaskOccurrencesProvider.overrideWith((ref) async => []),
      myFamilyInvitationsProvider.overrideWith((ref) async => []),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
            routerConfig: router,
            builder: (_, child) => FamilyLiveRefresh(child: child!))));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    final before = client.flushes;
    router.push('/other');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(client.flushes, greaterThan(before));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final paused = client.flushes;
    await tester.pump(const Duration(seconds: 21));
    expect(client.flushes, paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(client.flushes, greaterThan(paused));
    final resumed = client.flushes;
    router.pop();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(client.flushes, greaterThan(resumed));
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    router.dispose();
    expect(tester.takeException(), isNull);
  });
}
