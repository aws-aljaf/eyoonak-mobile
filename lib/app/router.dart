import 'startup_intro.dart';
import 'auth_navigation.dart';
import '../features/auth/presentation/complete_membership_screen.dart';
import '../features/profile/presentation/account_deletion_screen.dart';
import '../features/family/presentation/device_location_screen.dart';
import '../features/health/presentation/health_screen.dart';
import '../features/admin/presentation/platform_admin_screen.dart';
import '../features/family_life/presentation/academy_screen.dart';
import '../features/family_life/presentation/prayer_screen.dart';
import '../features/family_life/presentation/family_life_screen.dart';
import '../features/exercises/presentation/exercises_screen.dart';
import '../features/exercises/presentation/exercise_detail_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/family_life/presentation/interest_world_screen.dart';

import '../features/accidents/presentation/accidents_list_screen.dart';
import '../features/accidents/presentation/report_accident_screen.dart';
import '../features/admin/data/admin_driver_models.dart';
import '../features/admin/data/admin_role_models.dart';
import '../features/admin/data/admin_user_models.dart';
import '../features/admin/data/admin_vehicle_models.dart';
import '../features/admin/presentation/admin_driver_detail_screen.dart';
import '../features/admin/presentation/admin_driver_form_screen.dart';
import '../features/admin/presentation/admin_drivers_screen.dart';
import '../features/admin/presentation/admin_home_screen.dart';
import '../features/admin/presentation/admin_report_exports_screen.dart';
import '../features/admin/presentation/admin_reports_screen.dart';
import '../features/admin/presentation/admin_role_detail_screen.dart';
import '../features/admin/presentation/admin_role_form_screen.dart';
import '../features/admin/presentation/admin_role_users_screen.dart';
import '../features/admin/presentation/admin_roles_screen.dart';
import '../features/admin/presentation/admin_tracking_screen.dart';
import '../features/admin/presentation/admin_trip_detail_screen.dart';
import '../features/admin/presentation/admin_trip_form_screen.dart';
import '../features/admin/presentation/admin_trips_screen.dart';
import '../features/admin/presentation/admin_user_assign_roles_screen.dart';
import '../features/admin/presentation/admin_user_detail_screen.dart';
import '../features/admin/presentation/admin_user_form_screen.dart';
import '../features/admin/presentation/admin_users_screen.dart';
import '../features/admin/presentation/admin_vehicle_assign_driver_screen.dart';
import '../features/admin/presentation/admin_vehicle_detail_screen.dart';
import '../features/admin/presentation/admin_vehicle_form_screen.dart';
import '../features/admin/presentation/admin_vehicles_screen.dart';
import '../features/admin/presentation/audit_logs_screen.dart';
import '../features/auth/presentation/devices_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/family_registration_screen.dart';
import '../features/auth/presentation/two_factor_screen.dart';
import '../features/dashboard/presentation/home_shell.dart';
import '../features/drivers/presentation/driver_documents_screen.dart';
import '../features/family/data/family_models.dart';
import '../features/family/presentation/device_pairing_generate_screen.dart';
import '../features/family/presentation/device_pairing_redeem_screen.dart';
import '../features/family/presentation/emergency_contacts_screen.dart';
import '../features/family/presentation/family_alerts_screen.dart';
import '../features/family/presentation/family_home_screen.dart';
import '../features/family/presentation/family_location_history_screen.dart';
import '../features/family/presentation/family_map_screen.dart';
import '../features/family/presentation/family_membership_screen.dart';
import '../features/family/presentation/family_timeline_screen.dart';
import '../features/family/presentation/safe_zone_editor_screen.dart';
import '../features/family/presentation/safe_zones_list_screen.dart';
import '../features/family/presentation/sos_events_screen.dart';
import '../features/family_tasks/data/family_task_models.dart';
import '../features/family_tasks/presentation/family_achievements_catalog_screen.dart';
import '../features/family_tasks/presentation/family_achievements_member_picker_screen.dart';
import '../features/family_tasks/presentation/family_approval_queue_screen.dart';
import '../features/family_tasks/presentation/family_challenge_detail_screen.dart';
import '../features/family_tasks/presentation/family_challenge_form_screen.dart';
import '../features/family_tasks/presentation/family_challenges_list_screen.dart';
import '../features/family_tasks/presentation/family_member_achievements_screen.dart';
import '../features/family_tasks/presentation/family_member_points_detail_screen.dart';
import '../features/family_tasks/presentation/family_points_screen.dart';
import '../features/family_tasks/presentation/family_reward_form_screen.dart';
import '../features/family_tasks/presentation/family_reward_redemptions_queue_screen.dart';
import '../features/family_tasks/presentation/family_reward_request_screen.dart';
import '../features/family_tasks/presentation/family_reward_requests_screen.dart';
import '../features/family_tasks/presentation/family_rewards_list_screen.dart';
import '../features/family_tasks/presentation/family_task_detail_screen.dart';
import '../features/family_tasks/presentation/family_task_form_screen.dart';
import '../features/family_tasks/presentation/family_tasks_list_screen.dart';
import '../features/family_tasks/presentation/family_weekly_report_screen.dart';
import '../features/family_tasks/presentation/my_family_tasks_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/trips/data/trip_models.dart';
import '../features/trips/presentation/pod_capture_screen.dart';
import '../features/trips/presentation/trip_detail_screen.dart';
import 'providers.dart';
import 'splash_screen.dart';

