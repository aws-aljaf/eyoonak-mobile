import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_envelope.dart';
import '../data/family_models.dart';

/// Every family this account belongs to. Most accounts belong to exactly
/// one (or zero, before creating/joining a first family) — see
/// FamilyHomeScreen for how a >1 result is handled.
final myFamiliesProvider = FutureProvider.autoDispose<List<FamilyModel>>((ref) async {
  final raw = await ref.watch(familyApiProvider).myFamilies();

  return raw.map(FamilyModel.fromJson).toList();
});

/// Judgment call #4 from the original Family Phase 1 plan (mirrored by the
/// web app's FamilyHubPage.vue): an account with more than one active
/// family membership must disambiguate via `X-Family-Id` on every
/// family-scoped request, or the backend answers 422. This holds "which
/// family the family screen is currently showing" — null is valid and
/// simply omits the header (fine for the zero-or-one-family case, which
/// is the overwhelming majority). FamilyHomeScreen auto-selects the sole
/// family once myFamiliesProvider resolves to exactly one, and offers an
/// explicit switcher when there's more than one.
final selectedFamilyIdProvider = StateProvider<int?>((ref) => null);

final familyMembersProvider = FutureProvider.autoDispose<List<FamilyMemberModel>>((ref) async {
  final familyId = ref.watch(selectedFamilyIdProvider);
  final raw = await ref.watch(familyApiProvider).members(familyId: familyId);

  return raw.map(FamilyMemberModel.fromJson).toList();
});

/// Backs `FamilyMembershipScreen`'s roster section. `FamilyRelationshipPolicy::viewAny()`
/// is broad (any active member of the family) — same "screen has no gate
/// of its own, the request is the gate" convention as `familyAlertsProvider`
/// etc. below.
final familyRelationshipsProvider = FutureProvider.autoDispose<List<FamilyRelationshipModel>>((ref) async {
  final familyId = ref.watch(selectedFamilyIdProvider);
  final raw = await ref.watch(familyApiProvider).familyRelationships(familyId: familyId);

  return raw.map(FamilyRelationshipModel.fromJson).toList();
});

/// Backs `FamilyMembershipScreen`'s "pending invitations for me" section.
/// Deliberately **not** watching `selectedFamilyIdProvider` — mirrors
/// `FamilyApi.myInvitations()`'s own docblock: this is global across every
/// family the account has a pending invite in, not scoped to whichever
/// family is currently selected.
final myFamilyInvitationsProvider = FutureProvider.autoDispose<List<FamilyRelationshipModel>>((ref) async {
  final raw = await ref.watch(familyApiProvider).myInvitations();

  return raw.map(FamilyRelationshipModel.fromJson).toList();
});

/// Safe zones for the map screen's read-only overlay (see
/// `family_geofence_shapes.dart`). Unlike `unreadAlertsCountProvider`
/// below, this isn't gated on a permission check client-side first — the
/// backend gate (`FamilyGeofencePolicy::viewAny`, `family_tracking.view`)
/// is the same permission `familyMembersProvider` already requires to show
/// anything on this screen at all, so by the time this provider is even
/// watched the account is already known to pass it.
final familyGeofencesProvider = FutureProvider.autoDispose<List<FamilyGeofenceModel>>((ref) async {
  final familyId = ref.watch(selectedFamilyIdProvider);
  final raw = await ref.watch(familyApiProvider).geofences(familyId: familyId);

  return raw.map(FamilyGeofenceModel.fromJson).toList();
});

/// Zero when the account has no `alerts.view` permission at all, rather
/// than letting that call 403 — mirrors the web app's AppLayout bell,
/// which only polls this endpoint when the permission is present.
final unreadAlertsCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final user = ref.watch(authControllerProvider).user;

  if (user == null || !user.permissions.contains('alerts.view')) {
    return 0;
  }

  final familyId = ref.watch(selectedFamilyIdProvider);

  return ref.watch(familyApiProvider).unreadAlertsCount(familyId: familyId);
});

/// The three independent `AlertController::index()` filters `FamilyAlertsScreen`
/// exposes as a filter bar — `null` in any field means "don't filter on
/// this dimension at all" (not "empty string"), matching
/// `FamilyApi.alerts()`'s own null-means-omit convention. A plain record
/// (not a class) since this is pure UI-selection state with no behavior of
/// its own — same reasoning as `_MemberFormResult` in
/// `family_home_screen.dart`.
typedef AlertsFilter = ({String? status, String? severity, String? type});

const AlertsFilter noAlertsFilter = (status: null, severity: null, type: null);

