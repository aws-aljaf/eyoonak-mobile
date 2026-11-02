import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../application/admin_roles_providers.dart';
import '../data/admin_role_models.dart';

/// One form for both "إضافة دور" (`role == null`) and "تعديل دور" (`role`
/// set) — verified directly against `StoreRoleRequest`/`UpdateRoleRequest`
/// before building this. Unlike `AdminUserFormScreen` (where role selection
/// only happens once, at creation, and is otherwise edited on a separate
/// screen — `AdminUserAssignRolesScreen`), `RoleController::store()`/
/// `::update()` BOTH accept `permission_ids` directly and `sync()` them in
/// the same DB transaction as the name/description fields (verified
/// directly against the controller) — so this screen combines the basic
/// fields and the permission checklist into a single save on both the
/// create and edit paths, matching the backend's own transactional design
/// rather than splitting across two round-trips.
///
/// `slug` is create-only — `UpdateRoleRequest` has no `slug` rule at all
/// (verified directly: the field is immutable after creation), so the slug
/// input only renders on the create path; editing shows the existing slug
/// as plain read-only text for context instead.
///
/// Reached from `AdminRolesScreen`'s "+" FAB (create, gated on
/// `settings.manage` — the same permission `RolePolicy::create()` itself
/// requires) or `AdminRoleDetailScreen`'s "تعديل" action (edit, gated on
/// `role.isEditable`, itself derived from `RolePolicy::update()`'s own
/// `company_id !== null` check, verified directly) — both already checked
/// before this route is pushed, so this screen carries no permission gate
/// of its own, same convention as every other admin form in this app; the
/// actual write request is still the real gate server-side either way.
class AdminRoleFormScreen extends ConsumerStatefulWidget {
  const AdminRoleFormScreen({super.key, this.role});

  /// `null` = create a new role; otherwise edit this one.
  final AdminRole? role;

  @override
  ConsumerState<AdminRoleFormScreen> createState() => _AdminRoleFormScreenState();
}

class _AdminRoleFormScreenState extends ConsumerState<AdminRoleFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final _nameController = TextEditingController(text: widget.role?.name);
  late final _nameArController = TextEditingController(text: widget.role?.nameAr);
  late final _slugController = TextEditingController(text: widget.role?.slug);
  late final _descriptionController = TextEditingController(text: widget.role?.description);

  /// `null` until the permission catalogue has loaded at least once and
  /// been used to seed the initial selection from `widget.role.permissions`
  /// — same "seed once, then own the local copy" pattern
  /// `AdminUserAssignRolesScreen._selectedRoleIds` uses for a user's roles.
  Set<int>? _selectedPermissionIds;

  bool _submitting = false;
  String? _error;

  bool get _isEditing => widget.role != null;

  @override
  void dispose() {
    _nameController.dispose();
    _nameArController.dispose();
    _slugController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Seeds `_selectedPermissionIds` from `widget.role.permissions` (keys)
  /// the first time the catalogue arrives — matched by key since `AdminRole`
  /// only carries permission keys, not ids (`RoleResource` never eager-loads
  /// full permission objects on a role, only their keys), same reasoning
  /// `AdminUserAssignRolesScreen` documents for matching roles by slug on a
  /// user.
  void _ensureInitialized(Map<String, List<AdminPermission>> catalog) {
    if (_selectedPermissionIds != null) {
      return;
    }

    final grantedKeys = widget.role?.permissions.toSet() ?? const <String>{};
    final selected = <int>{};
    for (final permissions in catalog.values) {
      for (final permission in permissions) {
        if (grantedKeys.contains(permission.key)) {
          selected.add(permission.id);
        }
      }
    }
    _selectedPermissionIds = selected;
  }

  Map<String, dynamic> _buildPayload() {
    String? blankToNull(String text) => text.trim().isEmpty ? null : text.trim();

    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'name_ar': blankToNull(_nameArController.text),
      'description': blankToNull(_descriptionController.text),
      'permission_ids': (_selectedPermissionIds ?? const <int>{}).toList(),
    };

    if (!_isEditing) {
      payload['slug'] = _slugController.text.trim();
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
      final api = ref.read(adminRolesApiProvider);
      final payload = _buildPayload();

      if (_isEditing) {
        await api.update(widget.role!.id, payload);
      } else {
        await api.create(payload);
      }

      ref.invalidate(adminRolesProvider);
      if (_isEditing) {
        ref.invalidate(adminRoleDetailProvider(widget.role!.id));
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
    final catalogAsync = ref.watch(adminPermissionsCatalogProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'تعديل الدور' : 'إضافة دور')),
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
              controller: _nameArController,
              decoration: const InputDecoration(labelText: 'الاسم بالعربية', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            if (!_isEditing)
              TextFormField(
                controller: _slugController,
                decoration: const InputDecoration(
                  labelText: 'المعرّف (slug) *',
                  helperText: 'أحرف إنجليزية صغيرة وأرقام وشرطة سفلية فقط، مثال: fleet_supervisor',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) {
                    return 'مطلوب';
                  }
                  if (!RegExp(r'^[a-z0-9_]+$').hasMatch(text)) {
                    return 'أحرف إنجليزية صغيرة وأرقام وـ فقط';
                  }
                  return null;
                },
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'المعرّف: ${widget.role!.slug} (غير قابل للتعديل)',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'الوصف', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            Text('الصلاحيات', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            catalogAsync.when(
              data: (catalog) {
                _ensureInitialized(catalog);

                return _PermissionsPicker(
                  catalog: catalog,
                  selectedIds: _selectedPermissionIds!,
                  onChanged: (ids) => setState(() => _selectedPermissionIds = ids),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) =>
                  Text('تعذر تحميل قائمة الصلاحيات: $error', style: const TextStyle(color: Colors.red)),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_submitting || _selectedPermissionIds == null) ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_isEditing ? 'حفظ التعديلات' : 'إضافة الدور'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Module-grouped permission checklist — adapts `AdminRoleDetailScreen`'s
/// own `_PermissionsChecklist`/`_PermissionRow` layout (same module cards,
/// same `permissionModuleLabels` headers) with the static check-icon
/// swapped for a bound `CheckboxListTile`, same "read-only display becomes
/// an editable selector" adaptation `AdminUserAssignRolesScreen` made of the
/// role-checklist pattern for roles-on-a-user.
class _PermissionsPicker extends StatelessWidget {
  const _PermissionsPicker({required this.catalog, required this.selectedIds, required this.onChanged});

  final Map<String, List<AdminPermission>> catalog;
  final Set<int> selectedIds;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final module in catalog.keys)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Text(
                      permissionModuleLabels[module] ?? module,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  for (final permission in catalog[module]!)
                    CheckboxListTile(
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(permission.descriptionAr ?? permission.key),
                      value: selectedIds.contains(permission.id),
                      onChanged: (checked) {
                        final next = Set<int>.from(selectedIds);
                        if (checked ?? false) {
                          next.add(permission.id);
                        } else {
                          next.remove(permission.id);
                        }
                        onChanged(next);
                      },
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
