import '../core/sync/family_offline.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/local_db/app_database.dart';
import '../core/local_db/offline_queue_repository.dart';
import '../core/location/location_service.dart';
import '../core/location/location_sync_client.dart';
import '../core/network/api_client.dart';
import '../core/storage/secure_token_store.dart';
import '../core/sync/sync_queue_service.dart';
import '../features/accidents/data/accidents_api.dart';
import '../features/admin/data/admin_drivers_api.dart';
import '../features/admin/data/admin_report_exports_api.dart';
import '../features/admin/data/admin_reports_api.dart';
import '../features/admin/data/admin_roles_api.dart';
import '../features/admin/data/admin_tracking_api.dart';
import '../features/admin/data/admin_trips_api.dart';
import '../features/admin/data/admin_users_api.dart';
import '../features/admin/data/admin_vehicle_types_api.dart';
import '../features/admin/data/admin_vehicles_api.dart';
import '../features/admin/data/audit_logs_api.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/application/auth_state.dart';
import '../features/auth/data/auth_api.dart';
import '../features/drivers/data/drivers_api.dart';
import '../features/family/data/family_api.dart';
import '../features/family/data/family_sos_action_handler.dart';
import '../features/family/data/family_sos_repository.dart';
import '../features/family_tasks/data/family_tasks_api.dart';
import '../features/notifications/data/notifications_api.dart';
import '../features/sos/data/sos_action_handler.dart';
import '../features/sos/data/sos_api.dart';
import '../features/sos/data/sos_repository.dart';
import '../features/trips/data/trip_action_handlers.dart';
import '../features/trips/data/trips_api.dart';
import '../features/trips/data/trips_repository.dart';
import '../features/vehicles/data/vehicles_api.dart';

/// Composition root — every provider below is a thin `Provider` that just
/// wires one class to its dependencies. Nothing here holds business
/// logic; that all lives in the classes being constructed.

final secureTokenStoreProvider = Provider<SecureTokenStore>((ref) => SecureTokenStore());

final familyOfflineProvider = Provider<FamilyOffline>((ref) {final store=FamilyOffline();ref.onDispose(store.dispose);return store;});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(getToken: ref.watch(secureTokenStoreProvider).readToken, familyOffline:ref.watch(familyOfflineProvider));
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);

  return db;
});

final offlineQueueRepositoryProvider = Provider<OfflineQueueRepository>((ref) {
  return OfflineQueueRepository(ref.watch(appDatabaseProvider));
});

final authApiProvider = Provider<AuthApi>((ref) => AuthApi(ref.watch(apiClientProvider)));

final tripsApiProvider = Provider<TripsApi>((ref) => TripsApi(ref.watch(apiClientProvider)));

final sosApiProvider = Provider<SosApi>((ref) => SosApi(ref.watch(apiClientProvider)));

final notificationsApiProvider = Provider<NotificationsApi>((ref) => NotificationsApi(ref.watch(apiClientProvider)));

final vehiclesApiProvider = Provider<VehiclesApi>((ref) => VehiclesApi(ref.watch(apiClientProvider)));

final driversApiProvider = Provider<DriversApi>((ref) => DriversApi(ref.watch(apiClientProvider)));

final familyApiProvider = Provider<FamilyApi>((ref) => FamilyApi(ref.watch(apiClientProvider)));

final familyTasksApiProvider = Provider<FamilyTasksApi>((ref) => FamilyTasksApi(ref.watch(apiClientProvider)));

final accidentsApiProvider = Provider<AccidentsApi>((ref) => AccidentsApi(ref.watch(apiClientProvider)));

final auditLogsApiProvider = Provider<AuditLogsApi>((ref) => AuditLogsApi(ref.watch(apiClientProvider)));

final adminVehiclesApiProvider = Provider<AdminVehiclesApi>((ref) => AdminVehiclesApi(ref.watch(apiClientProvider)));