/// Reset to "no filter" on every fresh visit to the alerts screen rather
/// than persisted across screen visits — deliberate: a stale forgotten
/// filter silently hiding new alerts (e.g. "resolved" left selected from
/// last time) is a worse surprise than having to re-pick a filter each
/// time, and this screen has no state to lose by resetting (unlike, say,
/// `selectedFamilyIdProvider`, which genuinely should persist across the
/// whole family section).
final alertsFilterProvider = StateProvider.autoDispose<AlertsFilter>((ref) => noAlertsFilter);

/// The full alerts list backing `FamilyAlertsScreen` — separate from
/// `unreadAlertsCountProvider` above (which stays a lightweight badge poll
/// gated the same way) since this one is only ever watched once the user
/// has actually opened the alerts screen. Watches `alertsFilterProvider` so
/// picking a new filter re-fetches from the backend (server-side filtering,
/// per `FamilyApi.alerts()`'s docblock — not a client-side list filter over
/// an already-fetched page, which would silently miss alerts outside
/// whatever page the unfiltered call happened to return).
final familyAlertsProvider = FutureProvider.autoDispose<List<FamilyAlertModel>>((ref) async {
  final familyId = ref.watch(selectedFamilyIdProvider);
  final filter = ref.watch(alertsFilterProvider);
  final raw = await ref.watch(familyApiProvider).alerts(
        familyId: familyId,
        status: filter.status,
        severity: filter.severity,
        type: filter.type,
      );

  return raw.map(FamilyAlertModel.fromJson).toList();
});

/// Backs `EmergencyContactsScreen`. Gated purely by the API call itself
/// (`EmergencyContactPolicy::viewAny()` needs `sos.view` OR
/// `sos.manage_contacts`) — same "screen has no gate of its own, the
/// request is the gate" convention as `familyAlertsProvider` above.
final emergencyContactsProvider = FutureProvider.autoDispose<List<EmergencyContactModel>>((ref) async {
  final familyId = ref.watch(selectedFamilyIdProvider);
  final raw = await ref.watch(familyApiProvider).emergencyContacts(familyId: familyId);

  return raw.map(EmergencyContactModel.fromJson).toList();
});

/// Which status `SosEventsScreen` is currently filtered to — defaults to
/// `'active'` (the web app's `SosPage.vue` reference default too): an
/// incident list is a management screen, and the most actionable status
/// is the one worth showing first. `null` means "every status", one of
/// the four filter options the screen offers.
final sosEventsStatusFilterProvider = StateProvider.autoDispose<String?>((ref) => 'active');

/// Which page `FamilyTimelineScreen` is currently showing — `autoDispose`
/// so leaving the screen forgets it rather than reopening on a stale later
/// page; mirrors `sosEventsStatusFilterProvider`'s own reset-on-leave
/// reasoning above.
final familyTimelinePageProvider = StateProvider.autoDispose<int>((ref) => 1);

/// Backs `FamilyTimelineScreen`. Unlike every other family list provider
/// in this file, this one returns the **raw `ApiEnvelope`**, not a parsed
/// model list — see `FamilyApi.timeline()`'s own docblock for why: this is
/// the first family feed with real prev/next page navigation the screen
/// needs (`envelope.currentPage`/`lastPage`/`hasMorePages`), so the screen
/// itself parses `envelope.data` into `FamilyTimelineItem`s alongside
/// reading that pagination metadata, instead of this provider throwing the
/// metadata away the way `familyMembersProvider`/`familyGeofencesProvider`
/// above implicitly do (by returning `getPaginated()`'s `.data` only).
final familyTimelineProvider = FutureProvider.autoDispose<ApiEnvelope>((ref) async {
  final familyId = ref.watch(selectedFamilyIdProvider);
  final page = ref.watch(familyTimelinePageProvider);

  return ref.watch(familyApiProvider).timeline(page: page, familyId: familyId);
});

/// Backs `SosEventsScreen`. Same "screen has no gate of its own, the
/// request is the gate" convention as `familyAlertsProvider`/
/// `emergencyContactsProvider` above — `SosEventPolicy::viewAny()` needs
/// `sos.view`.
final sosEventsProvider = FutureProvider.autoDispose<List<SosEventModel>>((ref) async {
  final familyId = ref.watch(selectedFamilyIdProvider);
  final status = ref.watch(sosEventsStatusFilterProvider);
  final raw = await ref.watch(familyApiProvider).sosEvents(status: status, familyId: familyId);

  return raw.map(SosEventModel.fromJson).toList();
});
