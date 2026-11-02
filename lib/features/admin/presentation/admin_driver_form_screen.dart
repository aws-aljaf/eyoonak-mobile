import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../application/admin_drivers_providers.dart';
import '../data/admin_driver_models.dart';

/// One form for both "إضافة سائق" (`driver == null`) and "تعديل سائق"
/// (`driver` set) — `StoreDriverRequest`/`UpdateDriverRequest` share almost
/// the same rule set (verified directly against both FormRequests before
/// building this; `full_name`/`phone` are `required` on create and
/// `sometimes` on edit, everything else identical), so one widget
/// collecting the same fields and picking `create()` or `update()` at
/// submit time avoids duplicating the whole layout twice — same pattern
/// `AdminVehicleFormScreen` already established.
///
/// **No `branch_id`/`user_id` fields** — see `AdminDriversApi`'s own
/// docblock for why both are deliberately left out (no branch picker
/// anywhere in this app; no endpoint to list unlinked company users for a
/// picker either, and linking a driver to login credentials is unrelated
/// to this controller regardless).
///
/// `status` is an ordinary dropdown field here, not a dedicated action —
/// verified directly that `DriverController` has no separate
/// suspend/reactivate/terminate endpoint the way `UserController` does,
/// so a status change travels through this same general `update()` call.
///
/// Reached from `AdminDriversScreen`'s "+" FAB (create, gated on
/// `drivers.create`) or `AdminDriverDetailScreen`'s edit action (gated on
/// `drivers.edit`) — both already checked before this route is pushed, so
/// this screen carries no permission gate of its own, same convention as
/// every other admin form in this app; the actual write request is still
/// the real gate server-side either way.
class AdminDriverFormScreen extends ConsumerStatefulWidget {
  const AdminDriverFormScreen({super.key, this.driver});

  /// `null` = create a new driver; otherwise edit this one.
  final AdminDriver? driver;

  @override
  ConsumerState<AdminDriverFormScreen> createState() => _AdminDriverFormScreenState();
}

class _AdminDriverFormScreenState extends ConsumerState<AdminDriverFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final _fullNameController = TextEditingController(text: widget.driver?.fullName);
  late final _phoneController = TextEditingController(text: widget.driver?.phone);
  late final _nationalIdController = TextEditingController(text: widget.driver?.nationalId);
  late final _governorateController = TextEditingController(text: widget.driver?.governorate);
  late final _addressController = TextEditingController(text: widget.driver?.address);
  late final _licenseNumberController = TextEditingController(text: widget.driver?.licenseNumber);
  late final _licenseTypeController = TextEditingController(text: widget.driver?.licenseType);
  late final _salaryController = TextEditingController(text: widget.driver?.salary?.toString());
  late final _emergencyContactNameController = TextEditingController(text: widget.driver?.emergencyContactName);
  late final _emergencyContactPhoneController = TextEditingController(text: widget.driver?.emergencyContactPhone);

  String? _status;
  DateTime? _birthDate;
  DateTime? _licenseExpiry;
  DateTime? _hireDate;

  bool _submitting = false;
  String? _error;

  bool get _isEditing => widget.driver != null;

  @override
  void initState() {
    super.initState();
    _status = widget.driver?.status ?? 'active';
    _birthDate = _parseDate(widget.driver?.birthDate);
    _licenseExpiry = _parseDate(widget.driver?.licenseExpiryDate);
    _hireDate = _parseDate(widget.driver?.hireDate);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _nationalIdController.dispose();
    _governorateController.dispose();
    _addressController.dispose();
    _licenseNumberController.dispose();
    _licenseTypeController.dispose();
    _salaryController.dispose();
    _emergencyContactNameController.dispose();
    _emergencyContactPhoneController.dispose();
    super.dispose();
  }

  DateTime? _parseDate(String? value) => value != null ? DateTime.tryParse(value) : null;

  Future<void> _pickDate(DateTime? current, void Function(DateTime?) onPicked) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 80),
      lastDate: now,
    );

    if (!mounted) {
      return;
    }

    if (picked != null) {
      setState(() => onPicked(picked));
    }
  }

  Map<String, dynamic> _buildPayload() {
    double? parseDouble(String text) => text.trim().isEmpty ? null : double.tryParse(text.trim());
    String? blankToNull(String text) => text.trim().isEmpty ? null : text.trim();

    return {
      'full_name': _fullNameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'national_id': blankToNull(_nationalIdController.text),
      'governorate': blankToNull(_governorateController.text),
      'address': blankToNull(_addressController.text),
      'birth_date': _birthDate?.toIso8601String().split('T').first,
      'license_number': blankToNull(_licenseNumberController.text),
      'license_type': blankToNull(_licenseTypeController.text),
      'license_expiry_date': _licenseExpiry?.toIso8601String().split('T').first,
      'hire_date': _hireDate?.toIso8601String().split('T').first,
      'salary': parseDouble(_salaryController.text),
      'status': _status,
      'emergency_contact_name': blankToNull(_emergencyContactNameController.text),
      'emergency_contact_phone': blankToNull(_emergencyContactPhoneController.text),
    };
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
      final api = ref.read(adminDriversApiProvider);
      final payload = _buildPayload();

      if (_isEditing) {
        await api.update(widget.driver!.id, payload);
      } else {
        await api.create(payload);
      }

      ref.invalidate(adminDriversProvider);
      if (_isEditing) {
        ref.invalidate(adminDriverDetailProvider(widget.driver!.id));
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
      appBar: AppBar(title: Text(_isEditing ? 'تعديل السائق' : 'إضافة سائق')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _fullNameController,
              decoration: const InputDecoration(labelText: 'الاسم الكامل *', border: OutlineInputBorder()),
              validator: (value) => (value == null || value.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'رقم الهاتف *', border: OutlineInputBorder()),
              validator: (value) => (value == null || value.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nationalIdController,
              decoration: const InputDecoration(labelText: 'رقم الهوية', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _governorateController,
                    decoration: const InputDecoration(labelText: 'المحافظة', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DateField(label: 'تاريخ الميلاد', value: _birthDate, onTap: () => _pickDate(_birthDate, (d) => _birthDate = d)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'العنوان', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Text('الرخصة والعمل', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _licenseNumberController,
                    decoration: const InputDecoration(labelText: 'رقم الرخصة', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _licenseTypeController,
                    decoration: const InputDecoration(labelText: 'نوع الرخصة', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _DateField(
              label: 'انتهاء الرخصة',
              value: _licenseExpiry,
              onTap: () => _pickDate(_licenseExpiry, (d) => _licenseExpiry = d),
            ),
            const SizedBox(height: 8),
            _DateField(label: 'تاريخ التعيين', value: _hireDate, onTap: () => _pickDate(_hireDate, (d) => _hireDate = d)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _salaryController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'الراتب', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'الحالة', border: OutlineInputBorder()),
              items: [
                for (final entry in driverStatusLabels.entries) DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) => setState(() => _status = value),
            ),
            const SizedBox(height: 16),
            Text('جهة اتصال الطوارئ', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emergencyContactNameController,
              decoration: const InputDecoration(labelText: 'الاسم', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emergencyContactPhoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'الهاتف', border: OutlineInputBorder()),
            ),
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
                    : Text(_isEditing ? 'حفظ التعديلات' : 'إضافة السائق'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onTap});

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.date_range_outlined, size: 18),
      label: Align(
        alignment: Alignment.centerRight,
        child: Text(value != null ? '$label: ${_format(value!)}' : label),
      ),
      style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
    );
  }

  String _format(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');

    return '$d/$m/${dt.year}';
  }
}
