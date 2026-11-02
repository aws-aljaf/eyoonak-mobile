import '../../../core/network/api_client.dart';

/// Talks to the `family-tasks`/`family-task-occurrences` endpoints exactly
/// as implemented server-side by
/// `FamilyTracking\FamilyTaskController`/`FamilyTracking\FamilyTaskOccurrenceController`
/// (backend/app/Http/Controllers/Api/V1/FamilyTracking/...), verified
/// directly against both controllers and their Form Requests before
/// writing this. Returns raw decoded JSON — callers (Riverpod providers)
/// turn it into `family_task_models.dart` types, the same split
/// `FamilyApi`/`family_models.dart` already uses.
///
/// Both resources sit inside the same `Route::middleware('family')` group
/// as `family-members`/`family-geofences` (verified directly against
/// `routes/api_v1.php`), so `familyId`, when given, is sent as
/// `X-Family-Id` on every method here — same convention, same reason
/// (`FamilyApi`'s own docblock): required only when the account belongs to
/// more than one active family.
class FamilyTasksApi {
  FamilyTasksApi(this._client);

  final ApiClient _client;

  Map<String, dynamic>? _familyHeader(int? familyId) =>
      familyId == null ? null : {'X-Family-Id': familyId.toString()};

  /// `GET /family-tasks` — the shared task board. Visible to every active
  /// family member (`FamilyTaskPolicy::viewAny()` is unconditionally true,
  /// per-row visibility is `view()`'s job) — transparency by design, see
  /// `FamilyTaskController`'s own docblock. `status`, when given, mirrors
  /// the controller's own `$request->filled('status')` exact-match filter
  /// (`active`/`archived`); omitted entirely to see both, matching
  /// `FamilyApi.alerts()`'s own null-means-omit convention. `per_page: 50`
  /// covers every realistic family's task count in one page, same
  /// reasoning `FamilyApi.members()` gives for its own `per_page: 100`.
  Future<List<Map<String, dynamic>>> tasks({int? familyId, String? status}) async {
    final envelope = await _client.getPaginated(
      '/family-tasks',
      query: {'per_page': 50, if (status != null) 'status': status},
      headers: _familyHeader(familyId),
    );

    return envelope.data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// `GET /family-tasks/{id}` — a single task's full detail (including its
  /// explicit assignee roster when `assignToAll` is false). Gated by
  /// `FamilyTaskPolicy::view()` — any active member of the task's family.
  Future<Map<String, dynamic>> task({required int taskId, int? familyId}) async {
    final data = await _client.get('/family-tasks/$taskId', headers: _familyHeader(familyId));

    return Map<String, dynamic>.from(data as Map);
  }

  /// `POST /family-tasks` — gated by `FamilyTaskPolicy::create()`
  /// (`owner`/`parent`/`admin` only, checked via `FamilyRelationship`, not
  /// the company Permission system — see that policy's own docblock). This
  /// method itself does not pre-check that role (see
  /// `family_tasks_providers.dart`'s `canManageFamilyTasksProvider`
  /// docblock for how the create/edit UI itself is gated instead) — a
  /// non-manager reaching this method regardless gets back whatever
  /// `ApiException` the 403 carries, same "the request is the real gate"
  /// convention as every other write in this codebase.
  ///
  /// `assigneeIds` is only sent when `assignToAll` is false — mirrors
  /// `StoreFamilyTaskRequest`'s own validation (both fields present is
  /// meaningless once `assign_to_all` is true, since the backend never
  /// stores a roster for it at all, see the `family_task_assignees`
  /// migration's docblock). `recurrenceDays` likewise only makes sense
  /// (and is only required server-side) when `recurrenceType ==
  /// 'specific_days'`.
  Future<Map<String, dynamic>> createTask({
    required String title,
    String? description,
    required String category,
    required int points,
    required bool requiresApproval,
    required bool assignToAll,
    List<int>? assigneeIds,
    required String recurrenceType,
    List<int>? recurrenceDays,
    required String startDate,
    String? endDate,
    String? timeStart,
    String? timeEnd,
    String? notes,
    int? familyId,
  }) async {
    final data = await _client.post(
      '/family-tasks',
      data: {
        'title': title,
        if (description != null && description.isNotEmpty) 'description': description,
        'category': category,
        'points': points,
        'requires_approval': requiresApproval,
        'assign_to_all': assignToAll,
        if (!assignToAll) 'assignee_ids': assigneeIds ?? const [],
        'recurrence_type': recurrenceType,
        if (recurrenceType == 'specific_days') 'recurrence_days': recurrenceDays ?? const [],
        'start_date': startDate,
        if (endDate != null && endDate.isNotEmpty) 'end_date': endDate,
        if (timeStart != null && timeStart.isNotEmpty) 'time_start': timeStart,
        if (timeEnd != null && timeEnd.isNotEmpty) 'time_end': timeEnd,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
      headers: _familyHeader(familyId),
    );

    return Map<String, dynamic>.from(data as Map);
  }

  /// `PUT /family-tasks/{id}` — gated by `FamilyTaskPolicy::update()`, same
  /// manager-only rule as `createTask()` above. Always sends the complete
  /// set of editable fields (not a true partial update) — same reasoning
  /// `FamilyApi.updateCircleGeofence()` gives for the same choice: this
  /// app's only editor (`FamilyTaskFormScreen`) always has every field in
  /// hand when it saves, so there is no partial-update case worth
  /// exploiting, and sending everything can't leave a field stale by
  /// omission. `status` is included here (unlike `createTask()`, which
  /// never sends one — a new task always starts `active` server-side) so
  /// the edit form can archive/reactivate a task.
  Future<Map<String, dynamic>> updateTask({
    required int taskId,
    required String title,
    String? description,
    required String category,
    required int points,
    required bool requiresApproval,
    required bool assignToAll,
    List<int>? assigneeIds,
    required String recurrenceType,
    List<int>? recurrenceDays,
    required String startDate,
    String? endDate,
    String? timeStart,
    String? timeEnd,
    String? notes,
    required String status,
    int? familyId,
  }) async {
    final data = await _client.put(
      '/family-tasks/$taskId',
      data: {
        'title': title,
        'description': description,
        'category': category,
        'points': points,
        'requires_approval': requiresApproval,
        'assign_to_all': assignToAll,
        if (!assignToAll) 'assignee_ids': assigneeIds ?? const [],
        'recurrence_type': recurrenceType,
        'recurrence_days': recurrenceType == 'specific_days' ? (recurrenceDays ?? const []) : const [],
        'start_date': startDate,
        'end_date': endDate,
        'time_start': timeStart,
        'time_end': timeEnd,
        'notes': notes,
        'status': status,
      },
      headers: _familyHeader(familyId),
    );

    return Map<String, dynamic>.from(data as Map);
  }

  /// `DELETE /family-tasks/{id}` — a **soft** delete (`FamilyTask` uses
  /// `SoftDeletes`, verified directly against the model), gated by the same
  /// manager-only `FamilyTaskPolicy::delete()` as update. This also removes
  /// the task from the shared board immediately, but leaves its historical
  /// occurrences (and the points already awarded from them) untouched —
  /// `FamilyTaskOccurrence` has no cascading delete tied to its parent task
  /// in the migration, verified directly.
  Future<void> deleteTask({required int taskId, int? familyId}) async {
    await _client.delete('/family-tasks/$taskId', headers: _familyHeader(familyId));
  }

  /// `GET /family-task-occurrences` — "مهامي" for a plain member/child (the
  /// backend narrows to their own linked `FamilyMember` row automatically,
  /// see `FamilyTaskOccurrenceController::index()`'s own docblock), or the
  /// whole family's occurrences for that day for an `owner`/`parent`/
  /// `admin`. `date` defaults server-side to today when omitted (sent here
  /// as `YYYY-MM-DD`, matching `$request->date('date')`'s expectation).
  /// `per_page: 50` mirrors the controller's own default.
  Future<List<Map<String, dynamic>>> occurrences({
    String? date,
    String? status,
    int? familyMemberId,
    int? familyId,
  }) async {
    final envelope = await _client.getPaginated(
      '/family-task-occurrences',
      query: {
        'per_page': 50,
        if (date != null) 'date': date,
        if (status != null) 'status': status,
        if (familyMemberId != null) 'family_member_id': familyMemberId,
      },
      headers: _familyHeader(familyId),
    );

    return envelope.data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// `POST /family-task-occurrences/{id}/complete` — "✅ تم الإنجاز".
  /// Gated by `FamilyTaskOccurrencePolicy::complete()`: the assigned
  /// member themselves (via their own linked account) or a manager acting
  /// on behalf of a member with no login of their own — see that policy's
  /// docblock. A no-op server-side unless the occurrence is still
  /// `pending` (idempotent, same pattern as `FamilyApi.markAlertRead()`) —
  /// this app still hides the button once a row is no longer `pending`
  /// (`FamilyTaskOccurrenceModel.canComplete`) rather than relying on that
  /// idempotency to paper over a stale UI. No request body: the controller
  /// takes nothing but the route-bound occurrence.
  Future<Map<String, dynamic>> completeOccurrence({required int occurrenceId, int? familyId}) async {
    final data = await _client.post(
      '/family-task-occurrences/$occurrenceId/complete',
      headers: _familyHeader(familyId),
    );

    return Map<String, dynamic>.from(data as Map);
  }

  /// `POST /family-task-occurrences/{id}/approve` — "اعتماد" on the parent's
  /// approval queue (PR-66). Gated by
  /// `FamilyTaskOccurrencePolicy::approve()`: manager-only
  /// (`owner`/`parent`/`admin`), no self-approval branch at all — see that
  /// policy's own docblock, this is deliberately stricter than
  /// `complete()`. A no-op (422) server-side unless the occurrence is
  /// currently `pending_approval` — this app still hides the button for
  /// any other status (`FamilyApprovalQueueScreen` only ever renders rows
  /// the `status=pending_approval` filter already returned) rather than
  /// relying on that guard to paper over a stale list. No request body:
  /// the controller takes nothing but the route-bound occurrence.
  Future<Map<String, dynamic>> approveOccurrence({required int occurrenceId, int? familyId}) async {
    final data = await _client.post(
      '/family-task-occurrences/$occurrenceId/approve',
      headers: _familyHeader(familyId),
    );

    return Map<String, dynamic>.from(data as Map);
  }

  /// `POST /family-task-occurrences/{id}/reject` — "رفض" on the parent's
  /// approval queue (PR-66). Same manager-only gate as `approveOccurrence()`
  /// above (`FamilyTaskOccurrencePolicy::reject()`). `reason`, when given,
  /// is sent as `reason` — verified directly against
  /// `FamilyTaskOccurrenceController::reject()`, which reads
  /// `$request->input('reason')` with no validation rule of its own (no
  /// `FormRequest`, no `required`), so an omitted/empty reason is
  /// perfectly valid and simply stores `null`.
  Future<Map<String, dynamic>> rejectOccurrence({required int occurrenceId, String? reason, int? familyId}) async {
    final data = await _client.post(
      '/family-task-occurrences/$occurrenceId/reject',
      data: {if (reason != null && reason.isNotEmpty) 'reason': reason},
      headers: _familyHeader(familyId),
    );

    return Map<String, dynamic>.from(data as Map);
  }

  /// `GET /family-members/{id}/points` — "رصيد النقاط" breakdown (PR-66,
  /// backed by `FamilyTracking\FamilyMemberPointsController::show()`, added
  /// in PR-60). Kept on this same `FamilyTasksApi` class rather than a new
  /// one — same reasoning `FamilyApi` already hosts several distinct
  /// backend resources (members/geofences/sos/locations) under one client
  /// class per feature, not one class per controller. **Stricter** gate
  /// than every other read in this class: visible to the member's own
  /// linked account, or to a manager — a plain member/child cannot view a
  /// sibling's breakdown (see that controller's own docblock), so callers
  /// must not blindly offer every roster row to every viewer (see
  /// `FamilyPointsScreen`'s own docblock for how the UI narrows this
  /// client-side ahead of the request).
  Future<Map<String, dynamic>> memberPoints({required int familyMemberId, int? familyId}) async {
    final data = await _client.get(
      '/family-members/$familyMemberId/points',
      headers: _familyHeader(familyId),
    );

    return Map<String, dynamic>.from(data as Map);
  }

  /// `GET /family-rewards` — the reward catalog (PR-61 backend,
  /// `FamilyTracking\FamilyRewardController::index()`, verified directly).
  /// Visible to every active member (`FamilyRewardPolicy::viewAny()` is
  /// unconditionally true, same "transparency by design" reasoning as
  /// `tasks()` above) — so a member always knows what they're saving points
  /// for. `status`, when given, mirrors the controller's own
  /// `$request->filled('status')` exact-match filter (`active`/`archived`);
  /// omitted entirely to see both, same null-means-omit convention as
  /// `tasks()`. `per_page: 50` for the same "covers every realistic
  /// family's count in one page" reasoning as that method.
  Future<List<Map<String, dynamic>>> rewards({int? familyId, String? status}) async {
    final envelope = await _client.getPaginated(
      '/family-rewards',
      query: {'per_page': 50, if (status != null) 'status': status},
      headers: _familyHeader(familyId),
    );

    return envelope.data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// `POST /family-rewards` — gated by `FamilyRewardPolicy::create()`
  /// (manager-only, checked via `FamilyRelationship`, not the company
  /// Permission system — see that policy's own docblock). Same
  /// "the request is the real gate" convention as `createTask()` above:
  /// this method itself does not pre-check the role, the UI does
  /// (`canManageFamilyTasksProvider`, reused as-is for rewards too).
  Future<Map<String, dynamic>> createReward({
    required String name,
    String? description,
    required int pointsCost,
    String? icon,
    int? familyId,
  }) async {
    final data = await _client.post(
      '/family-rewards',
      data: {
        'name': name,
        if (description != null && description.isNotEmpty) 'description': description,
        'points_cost': pointsCost,
        if (icon != null && icon.isNotEmpty) 'icon': icon,
      },
      headers: _familyHeader(familyId),
    );

    return Map<String, dynamic>.from(data as Map);
  }

  /// `PUT /family-rewards/{id}` — gated by `FamilyRewardPolicy::update()`,
  /// same manager-only rule as `createReward()` above. Always sends the
  /// complete set of editable fields (not a true partial update), same
  /// reasoning `updateTask()` gives for the same choice — this app's only
  /// editor (`FamilyRewardFormScreen`) always has every field in hand when
  /// it saves. `status` is included here (unlike `createReward()`, which
  /// never sends one — a new reward always starts `active` server-side) so
  /// the edit form can archive/reactivate a reward.
  Future<Map<String, dynamic>> updateReward({
    required int rewardId,
    required String name,
    String? description,
    required int pointsCost,
    String? icon,
    required String status,
    int? familyId,
  }) async {
    final data = await _client.put(
      '/family-rewards/$rewardId',
      data: {
        'name': name,
        'description': description,
        'points_cost': pointsCost,
        'icon': icon,
        'status': status,
      },
      headers: _familyHeader(familyId),
    );

    return Map<String, dynamic>.from(data as Map);
  }

  /// `DELETE /family-rewards/{id}` — a **hard** delete (`FamilyReward` has
  /// no `SoftDeletes`, verified directly against the model — unlike
  /// `FamilyTask`), gated by the same manager-only
  /// `FamilyRewardPolicy::delete()` as update. A redemption already made
  /// against this reward keeps its own `points_cost_snapshot`
  /// (`family_reward_redemptions.family_reward_id` cascades on delete per
  /// that migration, but the points already earned/spent are untouched —
  /// they live on `family_point_transactions`, not on the reward row).
  Future<void> deleteReward({required int rewardId, int? familyId}) async {
    await _client.delete('/family-rewards/$rewardId', headers: _familyHeader(familyId));
  }

  /// `GET /family-reward-redemptions` — gated by
  /// `FamilyRewardRedemptionPolicy::viewAny()` (unconditionally true); a
  /// manager sees every member's requests, a plain member only their own —
  /// the backend narrows this automatically
  /// (`FamilyRewardRedemptionController::index()`'s own manager-sees-all /
  /// member-sees-own split, verified directly, same shape as
  /// `FamilyTaskOccurrenceController::index()`), so this method never
  /// tries to pre-compute that split client-side. `familyMemberId`, when
  /// given, is only honoured server-side for a manager (a plain member's
  /// query is always narrowed to their own row regardless — see that
  /// controller's own docblock), matching `occurrences()`'s own
  /// `familyMemberId` parameter for the same reason. Unlike `occurrences()`
  /// there is no `date` filter at all — this endpoint has none, verified
  /// directly against the controller.
  Future<List<Map<String, dynamic>>> redemptions({
    String? status,
    int? familyMemberId,
    int? familyId,
  }) async {
    final envelope = await _client.getPaginated(
      '/family-reward-redemptions',
      query: {
        'per_page': 50,
        if (status != null) 'status': status,
        if (familyMemberId != null) 'family_member_id': familyMemberId,
      },
      headers: _familyHeader(familyId),
    );

    return envelope.data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// `POST /family-reward-redemptions` — "طلب استبدال". Not gated by
  /// `$this->authorize()` server-side at all (see
  /// `FamilyRewardRedemptionController::store()`'s own docblock: an inline
  /// self-or-manager check, the same policy-collision workaround
  /// `FamilyMemberPointsController::show()` already documents) — a plain
  /// member may only pass their own linked `familyMemberId`, a manager may
  /// pass any member's (including one with no login of their own). The
  /// backend re-validates the balance at this exact moment too (plan
  /// judgment call #5's docblock: "purely so a member gets an immediate,
  /// honest 'you can't afford this yet'"), so this can legitimately fail
  /// with a 422 even after this app's own client-side balance hint already
  /// showed a warning — that 422's `message` is surfaced as-is, not
  /// reworded.
  Future<Map<String, dynamic>> requestRedemption({
    required int familyRewardId,
    required int familyMemberId,
    int? familyId,
  }) async {
    final data = await _client.post(
      '/family-reward-redemptions',
      data: {'family_reward_id': familyRewardId, 'family_member_id': familyMemberId},
      headers: _familyHeader(familyId),
    );

    return Map<String, dynamic>.from(data as Map);
  }

  /// `POST /family-reward-redemptions/{id}/approve` — "اعتماد" on the
  /// parent's redemption queue. Gated by
  /// `FamilyRewardRedemptionPolicy::approve()`: manager-only, no
  /// self-approval branch at all — same shape as
  /// `FamilyTaskOccurrencePolicy::approve()`. A no-op (422) server-side
  /// unless the redemption is currently `pending`, and can also fail with
  /// a 422 if the member's balance dropped below the snapshot cost since
  /// the request (plan judgment call #5 — points are debited only here,
  /// re-checking the balance at this exact moment). No request body.
  Future<Map<String, dynamic>> approveRedemption({required int redemptionId, int? familyId}) async {
    final data = await _client.post(
      '/family-reward-redemptions/$redemptionId/approve',
      headers: _familyHeader(familyId),
    );

    return Map<String, dynamic>.from(data as Map);
  }

  /// `POST /family-reward-redemptions/{id}/reject` — "رفض" on the parent's
  /// redemption queue. Same manager-only gate as `approveRedemption()`
  /// above. **No `reason` parameter** — unlike
  /// `FamilyTaskOccurrenceController::reject()`,
  /// `FamilyRewardRedemptionController::reject()` takes no request body at
  /// all and `family_reward_redemptions` has no `rejection_reason` column
  /// (verified directly against both the controller and the migration), so
  /// this method sends nothing rather than inventing a field the backend
  /// would silently ignore.
  Future<Map<String, dynamic>> rejectRedemption({required int redemptionId, int? familyId}) async {
    final data = await _client.post(
      '/family-reward-redemptions/$redemptionId/reject',
      headers: _familyHeader(familyId),
    );

    return Map<String, dynamic>.from(data as Map);
  }

  /// `GET /family-challenges` — the family-wide challenge catalog (PR-62
  /// backend, `FamilyTracking\FamilyChallengeController::index()`, verified
  /// directly). Visible to every active member
  /// (`FamilyChallengePolicy::viewAny()` is unconditionally true, same
  /// "transparency by design" reasoning as `tasks()`/`rewards()` above).
  /// `status`, when given, mirrors the controller's own
  /// `$request->filled('status')` exact-match filter
  /// (`active`/`completed`/`archived`); omitted entirely to see all, same
  /// null-means-omit convention as `tasks()`. `per_page: 50` for the same
  /// "covers every realistic family's count in one page" reasoning.
  Future<List<Map<String, dynamic>>> challenges({int? familyId, String? status}) async {
    final envelope = await _client.getPaginated(
      '/family-challenges',
      query: {'per_page': 50, if (status != null) 'status': status},
      headers: _familyHeader(familyId),
    );

    return envelope.data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// `GET /family-challenges/{id}` — a single challenge's full detail.
  /// Gated by `FamilyChallengePolicy::view()` — any active member of the
  /// challenge's family.
  Future<Map<String, dynamic>> challenge({required int challengeId, int? familyId}) async {
    final data = await _client.get('/family-challenges/$challengeId', headers: _familyHeader(familyId));

    return Map<String, dynamic>.from(data as Map);
  }

  /// `POST /family-challenges` — gated by `FamilyChallengePolicy::create()`
  /// (manager-only, checked via `FamilyRelationship`, not the company
  /// Permission system — see that policy's own docblock). Same
  /// "the request is the real gate" convention as `createTask()`/
  /// `createReward()` above: this method itself does not pre-check the
  /// role, the UI does (`canManageFamilyTasksProvider`, reused as-is —
  /// challenges use the exact same manager role set). `categoryFilter`
  /// omitted (not sent as an explicit `null`) means "any task counts" —
  /// verified directly against `StoreFamilyChallengeRequest`'s own
  /// `nullable` rule, which treats an absent key the same as an explicit
  /// `null`.
  Future<Map<String, dynamic>> createChallenge({
    required String title,
    String? description,
    String? categoryFilter,
    required int goalTarget,
    required int bonusPoints,
    required String startDate,
    required String endDate,
    int? familyId,
  }) async {
    final data = await _client.post(
      '/family-challenges',
      data: {
        'title': title,
        if (description != null && description.isNotEmpty) 'description': description,
        if (categoryFilter != null) 'category_filter': categoryFilter,
        'goal_target': goalTarget,
        'bonus_points': bonusPoints,
        'start_date': startDate,
        'end_date': endDate,
      },
      headers: _familyHeader(familyId),
    );

    return Map<String, dynamic>.from(data as Map);
  }

  /// `PUT /family-challenges/{id}` — gated by
  /// `FamilyChallengePolicy::update()`, same manager-only rule as
  /// `createChallenge()` above. Always sends the complete set of editable
  /// fields (not a true partial update), same reasoning `updateTask()`/
  /// `updateReward()` give for the same choice — this app's only editor
  /// (`FamilyChallengeFormScreen`) always has every field in hand when it
  /// saves. `categoryFilter` is always sent here, including `null` (unlike
  /// `createChallenge()`, which omits the key entirely when absent) — this
  /// is how the edit form clears a previously-set filter back to "any
  /// task counts", matching `UpdateFamilyChallengeRequest`'s own
  /// `nullable` rule (a `null` value is accepted and stored, distinct from
  /// the key being absent, which `sometimes` would leave untouched).
  /// `status` is included here (unlike `createChallenge()`, which never
  /// sends one — a new challenge always starts `active` server-side) so
  /// the edit form can mark it completed/archived.
  Future<Map<String, dynamic>> updateChallenge({
    required int challengeId,
    required String title,
    String? description,
    String? categoryFilter,
    required int goalTarget,
    required int bonusPoints,
    required String startDate,
    required String endDate,
    required String status,
    int? familyId,
  }) async {
    final data = await _client.put(
      '/family-challenges/$challengeId',
      data: {
        'title': title,
        'description': description,
        'category_filter': categoryFilter,
        'goal_target': goalTarget,
        'bonus_points': bonusPoints,
        'start_date': startDate,
        'end_date': endDate,
        'status': status,
      },
      headers: _familyHeader(familyId),
    );

    return Map<String, dynamic>.from(data as Map);
  }

  /// `DELETE /family-challenges/{id}` — gated by the same manager-only
  /// `FamilyChallengePolicy::delete()` as update.
  Future<void> deleteChallenge({required int challengeId, int? familyId}) async {
    await _client.delete('/family-challenges/$challengeId', headers: _familyHeader(familyId));
  }

  /// `POST /family-challenges/{id}/join` — "المشاركة". Not gated by
  /// `$this->authorize()` server-side at all (see
  /// `FamilyChallengeController::join()`'s own docblock: an inline
  /// self-or-manager check, the same policy-collision workaround
  /// `FamilyRewardRedemptionController::store()` already documents) — a
  /// plain member may only pass their own linked `familyMemberId`, a
  /// manager may pass any member's (including one with no login of their
  /// own). Idempotent server-side (`firstOrCreate`) — joining twice just
  /// returns the existing participant row rather than erroring.
  Future<Map<String, dynamic>> joinChallenge({
    required int challengeId,
    required int familyMemberId,
    int? familyId,
  }) async {
    final data = await _client.post(
      '/family-challenges/$challengeId/join',
      data: {'family_member_id': familyMemberId},
      headers: _familyHeader(familyId),
    );

    return Map<String, dynamic>.from(data as Map);
  }

  /// `GET /family-challenges/{id}/participants` — "عرض التقدّم": every
  /// member who has joined this challenge, with their own
  /// `progress_count`/`goal_target`. Gated by `FamilyChallengePolicy::view()`
  /// — same as `challenge()` above, any active member of the family. This
  /// is a flat progress board, not a ranking — see
  /// `FamilyChallengeParticipantResource`'s own shape (no rank/position
  /// field at all) and this app's own `FamilyChallengeDetailScreen`
  /// docblock for why the UI never sorts these by progress.
  Future<List<Map<String, dynamic>>> challengeParticipants({required int challengeId, int? familyId}) async {
    final data = await _client.get(
      '/family-challenges/$challengeId/participants',
      headers: _familyHeader(familyId),
    );

    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// `GET /family-achievements` — the fixed, platform-wide badge catalog
  /// (PR-63 backend, `FamilyTracking\FamilyAchievementController::index()`,
  /// verified directly). No `FamilyAchievementPolicy` at all (see that
  /// controller's own docblock: the catalog carries no `family_id`, so
  /// `viewAny` would just be `true`) and no pagination either — the
  /// controller returns a plain `FamilyAchievement::query()->orderBy('id')
  /// ->get()` collection wrapped in `success()`, not a paginator, verified
  /// directly against both that call and `ApiController::success()` — so
  /// this uses `_client.get()` (which returns bare `data`), not
  /// `getPaginated()`, unlike every list method above. Identical for every
  /// family (no `X-Family-Id` needed to interpret the response), but still
  /// sent when known — same "harmless, consistent header" reasoning every
  /// other method in this class follows.
  Future<List<Map<String, dynamic>>> achievements({int? familyId}) async {
    final data = await _client.get('/family-achievements', headers: _familyHeader(familyId));

    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// `GET /family-members/{id}/achievements` — one member's earned badges
  /// (PR-63 backend, `FamilyAchievementController::memberAchievements()`,
  /// verified directly). **Same stricter self-or-manager gate** as
  /// `memberPoints()` above (an inline check, not `$this->authorize()` —
  /// see that controller's own docblock: "policy-collision workaround"), so
  /// a plain member/child cannot view a sibling's earned badges — callers
  /// must narrow the roster they offer the same way `FamilyPointsScreen`
  /// already does for points (see this feature's new
  /// `FamilyAchievementsMemberPickerScreen`, built on that exact template).
  /// No pagination, verified directly against the controller (a plain
  /// `->get()`, not paginated) — same `_client.get()` choice as
  /// `achievements()` above.
  Future<List<Map<String, dynamic>>> memberAchievements({required int familyMemberId, int? familyId}) async {
    final data = await _client.get(
      '/family-members/$familyMemberId/achievements',
      headers: _familyHeader(familyId),
    );

    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// `GET /family-tasks/weekly-report` — "التقرير الأسبوعي" (PR-70,
  /// backed by PR-64's `FamilyTracking\FamilyWeeklyReportController::show()`,
  /// verified directly — see that controller's own extensive docblock on
  /// why the response can never carry a negative/lowest-ranking field: no
  /// query param can ask for one, because none exists to ask for). Gated by
  /// `FamilyTaskPolicy::viewAny()` (unconditionally true, same as `tasks()`
  /// above) — any active family member may view the whole family's report,
  /// not just a manager. No request parameters at all: the backend always
  /// computes the CURRENT calendar week (`Carbon::now()->startOfWeek()`),
  /// verified directly — there is no way to request a past week, and this
  /// method does not pretend otherwise. `_client.get()` (bare `data`, not
  /// paginated) — same reasoning `achievements()`/`memberAchievements()`
  /// above give: the controller wraps a plain object in `success()`, not a
  /// `Paginator`.
  Future<Map<String, dynamic>> weeklyReport({int? familyId}) async {
    final data = await _client.get('/family-tasks/weekly-report', headers: _familyHeader(familyId));

    return Map<String, dynamic>.from(data as Map);
  }
}
