import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../application/admin_roles_providers.dart';
import '../application/admin_users_providers.dart';
import '../data/admin_role_models.dart';
import '../data/admin_user_models.dart';

/// "الأدوار" — `UserController::assignRoles()` (gated on `UserPolicy::
/// assignRoles()`, i.e. `users.edit` — verified directly against
/// `AssignRolesRequest`/`UserPolicy` before building this), reached only
/// from `AdminUserDetailScreen`'s own action (itself gated on
/// `users.edit`), so this screen carries no permission gate of its own
/// either.
///
/// `AssignRolesRequest` does a full `sync()` server-side, not an incremental
/// attach/detach — this screen is built the same way: a checklist of the
/// user's COMPLETE role set to review and confirm, not toggle-one-save-one.
/// Two things `UserPolicy::assignRoles()` does **not** guard against (both
/// verified directly, not assumed) get handled here instead: an empty
/// selection is a valid request that strips every role, so submitting one
/// asks for explicit confirmation; and there is no self-exclusion at all
/// (unlike delete/manageStatus/forceLogout), so a caller editing their OWN
/// account's roles sees a standing warning banner the whole time this
/// screen is open.
class AdminUserAssignRolesScreen extends ConsumerStatefulWidget {
  const AdminUserAssignRolesScreen({super.key, required this.user});

  final AdminUser user;

  @override
  ConsumerState<AdminUserAssignRolesScreen> createState() => _AdminUserAssignRolesScreenState();
}

class _AdminUserAssignRolesScreenState extends ConsumerState<AdminUserAssignRolesScreen> {
  Set<int>? _selectedRoleIds;
  bool _submitting = false;
  String? _error;

  /// Seeds `_selectedRoleIds` from `widget.user.roles` (slugs) the first
  /// time the role catalogue arrives — matched by slug since `AdminUser`
  /// only carries role slugs, not ids (`UserResource` never eager-loads
  /// full role objects on a user, only their slugs).
  void _ensureInitialized(List<AdminRole> roles) {
    _selectedRoleIds ??= roles.where((r) => widget.user.roles.contains(r.slug)).map((r) => r.id).toSet();
  }

  Future<void> _submit() async {
    final selected = _selectedRoleIds;
    if (selected == null) {
      return;
    }

    if (selected.isEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('إزالة كل الأدوار'),
          content: const Text('لم تُحدَّد أي أدوار — سيؤدي هذا إلى إزالة كل أدوار هذا المستخدم. متابعة؟'),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('إلغاء')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('متابعة'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) {
        return;
      }
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(adminUsersApiProvider).assignRoles(widget.user.id, selected.toList());
      ref.invalidate(adminUserDetailProvider(widget.user.id));
      ref.invalidate(adminUsersProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      setState(() {
        _submitting = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rolesAsync = ref.watch(adminRolesProvider);
    final currentUserId = ref.watch(authControllerProvider).user?.id;
    final isSelf = currentUserId != null && currentUserId == widget.user.id;

    return Scaffold(
      appBar: AppBar(title: Text('أدوار ${widget.user.name}')),
      body: Column(
        children: [
          if (isSelf)
            Container(
              width: double.infinity,
              color: Colors.amber.shade100,
              padding: const EdgeInsets.all(12),
              child: const Text(
                'أنت تُعدّل أدوار حسابك الخاص — قد تفقد وصولك لبعض شاشات الإدارة إذا أزلت الدور الذي يمنحك هذه الصلاحية.',
                style: TextStyle(color: Colors.black87),
              ),
            ),
          Expanded(
            child: rolesAsync.when(
              data: (roles) {
                _ensureInitialized(roles);
                final selected = _selectedRoleIds!;

                if (roles.isEmpty) {
                  return const Center(child: Text('لا توجد أدوار متاحة.'));
                }

                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: roles
                      .map(
                        (role) => CheckboxListTile(
                          title: Text(role.displayName),
                          subtitle: role.description != null ? Text(role.description!) : null,
                          value: selected.contains(role.id),
                          onChanged: (checked) {
                            setState(() {
                              if (checked ?? false) {
                                selected.add(role.id);
                              } else {
                                selected.remove(role.id);
                              }
                            });
                          },
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('تعذر تحميل الأدوار: $error', textAlign: TextAlign.center)),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_selectedRoleIds == null || _submitting) ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('حفظ الأدوار'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
