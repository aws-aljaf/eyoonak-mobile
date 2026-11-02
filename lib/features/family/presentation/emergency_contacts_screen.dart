import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_exception.dart';
import '../application/family_providers.dart';
import '../data/family_models.dart';

/// Full CRUD for the family's emergency-contact list — the mobile
/// counterpart to whatever admin UI exists on the web for
/// `EmergencyContactController`. These are people (with no app account of
/// their own, typically) who `FamilySosNotifier` records as "would have
/// been notified" when a family member triggers SOS — see that service's
/// own docblock for why this is advisory bookkeeping only: **no SMS or
/// push is actually sent to a contact today**, only an in-app `Alert` is
/// raised and the contact IDs are snapshotted onto the `SosEvent` row.
/// This screen must never imply otherwise (no "notified" wording — only
/// "سيتم إشعارها" framed as an app-side setting, never a delivery claim).
///
/// Permissions are `sos.*`, not `family_tracking.*` — a genuinely
/// different permission family from every other family-tracking screen in
/// this app, verified directly against `EmergencyContactPolicy`:
/// `viewAny` needs `sos.view` OR `sos.manage_contacts` (so a contact
/// manager who lacks `sos.view` can still reach this list), while
/// create/update/delete all need `sos.manage_contacts` specifically —
/// `update`/`delete` additionally require active family membership,
/// `create` does not (family scoping comes from `X-Family-Id` context
/// instead).
class EmergencyContactsScreen extends ConsumerWidget {
  const EmergencyContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(emergencyContactsProvider);
    final user = ref.watch(authControllerProvider).user;
    final canManage = user != null && user.permissions.contains('sos.manage_contacts');

    return Scaffold(
      appBar: AppBar(
        title: const Text('جهات الاتصال الطارئة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: () => ref.invalidate(emergencyContactsProvider),
          ),
        ],
      ),
      body: contactsAsync.when(
        data: (contacts) => _ContactsList(contacts: contacts, canManage: canManage),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(emergencyContactsProvider),
        ),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _addContact(context, ref),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('جهة اتصال جديدة'),
            )
          : null,
    );
  }

  Future<void> _addContact(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<_ContactFormResult>(
      context: context,
      builder: (context) => const _ContactFormDialog(),
    );

    if (result == null) return;

    try {
      final familyId = ref.read(selectedFamilyIdProvider);

      await ref.read(familyApiProvider).createEmergencyContact(
            name: result.name,
            phone: result.phone,
            relationship: result.relationship,
            notifyOnSos: result.notifyOnSos,
            familyId: familyId,
          );
      ref.invalidate(emergencyContactsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة جهة الاتصال')));
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إضافة جهة الاتصال: $error')));
      }
    }
  }
}

class _ContactsList extends StatelessWidget {
  const _ContactsList({required this.contacts, required this.canManage});

  final List<EmergencyContactModel> contacts;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    if (contacts.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: const Center(child: Text('لا توجد جهات اتصال طارئة بعد.')),
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: contacts.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _ContactCard(contact: contacts[index], canManage: canManage),
    );
  }
}

class _ContactCard extends ConsumerStatefulWidget {
  const _ContactCard({required this.contact, required this.canManage});

  final EmergencyContactModel contact;
  final bool canManage;

  @override
  ConsumerState<_ContactCard> createState() => _ContactCardState();
}

class _ContactCardState extends ConsumerState<_ContactCard> {
  bool _busy = false;

  Future<void> _edit() async {
    final result = await showDialog<_ContactFormResult>(
      context: context,
      builder: (context) => _ContactFormDialog(existing: widget.contact),
    );

    if (result == null || !mounted) return;

    setState(() => _busy = true);

    try {
      final familyId = ref.read(selectedFamilyIdProvider);

      await ref.read(familyApiProvider).updateEmergencyContact(
            contactId: widget.contact.id,
            name: result.name,
            phone: result.phone,
            relationship: result.relationship,
            notifyOnSos: result.notifyOnSos,
            familyId: familyId,
          );
      ref.invalidate(emergencyContactsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث جهة الاتصال')));
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحديث جهة الاتصال: $error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف جهة الاتصال'),
        content: Text('سيتم حذف "${widget.contact.name}" نهائيًا ولا يمكن التراجع عن ذلك. هل أنت متأكد؟'),
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

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);

    try {
      final familyId = ref.read(selectedFamilyIdProvider);

      await ref.read(familyApiProvider).deleteEmergencyContact(contactId: widget.contact.id, familyId: familyId);
      ref.invalidate(emergencyContactsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف جهة الاتصال')));
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حذف جهة الاتصال: $error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contact = widget.contact;

    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.contact_phone_outlined)),
        title: Text(contact.name),
        subtitle: Text([
          contact.phone,
          if (contact.relationship != null && contact.relationship!.isNotEmpty) contact.relationship!,
          // Deliberately "سيتم إشعارها داخل التطبيق" — an in-app-only
          // claim, never "سيتم إرسال رسالة" or similar, matching this
          // screen's own docblock on not implying real SMS/push delivery.
          contact.notifyOnSos ? 'سيتم إشعارها عند SOS' : 'غير مُفعَّلة للإشعار',
        ].join(' • ')),
        trailing: _busy
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : widget.canManage
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'تعديل', onPressed: _edit),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
                        tooltip: 'حذف',
                        onPressed: _delete,
                      ),
                    ],
                  )
                : null,
      ),
    );
  }
}

typedef _ContactFormResult = ({String name, String phone, String? relationship, bool notifyOnSos});

/// The create/edit form for a single contact — a dialog rather than a
/// full route (matching `_showCreateFamilyDialog`'s precedent on
/// `FamilyHomeScreen` for a similarly small, single-object form): four
/// plain fields, no map or multi-step flow to justify a whole screen.
class _ContactFormDialog extends StatefulWidget {
  const _ContactFormDialog({this.existing});

  final EmergencyContactModel? existing;

  @override
  State<_ContactFormDialog> createState() => _ContactFormDialogState();
}

class _ContactFormDialogState extends State<_ContactFormDialog> {
  late final _nameController = TextEditingController(text: widget.existing?.name ?? '');
  late final _phoneController = TextEditingController(text: widget.existing?.phone ?? '');
  late final _relationshipController = TextEditingController(text: widget.existing?.relationship ?? '');
  late bool _notifyOnSos = widget.existing?.notifyOnSos ?? true;
  String? _errorMessage;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      setState(() => _errorMessage = 'الرجاء إدخال الاسم ورقم الهاتف.');
      return;
    }

    final relationship = _relationshipController.text.trim();

    Navigator.pop(
      context,
      (
        name: name,
        phone: phone,
        relationship: relationship.isEmpty ? null : relationship,
        notifyOnSos: _notifyOnSos,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'تعديل جهة اتصال' : 'إضافة جهة اتصال'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'الاسم'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'رقم الهاتف'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _relationshipController,
              decoration: const InputDecoration(labelText: 'صلة القرابة (اختياري)'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('إشعار عند نداء استغاثة (SOS)'),
              value: _notifyOnSos,
              onChanged: (value) => setState(() => _notifyOnSos = value),
            ),
            if (_errorMessage case final message?) ...[
              const SizedBox(height: 4),
              Text(message, style: TextStyle(color: Colors.red.shade700)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: _submit, child: Text(_isEditing ? 'حفظ' : 'إضافة')),
      ],
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
                  Text('تعذر تحميل جهات الاتصال: $message', textAlign: TextAlign.center),
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