/// A fresh GoRouter is (deliberately, simply) rebuilt any time
/// AuthController's state changes — auth transitions are infrequent
/// (login/logout/2FA), so this is far cheaper to reason about than
/// wiring a ChangeNotifier bridge for a handful of state changes per
/// session. `redirect` below is the actual auth-gate.
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);
  ref.watch(startupIntroCompleteProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) => !ref.read(startupIntroCompleteProvider) ? (state.matchedLocation=='/splash'?null:'/splash') : authRedirect(authState, state.matchedLocation),
    routes: [
      GoRoute(path: '/complete-membership', builder: (context, state) => const CompleteMembershipScreen()),
      GoRoute(path: '/platform-admin', builder: (context, state) => const PlatformAdminScreen()),
      GoRoute(path: '/our-home/location-sharing', builder: (context, state) => const DeviceLocationScreen()),
      GoRoute(path: '/our-home/reminders', builder: (context, state) => const HealthScreen()),
      GoRoute(path: '/our-home/mother-cycle', builder: (context, state) => const HealthScreen(cycleOnly: true)),
      GoRoute(path: '/our-home/subscription', redirect: (context, state) => '/our-home'),
      GoRoute(path: '/our-home/interests', builder: (context, state) => const InterestWorldScreen()),
      GoRoute(
          path: '/our-home/interest-library', builder: (context, state) => const AcademyScreen(courseKey: 'interests')),
      GoRoute(path: '/our-home/stories', builder: (context, state) => const AcademyScreen(courseKey: 'stories')),
      GoRoute(path: '/our-home/etiquette', builder: (context, state) => const AcademyScreen(courseKey: 'etiquette')),
      GoRoute(path: '/our-home/english', builder: (context, state) => const AcademyScreen(courseKey: 'english')),
      GoRoute(path: '/our-home/academy', builder: (context, state) => const AcademyScreen()),
      GoRoute(path: '/our-home/diary', builder: (context, state) => const FamilyLifeScreen(section: 'diary')),
      GoRoute(path: '/our-home/memories', builder: (context, state) => const FamilyLifeScreen(section: 'memories')),
      GoRoute(path: '/our-home/kind-cards', builder: (context, state) => const FamilyLifeScreen(section: 'kind-cards')),
      GoRoute(path: '/our-home/occasions', builder: (context, state) => const FamilyLifeScreen(section: 'occasions')),
      GoRoute(path: '/our-home/prayer', builder: (context, state) => const PrayerScreen()),
      GoRoute(path: '/our-home', builder: (context, state) => const FamilyLifeScreen()),
      GoRoute(path: '/our-home/meals', builder: (context, state) => const FamilyLifeScreen(section: 'meals')),
      GoRoute(path: '/our-home/shopping', builder: (context, state) => const FamilyLifeScreen(section: 'shopping')),
      GoRoute(path: '/our-home/settings', builder: (context, state) => const FamilyLifeScreen(section: 'settings')),
      GoRoute(path: '/exercises', builder: (context, state) => const ExercisesScreen()),
      GoRoute(
          path: '/exercises/:id',
          builder: (context, state) => ExerciseDetailScreen(
              exerciseId: int.parse(state.pathParameters['id']!),
              memberId: int.parse(state.uri.queryParameters['memberId']!))),
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/register-family', builder: (context, state) => const FamilyRegistrationScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/2fa', builder: (context, state) => const TwoFactorScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomeShell()),
      // No permission gate on either admin route itself — same
      // "the request is the gate" convention as every family screen:
      // `AdminHomeScreen` only ever renders a tile for a section this
      // account's own `permissions` already include, and
      // `AuditLogController::index()` is what actually enforces
      // `audit_logs.view` server-side.
      GoRoute(path: '/admin', builder: (context, state) => const AdminHomeScreen()),
      GoRoute(path: '/admin/audit-logs', builder: (context, state) => const AuditLogsScreen()),
      // Same no-gate-on-the-route convention as `/admin/audit-logs` above
      // — `VehiclePolicy::viewAny()`/`::view()` are what actually enforce
      // `vehicles.view` server-side, and the only entry point
      // (`AdminHomeScreen`) never renders the "المركبات" tile that reaches
      // either route unless that permission is already present.
      GoRoute(path: '/admin/vehicles', builder: (context, state) => const AdminVehiclesScreen()),
      // `vehicles.create` is a separate permission from `vehicles.view`
      // (see `AdminVehiclesScreen`'s own docblock) — the "+" FAB there is
      // the only entry point, and is itself gated on that permission, so
      // this route carries no gate of its own either. Literal `new`
      // declared before the `:id` wildcard below, same convention as
      // every other feature in this file (`/family/tasks/new` etc.).
      GoRoute(path: '/admin/vehicles/new', builder: (context, state) => const AdminVehicleFormScreen()),
      GoRoute(
        path: '/admin/vehicles/:id',
        builder: (context, state) => AdminVehicleDetailScreen(vehicleId: int.parse(state.pathParameters['id']!)),
      ),
      // `extra` carries the full `AdminVehicle` already fetched by
      // `AdminVehicleDetailScreen` — same "don't re-fetch what the caller
      // already has in hand" convention as `/family/tasks/:id/edit` above.
      // No gate of its own — reached only from that screen's "تعديل" icon,
      // itself gated on `vehicles.edit`.
      GoRoute(
        path: '/admin/vehicles/:id/edit',
        builder: (context, state) => AdminVehicleFormScreen(vehicle: state.extra as AdminVehicle?),
      ),
      // "تعيين سائق" — reached only from `AdminVehicleDetailScreen`'s own
      // icon, itself gated on `vehicles.edit`, so this route carries no
      // gate either. `currentDriverId` arrives as a query parameter
      // (rather than `extra`) because it travels alongside the `:id` path
      // segment in a single `context.push` call there; an empty string
      // means "no current driver" and must not be handed to `int.parse`.
      GoRoute(
        path: '/admin/vehicles/:id/assign-driver',
        builder: (context, state) {
          final rawCurrentDriverId = state.uri.queryParameters['currentDriverId'];

          return AdminVehicleAssignDriverScreen(
            vehicleId: int.parse(state.pathParameters['id']!),
            currentDriverId:
                (rawCurrentDriverId == null || rawCurrentDriverId.isEmpty) ? null : int.parse(rawCurrentDriverId),
          );
        },
      ),
      // Same no-gate-on-the-route convention as `/admin/vehicles` above —
      // `DriverPolicy::viewAny()`/`::view()` enforce `drivers.view`
      // server-side, and `AdminHomeScreen`'s "السائقون" tile is the only
      // entry point.
      GoRoute(path: '/admin/drivers', builder: (context, state) => const AdminDriversScreen()),
      // `drivers.create` is a separate permission from `drivers.view` (see
      // `AdminDriversScreen`'s own docblock) — the "+" FAB there is the
      // only entry point, itself gated on that permission, so this route
      // carries no gate of its own either. Literal `new` declared before
      // the `:id` wildcard below, same convention as every other feature
      // in this file.
      GoRoute(path: '/admin/drivers/new', builder: (context, state) => const AdminDriverFormScreen()),
      GoRoute(
        path: '/admin/drivers/:id',
        builder: (context, state) => AdminDriverDetailScreen(driverId: int.parse(state.pathParameters['id']!)),
      ),
      // `extra` carries the full `AdminDriver` already fetched by
      // `AdminDriverDetailScreen` — same "don't re-fetch what the caller
      // already has in hand" convention as `/admin/vehicles/:id/edit`
      // above. No gate of its own — reached only from that screen's
      // "تعديل" icon, itself gated on `drivers.edit`.
      GoRoute(
        path: '/admin/drivers/:id/edit',
        builder: (context, state) => AdminDriverFormScreen(driver: state.extra as AdminDriver?),
      ),
      // Same no-gate-on-the-route convention as `/admin/vehicles`/
      // `/admin/drivers` above — `TripPolicy::viewAny()`/`::view()`
      // enforce `trips.view` server-side, and `AdminHomeScreen`'s
      // "إدارة الرحلات" tile is the only entry point.
      GoRoute(path: '/admin/trips', builder: (context, state) => const AdminTripsScreen()),
      // `trips.create` is a separate permission from `trips.view` (see
      // `AdminTripsScreen`'s own docblock) — the "+" FAB there is the only
      // entry point, itself gated on that permission, so this route carries
      // no gate of its own either. Literal `new` declared before the `:id`
      // wildcard below, same convention as every other feature in this file.
      GoRoute(path: '/admin/trips/new', builder: (context, state) => const AdminTripFormScreen()),
      GoRoute(
        path: '/admin/trips/:id',
        builder: (context, state) => AdminTripDetailScreen(tripId: int.parse(state.pathParameters['id']!)),
      ),
      // `extra` carries the full `Trip` already fetched by
      // `AdminTripDetailScreen` — same "don't re-fetch what the caller
      // already has in hand" convention as `/admin/drivers/:id/edit` above.
      // No gate of its own — reached only from that screen's "تعديل" icon,
      // itself gated on `trips.edit` AND `trip.isCoreEditable`.
      GoRoute(
        path: '/admin/trips/:id/edit',
        builder: (context, state) => AdminTripFormScreen(trip: state.extra as Trip?),
      ),
      // Same no-gate-on-the-route convention as `/admin/vehicles`/
      // `/admin/drivers`/`/admin/trips` above — `UserPolicy::viewAny()`/
      // `::view()` enforce `users.view` server-side, and `AdminHomeScreen`'s
      // "المستخدمون" tile is the only entry point.
      GoRoute(path: '/admin/users', builder: (context, state) => const AdminUsersScreen()),
      // `users.create` is a separate permission from `users.view` (see
      // `AdminUsersScreen`'s own docblock) — the "+" FAB there is the only
      // entry point, itself gated on that permission, so this route carries
      // no gate of its own either. Literal `new` declared before the `:id`
      // wildcard below, same convention as every other feature in this file.
      GoRoute(path: '/admin/users/new', builder: (context, state) => const AdminUserFormScreen()),
      GoRoute(
        path: '/admin/users/:id',
        builder: (context, state) => AdminUserDetailScreen(userId: int.parse(state.pathParameters['id']!)),
      ),
      // `extra` carries the full `AdminUser` already fetched by
      // `AdminUserDetailScreen` — same "don't re-fetch what the caller
      // already has in hand" convention as `/admin/vehicles/:id/edit` above.
      // No gate of its own — reached only from that screen's "تعديل" icon,
      // itself gated on `users.edit`.
      GoRoute(
        path: '/admin/users/:id/edit',
        builder: (context, state) => AdminUserFormScreen(user: state.extra as AdminUser?),
      ),
      // "الأدوار" — reached only from `AdminUserDetailScreen`'s own icon,
      // itself gated on `users.edit`, so this route carries no gate either.
      // `extra` carries the full `AdminUser` (roles come as slugs on it,
      // matched against the role catalogue inside the screen itself — see
      // its own docblock).
      GoRoute(
        path: '/admin/users/:id/roles',
        builder: (context, state) => AdminUserAssignRolesScreen(user: state.extra as AdminUser),
      ),
      // Same no-gate-on-the-route convention above — `RolePolicy::viewAny()`/
      // `::view()` enforce `settings.manage` server-side, and
      // `AdminHomeScreen`'s "الأدوار والصلاحيات" tile is the only entry
      // point.
      GoRoute(path: '/admin/roles', builder: (context, state) => const AdminRolesScreen()),
      // `settings.manage` is also `RolePolicy::create()`'s own requirement
      // (see `AdminRolesScreen`'s own docblock for why the FAB there is
      // effectively always visible once this route is reachable at all) —
      // the "+" FAB is the only entry point, itself gated on that
      // permission, so this route carries no gate of its own either.
      // Literal `new` declared before the `:id` wildcard below, same
      // convention as every other feature in this file.
      GoRoute(path: '/admin/roles/new', builder: (context, state) => const AdminRoleFormScreen()),
      GoRoute(
        path: '/admin/roles/:id',
        builder: (context, state) => AdminRoleDetailScreen(roleId: int.parse(state.pathParameters['id']!)),
      ),
      // `extra` carries the full `AdminRole` already fetched by
      // `AdminRoleDetailScreen` — same "don't re-fetch what the caller
      // already has in hand" convention as `/admin/users/:id/edit` above.
      // No gate of its own — reached only from that screen's "تعديل" icon,
      // itself gated on `role.isEditable`.
      GoRoute(
        path: '/admin/roles/:id/edit',
        builder: (context, state) => AdminRoleFormScreen(role: state.extra as AdminRole?),
      ),
      GoRoute(
        path: '/admin/roles/:id/users',
        builder: (context, state) => AdminRoleUsersScreen(roleId: int.parse(state.pathParameters['id']!)),
      ),
      // Same no-gate-on-the-route convention as `/admin/vehicles`/
      // `/admin/drivers`/`/admin/trips`/`/admin/users`/`/admin/roles`
      // above — the whole `reports/*` route group's `permission:
      // reports.view` middleware enforces access server-side, and
      // `AdminHomeScreen`'s "التقارير" tile is the only entry point.
      GoRoute(path: '/admin/reports', builder: (context, state) => const AdminReportsScreen()),
      // Reached from `AdminReportsScreen`'s own app bar actions (both the
      // "تصدير" button that creates a new export and the "سجل التصدير"
      // history icon) — no separate route gate, same reasoning as
      // `/admin/reports` above plus `AdminReportExportsScreen`'s own
      // docblock (`GET /reports/exports` only requires `reports.view`).
      GoRoute(path: '/admin/reports/exports', builder: (context, state) => const AdminReportExportsScreen()),
      // Same no-gate-on-the-route convention as `/admin/reports` above —
      // `LocationController::live()` enforces `tracking.view` server-side
      // itself (`abort_unless(...)`, not a policy class — see that
      // controller's own docblock), and `AdminHomeScreen`'s "التتبع الحي"
      // tile is the only entry point.
      GoRoute(path: '/admin/tracking', builder: (context, state) => const AdminTrackingScreen()),
      GoRoute(path: '/family', builder: (context, state) => const FamilyHomeScreen()),
      GoRoute(path: '/family/map', builder: (context, state) => const FamilyMapScreen()),
      // No permission gate on the route itself, same no-gate-on-the-route
      // convention as `/family/alerts`/`/family/emergency-contacts` below —
      // `FamilyMembershipScreen` defers entirely to `FamilyRelationshipPolicy`
      // via the API calls it makes (viewAny is broad — any active member —
      // while invite/edit/remove are separately gated per-control inside the
      // screen on the account's own role). The entry point on
      // `FamilyHomeScreen` has no permission gate either, matching that
      // policy's own broad viewAny — everyone in the family can at least see
      // the roster.
      GoRoute(path: '/family/membership', builder: (context, state) => const FamilyMembershipScreen()),
      // No permission gate here either (mirrors every other route added
      // this way in this file): FamilyTimelineController's only blanket
      // gate is FamilyMemberPolicy::viewAny() (family_tracking.view) — the
      // same permission already required to reach FamilyHomeScreen's own
      // roster at all, so this route is always reachable once that far.
      // Per-row visibility (capability/supervisor scoping) is enforced
      // entirely server-side inside the controller — see
      // FamilyTimelineScreen's own docblock.
      GoRoute(path: '/family/timeline', builder: (context, state) => const FamilyTimelineScreen()),
      // No permission gate on the route itself — same reasoning as every
      // other family screen: `FamilyApi.alerts()` only ever gets called
      // once `alerts.view` is already confirmed present (see
      // FamilyHomeScreen's bell, the only entry point into this route),
      // and the resolve button inside is separately gated on
      // `alerts.resolve` per-card, not per-route.
      GoRoute(path: '/family/alerts', builder: (context, state) => const FamilyAlertsScreen()),
      // No permission gate on the route itself, same convention as
      // `/family/alerts` above — `EmergencyContactsScreen` defers entirely
      // to what `EmergencyContactPolicy` lets the API calls it makes
      // through, and the entry point on FamilyHomeScreen is already gated
      // on `sos.view`/`sos.manage_contacts` (see that screen's docblock).
      GoRoute(path: '/family/emergency-contacts', builder: (context, state) => const EmergencyContactsScreen()),
      // Same no-gate-on-the-route convention as the two routes above —
      // `SosEventsScreen` defers to `SosEventPolicy` (also `sos.*`, but
      // `sos.view`/`sos.acknowledge`/`sos.resolve` specifically — distinct
      // from `sos.manage_contacts` above) via the API calls it makes. The
      // entry point on FamilyHomeScreen is gated on `sos.view` alone (see
      // that screen's docblock) since acknowledge/resolve are separately
      // gated per-row inside the screen.
      GoRoute(path: '/family/sos-events', builder: (context, state) => const SosEventsScreen()),
      // PR-65 (Family Tasks & Achievements, mobile foundation): the shared
      // task board — no permission gate on the route itself, same
      // no-gate-on-the-route convention as every other family screen:
      // `FamilyTaskPolicy::viewAny()` is unconditionally true (any active
      // member may list), and create/edit/delete affordances inside
      // `FamilyTasksListScreen`/`FamilyTaskDetailScreen` are separately
      // gated on `canManageFamilyTasksProvider` (owner/parent/admin for
      // the selected family) — real enforcement stays
      // `FamilyTaskPolicy::create()`/`::update()`/`::delete()` server-side.
      // Literal segments (`new`, `mine`) are declared before the `:id`
      // wildcard below, matching the backend's own
      // `family-tasks/weekly-report`-before-`{family_task}` ordering
      // rationale in `routes/api_v1.php`, even though go_router's own
      // matcher uses declaration order; literal task routes must precede params.
      GoRoute(path: '/family/tasks', builder: (context, state) => const FamilyTasksListScreen()),
      GoRoute(path: '/family/tasks/new', builder: (context, state) => const FamilyTaskFormScreen()),
      // "مهامي" — a plain member/child's own occurrences, or the whole
      // family's for an owner/parent/admin (the backend decides which per
      // account, see `FamilyTaskOccurrenceController::index()`'s own
      // docblock) — reachable for every account, no gate here either.
      GoRoute(path: '/family/tasks/mine', builder: (context, state) => const MyFamilyTasksScreen()),
      GoRoute(path: '/family/tasks/approvals', builder: (context, state) => const FamilyApprovalQueueScreen()),
      GoRoute(path: '/family/tasks/weekly-report', builder: (context, state) => const FamilyWeeklyReportScreen()),
      GoRoute(
        path: '/family/tasks/:id',
        builder: (context, state) => FamilyTaskDetailScreen(taskId: int.parse(state.pathParameters['id']!)),
      ),
      // `extra` carries the full `FamilyTaskModel` already fetched by
      // `FamilyTaskDetailScreen` — same "don't re-fetch what the caller
      // already has in hand" reasoning as `/family/safe-zones/:id/edit`
      // carrying `existingZone` the same way.
      GoRoute(
        path: '/family/tasks/:id/edit',
        builder: (context, state) => FamilyTaskFormScreen(existing: state.extra as FamilyTaskModel),
      ),
      // PR-66 (Family Tasks & Achievements, mobile): "قائمة انتظار موافقة
      // الوالد" — no permission gate on the route itself, same
      // no-gate-on-the-route convention as every other family screen: the
      // only entry point is `FamilyTasksListScreen`'s own app-bar icon,
      // rendered only when `canManageFamilyTasksProvider` is true, and the
      // real boundary is `FamilyTaskOccurrencePolicy::approve()`/`::reject()`
      // server-side (manager-only, no self-decision branch at all — see
      // that policy's docblock).
      // PR-70 (Family Tasks & Achievements, mobile, final PR of the plan):
      // "التقرير الأسبوعي" — no permission gate on the route itself, same
      // no-gate-on-the-route convention as every other family_tasks screen:
      // `FamilyTaskPolicy::viewAny()` is unconditionally true (any active
      // member may view the whole family's weekly report, not just a
      // manager), and the backend itself is the real boundary — see
      // `FamilyWeeklyReportController`'s own docblock. Path deliberately
      // mirrors the backend's own literal `family-tasks/weekly-report`
      // segment name (`routes/api_v1.php`), same "same segment name as the
      // API" convention `/family/tasks/mine` already follows for
      // `GET /family-task-occurrences`'s "مهامي" concept.
      // PR-66: "رصيد النقاط لكل فرد" — the member picker. No permission
      // gate on the route itself either; `FamilyPointsScreen` narrows the
      // roster it renders to rows this account may actually open (its own
      // docblock explains why), and the real, stricter boundary stays
      // `FamilyMemberPointsController::show()` server-side.
      GoRoute(path: '/family/points', builder: (context, state) => const FamilyPointsScreen()),
      // `extra` carries the member's name only (for the AppBar title) —
      // same convention as `/family/members/:id/history` below: the screen
      // itself re-fetches the breakdown by id.
      GoRoute(
        path: '/family/points/:id',
        builder: (context, state) => FamilyMemberPointsDetailScreen(
          familyMemberId: int.parse(state.pathParameters['id']!),
          memberName: state.extra as String? ?? 'فرد العائلة',
        ),
      ),
      // PR-67 (Family Tasks & Achievements, mobile): the reward catalog —
      // no permission gate on the route itself, same no-gate-on-the-route
      // convention as `/family/tasks` above: `FamilyRewardPolicy::viewAny()`
      // is unconditionally true (any active member may browse), and
      // create/edit/archive/delete affordances inside
      // `FamilyRewardsListScreen`/`FamilyRewardFormScreen` are separately
      // gated on `canManageFamilyTasksProvider` — real enforcement stays
      // `FamilyRewardPolicy::create()`/`::update()`/`::delete()`
      // server-side. Literal segments (`new`, `mine`, `redemptions`)
      // declared before the `:id` wildcards below, same convention as
      // `/family/tasks[...]`.
      GoRoute(path: '/family/rewards', builder: (context, state) => const FamilyRewardsListScreen()),
      GoRoute(path: '/family/rewards/new', builder: (context, state) => const FamilyRewardFormScreen()),
      // "طلباتي" — this account's own redemption request history, any
      // status. Reachable for every account, no gate here either — see
      // `myRedemptionRequestsProvider`'s own docblock for how it narrows
      // per viewer.
      GoRoute(path: '/family/rewards/mine', builder: (context, state) => const FamilyRewardRequestsScreen()),
      // PR-67: "قائمة انتظار موافقة استبدال المكافآت" — no permission gate
      // on the route itself, same no-gate-on-the-route convention as
      // `/family/tasks/approvals`: the only entry point is
      // `FamilyRewardsListScreen`'s own app-bar icon, rendered only when
      // `canManageFamilyTasksProvider` is true, and the real boundary is
      // `FamilyRewardRedemptionPolicy::approve()`/`::reject()` server-side
      // (manager-only, no self-decision branch at all).
      GoRoute(
        path: '/family/rewards/redemptions',
        builder: (context, state) => const FamilyRewardRedemptionsQueueScreen(),
      ),
      // `extra` carries the full `FamilyRewardModel` already fetched by
      // `FamilyRewardsListScreen` — same "don't re-fetch what the caller
      // already has in hand" reasoning as `/family/tasks/:id/edit` carrying
      // `FamilyTaskModel` the same way.
      GoRoute(
        path: '/family/rewards/:id/edit',
        builder: (context, state) => FamilyRewardFormScreen(existing: state.extra as FamilyRewardModel),
      ),
      // "طلب استبدال" — reached by tapping an active reward card, for any
      // active family member. Same `extra`-carries-the-model convention as
      // the edit route above.
      GoRoute(
        path: '/family/rewards/:id/request',
        builder: (context, state) => FamilyRewardRequestScreen(reward: state.extra as FamilyRewardModel),
      ),
      // PR-68 (Family Tasks & Achievements, mobile): the family-wide
      // challenge catalog — no permission gate on the route itself, same
      // no-gate-on-the-route convention as `/family/tasks`/`/family/rewards`
      // above: `FamilyChallengePolicy::viewAny()` is unconditionally true
      // (any active member may browse and join), and create/edit/delete
      // affordances inside `FamilyChallengesListScreen`/
      // `FamilyChallengeFormScreen` are separately gated on
      // `canManageFamilyTasksProvider` — real enforcement stays
      // `FamilyChallengePolicy::create()`/`::update()`/`::delete()`
      // server-side. Literal `new` declared before the `:id` wildcards
      // below, same convention as `/family/tasks[...]`/`/family/rewards[...]`.
      GoRoute(path: '/family/challenges', builder: (context, state) => const FamilyChallengesListScreen()),
      GoRoute(path: '/family/challenges/new', builder: (context, state) => const FamilyChallengeFormScreen()),
      GoRoute(
        path: '/family/challenges/:id',
        builder: (context, state) => FamilyChallengeDetailScreen(challengeId: int.parse(state.pathParameters['id']!)),
      ),
      // `extra` carries the full `FamilyChallengeModel` already fetched by
      // `FamilyChallengeDetailScreen` — same "don't re-fetch what the
      // caller already has in hand" convention as `/family/tasks/:id/edit`/
      // `/family/rewards/:id/edit` carrying their own models the same way.
      GoRoute(
        path: '/family/challenges/:id/edit',
        builder: (context, state) => FamilyChallengeFormScreen(existing: state.extra as FamilyChallengeModel),
      ),
      // PR-69 (Family Tasks & Achievements, mobile): the fixed, platform-
      // wide badge catalog — no permission gate on the route itself, same
      // no-gate-on-the-route convention as `/family/tasks`/`/family/rewards`/
      // `/family/challenges` above. There is no `FamilyAchievementPolicy` at
      // all server-side (the catalog carries no `family_id`, see
      // `FamilyAchievementController`'s own docblock) — this whole surface
      // is read-only, with no create/edit/delete affordance to gate in the
      // first place.
      GoRoute(path: '/family/achievements', builder: (context, state) => const FamilyAchievementsCatalogScreen()),
      // "شارات الأفراد" — the member picker, same no-gate-on-the-route
      // convention as `/family/points` above: `FamilyAchievementsMemberPickerScreen`
      // narrows the roster it renders to rows this account may actually
      // open (its own docblock explains why), and the real, stricter
      // boundary stays `FamilyAchievementController::memberAchievements()`
      // server-side.
      GoRoute(
        path: '/family/achievements/members',
        builder: (context, state) => const FamilyAchievementsMemberPickerScreen(),
      ),
      // `extra` carries the member's name only (for the AppBar title) —
      // same convention as `/family/points/:id`/`/family/members/:id/history`
      // above: the screen itself re-fetches everything it needs by id.
      GoRoute(
        path: '/family/achievements/members/:id',
        builder: (context, state) => FamilyMemberAchievementsScreen(
          familyMemberId: int.parse(state.pathParameters['id']!),
          memberName: state.extra as String? ?? 'فرد العائلة',
        ),
      ),
      // The management list — every zone, active or not, with edit/delete
      // actions gated per-row (see SafeZonesListScreen's own docblock).
      GoRoute(path: '/family/safe-zones', builder: (context, state) => const SafeZonesListScreen()),
      // No path params/extra — always creates a brand-new zone from
      // scratch.
      GoRoute(path: '/family/safe-zones/new', builder: (context, state) => const SafeZoneEditorScreen()),
      // `:id` is purely for a meaningful URL (matches the `/history`/`/pair`
      // routes' convention below) — the actual zone to edit travels via
      // `extra`, same reasoning as those routes carrying a name that way:
      // re-fetching a single geofence just to edit it would be wasted work
      // when SafeZonesListScreen already has the full object in hand.
      GoRoute(
        path: '/family/safe-zones/:id/edit',
        builder: (context, state) => SafeZoneEditorScreen(existingZone: state.extra as FamilyGeofenceModel),
      ),
      // No permission gate here (mirrors the backend's own redeem() route,
      // which lives outside the 'family' middleware group) — whoever is
      // logged in on this device may pair it, family member or not yet.
      GoRoute(path: '/family/pair-device', builder: (context, state) => const DevicePairingRedeemScreen()),
      // `extra` carries the member's name only (for the AppBar title) — the
      // screen itself re-fetches everything it needs by id, same reasoning
      // as `TripDetailScreen` taking just a bare `tripId` below.
      GoRoute(
        path: '/family/members/:id/history',
        builder: (context, state) => FamilyMemberLocationHistoryScreen(
          familyMemberId: int.parse(state.pathParameters['id']!),
          memberName: state.extra as String? ?? 'فرد العائلة',
        ),
      ),
      // Same `extra`-carries-just-the-name convention as the history route
      // above; `DevicePairingController::store()` itself enforces who may
      // actually generate a code (see FamilyApi.generatePairingCode's
      // docblock) — this route has no gate of its own, matching how every
      // other family screen defers authorization to the API call it makes.
      GoRoute(
        path: '/family/members/:id/pair',
        builder: (context, state) => DevicePairingGenerateScreen(
          familyMemberId: int.parse(state.pathParameters['id']!),
          memberName: state.extra as String? ?? 'فرد العائلة',
        ),
      ),
      GoRoute(
        path: '/trips/:id',
        builder: (context, state) => TripDetailScreen(tripId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/trips/:id/stops/:stopId/pod',
        builder: (context, state) => PodCaptureScreen(
          tripId: int.parse(state.pathParameters['id']!),
          stopId: int.parse(state.pathParameters['stopId']!),
        ),
      ),
      GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
      GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
      // No permission gate — see DevicesScreen's own docblock: session
      // management is available to every authenticated account regardless
      // of driver/family type, mirroring AuthController itself having no
      // permission checks on devices()/revokeDevice()/logoutAll().
      GoRoute(path: '/profile/account-deletion', builder: (context, state) => const AccountDeletionScreen()),
      GoRoute(path: '/profile/devices', builder: (context, state) => const DevicesScreen()),
      // No permission gate on the route itself — same convention as every
      // other screen here: `DriverDocumentsScreen` defers entirely to
      // `DriverPolicy::view` via the API call it makes (see its own
      // docblock), and the only entry point is `_ProfileDetails`, which
      // never renders this link unless a driver profile for `:id` already
      // loaded successfully on this very account.
      GoRoute(
        path: '/profile/documents/:id',
        builder: (context, state) => DriverDocumentsScreen(driverId: int.parse(state.pathParameters['id']!)),
      ),
      // No permission gate here either — same convention as
      // `/profile/documents/:id` above: `AccidentsListScreen` defers
      // entirely to `AccidentPolicy::viewAny()` via the API call it makes
      // (see that screen's docblock), and its only entry point is
      // `_ProfileDetails`, gated the same way "مستنداتي" already is.
      GoRoute(path: '/profile/accidents', builder: (context, state) => const AccidentsListScreen()),
      // `AccidentPolicy::create()` grants any linked-driver account access
      // with no RBAC permission at all, so this route needs no gate of its
      // own either — same reasoning as every other route in this file.
      GoRoute(path: '/profile/accidents/report', builder: (context, state) => const ReportAccidentScreen()),
    ],
  );
});

