import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/family_tasks_providers.dart';
import '../data/family_task_models.dart';

/// PR-69: one family member's badges — every catalog entry shown in a
/// binary earned/not-yet-earned state, never a percentage or a progress
/// bar toward earning it (the plan calls for exactly that: "شارات كل فرد",
/// not a prediction). Reached only from
/// `FamilyAchievementsMemberPickerScreen`, which already narrows the
/// roster to rows this account is allowed to open (see that screen's
/// docblock) — a 403 here still surfaces as a plain error state below
/// rather than crashing, exactly like `FamilyMemberPointsDetailScreen`.
///
/// Combines two independent reads — the full catalog
/// (`familyAchievementsProvider`, identical for every family) and this one
/// member's earned rows (`familyMemberAchievementsProvider`) — the same
/// "nest a second `.when()` inside the first" pattern
/// `FamilyRewardRequestScreen._BalanceAndSubmit` already uses for
/// `familyMemberPointsProvider`, rather than trying to combine two
/// `AsyncValue`s into one before rendering.
///
/// Deliberately shows only positive/neutral information (earned + date, or
/// not yet earned) — there is no comparison against a sibling anywhere on
/// this screen (it only ever fetches one member's earned list at a time),
/// so unlike the weekly report (PR-64) there was no "no negative field"
/// constraint to design around here either — the same reasoning
/// `FamilyMemberPointsDetailScreen`'s own docblock gives.
class FamilyMemberAchievementsScreen extends ConsumerWidget {
  const FamilyMemberAchievementsScreen({required this.familyMemberId, required this.memberName, super.key});

  final int familyMemberId;
  final String memberName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(familyAchievementsProvider);

    return Scaffold(
      appBar: AppBar(title: Text('شارات $memberName')),
      body: catalogAsync.when(
        data: (catalog) => _EarnedBadgesBody(
          familyMemberId: familyMemberId,
          catalog: catalog,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(familyAchievementsProvider),
        ),
      ),
    );
  }
}

class _EarnedBadgesBody extends ConsumerWidget {
  const _EarnedBadgesBody({required this.familyMemberId, required this.catalog});

  final int familyMemberId;
  final List<FamilyAchievementModel> catalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earnedAsync = ref.watch(familyMemberAchievementsProvider(familyMemberId));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(familyMemberAchievementsProvider(familyMemberId)),
      child: earnedAsync.when(
        data: (earned) {
          // Keyed by achievement code, not id — matches every other
          // cross-resource identity this feature relies on (`code` is the
          // catalog's own unique key, verified directly against
          // `family_achievements`' migration), and stays correct even if a
          // future catalog entry's numeric id ever diverges between the two
          // endpoints for any reason.
          final earnedByCode = {for (final entry in earned) entry.achievement.code: entry};

          if (catalog.isEmpty) {
            return LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('لا توجد شارات بعد.', textAlign: TextAlign.center),
                    ),
                  ),
                ),
              ),
            );
          }

          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            itemCount: catalog.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final achievement = catalog[index];
              final earnedEntry = earnedByCode[achievement.code];

              return _BadgeCard(achievement: achievement, earnedEntry: earnedEntry);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(familyMemberAchievementsProvider(familyMemberId)),
        ),
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.achievement, required this.earnedEntry});

  final FamilyAchievementModel achievement;
  final FamilyMemberAchievementModel? earnedEntry;

  @override
  Widget build(BuildContext context) {
    final isEarned = earnedEntry != null;
    final icon = achievement.icon != null && achievement.icon!.trim().isNotEmpty ? achievement.icon!.trim() : '🏅';

    return Card(
      color: isEarned ? null : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isEarned ? Theme.of(context).colorScheme.primaryContainer : null,
          child: Opacity(opacity: isEarned ? 1 : 0.35, child: Text(icon)),
        ),
        title: Text(
          achievement.name,
          style: TextStyle(color: isEarned ? null : Theme.of(context).disabledColor),
        ),
        subtitle: achievement.description != null && achievement.description!.isNotEmpty
            ? Text(
                achievement.description!,
                style: TextStyle(color: isEarned ? null : Theme.of(context).disabledColor),
              )
            : null,
        trailing: isEarned
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  if (earnedEntry!.earnedAt != null)
                    Text(
                      _formatDate(earnedEntry!.earnedAt!),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              )
            : Icon(Icons.lock_outline, color: Theme.of(context).disabledColor),
      ),
    );
  }

  String _formatDate(String isoDate) {
    // `earned_at` comes back as a full ISO-8601 timestamp (Eloquent's
    // `datetime` cast, see `FamilyMemberAchievement`'s own docblock) —
    // this only ever needs the date portion for a compact trailing label,
    // same "cheap substring, no intl dependency" convention already used
    // elsewhere in this feature (e.g. `MyFamilyTasksScreen`'s own day
    // header formatting).
    return isoDate.length >= 10 ? isoDate.substring(0, 10) : isoDate;
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('تعذر تحميل الشارات: $message', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
