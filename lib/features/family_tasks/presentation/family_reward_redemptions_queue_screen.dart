import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_exception.dart';
import '../../family/application/family_providers.dart';
import '../application/family_tasks_providers.dart';
import '../data/family_task_models.dart';

/// PR-67: "قائمة انتظار موافقة استبدال المكافآت" — every `pending`
/// redemption across the whole family, with "اعتماد"/"رفض" actions.
/// Manager-only, same `canManageFamilyTasksProvider` client-side signal
/// `FamilyApprovalQueueScreen` (PR-66) already uses — the HTTP request
/// itself, gated by `FamilyRewardRedemptionPolicy::approve()`/`::reject()`,
/// remains the real boundary (no self-decision branch at all, same as that
/// policy's task-occurrence counterpart). Only reachable from
/// `FamilyRewardsListScreen`'s own app-bar icon, itself only rendered when
/// `canManageFamilyTasksProvider` is true.
///
/// Unlike `FamilyApprovalQueueScreen`, there is no day-by-day navigation
/// here — `redemptions()` has no date filter at all (verified directly
/// against `FamilyRewardRedemptionController::index()`), so this is a
/// flat, undated list of everything currently `pending`.
///
/// "رفض" has **no reason dialog** — unlike task-occurrence rejection,
/// `FamilyRewardRedemptionController::reject()` takes no request body and
/// `family_reward_redemptions` has no `rejection_reason` column at all
/// (verified directly against both the controller and the migration), so
/// this screen only asks for a plain yes/no confirmation rather than
/// offering a text field the backend would silently discard.
class FamilyRewardRedemptionsQueueScreen extends ConsumerWidget {
  const FamilyRewardRedemptionsQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final redemptionsAsync = ref.watch(pendingRedemptionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('طلبات استبدال المكافآت')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(pendingRedemptionsProvider),
        child: redemptionsAsync.when(
          data: (redemptions) => _QueueList(redemptions: redemptions),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _ErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(pendingRedemptionsProvider),
          ),
        ),
      ),
    );
  }
}

class _QueueList extends StatelessWidget {
  const _QueueList({required this.redemptions});

  final List<FamilyRewardRedemptionModel> redemptions;

  @override
  Widget build(BuildContext context) {
    if (redemptions.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: const Center(child: Text('لا توجد طلبات استبدال بانتظار الموافقة.')),
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: redemptions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _QueueCard(redemption: redemptions[index]),
    );
  }
}

class _QueueCard extends ConsumerStatefulWidget {
  const _QueueCard({required this.redemption});

  final FamilyRewardRedemptionModel redemption;

  @override
  ConsumerState<_QueueCard> createState() => _QueueCardState();
}

class _QueueCardState extends ConsumerState<_QueueCard> {
  bool _busy = false;

  FamilyRewardRedemptionModel get redemption => widget.redemption;

  @override
  Widget build(BuildContext context) {
    final reward = redemption.reward;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(reward.icon != null && reward.icon!.trim().isNotEmpty ? reward.icon!.trim() : '🎁'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(reward.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        [
                          redemption.member.fullName,
                          '${redemption.pointsCostSnapshot} نقطة',
                          if (redemption.requestedAt != null) 'طُلبت: ${redemption.requestedAt}',
                        ].join(' • '),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_busy)
              const Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)))
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
                      onPressed: _reject,
                      icon: const Icon(Icons.close),
                      label: const Text('رفض'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _approve,
                      icon: const Icon(Icons.check),
                      label: const Text('اعتماد'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _approve() async {
    setState(() => _busy = true);

    try {
      final familyId = ref.read(selectedFamilyIdProvider);

      await ref.read(familyTasksApiProvider).approveRedemption(redemptionId: redemption.id, familyId: familyId);
      ref.invalidate(pendingRedemptionsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت الموافقة على استبدال المكافأة')));
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر اعتماد الطلب: $error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('رفض الطلب'),
        content: Text('سيتم رفض طلب استبدال "${redemption.reward.name}" لـ ${redemption.member.fullName}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('رفض'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);

    try {
      final familyId = ref.read(selectedFamilyIdProvider);

      await ref.read(familyTasksApiProvider).rejectRedemption(redemptionId: redemption.id, familyId: familyId);
      ref.invalidate(pendingRedemptionsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفض طلب الاستبدال')));
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر رفض الطلب: $error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
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
                  Text('تعذر تحميل الطلبات: $message', textAlign: TextAlign.center),
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
