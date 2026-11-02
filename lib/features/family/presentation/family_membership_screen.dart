import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_exception.dart';
import '../application/family_providers.dart';
import '../data/family_models.dart';

/// Family membership management — invite, view/edit roles and
/// tracking-capability grants, edit supervisor scoping, and remove
/// members, plus respond to the current account's own pending
/// invitations. This is the mobile counterpart to the web app's
/// `FamilyManagementPage.vue`, which is the direct source for every
/// label map and UX rule below (`ROLE_LABELS`, `CAPABILITY_LABELS`,
/// `ASSIGNABLE_ROLES`, `FULL_ACCESS_ROLES`, `canManage`, the
/// role==='supervisor'-only `supervises` payload, and the native-confirm
/// remove flow — reproduced here as a proper dialog, matching this app's
/// own `SafeZonesListScreen`/`EmergencyContactsScreen` convention rather
/// than a native OS confirm).
///
/// This is a genuinely different object from `FamilyMemberModel`/
/// `FamilyHomeScreen`'s roster: that screen lists *tracked people* (who
/// may have no app account at all); this screen lists *user accounts*
/// that are members of the family, with a role and permission grants —
/// see `FamilyRelationshipModel`'s own docblock for the full distinction.
///
/// `canManage` mirrors the web reference's own computed property exactly:
/// the current account's own relationship role must be `owner` or
/// `admin` — the same `FamilyRelationshipPolicy::create()`/`update()`/
/// `delete()` gate (`hasManagingRole()`), verified directly against that
/// Policy. Note `parent` is deliberately excluded even though it's a
/// `FULL_ACCESS_ROLES` member for viewing tracking data — those are two
/// unrelated gates on the backend, and this screen respects both
/// separately rather than conflating them.
class FamilyMembershipScreen extends ConsumerWidget {
  const FamilyMembershipScreen({super.key});

  static const _roleLabels = {
    'owner': 'مسؤول العائلة',
    'parent': 'أب أو أم',
    'admin': 'مسؤول العائلة',
    'supervisor': 'فرد من العائلة',
    'child': 'ابن أو بنت',
    'member': 'قريب',
    'father': 'أب',
    'mother': 'أم',
    'son': 'ابن',
    'daughter': 'بنت',
    'grandfather': 'جد',
    'grandmother': 'جدة',
    'brother': 'أخ',
    'sister': 'أخت',
    'relative': 'قريب'
  };
  static const _assignableRoles = [
    'father',
    'mother',
    'son',
    'daughter',
    'grandfather',
    'grandmother',
    'brother',
    'sister',
    'relative'
  ];
  static String familyRole(String k) => ['father', 'mother'].contains(k)
      ? 'parent'
      : ['son', 'daughter'].contains(k)
          ? 'child'
          : 'member';
  static String label(FamilyRelationshipModel r) =>
      _roleLabels[r.kinship] ?? _roleLabels[r.role] ?? 'فرد من العائلة';
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relationshipsAsync = ref.watch(familyRelationshipsProvider);
    final invitationsAsync = ref.watch(myFamilyInvitationsProvider);
    final user = ref.watch(authControllerProvider).user;

    // Mirrors the web reference's `myRelationship` computed
    // (`relationships.find(r => r.user_id === auth.user.id)`) — a plain
    // loop rather than `firstWhere(..., orElse: () => null)`, which
    // requires an awkward nullable-cast of the list to type-check.
    FamilyRelationshipModel? myRelationship;
    if (user != null) {
      for (final relationship in relationshipsAsync.valueOrNull ??
          const <FamilyRelationshipModel>[]) {
        if (relationship.isMe(user.id)) {
          myRelationship = relationship;
          break;
        }
      }
    }
    final canManage = myRelationship != null &&
        const {'owner', 'admin'}.contains(myRelationship.role);

