import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../application/admin_vehicle_types_providers.dart';
import '../application/admin_vehicles_providers.dart';
import '../data/admin_vehicle_models.dart';

/// One form for both "إضافة مركبة" (`vehicle == null`) and "تعديل مركبة"
/// (`vehicle` set) — `StoreVehicleRequest`/`UpdateVehicleRequest` share
/// almost the same rule set (verified directly against both FormRequests
/// before building this; the only real difference is which fields are
/// `required` vs `sometimes`/`nullable` on create vs edit), so one widget
/// collecting the same fields and picking `create()` or `update()` at
/// submit time avoids duplicating the whole layout twice.
///
/// Reached from `AdminVehiclesScreen`'s "+" FAB (create, gated on
/// `vehicles.create`) or `AdminVehicleDetailScreen`'s edit action (gated on
/// `vehicles.edit`) — both already checked before this route is pushed, so
/// this screen carries no permission gate of its own, same convention as
/// every other admin screen in this app; the actual write request is still
/// the real gate server-side either way.
class AdminVehicleFormScreen extends ConsumerStatefulWidget {
  const AdminVehicleFormScreen({super.key, this.vehicle});

  /// `null` = create a new vehicle; otherwise edit this one.
  final AdminVehicle? vehicle;

  @override
  ConsumerState<AdminVehicleFormScreen> createState() => _AdminVehicleFormScreenState();
}

