import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/family_tasks_providers.dart';
import '../data/family_task_models.dart';

/// PR-69 (Family Tasks & Achievements, mobile): "كتالوج الشارات" — the
/// fixed, platform-wide badge catalog seeded server-side by
/// `FamilyAchievementsSeeder` (verified directly: six badges today, but
/// this screen renders however many `GET /family-achievements` actually
/// returns rather than assuming that count). Purely read-only from this
/// client, like the rest of this feature's achievements surface — there is
/// no create/edit/grant endpoint at all (`FamilyAchievementController` only
/// exposes `index()`/`memberAchievements()`, verified directly), badges are
/// granted exclusively by `FamilyAchievementEvaluator::evaluate()` after
/// every approved task occurrence, server-side, with no mobile trigger of
/// any kind.
///
/// Deliberately shows `name`/`description`/`icon` only — `criteria_type`/
/// `criteria_value` are never sent by `FamilyAchievementResource` at all
/// (see `FamilyAchievementModel`'s own docblock), and `description` is
/// already the plain-language Arabic text a viewer needs (e.g. "إنجاز أول 5
/// مهام"), so there is no criteria-formatting logic to build here.
///
/// The one entry point into this whole PR-69 surface is
/// `FamilyTasksListScreen`'s new app-bar icon (same "new feature icon on
/// the tasks board, not on `FamilyHomeScreen`" convention PR-66/67/68 all
/// followed). From here, a single app-bar action opens "شارات الأفراد" —
/// the member picker (`FamilyAchievementsMemberPickerScreen`) — because the
/// catalog itself has no per-member concept at all, only the next screen
/// does.
class FamilyAchievementsCatalogScreen extends ConsumerWidget {
  const FamilyAchievementsCatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievementsAsync = ref.watch(familyAchievementsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإنجازات والشارات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_search_outlined),
            tooltip: 'شارات الأفراد',
            onPressed: () => context.push('/family/achievements/members'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(familyAchievementsProvider),
        child: achievementsAsync.when(
          data: (achievements) => _CatalogList(achievements: achievements),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _ErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(familyAchievementsProvider),
          ),
        ),
      ),
    );
  }
}

class _CatalogList extends StatelessWidget {
  const _CatalogList({required this.achievements});

  final List<FamilyAchievementModel> achievements;

  @override
  Widget build(BuildContext context) {
    if (achievements.isEmpty) {
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
      itemCount: achievements.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final achievement = achievements[index];

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              child: Text(
                achievement.icon != null && achievement.icon!.trim().isNotEmpty ? achievement.icon!.trim() : '🏅',
              ),
            ),
            title: Text(achievement.name),
            subtitle: achievement.description != null && achievement.description!.isNotEmpty
                ? Text(achievement.description!)
                : null,
          ),
        );
      },
    );
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
