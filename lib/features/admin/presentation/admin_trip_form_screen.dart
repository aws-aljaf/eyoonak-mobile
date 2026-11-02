import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../trips/application/trips_providers.dart';
import '../../trips/data/trip_models.dart';
import '../application/admin_trips_providers.dart';
import '../data/admin_driver_models.dart';
import '../data/admin_vehicle_models.dart';

/// One form for both "إضافة رحلة" (`trip == null`) and "تعديل رحلة" (`trip`
/// set) — `StoreTripRequest`/`UpdateTripRequest` share almost the same core
/// field set (verified directly against both FormRequests before building
/// this), so one widget collecting the same fields and picking `create()`
/// or `update()` at submit time avoids duplicating the whole layout twice —
/// same pattern `AdminVehicleFormScreen`/`AdminDriverFormScreen` already
/// established.
///
/// **Real differences from those two forms, all verified directly against
/// the backend before building this:**
/// - `vehicle_id`/`driver_id` are **required**, not omittable like
///   `branch_id`/`user_id` were on the vehicle/driver forms — there is no
///   endpoint to list "unassigned" ones, so this screen adds its own
///   lightweight search picker (`_showPicker`, fed by `_fetchVehicles`/
///   `_fetchDrivers`, reusing `AdminVehiclesApi`/`AdminDriversApi.index(q:
///   ...)`, the exact same endpoints `AdminVehiclesScreen`/
///   `AdminDriversScreen` already search with) rather than leaving the
///   field out.
/// - **`customer_id` is still omitted** — no endpoint anywhere in this app
///   lists a company's customers for a picker, same reasoning as
///   `branch_id`/`user_id` above.
/// - **No `status` field at all** — verified directly that `store()` forces
///   `status: 'draft'` unconditionally and `update()` never accepts
///   `status`; changing a trip's status is a separate state-machine action
///   (`POST /trips/{id}/status`) this admin surface deliberately does not
///   add (see `AdminTripsApi`'s own docblock).
/// - **Editing is only possible while `trip.isCoreEditable`** (`draft`/
///   `assigned`/`accepted`) — `UpdateTripRequest::withValidator` rejects
///   the whole request otherwise, so this screen shows a plain "لا يمكن
///   التعديل" message instead of a form when that's not the case, rather
///   than letting the user fill out a form that can only ever fail server
///   -side.
/// - **The stops editor only appears when creating** — `UpdateTripRequest`
///   has no `stops` rule at all (stops are create-only on this backend, see
///   `AdminTripsApi`'s docblock), so there is nothing to edit here after
///   creation.
///
/// Reached from `AdminTripsScreen`'s "+" FAB (create, gated on
/// `trips.create`) or `AdminTripDetailScreen`'s edit action (gated on
/// `trips.edit`) — both already checked before this route is pushed, so
/// this screen carries no permission gate of its own, same convention as
/// every other admin form in this app; the actual write request is still
/// the real gate server-side either way.
class AdminTripFormScreen extends ConsumerStatefulWidget {
  const AdminTripFormScreen({super.key, this.trip});

  /// `null` = create a new trip; otherwise edit this one.
  final Trip? trip;

  @override
  ConsumerState<AdminTripFormScreen> createState() => _AdminTripFormScreenState();
}

