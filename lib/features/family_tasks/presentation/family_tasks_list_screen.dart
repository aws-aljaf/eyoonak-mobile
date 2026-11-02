import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/family_tasks_providers.dart';
import '../data/family_task_models.dart';
import '../data/suggested_task_library.dart';

/// The family's shared task board — every active family member sees it
/// (`FamilyTaskPolicy::viewAny()` is unconditionally true, see that
/// policy's docblock: "المهام" is meant to be visible to everyone, not
/// just whoever a task happens to be assigned to). This is the PR-65 mobile
/// entry point named in the plan's "خارطة التنفيذ" row for this PR — reached
/// from `FamilyHomeScreen`'s new "✅ المهام" app-bar icon.
///
/// The "+ إضافة مهمة" FAB and each card's edit/delete affordances are
/// gated on `canManageFamilyTasksProvider` (owner/parent/admin for the
/// currently selected family) — real enforcement is still
/// `FamilyTaskPolicy::create()`/`update()`/`delete()` server-side, this is
/// only UX (see that provider's own docblock).
class FamilyTasksListScreen extends ConsumerWidget {
  const FamilyTasksListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(familyTasksProvider);
    final statusFilter = ref.watch(familyTasksStatusFilterProvider);
    final canManage = ref.watch(canManageFamilyTasksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('المهام العائلية'),
        actions: [
          PopupMenuButton<String?>(
            tooltip: 'تصفية الحالة',
            icon: const Icon(Icons.filter_list),
            initialValue: statusFilter,
            onSelected: (value) => ref.read(familyTasksStatusFilterProvider.notifier).state = value,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'active', child: Text('النشطة فقط')),
              PopupMenuItem(value: 'archived', child: Text('المؤرشفة فقط')),
              PopupMenuItem(value: null, child: Text('الكل')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.checklist_outlined),
            tooltip: 'مهامي',
            onPressed: () => context.push('/family/tasks/mine'),
          ),
          // PR-66: "قائمة انتظار موافقة الوالد" — manager-only, gated the
          // same way this screen's own FAB is (`canManageFamilyTasksProvider`).
          // The real boundary stays `FamilyTaskOccurrencePolicy::approve()`/
          // `::reject()` server-side (see `FamilyApprovalQueueScreen`'s own
          // docblock).
          if (canManage)
            IconButton(
              icon: const Icon(Icons.fact_check_outlined),
              tooltip: 'طلبات الموافقة',
              onPressed: () => context.push('/family/tasks/approvals'),
            ),
          // PR-66: "رصيد النقاط" — reachable by everyone (not gated on
          // `canManage`), since a plain member can always view their own
          // breakdown; `FamilyPointsScreen` itself narrows what it renders
          // per viewer (see that screen's own docblock).
          IconButton(
            icon: const Icon(Icons.stars_outlined),
            tooltip: 'رصيد النقاط',
            onPressed: () => context.push('/family/points'),
          ),
          // PR-67 (Family Tasks & Achievements, mobile): the reward
          // catalog — reachable by everyone (not gated on `canManage`),
          // same reasoning as "رصيد النقاط" above: a plain member may
          // always browse the catalog and request a redemption
          // (`FamilyRewardPolicy::viewAny()` is unconditionally true);
          // `FamilyRewardsListScreen` itself gates create/edit/archive on
          // `canManageFamilyTasksProvider`.
          IconButton(
            icon: const Icon(Icons.card_giftcard_outlined),
            tooltip: 'المكافآت',
            onPressed: () => context.push('/family/rewards'),
          ),
          // PR-68 (Family Tasks & Achievements, mobile): the challenge
          // catalog — reachable by everyone (not gated on `canManage`),
          // same reasoning as "رصيد النقاط"/"المكافآت" above: a plain
          // member may always browse challenges and join one
          // (`FamilyChallengePolicy::viewAny()` is unconditionally true);
          // `FamilyChallengesListScreen` itself gates create/edit/delete on
          // `canManageFamilyTasksProvider`.
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'التحديات',
            onPressed: () => context.push('/family/challenges'),
          ),
          // PR-69 (Family Tasks & Achievements, mobile): the badge catalog
          // — reachable by everyone (not gated on `canManage`), same
          // reasoning as "رصيد النقاط"/"المكافآت"/"التحديات" above: the
          // catalog is read-only and identical for every family, and a
          // plain member may always view it plus their own earned badges
          // (`FamilyAchievementController` has no policy gate at all — see
          // that controller's own docblock).
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined),
            tooltip: 'الإنجازات والشارات',
            onPressed: () => context.push('/family/achievements'),
          ),
          // PR-70 (Family Tasks & Achievements, mobile, final PR): the
          // weekly report — reachable by everyone (not gated on
          // `canManage`), same reasoning as every other icon added to this
          // bar since PR-66: `FamilyTaskPolicy::viewAny()` is
          // unconditionally true, and `FamilyWeeklyReportController` has no
          // manager-only restriction of its own either. Also reachable via
          // `FamilyHomeScreen`'s new six-pillar grid ("📊التقرير") — kept
          // here too as a second, equally valid entry point, same as every
          // other icon on this bar.
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined),
            tooltip: 'التقرير الأسبوعي',
            onPressed: () => context.push('/family/tasks/weekly-report'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(familyTasksProvider),
        child: tasksAsync.when(
          data: (tasks) => _TaskList(tasks: tasks, canManage: canManage),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _ErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(familyTasksProvider),
          ),
        ),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/family/tasks/new'),
              icon: const Icon(Icons.add_task),
              label: const Text('إضافة مهمة'),
            )
          : null,
    );
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({required this.tasks, required this.canManage});

  final List<FamilyTaskModel> tasks;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
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
                      ? 'لا توجد مهام بعد. اضغط على "إضافة مهمة" للبدء.'
                      : 'لا توجد مهام بعد.',
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
      itemCount: tasks.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _TaskCard(task: tasks[index]),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});

  final FamilyTaskModel task;

  @override
  Widget build(BuildContext context) {
    final categoryLabel = familyTaskCategoryLabels[task.category] ?? task.category;
    final recurrenceLabel = familyTaskRecurrenceLabels[task.recurrenceType] ?? task.recurrenceType;
    final assigneeSummary = task.assignToAll
        ? 'كل أفراد العائلة'
        : (task.assignees.isEmpty
            ? 'لا يوجد إسناد'
            : task.assignees.map((a) => a.fullName).join('، '));

    return Card(
      child: ListTile(
        onTap: () => context.push('/family/tasks/${task.id}'),
        leading: CircleAvatar(child: Text('${task.points}')),
        title: Text(task.title),
        subtitle: Text(
          [
            categoryLabel,
            recurrenceLabel,
            assigneeSummary,
            if (!task.isActive) 'مؤرشفة',
          ].join(' • '),
        ),
        trailing: task.requiresApproval ? const Icon(Icons.verified_user_outlined, size: 20) : null,
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
                  Text('تعذر تحميل المهام: $message', textAlign: TextAlign.center),
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