class _AdminVehicleFormScreenState extends ConsumerState<AdminVehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final _plateNumberController = TextEditingController(text: widget.vehicle?.plateNumber);
  late final _plateGovernorateController = TextEditingController(text: widget.vehicle?.plateGovernorate);
  late final _brandController = TextEditingController(text: widget.vehicle?.brand);
  late final _modelController = TextEditingController(text: widget.vehicle?.model);
  late final _yearController = TextEditingController(text: widget.vehicle?.year?.toString());
  late final _colorController = TextEditingController(text: widget.vehicle?.color);
  late final _vinController = TextEditingController(text: widget.vehicle?.vin);
  late final _engineNumberController = TextEditingController(text: widget.vehicle?.engineNumber);
  late final _chassisNumberController = TextEditingController(text: widget.vehicle?.chassisNumber);
  late final _tankCapacityController = TextEditingController(text: widget.vehicle?.tankCapacityLiters?.toString());
  late final _currentMileageController = TextEditingController(text: widget.vehicle?.currentMileage?.toString());

  int? _vehicleTypeId;
  String? _fuelType;
  String? _status;
  DateTime? _insuranceExpiry;
  DateTime? _registrationExpiry;
  DateTime? _licenseExpiry;
  DateTime? _inspectionExpiry;

  bool _submitting = false;
  String? _error;

  bool get _isEditing => widget.vehicle != null;

  @override
  void initState() {
    super.initState();
    _vehicleTypeId = widget.vehicle?.vehicleTypeId;
    _fuelType = widget.vehicle?.fuelType;
    _status = widget.vehicle?.status;
    _insuranceExpiry = _parseDate(widget.vehicle?.insuranceExpiryDate);
    _registrationExpiry = _parseDate(widget.vehicle?.registrationExpiryDate);
    _licenseExpiry = _parseDate(widget.vehicle?.licenseExpiryDate);
    _inspectionExpiry = _parseDate(widget.vehicle?.inspectionExpiryDate);
  }

  @override
  void dispose() {
    _plateNumberController.dispose();
    _plateGovernorateController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _vinController.dispose();
    _engineNumberController.dispose();
    _chassisNumberController.dispose();
    _tankCapacityController.dispose();
    _currentMileageController.dispose();
    super.dispose();
  }

  DateTime? _parseDate(String? value) => value != null ? DateTime.tryParse(value) : null;

  Future<void> _pickDate(DateTime? current, void Function(DateTime?) onPicked) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 15),
    );

    if (!mounted) {
      return;
    }

    if (picked != null) {
      setState(() => onPicked(picked));
    }
  }

  Map<String, dynamic> _buildPayload() {
    int? parseInt(String text) => text.trim().isEmpty ? null : int.tryParse(text.trim());
    String? blankToNull(String text) => text.trim().isEmpty ? null : text.trim();

    return {
      'vehicle_type_id': _vehicleTypeId,
      'plate_number': _plateNumberController.text.trim(),
      'plate_governorate': blankToNull(_plateGovernorateController.text),
      'brand': _brandController.text.trim(),
      'model': _modelController.text.trim(),
      'year': parseInt(_yearController.text),
      'color': blankToNull(_colorController.text),
      'vin': blankToNull(_vinController.text),
      'engine_number': blankToNull(_engineNumberController.text),
      'chassis_number': blankToNull(_chassisNumberController.text),
      'fuel_type': _fuelType,
      'tank_capacity_liters': parseInt(_tankCapacityController.text),
      'current_mileage': parseInt(_currentMileageController.text),
      'status': _status,
      'insurance_expiry_date': _insuranceExpiry?.toIso8601String().split('T').first,
      'registration_expiry_date': _registrationExpiry?.toIso8601String().split('T').first,
      'license_expiry_date': _licenseExpiry?.toIso8601String().split('T').first,
      'inspection_expiry_date': _inspectionExpiry?.toIso8601String().split('T').first,
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
      final api = ref.read(adminVehiclesApiProvider);
      final payload = _buildPayload();

      if (_isEditing) {
        await api.update(widget.vehicle!.id, payload);
      } else {
        await api.create(payload);
      }

      ref.invalidate(adminVehiclesProvider);
      if (_isEditing) {
        ref.invalidate(adminVehicleDetailProvider(widget.vehicle!.id));
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
    final typesAsync = ref.watch(adminVehicleTypesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'تعديل المركبة' : 'إضافة مركبة')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            typesAsync.when(
              data: (types) => DropdownButtonFormField<int>(
                initialValue: _vehicleTypeId,
                decoration: const InputDecoration(labelText: 'نوع المركبة *', border: OutlineInputBorder()),
                items: [
                  for (final type in types) DropdownMenuItem(value: type.id, child: Text(type.displayName)),
                ],
                onChanged: (value) => setState(() => _vehicleTypeId = value),
                validator: (value) => value == null ? 'اختر نوع المركبة' : null,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (error, stack) => Text('تعذر تحميل أنواع المركبات: $error', style: const TextStyle(color: Colors.red)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _plateNumberController,
              decoration: const InputDecoration(labelText: 'رقم اللوحة *', border: OutlineInputBorder()),
              validator: (value) => (value == null || value.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _plateGovernorateController,
              decoration: const InputDecoration(labelText: 'محافظة اللوحة', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _brandController,
                    decoration: const InputDecoration(labelText: 'الماركة *', border: OutlineInputBorder()),
                    validator: (value) => (value == null || value.trim().isEmpty) ? 'مطلوب' : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _modelController,
                    decoration: const InputDecoration(labelText: 'الموديل *', border: OutlineInputBorder()),
                    validator: (value) => (value == null || value.trim().isEmpty) ? 'مطلوب' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _yearController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'سنة الصنع', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _colorController,
                    decoration: const InputDecoration(labelText: 'اللون', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _vinController,
              decoration: const InputDecoration(labelText: 'رقم الهيكل (VIN)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _engineNumberController,
                    decoration: const InputDecoration(labelText: 'رقم المحرك', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _chassisNumberController,
                    decoration: const InputDecoration(labelText: 'رقم الشاصي', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _fuelType,
              decoration: const InputDecoration(labelText: 'نوع الوقود', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'petrol', child: Text('بنزين')),
                DropdownMenuItem(value: 'diesel', child: Text('ديزل')),
                DropdownMenuItem(value: 'gas', child: Text('غاز')),
                DropdownMenuItem(value: 'electric', child: Text('كهربائي')),
                DropdownMenuItem(value: 'hybrid', child: Text('هجين')),
              ],
              onChanged: (value) => setState(() => _fuelType = value),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _tankCapacityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'سعة الخزان (لتر)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _currentMileageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'العداد الحالي (كم)', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'الحالة', border: OutlineInputBorder()),
              items: [
                for (final entry in vehicleStatusLabels.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) => setState(() => _status = value),
            ),
            const SizedBox(height: 16),
            Text('تواريخ الانتهاء', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _DateField(label: 'التأمين', value: _insuranceExpiry, onTap: () => _pickDate(_insuranceExpiry, (d) => _insuranceExpiry = d)),
            const SizedBox(height: 8),
            _DateField(
              label: 'التسجيل',
              value: _registrationExpiry,
              onTap: () => _pickDate(_registrationExpiry, (d) => _registrationExpiry = d),
            ),
            const SizedBox(height: 8),
            _DateField(label: 'الرخصة', value: _licenseExpiry, onTap: () => _pickDate(_licenseExpiry, (d) => _licenseExpiry = d)),
            const SizedBox(height: 8),
            _DateField(
              label: 'الفحص الفني',
              value: _inspectionExpiry,
              onTap: () => _pickDate(_inspectionExpiry, (d) => _inspectionExpiry = d),
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
                    : Text(_isEditing ? 'حفظ التعديلات' : 'إضافة المركبة'),
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
