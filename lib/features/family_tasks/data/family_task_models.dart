/// Mirrors `FamilyTaskResource`
/// (backend/app/Http/Resources/Api/V1/FamilyTaskResource.php) field-for-field
/// — verified directly against that resource before building this, same
/// discipline every other model in this app follows (see
/// `family_models.dart`'s own header comments).
class FamilyTaskAssignee {
  const FamilyTaskAssignee({required this.id, required this.fullName});

  factory FamilyTaskAssignee.fromJson(Map<String, dynamic> json) {
    return FamilyTaskAssignee(id: json['id'] as int, fullName: json['full_name'] as String);
  }

  final int id;
  final String fullName;
}

/// A single task on the family's shared board. `assignees` mirrors
/// `FamilyTaskResource`'s `whenLoaded('assignees', ...)` — verified
/// directly: it is only ever a non-empty list when `assignToAll` is
/// `false` (an assign-to-all task deliberately stores no assignee rows at
/// all, see `create_family_task_assignees_table`'s migration docblock on
/// the backend), so this model never tries to distinguish "empty because
/// assigned to everyone" from "empty because genuinely nobody" — the
/// caller always checks `assignToAll` first.
class FamilyTaskModel {
  const FamilyTaskModel({
    required this.id,
    required this.title,
    required this.category,
    required this.points,
    required this.requiresApproval,
    required this.assignToAll,
    required this.assignees,
    required this.recurrenceType,
    required this.recurrenceDays,
    required this.startDate,
    required this.status,
    required this.createdByUserId,
    this.description,
    this.endDate,
    this.timeStart,
    this.timeEnd,
    this.familyRewardId,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory FamilyTaskModel.fromJson(Map<String, dynamic> json) {
    return FamilyTaskModel(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: json['category'] as String,
      points: (json['points'] as num).toInt(),
      requiresApproval: json['requires_approval'] as bool,
      assignToAll: json['assign_to_all'] as bool,
      assignees: (json['assignees'] as List?)
              ?.map((e) => FamilyTaskAssignee.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      recurrenceType: json['recurrence_type'] as String,
      recurrenceDays: (json['recurrence_days'] as List?)?.map((e) => (e as num).toInt()).toList(),
      startDate: json['start_date'] as String,
      endDate: json['end_date'] as String?,
      timeStart: json['time_start'] as String?,
      timeEnd: json['time_end'] as String?,
      familyRewardId: json['family_reward_id'] as int?,
      notes: json['notes'] as String?,
      status: json['status'] as String,
      createdByUserId: json['created_by_user_id'] as int?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  final int id;
  final String title;
  final String? description;
  final String category;
  final int points;
  final bool requiresApproval;
  final bool assignToAll;
  final List<FamilyTaskAssignee> assignees;
  final String recurrenceType;
  final List<int>? recurrenceDays;
  final String startDate;
  final String? endDate;
  final String? timeStart;
  final String? timeEnd;
  final int? familyRewardId;
  final String? notes;
  final String status;
  final int? createdByUserId;
  final String? createdAt;
  final String? updatedAt;

  bool get isActive => status == 'active';
}

/// The `family_task` sub-object nested inside `FamilyTaskOccurrenceResource`
/// — deliberately a separate, narrower type from `FamilyTaskModel` above:
/// verified directly against that resource, it only ever carries
/// `id/title/category/points/requires_approval/time_start/time_end`, never
/// the full task shape (`assignees`/`recurrence_*`/etc. are absent here on
/// purpose, not merely unused).
class FamilyTaskOccurrenceTaskSummary {
  const FamilyTaskOccurrenceTaskSummary({
    required this.id,
    required this.title,
    required this.category,
    required this.points,
    required this.requiresApproval,
    this.timeStart,
    this.timeEnd,
  });

  factory FamilyTaskOccurrenceTaskSummary.fromJson(Map<String, dynamic> json) {
    return FamilyTaskOccurrenceTaskSummary(
      id: json['id'] as int,
      title: json['title'] as String,
      category: json['category'] as String,
      points: (json['points'] as num).toInt(),
      requiresApproval: json['requires_approval'] as bool,
      timeStart: json['time_start'] as String?,
      timeEnd: json['time_end'] as String?,
    );
  }

  final int id;
  final String title;
  final String category;
  final int points;
  final bool requiresApproval;
  final String? timeStart;
  final String? timeEnd;
}

/// The `family_member` sub-object nested inside `FamilyTaskOccurrenceResource`
/// — same narrow-on-purpose reasoning as `FamilyTaskOccurrenceTaskSummary`
/// above (verified directly: only `id`/`full_name`, never the full roster
/// shape `FamilyMemberModel` carries).
class FamilyTaskOccurrenceMemberSummary {
  const FamilyTaskOccurrenceMemberSummary({required this.id, required this.fullName});

  factory FamilyTaskOccurrenceMemberSummary.fromJson(Map<String, dynamic> json) {
    return FamilyTaskOccurrenceMemberSummary(id: json['id'] as int, fullName: json['full_name'] as String);
  }

  final int id;
  final String fullName;
}

/// One day's due instance of a task — mirrors `FamilyTaskOccurrenceResource`
/// field-for-field. `pointsAwarded` is a snapshot taken at generation/
/// approval time (see `family_task_occurrences` migration's docblock on the
/// backend) — it deliberately never tracks back to `task.points`, which may
/// have changed since.
class FamilyTaskOccurrenceModel {
  const FamilyTaskOccurrenceModel({
    required this.id,
    required this.status,
    required this.task,
    required this.member,
    this.occurrenceDate,
    this.completedAt,
    this.approvedAt,
    this.pointsAwarded,
    this.rejectionReason,
  });

  factory FamilyTaskOccurrenceModel.fromJson(Map<String, dynamic> json) {
    return FamilyTaskOccurrenceModel(
      id: json['id'] as int,
      occurrenceDate: json['occurrence_date'] as String?,
      status: json['status'] as String,
      completedAt: json['completed_at'] as String?,
      approvedAt: json['approved_at'] as String?,
      pointsAwarded: json['points_awarded'] as int?,
      rejectionReason: json['rejection_reason'] as String?,
      task: FamilyTaskOccurrenceTaskSummary.fromJson(Map<String, dynamic>.from(json['family_task'] as Map)),
      member: FamilyTaskOccurrenceMemberSummary.fromJson(Map<String, dynamic>.from(json['family_member'] as Map)),
    );
  }

  final int id;
  final String? occurrenceDate;
  final String status;
  final String? completedAt;
  final String? approvedAt;
  final int? pointsAwarded;
  final String? rejectionReason;
  final FamilyTaskOccurrenceTaskSummary task;
  final FamilyTaskOccurrenceMemberSummary member;

  /// Whether "✅ تم الإنجاز" should still be offered for this row — the
  /// occurrence has not been acted on at all yet. Every other status
  /// (`pending_approval`/`approved`/`rejected`/`missed`) is a terminal or
  /// awaiting-someone-else state from the tapping member's point of view.
  bool get canComplete => status == 'pending';

  /// Whether "اعتماد"/"رفض" should be offered on the parent's approval
  /// queue (PR-66) for this row.
  bool get canDecide => status == 'pending_approval';
}

/// "رصيد النقاط" — a single family member's points breakdown (PR-66),
/// mirroring `FamilyMemberPointsController::show()`'s response shape
/// field-for-field, verified directly against that controller. Deliberately
/// a separate type from `FamilyMemberModel`
/// (`features/family/data/family_models.dart`) — that one is the roster
/// row itself (and already carries the plain `points_balance` for the
/// shared scoreboard), this one is an aggregate read over
/// `family_point_transactions` that only exists once fetched for a specific
/// member, exactly like `FamilyTaskOccurrenceTaskSummary` is kept separate
/// from `FamilyTaskModel` above.
class FamilyMemberPointsModel {
  const FamilyMemberPointsModel({
    required this.familyMemberId,
    required this.pointsBalance,
    required this.pointsThisWeek,
    required this.pointsTotalEarned,
    required this.pointsSpentOnRewards,
  });

  factory FamilyMemberPointsModel.fromJson(Map<String, dynamic> json) {
    return FamilyMemberPointsModel(
      familyMemberId: json['family_member_id'] as int,
      pointsBalance: (json['points_balance'] as num).toInt(),
      pointsThisWeek: (json['points_this_week'] as num).toInt(),
      pointsTotalEarned: (json['points_total_earned'] as num).toInt(),
      pointsSpentOnRewards: (json['points_spent_on_rewards'] as num).toInt(),
    );
  }

  final int familyMemberId;
  final int pointsBalance;
  final int pointsThisWeek;
  final int pointsTotalEarned;
  final int pointsSpentOnRewards;
}

/// A single entry in the reward catalog — mirrors `FamilyRewardResource`
/// (backend/app/Http/Resources/Api/V1/FamilyRewardResource.php) field-for-
/// field, verified directly against that resource before building this,
/// same discipline every other model in this feature follows.
class FamilyRewardModel {
  const FamilyRewardModel({
    required this.id,
    required this.name,
    required this.pointsCost,
    required this.status,
    this.description,
    this.icon,
    this.createdAt,
    this.updatedAt,
  });

  factory FamilyRewardModel.fromJson(Map<String, dynamic> json) {
    return FamilyRewardModel(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      pointsCost: (json['points_cost'] as num).toInt(),
      icon: json['icon'] as String?,
      status: json['status'] as String,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  final int id;
  final String name;
  final String? description;
  final int pointsCost;
  final String? icon;
  final String status;
  final String? createdAt;
  final String? updatedAt;

  bool get isActive => status == 'active';
}

/// The `family_reward` sub-object nested inside
/// `FamilyRewardRedemptionResource` — deliberately a narrower type than
/// `FamilyRewardModel` above, verified directly against that resource: it
/// only ever carries `id/name/icon`, never `description`/`points_cost`/
/// `status` (the redemption's own `points_cost_snapshot` is what matters
/// once a request exists, not the reward's current, possibly-since-edited
/// price — see that migration's docblock).
class FamilyRewardRedemptionRewardSummary {
  const FamilyRewardRedemptionRewardSummary({required this.id, required this.name, this.icon});

  factory FamilyRewardRedemptionRewardSummary.fromJson(Map<String, dynamic> json) {
    return FamilyRewardRedemptionRewardSummary(
      id: json['id'] as int,
      name: json['name'] as String,
      icon: json['icon'] as String?,
    );
  }

  final int id;
  final String name;
  final String? icon;
}

/// The `family_member` sub-object nested inside
/// `FamilyRewardRedemptionResource` — same narrow-on-purpose reasoning as
/// `FamilyTaskOccurrenceMemberSummary` above (verified directly: only
/// `id`/`full_name`).
class FamilyRewardRedemptionMemberSummary {
  const FamilyRewardRedemptionMemberSummary({required this.id, required this.fullName});

  factory FamilyRewardRedemptionMemberSummary.fromJson(Map<String, dynamic> json) {
    return FamilyRewardRedemptionMemberSummary(id: json['id'] as int, fullName: json['full_name'] as String);
  }

  final int id;
  final String fullName;
}

/// A member's request to redeem a reward — mirrors
/// `FamilyRewardRedemptionResource` field-for-field, verified directly.
/// `pointsCostSnapshot` is frozen at request time (see
/// `create_family_reward_redemptions_table`'s migration docblock on the
/// backend) — it never tracks back to `reward.pointsCost`, which may have
/// changed since. There is deliberately no `rejectionReason` field here
/// (unlike `FamilyTaskOccurrenceModel`) — the backend has no such column
/// for a redemption at all, verified directly against both the resource
/// and the migration.
class FamilyRewardRedemptionModel {
  const FamilyRewardRedemptionModel({
    required this.id,
    required this.status,
    required this.pointsCostSnapshot,
    required this.reward,
    required this.member,
    this.requestedAt,
    this.decidedAt,
  });

  factory FamilyRewardRedemptionModel.fromJson(Map<String, dynamic> json) {
    return FamilyRewardRedemptionModel(
      id: json['id'] as int,
      status: json['status'] as String,
      pointsCostSnapshot: (json['points_cost_snapshot'] as num).toInt(),
      requestedAt: json['requested_at'] as String?,
      decidedAt: json['decided_at'] as String?,
      reward: FamilyRewardRedemptionRewardSummary.fromJson(Map<String, dynamic>.from(json['family_reward'] as Map)),
      member: FamilyRewardRedemptionMemberSummary.fromJson(Map<String, dynamic>.from(json['family_member'] as Map)),
    );
  }

  final int id;
  final String status;
  final int pointsCostSnapshot;
  final String? requestedAt;
  final String? decidedAt;
  final FamilyRewardRedemptionRewardSummary reward;
  final FamilyRewardRedemptionMemberSummary member;

  /// Whether "اعتماد"/"رفض" should be offered on the parent's redemption
  /// queue for this row — the lifecycle is `pending` → `approved`/
  /// `rejected`, with no further transitions (see
  /// `FamilyRewardRedemption::STATUSES`).
  bool get canDecide => status == 'pending';
}

/// A single family-wide challenge — mirrors `FamilyChallengeResource`
/// (backend/app/Http/Resources/Api/V1/FamilyChallengeResource.php)
/// field-for-field, verified directly against that resource before
/// building this. `categoryFilter` is deliberately nullable (unlike
/// `FamilyTaskModel.category`, always present) — `null` means "any task
/// counts toward this challenge's goal, not just one category", per
/// `FamilyChallenge::matches()`'s own check on the backend.
class FamilyChallengeModel {
  const FamilyChallengeModel({
    required this.id,
    required this.title,
    required this.goalTarget,
    required this.bonusPoints,
    required this.status,
    this.description,
    this.categoryFilter,
    this.startDate,
    this.endDate,
    this.createdAt,
    this.updatedAt,
  });

  factory FamilyChallengeModel.fromJson(Map<String, dynamic> json) {
    return FamilyChallengeModel(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      categoryFilter: json['category_filter'] as String?,
      goalTarget: (json['goal_target'] as num).toInt(),
      bonusPoints: (json['bonus_points'] as num).toInt(),
      startDate: json['start_date'] as String?,
      endDate: json['end_date'] as String?,
      status: json['status'] as String,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  final int id;
  final String title;
  final String? description;
  final String? categoryFilter;
  final int goalTarget;
  final int bonusPoints;
  final String? startDate;
  final String? endDate;
  final String status;
  final String? createdAt;
  final String? updatedAt;

  bool get isActive => status == 'active';
}

/// The `family_member` sub-object nested inside
/// `FamilyChallengeParticipantResource` — same narrow-on-purpose reasoning
/// as `FamilyTaskOccurrenceMemberSummary` above (verified directly: only
/// `id`/`full_name`).
class FamilyChallengeParticipantMemberSummary {
  const FamilyChallengeParticipantMemberSummary({required this.id, required this.fullName});

  factory FamilyChallengeParticipantMemberSummary.fromJson(Map<String, dynamic> json) {
    return FamilyChallengeParticipantMemberSummary(id: json['id'] as int, fullName: json['full_name'] as String);
  }

  final int id;
  final String fullName;
}

/// One entry in the platform-wide badge catalog (PR-69) — mirrors
/// `FamilyAchievementResource` field-for-field, verified directly against
/// that resource before building this. Deliberately carries no
/// `criteria_type`/`criteria_value` at all — the backend resource itself
/// never exposes them (see that resource's own docblock: "an internal
/// evaluation detail"), so `description` is already the plain-language
/// Arabic text a viewer needs (e.g. "إنجاز أول 5 مهام") and this app has no
/// criteria-formatting logic to build at all, unlike
/// `familyTaskCategoryLabels`/`familyChallengeStatusLabels` above which do
/// translate a raw enum value. The catalog itself is identical and shared
/// across every family (verified directly: `FamilyAchievement` has no
/// `family_id`/`BelongsToFamily`, see that model's own docblock, and PR-63's
/// tenant-isolation test confirms it), so this model never carries a
/// family-scoped field either.
class FamilyAchievementModel {
  const FamilyAchievementModel({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    this.icon,
  });

  factory FamilyAchievementModel.fromJson(Map<String, dynamic> json) {
    return FamilyAchievementModel(
      id: json['id'] as int,
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
    );
  }

  final int id;
  final String code;
  final String name;
  final String? description;
  final String? icon;
}

/// The `achievement` sub-object nested inside
/// `FamilyMemberAchievementResource` — same shape as
/// `FamilyAchievementModel` above (verified directly against that
/// resource's own nested array: `id/code/name/description/icon`), kept as a
/// separate type rather than reusing `FamilyAchievementModel` because it is
/// parsed from a different JSON shape (a plain nested map, not a resource
/// collection item) — same "narrow, nested summary" convention as
/// `FamilyTaskOccurrenceTaskSummary`/`FamilyRewardRedemptionRewardSummary`
/// above.
class FamilyMemberAchievementBadgeSummary {
  const FamilyMemberAchievementBadgeSummary({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    this.icon,
  });

  factory FamilyMemberAchievementBadgeSummary.fromJson(Map<String, dynamic> json) {
    return FamilyMemberAchievementBadgeSummary(
      id: json['id'] as int,
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
    );
  }

  final int id;
  final String code;
  final String name;
  final String? description;
  final String? icon;
}

/// One badge a member has actually earned — mirrors
/// `FamilyMemberAchievementResource` field-for-field, verified directly.
/// Written exclusively by `FamilyAchievementEvaluator` server-side (see that
/// service's docblock) — there is no create/grant endpoint at all, so this
/// model (like `FamilyAchievementModel` above) is only ever read, never
/// built from user input on this client.
class FamilyMemberAchievementModel {
  const FamilyMemberAchievementModel({required this.id, required this.earnedAt, required this.achievement});

  factory FamilyMemberAchievementModel.fromJson(Map<String, dynamic> json) {
    return FamilyMemberAchievementModel(
      id: json['id'] as int,
      earnedAt: json['earned_at'] as String?,
      achievement: FamilyMemberAchievementBadgeSummary.fromJson(
        Map<String, dynamic>.from(json['achievement'] as Map),
      ),
    );
  }

  final int id;
  final String? earnedAt;
  final FamilyMemberAchievementBadgeSummary achievement;
}

/// One member's progress row on a challenge — mirrors
/// `FamilyChallengeParticipantResource` field-for-field, verified directly.
/// Deliberately carries no rank/position field at all (the backend
/// resource has none) — `FamilyChallengeDetailScreen` renders this list
/// unsorted by progress (declaration order from the API, itself unordered
/// by the controller), matching plan judgment call #7's "no
/// negative/competitive ranking" principle, already established for the
/// weekly report (PR-64): a plain, factual "how much has each member
/// completed toward the goal", never "who's in Nth place".
class FamilyChallengeParticipantModel {
  const FamilyChallengeParticipantModel({
    required this.id,
    required this.progressCount,
    required this.goalTarget,
    required this.member,
    this.completedAt,
  });

  factory FamilyChallengeParticipantModel.fromJson(Map<String, dynamic> json) {
    return FamilyChallengeParticipantModel(
      id: json['id'] as int,
      progressCount: (json['progress_count'] as num).toInt(),
      goalTarget: (json['goal_target'] as num).toInt(),
      completedAt: json['completed_at'] as String?,
      member: FamilyChallengeParticipantMemberSummary.fromJson(
        Map<String, dynamic>.from(json['family_member'] as Map),
      ),
    );
  }

  final int id;
  final int progressCount;
  final int goalTarget;
  final String? completedAt;
  final FamilyChallengeParticipantMemberSummary member;

  /// Whether this participant has reached the challenge's goal — mirrors
  /// `completed_at` being non-null server-side (set by
  /// `FamilyChallengeProgressService` once `progress_count >= goal_target`,
  /// see that service's docblock on the backend).
  bool get isCompleted => completedAt != null;
}

/// One row of `FamilyWeeklyReportController::show()`'s `members` array
/// (PR-64 backend, PR-70 mobile) — mirrors that response field-for-field,
/// verified directly against the controller. `approvalRate` is nullable:
/// the backend only computes it once at least one occurrence has been
/// decided (`approved` or `rejected`) this week, `null` otherwise (never
/// `0` as a stand-in — see that controller's own `$decided > 0 ? ... :
/// null` line). This list is deliberately never sorted by this app —
/// `FamilyWeeklyReportScreen` renders it in exactly the order the backend
/// returns it (by `family_member_id`, verified directly), matching plan
/// judgment call #7's "no client-side ranking on top of a response that
/// deliberately has none" principle, already established for
/// `FamilyChallengeParticipantModel` above.
class FamilyWeeklyReportMemberModel {
  const FamilyWeeklyReportMemberModel({
    required this.familyMemberId,
    required this.fullName,
    required this.tasksCompleted,
    required this.pointsEarned,
    this.approvalRate,
  });

  factory FamilyWeeklyReportMemberModel.fromJson(Map<String, dynamic> json) {
    return FamilyWeeklyReportMemberModel(
      familyMemberId: json['family_member_id'] as int,
      fullName: json['full_name'] as String,
      tasksCompleted: (json['tasks_completed'] as num).toInt(),
      pointsEarned: (json['points_earned'] as num).toInt(),
      approvalRate: (json['approval_rate'] as num?)?.toDouble(),
    );
  }

  final int familyMemberId;
  final String fullName;
  final int tasksCompleted;
  final int pointsEarned;
  final double? approvalRate;
}

/// One entry inside `highlights.most_tasks_completed`/`highlights.most_improved`
/// (PR-64 backend) — both are shaped identically
/// (`family_member_id`/`full_name` plus one differently-named numeric
/// field, `tasks_completed` or `improvement`), verified directly against
/// `FamilyWeeklyReportController::topBy()`, so this single model covers
/// both via an explicit `valueKey` passed at parse time rather than two
/// near-duplicate classes. Every entry here is guaranteed positive and
/// non-arbitrary by the backend itself (see that controller's own
/// docblock: zero never "wins", and every member tied for the max is
/// listed, never just one) — this app renders every entry it receives with
/// no further filtering/sorting of its own.
class FamilyWeeklyReportHighlightEntryModel {
  const FamilyWeeklyReportHighlightEntryModel({
    required this.familyMemberId,
    required this.fullName,
    required this.value,
  });

  factory FamilyWeeklyReportHighlightEntryModel.fromJson(Map<String, dynamic> json, String valueKey) {
    return FamilyWeeklyReportHighlightEntryModel(
      familyMemberId: json['family_member_id'] as int,
      fullName: json['full_name'] as String,
      value: (json[valueKey] as num).toInt(),
    );
  }

  final int familyMemberId;
  final String fullName;
  final int value;
}

/// "التقرير الأسبوعي" (PR-70) — mirrors
/// `FamilyWeeklyReportController::show()`'s full response shape, verified
/// directly. **This is the one model in this whole feature built
/// specifically to enforce plan judgment call #7 on the client side too**:
/// there is no field here (and must never be added) for "least"/"lowest"/
/// "worst"/rank — the backend's own docblock explains at length why that
/// endpoint was designed to make such a field structurally impossible to
/// return, and this model only ever exposes what it actually sends
/// (`members` plus two purely positive `highlights` lists).
class FamilyWeeklyReportModel {
  const FamilyWeeklyReportModel({
    required this.weekStart,
    required this.weekEnd,
    required this.members,
    required this.mostTasksCompleted,
    required this.mostImproved,
  });

  factory FamilyWeeklyReportModel.fromJson(Map<String, dynamic> json) {
    final highlights = Map<String, dynamic>.from(json['highlights'] as Map);

    return FamilyWeeklyReportModel(
      weekStart: json['week_start'] as String,
      weekEnd: json['week_end'] as String,
      members: (json['members'] as List)
          .map((e) => FamilyWeeklyReportMemberModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      mostTasksCompleted: (highlights['most_tasks_completed'] as List)
          .map(
            (e) => FamilyWeeklyReportHighlightEntryModel.fromJson(
              Map<String, dynamic>.from(e as Map),
              'tasks_completed',
            ),
          )
          .toList(),
      mostImproved: (highlights['most_improved'] as List)
          .map(
            (e) => FamilyWeeklyReportHighlightEntryModel.fromJson(
              Map<String, dynamic>.from(e as Map),
              'improvement',
            ),
          )
          .toList(),
    );
  }

  final String weekStart;
  final String weekEnd;
  final List<FamilyWeeklyReportMemberModel> members;
  final List<FamilyWeeklyReportHighlightEntryModel> mostTasksCompleted;
  final List<FamilyWeeklyReportHighlightEntryModel> mostImproved;
}