class _AdminTripFormScreenState extends ConsumerState<AdminTripFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final _originAddressController = TextEditingController(text: widget.trip?.originAddress);
  late final _originLatController = TextEditingController(text: widget.trip?.originLat?.toString());
  late final _originLngController = TextEditingController(text: widget.trip?.originLng?.toString());
  late final _destinationAddressController = TextEditingController(text: widget.trip?.destinationAddress);
  late final _destinationLatController = TextEditingController(text: widget.trip?.destinationLat?.toString());
  late final _destinationLngController = TextEditingController(text: widget.trip?.destinationLng?.toString());
  late final _cargoController = TextEditingController(text: widget.trip?.cargoDescription);
  late final _weightController = TextEditingController(text: widget.trip?.weightKg?.toString());
  late final _quantityController = TextEditingController(text: widget.trip?.quantity?.toString());
  late final _distanceController = TextEditingController(text: widget.trip?.distanceKm?.toString());
  late final _notesController = TextEditingController(text: widget.trip?.notes);

  int? _vehicleId;
  String? _vehicleLabel;
  int? _driverId;
  String? _driverLabel;
  DateTime? _expectedStart;
  DateTime? _expectedArrival;

  final List<_StopDraft> _stops = [];

  bool _submitting = false;
  String? _error;

  bool get _isEditing => widget.trip != null;

  bool get _isCoreEditable => !_isEditing || widget.trip!.isCoreEditable;

  @override
  void initState() {
    super.initState();
    _vehicleId = widget.trip?.vehicleId;
    _vehicleLabel = widget.trip?.vehiclePlateNumber;
    _driverId = widget.trip?.driverId;
    _driverLabel = widget.trip?.driverName;
    _expectedStart = widget.trip?.expectedStartAt;
    _expectedArrival = widget.trip?.expectedArrivalAt;
  }

  @override
  void dispose() {
    _originAddressController.dispose();
    _originLatController.dispose();
    _originLngController.dispose();
    _destinationAddressController.dispose();
    _destinationLatController.dispose();
    _destinationLngController.dispose();
    _cargoController.dispose();
    _weightController.dispose();
    _quantityController.dispose();
    _distanceController.dispose();
    _notesController.dispose();
    for (final stop in _stops) {
      stop.dispose();
    }
    super.dispose();
  }

  Future<List<_PickerOption>> _fetchVehicles(String query) async {
    final envelope = await ref.read(adminVehiclesApiProvider).index(perPage: 30, q: query.isEmpty ? null : query);

    return envelope.data.map((e) {
      final vehicle = AdminVehicle.fromJson(Map<String, dynamic>.from(e as Map));

      return _PickerOption(
        id: vehicle.id,
        title: vehicle.plateNumber,
        subtitle: vehicle.displayName.isEmpty ? null : vehicle.displayName,
      );
    }).toList();
  }

  Future<List<_PickerOption>> _fetchDrivers(String query) async {
    final envelope = await ref.read(adminDriversApiProvider).index(perPage: 30, q: query.isEmpty ? null : query);

    return envelope.data.map((e) {
      final driver = AdminDriver.fromJson(Map<String, dynamic>.from(e as Map));

      return _PickerOption(id: driver.id, title: driver.fullName, subtitle: driver.phone);
    }).toList();
  }

  Future<void> _pickDateTime(DateTime? current, void Function(DateTime?) onPicked) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );

    if (!mounted || date == null) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: current != null ? TimeOfDay.fromDateTime(current) : TimeOfDay.now(),
    );

    if (!mounted) {
      return;
    }

    setState(() => onPicked(DateTime(date.year, date.month, date.day, time?.hour ?? 0, time?.minute ?? 0)));
  }

  Map<String, dynamic> _buildPayload() {
    double? parseDouble(String text) => text.trim().isEmpty ? null : double.tryParse(text.trim());
    int? parseInt(String text) => text.trim().isEmpty ? null : int.tryParse(text.trim());
    String? blankToNull(String text) => text.trim().isEmpty ? null : text.trim();

    final payload = <String, dynamic>{
      'vehicle_id': _vehicleId,
      'driver_id': _driverId,
      'origin_address': _originAddressController.text.trim(),
      'origin_lat': parseDouble(_originLatController.text),
      'origin_lng': parseDouble(_originLngController.text),
      'destination_address': _destinationAddressController.text.trim(),
      'destination_lat': parseDouble(_destinationLatController.text),
      'destination_lng': parseDouble(_destinationLngController.text),
      'cargo_description': blankToNull(_cargoController.text),
      'weight_kg': parseDouble(_weightController.text),
      'quantity': parseInt(_quantityController.text),
      'distance_km': parseDouble(_distanceController.text),
      'expected_start_at': _expectedStart?.toIso8601String(),
      'expected_arrival_at': _expectedArrival?.toIso8601String(),
      'notes': blankToNull(_notesController.text),
    };

    if (!_isEditing) {
      final stops = _stops.map((s) => s.toJson()).whereType<Map<String, dynamic>>().toList();

      if (stops.isNotEmpty) {
        payload['stops'] = stops;
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
      final api = ref.read(adminTripsApiProvider);
      final payload = _buildPayload();

      if (_isEditing) {
        await api.update(widget.trip!.id, payload);
      } else {
        await api.create(payload);
      }

      ref.invalidate(adminTripsProvider);
      if (_isEditing) {
        ref.invalidate(tripDetailProvider(widget.trip!.id));
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
    if (!_isCoreEditable) {
      return Scaffold(
        appBar: AppBar(title: const Text('تعديل الرحلة')),
        body: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'لا يمكن تعديل بيانات هذه الرحلة لأنها بدأت أو انتهت بالفعل.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'تعديل الرحلة' : 'إضافة رحلة')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FormField<int>(
              initialValue: _vehicleId,
              validator: (value) => _vehicleId == null ? 'اختر المركبة' : null,
              builder: (field) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PickerButton(
                    label: 'المركبة *',
                    icon: Icons.local_shipping_outlined,
                    value: _vehicleLabel,
                    onTap: () async {
                      final picked = await _showPicker(title: 'اختر المركبة', fetch: _fetchVehicles);

                      if (picked != null) {
                        setState(() {
                          _vehicleId = picked.id;
                          _vehicleLabel = picked.title;
                        });
                        field.didChange(picked.id);
                      }
                    },
                  ),
                  if (field.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, right: 4),
                      child: Text(field.errorText!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FormField<int>(
              initialValue: _driverId,
              validator: (value) => _driverId == null ? 'اختر السائق' : null,
              builder: (field) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PickerButton(
                    label: 'السائق *',
                    icon: Icons.badge_outlined,
                    value: _driverLabel,
                    onTap: () async {
                      final picked = await _showPicker(title: 'اختر السائق', fetch: _fetchDrivers);

                      if (picked != null) {
                        setState(() {
                          _driverId = picked.id;
                          _driverLabel = picked.title;
                        });
                        field.didChange(picked.id);
                      }
                    },
                  ),
                  if (field.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, right: 4),
                      child: Text(field.errorText!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('نقطة الانطلاق', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextFormField(
              controller: _originAddressController,
              decoration: const InputDecoration(labelText: 'العنوان *', border: OutlineInputBorder()),
              validator: (value) => (value == null || value.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _originLatController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: const InputDecoration(labelText: 'خط العرض', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _originLngController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: const InputDecoration(labelText: 'خط الطول', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('نقطة الوصول', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextFormField(
              controller: _destinationAddressController,
              decoration: const InputDecoration(labelText: 'العنوان *', border: OutlineInputBorder()),
              validator: (value) => (value == null || value.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _destinationLatController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: const InputDecoration(labelText: 'خط العرض', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _destinationLngController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: const InputDecoration(labelText: 'خط الطول', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('الشحنة والجدولة', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextFormField(
              controller: _cargoController,
              decoration: const InputDecoration(labelText: 'وصف الحمولة', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'الوزن (كغم)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'الكمية', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _distanceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'المسافة (كم)', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _DateTimeField(
              label: 'البدء المتوقع',
              value: _expectedStart,
              onTap: () => _pickDateTime(_expectedStart, (d) => _expectedStart = d),
            ),
            const SizedBox(height: 8),
            _DateTimeField(
              label: 'الوصول المتوقع',
              value: _expectedArrival,
              onTap: () => _pickDateTime(_expectedArrival, (d) => _expectedArrival = d),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'ملاحظات', border: OutlineInputBorder()),
            ),
            if (!_isEditing) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('المحطات (اختياري)', style: Theme.of(context).textTheme.titleSmall),
                  TextButton.icon(
                    onPressed: () => setState(() => _stops.add(_StopDraft())),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('إضافة محطة'),
                  ),
                ],
              ),
              for (var i = 0; i < _stops.length; i++) _StopRow(index: i, stop: _stops[i], onRemove: () => setState(() {
                    _stops[i].dispose();
                    _stops.removeAt(i);
                  })),
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
                    : Text(_isEditing ? 'حفظ التعديلات' : 'إضافة الرحلة'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<_PickerOption?> _showPicker({
    required String title,
    required Future<List<_PickerOption>> Function(String query) fetch,
  }) {
    return showModalBottomSheet<_PickerOption>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PickerSheet(title: title, fetch: fetch),
    );
  }
}

class _PickerOption {
  const _PickerOption({required this.id, required this.title, this.subtitle});

  final int id;
  final String title;
  final String? subtitle;
}

/// Search-as-you-search-and-press-enter sheet, same "search on submit" UX
/// as `AdminVehiclesScreen`/`AdminDriversScreen`'s own filter bars — loads
/// an unfiltered first page on open so a short fleet/roster is usable
/// without typing anything first.
class _PickerSheet extends StatefulWidget {
  const _PickerSheet({required this.title, required this.fetch});

  final String title;
  final Future<List<_PickerOption>> Function(String query) fetch;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  final _searchController = TextEditingController();
  Future<List<_PickerOption>>? _future;

  @override
  void initState() {
    super.initState();
    _future = widget.fetch('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    setState(() => _future = widget.fetch(_searchController.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'بحث',
                isDense: true,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _search),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<_PickerOption>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('تعذر التحميل: ${snapshot.error}'));
                  }

                  final options = snapshot.data ?? const [];

                  if (options.isEmpty) {
                    return const Center(child: Text('لا توجد نتائج مطابقة.'));
                  }

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options[index];

                      return ListTile(
                        title: Text(option.title),
                        subtitle: option.subtitle != null ? Text(option.subtitle!) : null,
                        onTap: () => Navigator.of(context).pop(option),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({required this.label, required this.icon, required this.value, required this.onTap});

  final String label;
  final IconData icon;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Align(
        alignment: Alignment.centerRight,
        child: Text(value ?? label),
      ),
      style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
    );
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({required this.label, required this.value, required this.onTap});

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.event_outlined, size: 18),
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
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');

    return '$d/$m/${dt.year} $h:$min';
  }
}

/// One draft stop row in the create-only stops editor — matches
/// `StoreTripRequest`'s `stops.*.address`(required)/`contact_name`/
/// `contact_phone` rules exactly. `lat`/`lng`/`expected_time` are left out
/// here, same reasoning `branch_id`/`customer_id` are left out of the form
/// above: there is no map-picker infrastructure anywhere in this app to
/// collect a stop's coordinates meaningfully.
class _StopDraft {
  _StopDraft()
      : addressController = TextEditingController(),
        contactNameController = TextEditingController(),
        contactPhoneController = TextEditingController();

  final TextEditingController addressController;
  final TextEditingController contactNameController;
  final TextEditingController contactPhoneController;

  void dispose() {
    addressController.dispose();
    contactNameController.dispose();
    contactPhoneController.dispose();
  }

  /// `null` when the address is blank — a half-filled stop row is silently
  /// dropped from the payload rather than blocking submission, since stops
  /// are entirely optional on `StoreTripRequest`.
  Map<String, dynamic>? toJson() {
    final address = addressController.text.trim();

    if (address.isEmpty) {
      return null;
    }

    return {
      'address': address,
      if (contactNameController.text.trim().isNotEmpty) 'contact_name': contactNameController.text.trim(),
      if (contactPhoneController.text.trim().isNotEmpty) 'contact_phone': contactPhoneController.text.trim(),
    };
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({required this.index, required this.stop, required this.onRemove});

  final int index;
  final _StopDraft stop;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('محطة ${index + 1}', style: Theme.of(context).textTheme.bodyMedium)),
                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: onRemove),
              ],
            ),
            TextField(
              controller: stop.addressController,
              decoration: const InputDecoration(labelText: 'العنوان', border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: stop.contactNameController,
                    decoration: const InputDecoration(labelText: 'اسم جهة الاتصال', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: stop.contactPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'الهاتف', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
