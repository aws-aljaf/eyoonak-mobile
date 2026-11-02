import '../../../core/widgets/family_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_exception.dart';
import '../../family/application/family_providers.dart';
import '../../family/data/family_models.dart';
import '../application/family_tasks_providers.dart';
import '../data/family_task_models.dart';

/// PR-67: "طلب استبدال" — request a redemption for one reward. Reached by
/// tapping an active card on `FamilyRewardsListScreen`, for any active
/// family member (`FamilyRewardRedemptionController::store()` has no
/// `$this->authorize()` gate at all, only an inline self-or-manager check
/// — see `FamilyTasksApi.requestRedemption()`'s own docblock).
///
/// A plain member always requests for themselves
/// (`myFamilyMemberIdProvider`) — the backend would 403 any other
/// `family_member_id` from a non-manager anyway, so there is nothing to
/// pick. A manager may additionally choose *any* family member (including
/// one with no login of their own, e.g. a young child) via the picker
/// below — this is the one place in this feature a manager acts on behalf
/// of a specific member by choice rather than by the backend's own
/// "manager sees everything" default.
///
/// Shows the chosen member's current points balance
/// (`familyMemberPointsProvider`) so they know what they can afford before
/// submitting — a plain UX hint, not the real gate: plan judgment call #5
/// is explicit that the actual, authoritative balance check happens again
/// at `approve()` time, and `FamilyRewardRedemptionController::store()`
/// itself also re-checks up front (verified directly against that
/// controller) purely so this request can fail honestly and immediately
/// rather than being silently doomed. Either way, this screen never
/// disables the submit button on a low balance — it only warns — since a
/// balance can legitimately change between opening this screen and
/// tapping submit.
class FamilyRewardRequestScreen extends ConsumerStatefulWidget {
  const FamilyRewardRequestScreen({required this.reward, super.key});

  final FamilyRewardModel reward;

  @override
  ConsumerState<FamilyRewardRequestScreen> createState() => _FamilyRewardRequestScreenState();
}

class _FamilyRewardRequestScreenState extends ConsumerState<FamilyRewardRequestScreen> {
  int? _pickedMemberId;
  bool _submitting = false;
  String? _errorMessage;

  Future<void> _submit(int familyMemberId) async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final familyId = ref.read(selectedFamilyIdProvider);

      await ref.read(familyTasksApiProvider).requestRedemption(
            familyRewardId: widget.reward.id,
            familyMemberId: familyMemberId,
            familyId: familyId,
          );
      ref.invalidate(myRedemptionRequestsProvider);

      if (!mounted) return;
      await showFamilySuccess(context);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال طلب استبدال المكافأة، بانتظار موافقة الوالد')),
      );
    } on ApiException catch (error) {
      setState(() => _errorMessage = error.message);
    } catch (error) {
      setState(() => _errorMessage = 'تعذر إرسال الطلب: $error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = ref.watch(canManageFamilyTasksProvider);
    final myMemberId = ref.watch(myFamilyMemberIdProvider);

    // Only a manager needs the full roster (to pick a different member than
    // themselves) — `ref.watch` here is a plain method call, not a hook, so
    // calling it conditionally is safe (unlike flutter_hooks' `useX()`
    // calls), and this also avoids fetching a list a plain member has no
    // use for on this screen at all.
    final AsyncValue<List<FamilyMemberModel>>? membersAsync = canManage ? ref.watch(familyMembersProvider) : null;
    final members = membersAsync?.valueOrNull ?? const <FamilyMemberModel>[];

    // The single "who is this request for" resolution, shared by the
    // picker's own selection AND by what actually gets submitted — a
    // manager who never touches the dropdown still submits for whichever
    // member it defaulted to (their own linked member, or else the
    // roster's first row), rather than the picker silently showing one
    // value while submit resolves a different (possibly null) one.
    final int? effectiveMemberId =
        canManage ? (_pickedMemberId ?? myMemberId ?? (members.isEmpty ? null : members.first.id)) : myMemberId;

    return Scaffold(
      appBar: AppBar(title: const Text('طلب استبدال مكافأة')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(
                    widget.reward.icon != null && widget.reward.icon!.trim().isNotEmpty
                        ? widget.reward.icon!.trim()
                        : '🎁',
                  ),
                ),
                title: Text(widget.reward.name),
                subtitle: Text('${widget.reward.pointsCost} نقطة'),
              ),
            ),
            if (widget.reward.description != null && widget.reward.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(widget.reward.description!),
            ],
            const SizedBox(height: 16),
            if (canManage)
              membersAsync!.when(
                data: (_) => _MemberPicker(
                  members: members,
                  selectedId: effectiveMemberId,
                  onChanged: (id) => setState(() => _pickedMemberId = id),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Text('تعذر تحميل أفراد العائلة: $error'),
              )
            else
              const Text('سيتم إرسال الطلب باسمك.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            if (effectiveMemberId == null)
              const Text(
                'تعذر تحديد الفرد الذي سيقدّم الطلب ضمن هذه العائلة.',
                style: TextStyle(color: Colors.red),
              )
            else
              _BalanceAndSubmit(
                familyMemberId: effectiveMemberId,
                reward: widget.reward,
                submitting: _submitting,
                errorMessage: _errorMessage,
                onSubmit: () => _submit(effectiveMemberId),
              ),
          ],
        ),
      ),
    );
  }
}

class _MemberPicker extends StatelessWidget {
  const _MemberPicker({required this.members, required this.selectedId, required this.onChanged});

  final List<FamilyMemberModel> members;
  final int? selectedId;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const Text('لا يوجد أفراد بهذه العائلة بعد.');
    }

    return DropdownButtonFormField<int>(
      initialValue: selectedId,
      decoration: const InputDecoration(labelText: 'الفرد الذي يطلب المكافأة', border: OutlineInputBorder()),
      items: [
        for (final member in members) DropdownMenuItem(value: member.id, child: Text(member.fullName)),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _BalanceAndSubmit extends ConsumerWidget {
  const _BalanceAndSubmit({
    required this.familyMemberId,
    required this.reward,
    required this.submitting,
    required this.errorMessage,
    required this.onSubmit,
  });

  final int familyMemberId;
  final FamilyRewardModel reward;
  final bool submitting;
  final String? errorMessage;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pointsAsync = ref.watch(familyMemberPointsProvider(familyMemberId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        pointsAsync.when(
          data: (points) {
            final insufficient = points.pointsBalance < reward.pointsCost;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: ListTile(
                    leading: Icon(Icons.account_balance_wallet_outlined, color: Theme.of(context).colorScheme.primary),
                    title: const Text('الرصيد الحالي'),
                    trailing: Text(
                      '${points.pointsBalance} نقطة',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (insufficient) ...[
                  const SizedBox(height: 8),
                  Text(
                    'رصيدك الحالي أقل من تكلفة هذه المكافأة (${reward.pointsCost} نقطة) — يمكنك إرسال الطلب على أي حال، لكن الموافقة تتطلب رصيدًا كافيًا وقت اعتماد الوالد.',
                    style: const TextStyle(color: Colors.orange),
                  ),
                ],
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Text('تعذر تحميل الرصيد: $error', style: const TextStyle(color: Colors.red)),
        ),
        if (errorMessage case final message?) ...[
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: Colors.red.shade700)),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: submitting ? null : onSubmit,
            child: submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('إرسال الطلب'),
          ),
        ),
      ],
    );
  }
}
