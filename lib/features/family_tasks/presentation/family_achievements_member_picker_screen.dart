import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../family/application/family_providers.dart';
import '../../family/data/family_models.dart';
import '../application/family_tasks_providers.dart';

/// PR-69: "شارات الأفراد" — the entry point into a single member's earned
/// badges. Built directly on `FamilyPointsScreen`'s own template (PR-66) —
/// same roster source (`familyMembersProvider`, already fetched elsewhere,
/// no dedicated "list of members with badge counts" endpoint exists), same
/// narrowing reasoning, and same reused `canManageFamilyTasksProvider`
/// role signal.
///
/// **Narrowed client-side to what the backend will actually allow**:
/// `FamilyAchievementController::memberAchievements()` uses the exact same
/// self-or-manager inline check as `FamilyMemberPointsController::show()`
/// (verified directly against that controller — see its own docblock: "the
/// same policy-collision workaround") — a manager (`owner`/`parent`/
/// `admin`) may open any member's earned badges, but a plain member/child
/// may only open their own. Rather than list every member and let a
/// non-manager's tap 403, this screen only ever renders the rows this
/// account is actually allowed to open: the full roster for a manager, or
/// just this account's own linked member row otherwise. The HTTP request
/// remains the real boundary either way — this is UX, not security, exactly
/// like `FamilyPointsScreen`.
class FamilyAchievementsMemberPickerScreen extends ConsumerWidget {
  const FamilyAchievementsMemberPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(familyMembersProvider);
    final canManage = ref.watch(canManageFamilyTasksProvider);
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      appBar: AppBar(title: const Text('شارات الأفراد')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(familyMembersProvider),
        child: membersAsync.when(
          data: (members) {
            final visible = canManage
                ? members
                : members.where((m) => user != null && m.isMe(user.id)).toList();

            return _MembersList(members: visible, canManage: canManage);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _ErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(familyMembersProvider),
          ),
        ),
      ),
    );
  }
}

class _MembersList extends StatelessWidget {
  const _MembersList({required this.members, required this.canManage});

  final List<FamilyMemberModel> members;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  canManage ? 'لا يوجد أفراد بعد.' : 'تعذر العثور على فردك ضمن هذه العائلة.',
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
      itemCount: members.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final member = members[index];

        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.emoji_events_outlined)),
            title: Text(member.fullName),
            subtitle: Text(member.relationship),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => context.push('/family/achievements/members/${member.id}', extra: member.fullName),
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
                  Text('تعذر تحميل الأفراد: $message', textAlign: TextAlign.center),
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
