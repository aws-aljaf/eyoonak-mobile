import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/family_tasks_providers.dart';
import '../data/family_task_models.dart';

/// PR-66: one family member's points breakdown — "نقاط هذا الأسبوع/الكلية/
/// المصروفة" plus the current balance, mirroring
/// `FamilyMemberPointsController::show()`'s response exactly (see
/// `FamilyMemberPointsModel`'s own docblock). Reached only from
/// `FamilyPointsScreen`, which already narrows the roster to rows this
/// account is allowed to open (see that screen's docblock) — a 403 here
/// still surfaces as a plain error state below rather than crashing,
/// exactly like every other detail screen in this app.
///
/// Deliberately shows only positive/neutral figures (balance, this week,
/// total earned, spent on rewards) — there is nothing here to compare
/// against a sibling (this screen never fetches more than one member's
/// breakdown at a time), so unlike the weekly report (PR-64) there was no
/// "no negative field" constraint to design around; it simply doesn't
/// arise for a single-member view.
class FamilyMemberPointsDetailScreen extends ConsumerWidget {
  const FamilyMemberPointsDetailScreen({required this.familyMemberId, required this.memberName, super.key});

  final int familyMemberId;
  final String memberName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pointsAsync = ref.watch(familyMemberPointsProvider(familyMemberId));

    return Scaffold(
      appBar: AppBar(title: Text('نقاط $memberName')),
      body: pointsAsync.when(
        data: (points) => _PointsBody(memberName: memberName, points: points),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(familyMemberPointsProvider(familyMemberId)),
        ),
      ),
    );
  }
}

class _PointsBody extends StatelessWidget {
  const _PointsBody({required this.memberName, required this.points});

  final String memberName;
  final FamilyMemberPointsModel points;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _PointsCard(
          icon: Icons.account_balance_wallet_outlined,
          label: 'الرصيد الحالي',
          value: points.pointsBalance,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 12),
        _PointsCard(
          icon: Icons.calendar_view_week_outlined,
          label: 'نقاط هذا الأسبوع',
          value: points.pointsThisWeek,
          color: Colors.blue.shade700,
        ),
        const SizedBox(height: 12),
        _PointsCard(
          icon: Icons.emoji_events_outlined,
          label: 'إجمالي النقاط المكتسبة',
          value: points.pointsTotalEarned,
          color: Colors.green.shade700,
        ),
        const SizedBox(height: 12),
        _PointsCard(
          icon: Icons.card_giftcard_outlined,
          label: 'النقاط المصروفة على المكافآت',
          value: points.pointsSpentOnRewards,
          color: Colors.orange.shade700,
        ),
      ],
    );
  }
}

class _PointsCard extends StatelessWidget {
  const _PointsCard({required this.icon, required this.label, required this.value, required this.color});

  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), child: Icon(icon, color: color)),
        title: Text(label),
        trailing: Text(
          '$value',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
        ),
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
                  Text('تعذر تحميل النقاط: $message', textAlign: TextAlign.center),
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
