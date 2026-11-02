import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_exception.dart';
import '../../family/application/family_providers.dart';
import '../application/family_tasks_providers.dart';
import '../data/family_task_models.dart';
import '../data/suggested_task_library.dart';

/// PR-67: the reward catalog — every active family member sees it
/// (`FamilyRewardPolicy::viewAny()` is unconditionally true, see that
/// policy's docblock: like the task board, this is meant to be visible to
/// everyone so they know what they're saving points for). Reached from
/// `FamilyTasksListScreen`'s new "المكافآت" app-bar icon — a single icon
/// added there rather than crowding `FamilyHomeScreen`'s already-dense app
/// bar further, same call PR-66 already made for "طلبات الموافقة"/"رصيد
/// النقاط".
///
/// The "+ إضافة مكافأة" FAB and each card's edit/archive/delete
/// affordances are gated on `canManageFamilyTasksProvider` (reused as-is —
/// rewards use the exact same `owner`/`parent`/`admin` role set as tasks);
/// real enforcement stays `FamilyRewardPolicy::create()`/`update()`/
/// `delete()` server-side. Tapping a card (any account, manager or not)
/// opens the redemption request flow — a manager may additionally pick
/// *which* family member is requesting (see `FamilyRewardRequestScreen`'s
/// own docblock).
class FamilyRewardsListScreen extends ConsumerWidget {
  const FamilyRewardsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewardsAsync = ref.watch(familyRewardsProvider);
    final statusFilter = ref.watch(familyRewardsStatusFilterProvider);
    final canManage = ref.watch(canManageFamilyTasksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('المكافآت'),
        actions: [
          PopupMenuButton<String?>(
            tooltip: 'تصفية الحالة',
            icon: const Icon(Icons.filter_list),
            initialValue: statusFilter,
            onSelected: (value) => ref.read(familyRewardsStatusFilterProvider.notifier).state = value,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'active', child: Text('النشطة فقط')),
              PopupMenuItem(value: 'archived', child: Text('المؤرشفة فقط')),
              PopupMenuItem(value: null, child: Text('الكل')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'طلباتي',
            onPressed: () => context.push('/family/rewards/mine'),
          ),
          // Manager-only, same gating convention as "طلبات الموافقة" on
          // `FamilyTasksListScreen` — the real boundary stays
          // `FamilyRewardRedemptionPolicy::approve()`/`::reject()`
          // server-side (see `FamilyRewardRedemptionsQueueScreen`'s own
          // docblock).
          if (canManage)
            IconButton(
              icon: const Icon(Icons.playlist_add_check_outlined),
              tooltip: 'طلبات الاستبدال',
              onPressed: () => context.push('/family/rewards/redemptions'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(familyRewardsProvider),
        child: rewardsAsync.when(
          data: (rewards) => _RewardList(rewards: rewards, canManage: canManage),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _ErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(familyRewardsProvider),
          ),
        ),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/family/rewards/new'),
              icon: const Icon(Icons.add),
              label: const Text('إضافة مكافأة'),
            )
          : null,
    );
  }
}

class _RewardList extends StatelessWidget {
  const _RewardList({required this.rewards, required this.canManage});

  final List<FamilyRewardModel> rewards;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    if (rewards.isEmpty) {
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
                      ? 'لا توجد مكافآت بعد. اضغط على "إضافة مكافأة" للبدء.'
                      : 'لا توجد مكافآت بعد.',
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
      itemCount: rewards.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _RewardCard(reward: rewards[index], canManage: canManage),
    );
  }
}

class _RewardCard extends ConsumerWidget {
  const _RewardCard({required this.reward, required this.canManage});

  final FamilyRewardModel reward;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusLabel = familyRewardStatusLabels[reward.status] ?? reward.status;

    return Card(
      child: ListTile(
        onTap: reward.isActive ? () => context.push('/family/rewards/${reward.id}/request', extra: reward) : null,
        leading: CircleAvatar(
          child: Text(reward.icon != null && reward.icon!.trim().isNotEmpty ? reward.icon!.trim() : '🎁'),
        ),
        title: Text(reward.name),
        subtitle: Text(
          [
            '${reward.pointsCost} نقطة',
            if (!reward.isActive) statusLabel,
            if (reward.description != null && reward.description!.isNotEmpty) reward.description!,
          ].join(' • '),
        ),
        trailing: canManage
            ? PopupMenuButton<String>(
                tooltip: 'المزيد',
                onSelected: (value) {
                  if (value == 'edit') {
                    context.push('/family/rewards/${reward.id}/edit', extra: reward);
                  } else if (value == 'toggle_status') {
                    _toggleStatus(context, ref);
                  } else if (value == 'delete') {
                    _delete(context, ref);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                  PopupMenuItem(
                    value: 'toggle_status',
                    child: Text(reward.isActive ? 'أرشفة' : 'إعادة تفعيل'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('حذف', style: TextStyle(color: Colors.red.shade700)),
                  ),
                ],
              )
            : (reward.isActive ? const Icon(Icons.chevron_left) : null),
      ),
    );
  }

  Future<void> _toggleStatus(BuildContext context, WidgetRef ref) async {
    final familyId = ref.read(selectedFamilyIdProvider);
    final nextStatus = reward.isActive ? 'archived' : 'active';

    try {
      await ref.read(familyTasksApiProvider).updateReward(
            rewardId: reward.id,
            name: reward.name,
            description: reward.description,
            pointsCost: reward.pointsCost,
            icon: reward.icon,
            status: nextStatus,
            familyId: familyId,
          );
      ref.invalidate(familyRewardsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(nextStatus == 'archived' ? 'تمت أرشفة المكافأة' : 'تمت إعادة تفعيل المكافأة')),
        );
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحديث المكافأة: $error')));
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المكافأة'),
        content: Text('سيتم حذف مكافأة "${reward.name}" نهائيًا من الكتالوج. هل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final familyId = ref.read(selectedFamilyIdProvider);

      await ref.read(familyTasksApiProvider).deleteReward(rewardId: reward.id, familyId: familyId);
      ref.invalidate(familyRewardsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف المكافأة')));
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حذف المكافأة: $error')));
      }
    }
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
                  Text('تعذر تحميل المكافآت: $message', textAlign: TextAlign.center),
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
