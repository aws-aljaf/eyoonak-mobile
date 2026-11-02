import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../family/application/family_providers.dart';
import '../../family/data/family_models.dart';
import '../data/family_task_models.dart';

/// Which `family-tasks` `status` the board (`FamilyTasksListScreen`) is
/// currently filtered to — `null` means "both `active` and `archived`",
/// matching `FamilyTasksApi.tasks()`'s own null-means-omit convention.
/// `autoDispose` so leaving the screen forgets a stale filter, same
/// reasoning `alertsFilterProvider` gives for its own reset-on-leave
/// choice.
final familyTasksStatusFilterProvider = StateProvider.autoDispose<String?>((ref) => 'active');

/// The shared task board — every family member may see it
/// (`FamilyTaskPolicy::viewAny()` is unconditionally true, see that
/// policy's docblock); create/edit/delete affordances are what's actually
/// gated, via `canManageFamilyTasksProvider` below.
final familyTasksProvider = FutureProvider.autoDispose<List<FamilyTaskModel>>((ref) async {
  final familyId = ref.watch(selectedFamilyIdProvider);
  final status = ref.watch(familyTasksStatusFilterProvider);
  final raw = await ref.watch(familyTasksApiProvider).tasks(familyId: familyId, status: status);

  return raw.map(FamilyTaskModel.fromJson).toList();
});

/// A single task's full detail, keyed by id — backs
/// `FamilyTaskDetailScreen`. `.family` (not a plain `FutureProvider`)
/// because the detail screen only knows which task id it needs at
/// navigation time, same reasoning every other `:id`-keyed detail screen
/// in this app (e.g. `AdminVehicleDetailScreen`) re-fetches by id rather
/// than trusting whatever the list screen happened to have in memory.
final familyTaskDetailProvider =
    FutureProvider.autoDispose.family<FamilyTaskModel, int>((ref, taskId) async {
  final familyId = ref.watch(selectedFamilyIdProvider);
  final raw = await ref.watch(familyTasksApiProvider).task(taskId: taskId, familyId: familyId);

  return FamilyTaskModel.fromJson(raw);
});

/// Which calendar day `MyFamilyTasksScreen` is currently showing —
/// `YYYY-MM-DD`, matching `FamilyTasksApi.occurrences()`'s own expected
/// format. Defaults to today; `autoDispose` so leaving the screen forgets
/// a stale day the same way `familyTimelinePageProvider` forgets a stale
/// page.
final myTasksDateProvider = StateProvider.autoDispose<String>((ref) {
  final now = DateTime.now();

  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
});

/// Backs `MyFamilyTasksScreen` — "مهامي" for a plain member/child, or the
/// whole family's occurrences for that day for an `owner`/`parent`/`admin`
/// (the backend decides which, per `FamilyTaskOccurrenceController::index()`'s
/// own docblock — this app never tries to pre-compute that split
/// client-side, it just renders whatever comes back).
final familyTaskOccurrencesProvider = FutureProvider.autoDispose<List<FamilyTaskOccurrenceModel>>((ref) async {
  final familyId = ref.watch(selectedFamilyIdProvider);
  final date = ref.watch(myTasksDateProvider);
  final raw = await ref.watch(familyTasksApiProvider).occurrences(date: date, familyId: familyId);

  return raw.map(FamilyTaskOccurrenceModel.fromJson).toList();
});

/// The current account's own `FamilyRelationship` row for the currently
/// selected family — `null` while `familyRelationshipsProvider` is still
/// loading/erroring, or genuinely absent (an account viewing a family it
/// has no membership row in at all, which normally can't happen once past
/// `FamilyHomeScreen`, but this stays defensive rather than assuming).
/// Mirrors `FamilyMembershipScreen`'s own `myRelationship` lookup exactly
/// (same plain-loop-over-`isMe()` pattern) — reused here instead of
/// duplicated into that screen's `build()` because two features now need
/// the same "which row in this list is mine" lookup.
final currentFamilyRelationshipProvider = Provider.autoDispose<FamilyRelationshipModel?>((ref) {
  final user = ref.watch(authControllerProvider).user;

  if (user == null) return null;

  final relationships = ref.watch(familyRelationshipsProvider).valueOrNull ?? const <FamilyRelationshipModel>[];

  for (final relationship in relationships) {
    if (relationship.isMe(user.id)) {
      return relationship;
    }
  }

  return null;
});

