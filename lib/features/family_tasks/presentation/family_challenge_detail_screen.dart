import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_exception.dart';
import '../../family/application/family_providers.dart';
import '../application/family_tasks_providers.dart';
import '../data/family_task_models.dart';
import '../data/suggested_task_library.dart';

/// PR-68: one challenge's full detail — title/description/rules, then the
/// progress board ("عرض التقدّم") and the "المشاركة" action. Reached by
/// tapping a card on `FamilyChallengesListScreen`. Edit/delete are gated
/// the same way that screen's FAB is (`canManageFamilyTasksProvider`); the
/// actual authorization boundary stays
/// `FamilyChallengePolicy::update()`/`::delete()` server-side.
///
/// **Progress board, not a ranking**: `_ProgressBoard` below renders every
/// participant in whatever order `challengeParticipantsProvider` returns
/// them (the backend's own declaration order, itself unordered by
/// `FamilyChallengeController::participants()` — verified directly, no
/// `orderBy` at all) — this screen never sorts by `progressCount`, never
/// numbers a "1st/2nd" position, and never highlights one member's row
/// over another's beyond marking a completed goal with a plain checkmark.
/// This mirrors the same "no negative/competitive ranking" principle the
/// weekly report (PR-64) already established for this whole feature (plan
/// judgment call #7) — a simple "X من Y مهام" count and progress bar per
/// member, nothing more.
///
/// **المشاركة**: a plain member who hasn't joined yet sees a single
/// "الانضمام إلى التحدي" button that joins *themselves*
/// (`myFamilyMemberIdProvider`). A manager additionally sees a small
/// "إشراك فرد آخر" picker (same shape as `FamilyRewardRequestScreen`'s own
/// member picker) to enroll any other family member — including one with
/// no login of their own (e.g. a young child who cannot tap the button on
/// their own device) — mirroring
/// `FamilyChallengeController::join()`'s own self-or-manager
/// authorization (see that controller's docblock). This manager-enrolls
/// affordance was not spelled out explicitly in the plan's PR-68 row, but
/// follows directly from PR-67's own precedent for the identical
/// self-or-manager gate on `FamilyRewardRedemptionController::store()` —
/// without it, a family member with no linked account could never join a
/// challenge at all.
class FamilyChallengeDetailScreen extends ConsumerWidget {
  const FamilyChallengeDetailScreen({required this.challengeId, super.key});

  final int challengeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengeAsync = ref.watch(familyChallengeDetailProvider(challengeId));
    final canManage = ref.watch(canManageFamilyTasksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل التحدي'),
        actions: [
          if (canManage)
            challengeAsync.when(
              data: (challenge) => PopupMenuButton<String>(
                tooltip: 'المزيد',
                onSelected: (value) {
                  if (value == 'edit') {
                    context.push('/family/challenges/${challenge.id}/edit', extra: challenge);
                  } else if (value == 'delete') {
                    _delete(context, ref, challenge);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('حذف', style: TextStyle(color: Colors.red.shade700)),
                  ),
                ],
              ),
              loading: () => const SizedBox.shrink(),
              error: (error, stack) => const SizedBox.shrink(),
            ),
        ],
      ),
      body: challengeAsync.when(
        data: (challenge) => _ChallengeDetailBody(challenge: challenge),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(familyChallengeDetailProvider(challengeId)),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, FamilyChallengeModel challenge) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف التحدي'),
        content: Text('سيتم حذف تحدي "${challenge.title}" نهائيًا. هل أنت متأكد؟'),
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

      await ref.read(familyTasksApiProvider).deleteChallenge(challengeId: challenge.id, familyId: familyId);
      ref.invalidate(familyChallengesProvider);

      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف التحدي')));
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حذف التحدي: $error')));
      }
    }
  }
}

class _ChallengeDetailBody extends ConsumerWidget {
  const _ChallengeDetailBody({required this.challenge});