final adminVehicleTypesApiProvider =
    Provider<AdminVehicleTypesApi>((ref) => AdminVehicleTypesApi(ref.watch(apiClientProvider)));

final adminDriversApiProvider = Provider<AdminDriversApi>((ref) => AdminDriversApi(ref.watch(apiClientProvider)));

final adminTripsApiProvider = Provider<AdminTripsApi>((ref) => AdminTripsApi(ref.watch(apiClientProvider)));

final adminUsersApiProvider = Provider<AdminUsersApi>((ref) => AdminUsersApi(ref.watch(apiClientProvider)));

final adminRolesApiProvider = Provider<AdminRolesApi>((ref) => AdminRolesApi(ref.watch(apiClientProvider)));

final adminPermissionsApiProvider =
    Provider<AdminPermissionsApi>((ref) => AdminPermissionsApi(ref.watch(apiClientProvider)));

final adminReportsApiProvider = Provider<AdminReportsApi>((ref) => AdminReportsApi(ref.watch(apiClientProvider)));

final adminReportExportsApiProvider =
    Provider<AdminReportExportsApi>((ref) => AdminReportExportsApi(ref.watch(apiClientProvider)));

final adminTrackingApiProvider = Provider<AdminTrackingApi>((ref) => AdminTrackingApi(ref.watch(apiClientProvider)));

/// Every actionType a PendingAction row can carry MUST have exactly one
/// handler registered here — see SyncQueueService's docblock.
final syncQueueServiceProvider = Provider<SyncQueueService>((ref) {
  return SyncQueueService(
    queue: ref.watch(offlineQueueRepositoryProvider),
    handlers: {
      ...tripActionHandlers(ref.watch(tripsApiProvider)),
      ...sosActionHandlers(ref.watch(sosApiProvider)),
      ...familySosActionHandlers(ref.watch(familyApiProvider)),
    },
  );
});

final tripsRepositoryProvider = Provider<TripsRepository>((ref) {
  return TripsRepository(
    api: ref.watch(tripsApiProvider),
    queue: ref.watch(offlineQueueRepositoryProvider),
    syncQueue: ref.watch(syncQueueServiceProvider),
  );
});

final sosRepositoryProvider = Provider<SosRepository>((ref) {
  return SosRepository(
    queue: ref.watch(offlineQueueRepositoryProvider),
    syncQueue: ref.watch(syncQueueServiceProvider),
  );
});

final familySosRepositoryProvider = Provider<FamilySosRepository>((ref) {
  return FamilySosRepository(
    queue: ref.watch(offlineQueueRepositoryProvider),
    syncQueue: ref.watch(syncQueueServiceProvider),
  );
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService(queue: ref.watch(offlineQueueRepositoryProvider));
});

final locationSyncClientProvider = Provider<LocationSyncClient>((ref) {
  return LocationSyncClient(queue: ref.watch(offlineQueueRepositoryProvider), client: ref.watch(apiClientProvider));
});

final connectivityStreamProvider = StreamProvider<ConnectivityResult>((ref) {
  return Connectivity().onConnectivityChanged;
});

/// Flushes the offline queue every time connectivity is restored — the
/// UI layer (app.dart) just needs to `ref.watch` this once at the root so
/// the listener is alive for the app's lifetime.
final connectivityFlushListenerProvider = Provider<void>((ref) {
  ref.listen(connectivityStreamProvider, (previous, next) {
    final hasConnection = next.valueOrNull != null && next.valueOrNull != ConnectivityResult.none;

    if (hasConnection) {
      ref.read(syncQueueServiceProvider).flush();
      ref.read(locationSyncClientProvider).flush();
    }
  });
});

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authApiProvider), ref.watch(secureTokenStoreProvider));
});

final pendingActionCountProvider = StreamProvider<int>((ref) {
  return ref.watch(tripsRepositoryProvider).watchPendingActionCount();
});