/// Whether the current account may manage tasks (create/edit/delete) for
/// the currently selected family — mirrors `FamilyRelationship::FULL_ACCESS_ROLES`
/// (`owner`/`parent`/`admin`) exactly, the same set `FamilyTaskPolicy`
/// checks server-side via `isManager()` (see that policy's docblock).
/// Deliberately reuses `FamilyRelationshipModel.hasFullAccess` — a client-
/// side role signal that genuinely exists in this codebase (populated by
/// `familyRelationshipsProvider`, already fetched for `FamilyMembershipScreen`)
/// — rather than the "no ready role source, so don't gate at all"
/// fallback `FamilyApi.updateFamily()`'s docblock describes for a
/// different, narrower check: unlike that case, the exact role set this
/// feature needs (`FULL_ACCESS_ROLES`) is already exposed by an existing
/// provider, so there is no reason to skip a real client-side gate here.
/// The HTTP request itself remains the actual authorization boundary
/// either way (`FamilyTaskPolicy`) — this only controls whether the
/// create/edit/delete UI renders at all, exactly like every other
/// permission-gated affordance in this app.
final canManageFamilyTasksProvider = Provider.autoDispose<bool>((ref) {
  final relationship = ref.watch(currentFamilyRelationshipProvider);

  return relationship != null && relationship.hasFullAccess;
});

/// Which calendar day `FamilyApprovalQueueScreen` (PR-66) is currently
/// showing — same `YYYY-MM-DD` format and same reasoning as
/// `myTasksDateProvider` above. A separate provider (not the same one
/// `MyFamilyTasksScreen` uses) because the two screens are independent —
/// paging one's day should never silently move the other's.
final approvalQueueDateProvider = StateProvider.autoDispose<String>((ref) {
  final now = DateTime.now();

  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
});

/// Backs `FamilyApprovalQueueScreen` — every `pending_approval` occurrence
/// for the selected day, across the whole family. Only ever meaningful for
/// a manager: `FamilyTaskOccurrenceController::index()` only returns the
/// whole family's rows (rather than narrowing to the caller's own linked
/// member) when the caller is a manager — see that controller's own
/// docblock — so a plain member reaching this provider would just see
/// their own `pending_approval` rows, if any, not a real "queue". The
/// screen itself is only reachable via a `canManageFamilyTasksProvider`-gated
/// entry point, so this stays defensive rather than duplicating that check.
final pendingApprovalOccurrencesProvider = FutureProvider.autoDispose<List<FamilyTaskOccurrenceModel>>((ref) async {
  final familyId = ref.watch(selectedFamilyIdProvider);
  final date = ref.watch(approvalQueueDateProvider);
  final raw = await ref
      .watch(familyTasksApiProvider)
      .occurrences(date: date, status: 'pending_approval', familyId: familyId);

  return raw.map(FamilyTaskOccurrenceModel.fromJson).toList();
});

/// A single family member's points breakdown, keyed by their
/// `family_member_id` — backs `FamilyMemberPointsDetailScreen` (PR-66).
/// `.family` for the same reasoning `familyTaskDetailProvider` above gives:
/// the detail screen only knows which member id it needs at navigation
/// time. Note this can legitimately fail with a 403 if the caller isn't
/// the member themselves nor a manager (see
/// `FamilyTasksApi.memberPoints()`'s own docblock) — `FamilyPointsScreen`
/// only ever offers a row this account is actually allowed to open, but
/// this provider itself does not re-check that client-side.
final familyMemberPointsProvider =
    FutureProvider.autoDispose.family<FamilyMemberPointsModel, int>((ref, familyMemberId) async {
  final familyId = ref.watch(selectedFamilyIdProvider);
  final raw = await ref.watch(familyTasksApiProvider).memberPoints(familyMemberId: familyMemberId, familyId: familyId);

  return FamilyMemberPointsModel.fromJson(raw);
});

/// PR-67: the current account's own `FamilyMember` id within the currently
/// selected family — `null` while `familyMembersProvider` is still
/// loading/erroring, or genuinely absent (mirrors
/// `currentFamilyRelationshipProvider`'s own defensive reasoning above).
/// Used two ways: as the default (and, for a plain member, the *only*
/// legal) `familyMemberId` a redemption request may carry
/// (`FamilyRewardRequestScreen`), and to narrow "طلباتي" to this account's
/// own row for a manager, whose redemption reads are NOT auto-narrowed
/// server-side the way a plain member's are (see
/// `FamilyTasksApi.redemptions()`'s own docblock).
final myFamilyMemberIdProvider = Provider.autoDispose<int?>((ref) {
  final user = ref.watch(authControllerProvider).user;

  if (user == null) return null;

  final members = ref.watch(familyMembersProvider).valueOrNull ?? const <FamilyMemberModel>[];

  for (final member in members) {
    if (member.isMe(user.id)) {
      return member.id;
    }
  }

  return null;
});

/// Which `family-rewards` `status` `FamilyRewardsListScreen` is currently
/// filtered to — same `null`-means-both convention as
/// `familyTasksStatusFilterProvider` above.
final familyRewardsStatusFilterProvider = StateProvider.autoDispose<String?>((ref) => 'active');

