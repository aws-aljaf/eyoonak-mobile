import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/family_tasks_providers.dart';
import '../data/family_task_models.dart';
import '../data/suggested_task_library.dart';

/// PR-68: the family-wide challenge catalog — every active member sees it
/// (`FamilyChallengePolicy::viewAny()` is unconditionally true, see that
/// policy's docblock: like the task board/reward catalog, this is meant to
/// be visible to everyone). Reached from `FamilyTasksListScreen`'s new
/// "التحديات" app-bar icon — a single icon added there rather than
/// crowding `FamilyHomeScreen`'s already-dense app bar further, same call
/// PR-66/PR-67 already made for their own new entry points.
///
/// The "+ إنشاء تحدٍ" FAB and each card's edit/delete affordances are
/// gated on `canManageFamilyTasksProvider` (reused as-is — challenges use
/// the exact same `owner`/`parent`/`admin` role set as tasks/rewards);
/// real enforcement stays `FamilyChallengePolicy::create()`/`update()`/
/// `delete()` server-side. Tapping any card (manager or not) opens the
/// detail screen, which shows the progress board and, for a member who
/// hasn't joined yet, a "المشاركة" button.
class FamilyChallengesListScreen extends ConsumerWidget {
  const FamilyChallengesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengesAsync = ref.watch(familyChallengesProvider);
    final statusFilter = ref.watch(familyChallengesStatusFilterProvider);
    final canManage = ref.watch(canManageFamilyTasksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('التحديات العائلية'),
        actions: [
          PopupMenuButton<String?>(
            tooltip: 'تصفية الحالة',
            icon: const Icon(Icons.filter_list),
            initialValue: statusFilter,
            onSelected: (value) => ref.read(familyChallengesStatusFilterProvider.notifier).state = value,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'active', child: Text('النشطة فقط')),
              PopupMenuItem(value: 'completed', child: Text('المكتملة فقط')),
              PopupMenuItem(value: 'archived', child: Text('المؤرشفة فقط')),
              PopupMenuItem(value: null, child: Text('الكل')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(familyChallengesProvider),
        child: challengesAsync.when(
          data: (challenges) => _ChallengeList(challenges: challenges, canManage: canManage),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _ErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(familyChallengesProvider),
          ),
        ),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/family/challenges/new'),
              icon: const Icon(Icons.flag_outlined),
              label: const Text('إنشاء تحدٍ'),
            )
          : null,
    );
  }
}

class _ChallengeList extends StatelessWidget {
  const _ChallengeList({required this.challenges, required this.canManage});

  final List<FamilyChallengeModel> challenges;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    if (challenges.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  canManage
                      ? 'لا توجد تحديات بعد. اضغط على "إنشاء تحدٍ" للبدء.'
                      : 'لا توجد تحديات بعد.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: challenges.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _ChallengeCard(challenge: challenges[index]),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({required this.challenge});

  final FamilyChallengeModel challenge;

  @override
  Widget build(BuildContext context) {
    final statusLabel = familyChallengeStatusLabels[challenge.status] ?? challenge.status;
    final categoryLabel = challenge.categoryFilter == null
        ? 'كل التصنيفات'
        : (familyTaskCategoryLabels[challenge.categoryFilter] ?? challenge.categoryFilter!);

    return Card(
      child: ListTile(
        onTap: () => context.push('/family/challenges/${challenge.id}'),
        leading: const CircleAvatar(child: Icon(Icons.flag_outlined)),
        title: Text(challenge.title),
        subtitle: Text(
          [
            'الهدف: ${challenge.goalTarget}',
            categoryLabel,
            '${challenge.bonusPoints} نقطة إضافية',
            if (!challenge.isActive) statusLabel,
          ].join(' • '),
        ),
        trailing: const Icon(Icons.chevron_left),
      ),
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
                  Text('تعذر تحميل التحديات: $message', textAlign: TextAlign.center),
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
