import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/family_tasks_providers.dart';
import '../data/family_task_models.dart';
import '../data/suggested_task_library.dart';

/// PR-67: "طلباتي" — this account's own redemption request history (any
/// status: pending/approved/rejected), reached from `FamilyRewardsListScreen`'s
/// own app-bar icon. Backed by `myRedemptionRequestsProvider` — see that
/// provider's own docblock for why a manager's request is filtered
/// client-side to their own `family_member_id` while a plain member's
/// relies on the backend's own auto-narrowing.
///
/// Deliberately shows only this account's own rows, never a sibling's — no
/// "who requested less" comparison is possible here even in principle,
/// unlike the weekly report (PR-64) this never needed a "no negative
/// field" design pass.
class FamilyRewardRequestsScreen extends ConsumerWidget {
  const FamilyRewardRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(myRedemptionRequestsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('طلباتي')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myRedemptionRequestsProvider),
        child: requestsAsync.when(
          data: (requests) => _RequestList(requests: requests),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _ErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(myRedemptionRequestsProvider),
          ),
        ),
      ),
    );
  }
}

class _RequestList extends StatelessWidget {
  const _RequestList({required this.requests});

  final List<FamilyRewardRedemptionModel> requests;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: const Center(child: Text('لم تُرسل أي طلبات استبدال بعد.')),
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: requests.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _RequestCard(request: requests[index]),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});

  final FamilyRewardRedemptionModel request;

  Color _statusColor(BuildContext context) {
    switch (request.status) {
      case 'approved':
        return Colors.green.shade700;
      case 'rejected':
        return Colors.red.shade700;
      default:
        return Colors.orange.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusLabel = familyRewardRedemptionStatusLabels[request.status] ?? request.status;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
            request.reward.icon != null && request.reward.icon!.trim().isNotEmpty ? request.reward.icon!.trim() : '🎁',
          ),
        ),
        title: Text(request.reward.name),
        subtitle: Text(
          [
            '${request.pointsCostSnapshot} نقطة',
            if (request.requestedAt != null) 'طُلبت: ${request.requestedAt}',
          ].join(' • '),
        ),
        trailing: Text(statusLabel, style: TextStyle(color: _statusColor(context), fontWeight: FontWeight.bold)),
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