/// The reward catalog — every active family member may see it
/// (`FamilyRewardPolicy::viewAny()` is unconditionally true, see that
/// policy's docblock); create/edit/archive/delete affordances are what's
/// actually gated, via `canManageFamilyTasksProvider` (reused as-is —
/// rewards use the exact same manager role set as tasks).
final familyRewardsProvider = FutureProvider.autoDispose<List<FamilyRewardModel>>((ref) async {
  final familyId = ref.watch(selectedFamilyIdProvider);
  final status = ref.watch(familyRewardsStatusFilterProvider);
  final raw = await ref.watch(familyTasksApiProvider).rewards(familyId: familyId, status: status);

  return raw.map(FamilyRewardModel.fromJson).toList();
});

/// Backs `FamilyRewardRedemptionsQueueScreen` — every `pending` redemption
/// across the whole family. Only ever meaningful for a manager (a plain
/// member reaching this would just see their own `pending` requests, if
/// any, same reasoning `pendingApprovalOccurrencesProvider` above gives)
/// — the screen itself is only reachable via a
/// `canManageFamilyTasksProvider`-gated entry point. Unlike
/// `pendingApprovalOccurrencesProvider` there is no day to page through —
/// `redemptions()` has no date filter at all (see that method's own
/// docblock), so this is a flat, undated list.
final pendingRedemptionsProvider = FutureProvider.autoDispose<List<FamilyRewardRedemptionModel>>((ref) async {
  final familyId = ref.watch(selectedFamilyIdProvider);
  final raw = await ref.watch(familyTasksApiProvider).redemptions(status: 'pending', familyId: familyId);

  return raw.map(FamilyRewardRedemptionModel.fromJson).toList();
});

/// Backs `FamilyRewardRequestsScreen` ("طلباتي") — this account's own
/// redemption request history, any status. A plain member's
/// `redemptions()` call is already auto-narrowed to their own row
/// server-side (see that method's own docblock), but a manager's is NOT —
/// so this provider explicitly passes `familyMemberId:
/// myFamilyMemberIdProvider` only when the caller is a manager, leaving it
/// omitted otherwise (passing your own id explicitly would be harmless for
/// a plain member too, but relying on the same auto-narrowing every other
/// screen already trusts keeps this consistent with
/// `familyTaskOccurrencesProvider`'s "مهامي" reasoning above).
final myRedemptionRequestsProvider = FutureProvider.autoDispose<List<FamilyRewardRedemptionModel>>((ref) async {
  final familyId = ref.watch(selectedFamilyIdProvider);
  final canManage = ref.watch(canManageFamilyTasksProvider);
  final myMemberId = ref.watch(myFamilyMemberIdProvider);
  final raw = await ref.watch(familyTasksApiProvider).redemptions(
        familyId: familyId,
        familyMemberId: canManage ? myMemberId : null,
      );

  return raw.map(FamilyRewardRedemptionModel.fromJson).toList();
});

/// PR-68: which `family-challenges` `status` `FamilyChallengesListScreen` is
/// currently filtered to — same `null`-means-all convention as
/// `familyTasksStatusFilterProvider`/`familyRewardsStatusFilterProvider`
/// above.
final familyChallengesStatusFilterProvider = StateProvider.autoDispose<String?>((ref) => 'active');

/// The family-wide challenge catalog — every active member may see it
/// (`FamilyChallengePolicy::viewAny()` is unconditionally true, see that
/// policy's docblock); create/edit/delete affordances are what's actually
/// gated, via `canManageFamilyTasksProvider` (reused as-is — challenges use
/// the exact same manager role set as tasks/rewards).
final familyChallengesProvider = FutureProvider.autoDispose<List<FamilyChallengeModel>>((ref) async {
  final familyId = ref.watch(selectedFamilyIdProvider);
  final status = ref.watch(familyChallengesStatusFilterProvider);
  final raw = await ref.watch(familyTasksApiProvider).challenges(familyId: familyId, status: status);

  return raw.map(FamilyChallengeModel.fromJson).toList();
});

/// A single challenge's full detail, keyed by id — backs
/// `FamilyChallengeDetailScreen`. `.family` for the same reasoning
/// `familyTaskDetailProvider` above gives: the detail screen only knows
/// which challenge id it needs at navigation time.
final familyChallengeDetailProvider =
    FutureProvider.autoDispose.family<FamilyChallengeModel, int>((ref, challengeId) async {
  final familyId = ref.watch(selectedFamilyIdProvider);
  final raw = await ref.watch(familyTasksApiProvider).challenge(challengeId: challengeId, familyId: familyId);

  return FamilyChallengeModel.fromJson(raw);
});