  final FamilyChallengeModel challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participantsAsync = ref.watch(challengeParticipantsProvider(challenge.id));
    final categoryLabel = challenge.categoryFilter == null
        ? 'كل التصنيفات'
        : (familyTaskCategoryLabels[challenge.categoryFilter] ?? challenge.categoryFilter!);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(challengeParticipantsProvider(challenge.id)),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(challenge.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          if (challenge.description != null && challenge.description!.isNotEmpty) ...[
            Text(challenge.description!),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('الهدف: ${challenge.goalTarget} مهام')),
              Chip(label: Text(categoryLabel)),
              Chip(label: Text('${challenge.bonusPoints} نقطة إضافية')),
              Chip(label: Text(familyChallengeStatusLabels[challenge.status] ?? challenge.status)),
            ],
          ),
          const SizedBox(height: 8),
          if (challenge.startDate != null || challenge.endDate != null)
            Text(
              'من ${challenge.startDate ?? '--'} إلى ${challenge.endDate ?? '--'}',
              style: const TextStyle(color: Colors.grey),
            ),
          const SizedBox(height: 20),
          Text('التقدّم', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          participantsAsync.when(
            data: (participants) => _ProgressBoard(participants: participants),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Text('تعذر تحميل التقدّم: $error', style: const TextStyle(color: Colors.red)),
          ),
          const SizedBox(height: 20),
          participantsAsync.when(
            data: (participants) => _JoinSection(challenge: challenge, participants: participants),
            loading: () => const SizedBox.shrink(),
            error: (error, stack) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// Plain progress list — every participant, unsorted, each row a name plus
/// a factual "X من Y" count and a bounded progress bar. No rank, no
/// position, no "الأفضل"/"الأسوأ" language anywhere in this widget — see
/// this file's own top docblock for why.
class _ProgressBoard extends StatelessWidget {
  const _ProgressBoard({required this.participants});

  final List<FamilyChallengeParticipantModel> participants;

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return const Text('لا يوجد مشاركون بعد في هذا التحدي.', style: TextStyle(color: Colors.grey));
    }

    return Column(
      children: [
        for (final participant in participants) _ProgressRow(participant: participant),
      ],
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.participant});

  final FamilyChallengeParticipantModel participant;

  @override
  Widget build(BuildContext context) {
    // `num.clamp()` returns `num`, not `double` (there is no `double`-typed
    // override) — `.toDouble()` afterward is required so this stays a
    // `double` for `LinearProgressIndicator.value` below, which does not
    // accept the wider `num` type.
    final double ratio = participant.goalTarget <= 0
        ? 0.0
        : (participant.progressCount / participant.goalTarget).clamp(0.0, 1.0).toDouble();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(participant.member.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                if (participant.isCompleted)
                  Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 20),
                const SizedBox(width: 4),
                Text('${participant.progressCount} / ${participant.goalTarget} مهام'),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: ratio, minHeight: 8),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "المشاركة" action area — see this file's own top docblock for the
/// full self-vs-manager reasoning.
class _JoinSection extends ConsumerStatefulWidget {
  const _JoinSection({required this.challenge, required this.participants});

  final FamilyChallengeModel challenge;
  final List<FamilyChallengeParticipantModel> participants;

  @override
  ConsumerState<_JoinSection> createState() => _JoinSectionState();
}

class _JoinSectionState extends ConsumerState<_JoinSection> {
  int? _pickedMemberId;
  bool _joining = false;
  String? _errorMessage;

  Future<void> _join(int familyMemberId) async {
    setState(() {
      _joining = true;
      _errorMessage = null;
    });

    try {
      final familyId = ref.read(selectedFamilyIdProvider);

      await ref.read(familyTasksApiProvider).joinChallenge(
            challengeId: widget.challenge.id,
            familyMemberId: familyMemberId,
            familyId: familyId,
          );
      ref.invalidate(challengeParticipantsProvider(widget.challenge.id));

      if (!mounted) return;
      setState(() => _pickedMemberId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت المشاركة في التحدي')),
      );
    } on ApiException catch (error) {
      setState(() => _errorMessage = error.message);
    } catch (error) {
      setState(() => _errorMessage = 'تعذر إتمام المشاركة: $error');
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = ref.watch(canManageFamilyTasksProvider);
    final myMemberId = ref.watch(myFamilyMemberIdProvider);
    final joinedMemberIds = widget.participants.map((p) => p.member.id).toSet();
    final iHaveJoined = myMemberId != null && joinedMemberIds.contains(myMemberId);

    final children = <Widget>[];

    if (myMemberId != null && !iHaveJoined) {
      children.add(
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _joining ? null : () => _join(myMemberId),
            icon: const Icon(Icons.add_task),
            label: const Text('الانضمام إلى التحدي'),
          ),
        ),
      );
    } else if (iHaveJoined) {
      children.add(
        const Text('أنت مشارك بالفعل في هذا التحدي — تقدّمك ظاهر أعلاه.', style: TextStyle(color: Colors.grey)),
      );
    }

    if (canManage) {
      children.add(const SizedBox(height: 16));
      children.add(Text('إشراك فرد آخر', style: Theme.of(context).textTheme.titleSmall));
      children.add(const SizedBox(height: 8));
      children.add(
        _ManagerEnrollPicker(
          joinedMemberIds: joinedMemberIds,
          selectedId: _pickedMemberId,
          onChanged: (id) => setState(() => _pickedMemberId = id),
          onEnroll: _pickedMemberId == null || _joining ? null : () => _join(_pickedMemberId!),
          joining: _joining,
        ),
      );
    }

    if (_errorMessage case final message?) {
      children.add(const SizedBox(height: 12));
      children.add(Text(message, style: TextStyle(color: Colors.red.shade700)));
    }

    if (children.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}

class _ManagerEnrollPicker extends ConsumerWidget {
  const _ManagerEnrollPicker({
    required this.joinedMemberIds,
    required this.selectedId,
    required this.onChanged,
    required this.onEnroll,
    required this.joining,
  });

  final Set<int> joinedMemberIds;
  final int? selectedId;
  final ValueChanged<int> onChanged;
  final VoidCallback? onEnroll;
  final bool joining;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(familyMembersProvider);

    return membersAsync.when(
      data: (members) {
        final notJoined = members.where((m) => !joinedMemberIds.contains(m.id)).toList();

        if (notJoined.isEmpty) {
          return const Text('كل أفراد العائلة مشاركون بالفعل في هذا التحدي.', style: TextStyle(color: Colors.grey));
        }

        return Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: selectedId,
                decoration: const InputDecoration(labelText: 'الفرد', border: OutlineInputBorder()),
                items: [
                  for (final member in notJoined) DropdownMenuItem(value: member.id, child: Text(member.fullName)),
                ],
                onChanged: (value) {
                  if (value != null) onChanged(value);
                },
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onEnroll,
              child: joining
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('إشراك'),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Text('تعذر تحميل أفراد العائلة: $error'),
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
                  Text('تعذر تحميل التحدي: $message', textAlign: TextAlign.center),
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
