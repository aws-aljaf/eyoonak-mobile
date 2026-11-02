import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../application/admin_roles_providers.dart';
import '../application/admin_users_providers.dart';
import '../data/admin_user_models.dart';

/// One form for both "إضافة مستخدم" (`user == null`) and "تعديل مستخدم"
/// (`user` set) — verified directly against `StoreUserRequest`/
/// `UpdateUserRequest` before building this. Unlike
/// `AdminVehicleFormScreen`, the two requests are NOT close enough to share
/// every field: `password` and `role_ids` exist only on `StoreUserRequest`
/// (roles are edited afterwards via `AdminUserAssignRolesScreen`, password
/// only via the dedicated "إعادة تعيين كلمة المرور" action), and `status`
/// exists on neither this screen's payload nor `StoreUserRequest` at all —
/// see `AdminUsersApi`'s own docblock for why `status` is deliberately never
/// sent from here (suspend/reactivate are the only path).
///
/// **No `branch_id` field** — same reasoning `AdminVehiclesApi`/
/// `AdminDriversApi`/`AdminTripsApi` already documented: no endpoint
/// anywhere in this app lists a company's branches for a picker, and a raw
/// numeric-id text field would be worse than omitting the field (a new user
/// is simply created/kept branch-less; an office admin can still see/manage
/// them everywhere else).
///
/// Reached from `AdminUsersScreen`'s "+" FAB (create, gated on
/// `users.create`) or `AdminUserDetailScreen`'s "تعديل" action (gated on
/// `users.edit`) — both already checked before this route is pushed, so this
/// screen carries no permission gate of its own, same convention as every
/// other admin form in this app; the actual write request is still the real
/// gate server-side either way.
class AdminUserFormScreen extends ConsumerStatefulWidget {
  const AdminUserFormScreen({super.key, this.user});

  /// `null` = create a new user; otherwise edit this one.
  final AdminUser? user;

  @override
  ConsumerState<AdminUserFormScreen> createState() => _AdminUserFormScreenState();
}

class _AdminUserFormScreenState extends ConsumerState<AdminUserFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final _nameController = TextEditingController(text: widget.user?.name);
  late final _emailController = TextEditingController(text: widget.user?.email);
  late final _phoneController = TextEditingController(text: widget.user?.phone);
  final _passwordController = TextEditingController();

  String? _locale;
  final Set<int> _selectedRoleIds = {};

  bool _submitting = false;
  String? _error;

  bool get _isEditing => widget.user != null;

  @override
  void initState() {
    super.initState();
    _locale = widget.user?.locale ?? 'ar';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildPayload() {
    String? blankToNull(String text) => text.trim().isEmpty ? null : text.trim();

    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': blankToNull(_phoneController.text),
      'locale': _locale,
    };

    if (!_isEditing) {
      payload['password'] = _passwordController.text;
      if (_selectedRoleIds.isNotEmpty) {
        payload['role_ids'] = _selectedRoleIds.toList();
      }
    }

    return payload;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final api = ref.read(adminUsersApiProvider);
      final payload = _buildPayload();

      if (_isEditing) {
        await api.update(widget.user!.id, payload);
      } else {
        await api.create(payload);
      }

      ref.invalidate(adminUsersProvider);
      if (_isEditing) {
        ref.invalidate(adminUserDetailProvider(widget.user!.id));
      }

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
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'تعديل المستخدم' : 'إضافة مستخدم')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'الاسم *', border: OutlineInputBorder()),
              validator: (value) => (value == null || value.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'البريد الإلكتروني *', border: OutlineInputBorder()),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'مطلوب';
                }
                if (!value.contains('@')) {
                  return 'بريد إلكتروني غير صالح';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'الهاتف', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _locale,
              decoration: const InputDecoration(labelText: 'اللغة', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'ar', child: Text('العربية')),
                DropdownMenuItem(value: 'en', child: Text('الإنجليزية')),
                DropdownMenuItem(value: 'ku', child: Text('الكردية')),
              ],
              onChanged: (value) => setState(() => _locale = value),
            ),
            if (!_isEditing) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'كلمة المرور *', border: OutlineInputBorder()),
                validator: (value) {
                  if (value == null || value.length < 8) {
                    return '8 أحرف على الأقل';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text('الأدوار (اختياري)', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              const Text(
                'يمكن تعديل أدوار المستخدم لاحقًا من شاشة تفاصيله.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 8),
              _RolesChecklist(
                selectedRoleIds: _selectedRoleIds,
                onChanged: (ids) => setState(() {
                  _selectedRoleIds
                    ..clear()
                    ..addAll(ids);
                }),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_isEditing ? 'حفظ التعديلات' : 'إضافة المستخدم'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Only rendered on the create path (see the form above) — a flat checklist
/// of every role this company can assign (`adminRolesProvider`, the same
/// unpaginated catalogue `AdminRolesScreen` lists), letting the admin grant
/// role(s) at creation time instead of a required separate follow-up trip
/// through `AdminUserAssignRolesScreen` right after.
class _RolesChecklist extends ConsumerWidget {
  const _RolesChecklist({required this.selectedRoleIds, required this.onChanged});

  final Set<int> selectedRoleIds;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rolesAsync = ref.watch(adminRolesProvider);

    return rolesAsync.when(
      data: (roles) {
        if (roles.isEmpty) {
          return const Text('لا توجد أدوار متاحة.', style: TextStyle(color: Colors.grey));
        }

        return Column(
          children: roles
              .map(
                (role) => CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(role.displayName),
                  value: selectedRoleIds.contains(role.id),
                  onChanged: (checked) {
                    final next = Set<int>.from(selectedRoleIds);
                    if (checked ?? false) {
                      next.add(role.id);
                    } else {
                      next.remove(role.id);
                    }
                    onChanged(next);
                  },
                ),
              )
              .toList(),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (error, stack) => Text('تعذر تحميل الأدوار: $error', style: const TextStyle(color: Colors.red)),
    );
  }
}