/// "عرض التقدّم" — every member who has joined a given challenge, keyed by
/// challenge id. `.family` for the same per-id reasoning as
/// `familyChallengeDetailProvider` above. Deliberately never sorted by
/// `progressCount` anywhere downstream — see
/// `FamilyChallengeParticipantModel`'s own docblock for why (plan judgment
/// call #7's no-ranking principle).
final challengeParticipantsProvider =
    FutureProvider.autoDispose.family<List<FamilyChallengeParticipantModel>, int>((ref, challengeId) async {
  final familyId = ref.watch(selectedFamilyIdProvider);
  final raw =
      await ref.watch(familyTasksApiProvider).challengeParticipants(challengeId: challengeId, familyId: familyId);

  return raw.map(FamilyChallengeParticipantModel.fromJson).toList();
});

/// PR-69: the fixed, platform-wide badge catalog — identical for every
/// family (see `FamilyAchievementModel`'s own docblock), so this is a plain
/// `FutureProvider` (no `.family` keying), unlike every other catalog
/// provider above (`familyTasksProvider`/`familyRewardsProvider`/
/// `familyChallengesProvider`) which is scoped per selected family. Still
/// re-fetches whenever `selectedFamilyIdProvider` changes (harmless — the
/// response would be byte-identical) rather than special-casing that away,
/// keeping this consistent with every other provider in this file that
/// watches it.
final familyAchievementsProvider = FutureProvider.autoDispose<List<FamilyAchievementModel>>((ref) async {
  final familyId = ref.watch(selectedFamilyIdProvider);
  final raw = await ref.watch(familyTasksApiProvider).achievements(familyId: familyId);

  return raw.map(FamilyAchievementModel.fromJson).toList();
});

/// One family member's earned badges, keyed by their `family_member_id` —
/// backs `FamilyMemberAchievementsScreen` (PR-69). `.family` for the same
/// per-id reasoning `familyMemberPointsProvider` above gives. Note this can
/// legitimately fail with a 403 if the caller isn't the member themselves
/// nor a manager (see `FamilyTasksApi.memberAchievements()`'s own
/// docblock) — `FamilyAchievementsMemberPickerScreen` only ever offers a
/// row this account is actually allowed to open (built on the exact same
/// template as `FamilyPointsScreen`), but this provider itself does not
/// re-check that client-side, matching `familyMemberPointsProvider`'s own
/// choice.
final familyMemberAchievementsProvider =
    FutureProvider.autoDispose.family<List<FamilyMemberAchievementModel>, int>((ref, familyMemberId) async {
  final familyId = ref.watch(selectedFamilyIdProvider);
  final raw =
      await ref.watch(familyTasksApiProvider).memberAchievements(familyMemberId: familyMemberId, familyId: familyId);

  return raw.map(FamilyMemberAchievementModel.fromJson).toList();
});

/// PR-70: "التقرير الأسبوعي" — every active family member may view it
/// (`FamilyTaskPolicy::viewAny()` is unconditionally true, same reasoning
/// `familyTasksProvider` above gives). Plain `FutureProvider.autoDispose`
/// (no `.family` keying) — the backend always computes the CURRENT
/// calendar week itself with no id/date parameter to key by (see
/// `FamilyTasksApi.weeklyReport()`'s own docblock), same shape as
/// `familyAchievementsProvider`'s own "nothing to key by" reasoning.
final familyWeeklyReportProvider = FutureProvider.autoDispose<FamilyWeeklyReportModel>((ref) async {
  final familyId = ref.watch(selectedFamilyIdProvider);
  final raw = await ref.watch(familyTasksApiProvider).weeklyReport(familyId: familyId);

  return FamilyWeeklyReportModel.fromJson(raw);
});

/// PR-70: backs the "عائلتي" summary card on `FamilyHomeScreen` — TODAY's
/// occurrences across the family (or just the caller's own, for a plain
/// member/child — same backend split `familyTaskOccurrencesProvider` above
/// documents). Deliberately its OWN provider rather than reusing
/// `familyTaskOccurrencesProvider`/`myTasksDateProvider`: that pair is
/// `MyFamilyTasksScreen`'s own page state, and go_router keeps a previously
/// pushed route mounted underneath whatever is pushed on top of it — so if
/// this card watched that same pair, paging the day on "مهامي" would
/// silently change what the still-mounted home screen shows too, the
/// moment the user pushed "مهامي" on top of `FamilyHomeScreen` and paged
/// away from today. This computes "today" fresh on every rebuild instead,
/// and reuses the exact same `FamilyTasksApi.occurrences()` call (no new
/// backend endpoint) with that explicit date.
final todayFamilyTaskOccurrencesProvider = FutureProvider.autoDispose<List<FamilyTaskOccurrenceModel>>((ref) async {
  final familyId = ref.watch(selectedFamilyIdProvider);
  final now = DateTime.now();
  final today =
      '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final raw = await ref.watch(familyTasksApiProvider).occurrences(date: today, familyId: familyId);

  return raw.map(FamilyTaskOccurrenceModel.fromJson).toList();
});