    return Scaffold(
      appBar: AppBar(
        title: const Text('أفراد العائلة (الحسابات)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: () {
              ref.invalidate(familyRelationshipsProvider);
              ref.invalidate(myFamilyInvitationsProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(familyRelationshipsProvider);
          ref.invalidate(myFamilyInvitationsProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          children: [
            invitationsAsync.when(
              data: (invitations) => invitations.isEmpty
                  ? const SizedBox.shrink()
                  : _InvitationsBanner(invitations: invitations),
              loading: () => const SizedBox.shrink(),
              // Silent on error: a global, secondary section shouldn't block
              // the primary roster below from rendering just because
              // GET /family-invitations failed transiently.
              error: (error, stack) => const SizedBox.shrink(),
            ),
            relationshipsAsync.when(
              data: (relationships) => relationships.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: Center(
                          child: Text('لا يوجد أفراد بهذه العائلة بعد.')),
                    )
                  : Column(
                      children: [
                        for (final relationship in relationships)
                          _RelationshipCard(
                              relationship: relationship, canManage: canManage),
                      ],
                    ),
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('تعذر تحميل أفراد العائلة: $error',
                        textAlign: TextAlign.center),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: canManage || myRelationship?.role == 'parent'
          ? FloatingActionButton.extended(
              onPressed: () => _invite(context, ref),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('إضافة فرد للعائلة'),
            )
          : null,
    );
  }

  Future<void> _invite(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<({String phone, String role})>(
      context: context,
      builder: (context) => _InviteDialog(
          roleLabels: _roleLabels,
          assignableRoles: (ref.read(familyRelationshipsProvider).valueOrNull ??
                      [])
                  .any((r) =>
                      r.userId == ref.read(authControllerProvider).user?.id &&
                      r.role == 'parent')
              ? _assignableRoles
                  .where((k) => !['father', 'mother'].contains(k))
                  .toList()
              : _assignableRoles),
    );

    if (result == null) return;

    try {
      final familyId = ref.read(selectedFamilyIdProvider);

      await ref.read(familyApiProvider).inviteFamilyMember(
            phone: result.phone,
            role: FamilyMembershipScreen.familyRole(result.role),
            kinship: result.role,
            familyId: familyId,
          );
      ref.invalidate(familyRelationshipsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تم إرسال الدعوة')));
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذر إرسال الدعوة: $error')));
      }
    }
  }
}

/// The "دعوات معلّقة لك" section — visible to any account with at least
/// one pending invitation, regardless of `canManage` (accepting/declining
/// an invitation extended to yourself has nothing to do with whether you
/// can manage anyone else's membership).
class _InvitationsBanner extends ConsumerStatefulWidget {
  const _InvitationsBanner({required this.invitations});

  final List<FamilyRelationshipModel> invitations;

  @override
  ConsumerState<_InvitationsBanner> createState() => _InvitationsBannerState();
}

class _InvitationsBannerState extends ConsumerState<_InvitationsBanner> {
  int? _respondingTo;

  Future<void> _respond(FamilyRelationshipModel invitation, bool accept) async {
    setState(() => _respondingTo = invitation.id);

    try {
      final api = ref.read(familyApiProvider);

      if (accept) {
        await api.acceptFamilyInvitation(relationshipId: invitation.id);
        await ref.read(authControllerProvider.notifier).refreshMembership();
      } else {
        await api.declineFamilyInvitation(relationshipId: invitation.id);
      }

      ref.invalidate(myFamilyInvitationsProvider);
      // A newly-accepted invitation adds a row to whichever family it was
      // for — the family's own roster (and, if this account had none
      // selected yet, `myFamiliesProvider`) should reflect that too.
      ref.invalidate(familyRelationshipsProvider);
      ref.invalidate(myFamiliesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(accept ? 'تم قبول الدعوة' : 'تم رفض الدعوة')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذر تنفيذ الطلب: $error')));
      }
    } finally {
      if (mounted) setState(() => _respondingTo = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color:
          Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('دعوات معلّقة لك',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (final invitation in widget.invitations)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'دعوة للانضمام إلى "${invitation.familyName ?? 'عائلة'}" '
                        'بدور ${FamilyMembershipScreen.label(invitation)}',
                      ),
                    ),
                    if (_respondingTo == invitation.id)
                      const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else ...[
                      TextButton(
                        onPressed: () => _respond(invitation, true),
                        child: const Text('قبول'),
                      ),
                      TextButton(
                        onPressed: () => _respond(invitation, false),
                        child: const Text('رفض'),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RelationshipCard extends ConsumerStatefulWidget {
  const _RelationshipCard(
      {required this.relationship, required this.canManage});

  final FamilyRelationshipModel relationship;
  final bool canManage;

  @override
  ConsumerState<_RelationshipCard> createState() => _RelationshipCardState();
}

class _RelationshipCardState extends ConsumerState<_RelationshipCard> {
  bool _busy = false;

  Future<void> _edit() async {
    final relationship = widget.relationship;
    final result = await showDialog<_EditResult>(
      context: context,
      builder: (context) => _EditDialog(relationship: relationship),
    );

    if (result == null || !mounted) return;

    setState(() => _busy = true);

    try {
      await ref.read(familyApiProvider).updateFamilyRelationship(
            relationshipId: relationship.id,
            role: FamilyMembershipScreen.familyRole(result.role),
            kinship: result.role,
            trackingPermissions: result.trackingPermissions,
            supervises: result.supervises,
          );
      ref.invalidate(familyRelationshipsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تم تحديث العضوية')));
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر تحديث العضوية: $error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmRemove() async {
    final relationship = widget.relationship;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إزالة من العائلة'),
        content: Text(
          'سيتم إزالة "${relationship.userName ?? relationship.userPhone ?? 'هذا الحساب'}" من العائلة. '
          'هل أنت متأكد؟',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إزالة'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);

    try {
      await ref
          .read(familyApiProvider)
          .removeFamilyRelationship(relationshipId: relationship.id);
      ref.invalidate(familyRelationshipsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تمت إزالة العضو')));
      }
    } on ApiException catch (error) {
      // Surfaces guardLastOwner()'s Arabic 422 message verbatim — e.g.
      // refusing to remove the family's last active owner.
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذر إزالة العضو: $error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final relationship = widget.relationship;
    // Mirrors the web reference's `v-if="canManage && rel.role !== 'owner'"`
    // — never offer to edit/remove the owner row from here at all, rather
    // than showing the controls and letting `guardLastOwner()`/the create
    // validation (role can't be set to 'owner') reject it after the fact.
    final showActions = widget.canManage && relationship.role != 'owner';

    return Card(
      color: relationship.kinship == 'daughter'
          ? const Color(0xFFFCE7F3)
          : relationship.kinship == 'son'
              ? const Color(0xFFDBEAFE)
              : null,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
            child: Icon(relationship.status == 'invited'
                ? Icons.mail_outline
                : Icons.person)),
        title: Text(relationship.userName ??
            relationship.userPhone ??
            'حساب #${relationship.userId}'),
        subtitle: Text([
          FamilyMembershipScreen.label(relationship),
          if (relationship.status == 'invited') 'بانتظار القبول',
        ].join(' • ')),
        trailing: _busy
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : showActions
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'تعديل',
                          onPressed: _edit),
                      IconButton(
                        icon: Icon(Icons.person_remove_outlined,
                            color: Colors.red.shade700),
                        tooltip: 'إزالة',
                        onPressed: _confirmRemove,
                      ),
                    ],
                  )
                : null,
      ),
    );
  }
}

/// The invite form — phone + role dropdown from `ASSIGNABLE_ROLES`,
/// matching the web reference's invite modal exactly (`{phone, role}`,
/// defaulting to `'member'`).
class _InviteDialog extends StatefulWidget {
  const _InviteDialog(
      {required this.roleLabels, required this.assignableRoles});

  final Map<String, String> roleLabels;
  final List<String> assignableRoles;

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final _phoneController = TextEditingController();
  String _role = 'son';
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    final phone = _phoneController.text.trim();

    if (phone.isEmpty) {
      setState(() => _errorMessage = 'الرجاء إدخال رقم الهاتف.');
      return;
    }

    Navigator.pop(context, (phone: phone, role: _role));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة فرد للعائلة جديد'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Must already be a registered account — verified directly
            // against StoreFamilyRelationshipRequest's Rule::exists('users',
            // 'phone'); this app doesn't try to explain that constraint
            // pre-emptively, it just surfaces the backend's own 422 if the
            // number isn't found (matching every other form in this app).
            TextField(
              controller: _phoneController,
              autofocus: true,
              keyboardType: TextInputType.phone,
              decoration:
                  const InputDecoration(labelText: 'رقم الهاتف (لحساب مسجَّل)'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'صلة القرابة'),
              items: [
                for (final role in widget.assignableRoles)
                  DropdownMenuItem(
                      value: role,
                      child: Text(widget.roleLabels[role] ?? role)),
              ],
              onChanged: (value) => setState(() => _role = value ?? _role),
            ),
            if (_errorMessage case final message?) ...[
              const SizedBox(height: 4),
              Text(message, style: TextStyle(color: Colors.red.shade700)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء')),
        FilledButton(onPressed: _submit, child: const Text('إرسال الدعوة')),
      ],
    );
  }
}

typedef _EditResult = ({
  String role,
  List<String> trackingPermissions,
  List<int> supervises
});

/// The edit form: role dropdown, then a capability checklist that's
/// replaced by an explanatory note whenever the *currently selected* role
/// is in `FULL_ACCESS_ROLES` (mirrors the web reference's
/// `v-if="FULL_ACCESS_ROLES.includes(editForm.role)"` — reactive to the
/// dropdown, not frozen at the relationship's original role), then a
/// member multi-select shown only when the selected role is
/// `'supervisor'`. Uses `familyMembersProvider` (the tracked-people
/// roster, not this screen's own account roster) for the supervises
/// picker, same as the web reference's separate `familyMembers` fetch.
class _EditDialog extends ConsumerStatefulWidget {
  const _EditDialog({required this.relationship});

  final FamilyRelationshipModel relationship;

  @override
  ConsumerState<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends ConsumerState<_EditDialog> {
  late String _role = widget.relationship.kinship ??
      (widget.relationship.role == 'parent'
          ? 'father'
          : widget.relationship.role == 'child'
              ? 'son'
              : 'relative');
  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('صلة القرابة'),
          content: DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'صلة القرابة'),
              items: [
                for (final key in FamilyMembershipScreen._assignableRoles)
                  DropdownMenuItem(
                      value: key,
                      child: Text(FamilyMembershipScreen._roleLabels[key]!))
              ],
              onChanged: (value) => setState(() => _role = value ?? _role)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(context, (
                      role: _role,
                      trackingPermissions:
                          widget.relationship.trackingPermissions,
                      supervises: widget.relationship.supervises
                    )),
                child: const Text('حفظ'))
          ]);
}
