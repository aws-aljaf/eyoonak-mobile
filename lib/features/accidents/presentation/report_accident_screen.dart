import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/providers.dart';
import '../../trips/application/trips_providers.dart';
import '../application/accidents_providers.dart';

/// "الإبلاغ عن حادث" — `AccidentController::store()`, verified directly
/// against `AccidentPolicy::create()` and `StoreAccidentRequest` before
/// building this (see `AccidentsApi.create()`'s docblock): any account
/// with a linked driver profile may file a report against their OWN
/// driver record with no RBAC permission at all.
///
/// `vehicle_id` is deliberately NOT a field the driver picks — it's
/// pre-filled from `DriverProfile.currentVehicleId` and shown read-only,
/// because this app has no vehicle list to choose from
/// (`VehiclesApi` has no `index()`). A driver with no vehicle currently
/// assigned cannot file a report from this screen at all (see
/// `_NoVehicleAssigned` below) — `StoreAccidentRequest` only requires
/// `vehicle_id` to belong to the same company, not specifically to this
/// driver, but this app has no safe way to resolve any OTHER vehicle id,
/// so it deliberately narrows to the one it can.
class ReportAccidentScreen extends ConsumerStatefulWidget {
  const ReportAccidentScreen({super.key});

  @override
  ConsumerState<ReportAccidentScreen> createState() => _ReportAccidentScreenState();
}

class _ReportAccidentScreenState extends ConsumerState<ReportAccidentScreen> {
  final _descriptionController = TextEditingController();
  final _damageController = TextEditingController();
  final _locationController = TextEditingController();
  final _thirdPartyController = TextEditingController();
  final _costController = TextEditingController();
  final _picker = ImagePicker();

  DateTime _occurredAt = DateTime.now();
  int? _tripId;
  double? _lat;
  double? _lng;
  bool _locating = false;
  final List<XFile> _photos = [];
  XFile? _policeReport;
  bool _submitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _damageController.dispose();
    _locationController.dispose();
    _thirdPartyController.dispose();
    _costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vehicleAsync = ref.watch(reportingVehicleProvider);
    final tripsAsync = ref.watch(myTripsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('الإبلاغ عن حادث')),
      body: vehicleAsync.when(
        data: (vehicle) {
          if (vehicle == null) {
            return const _NoVehicleAssigned();
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.local_shipping_outlined),
                  title: Text(vehicle.plateNumber),
                  subtitle: Text([vehicle.brand, vehicle.model].whereType<String>().join(' ')),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('وقت الحادث'),
                subtitle: Text(_formatDateTime(_occurredAt)),
                trailing: const Icon(Icons.edit_outlined),
                onTap: _pickOccurredAt,
              ),
              tripsAsync.maybeWhen(
                data: (trips) => trips.isEmpty
                    ? const SizedBox.shrink()
                    : DropdownButtonFormField<int?>(
                        initialValue: _tripId,
                        decoration: const InputDecoration(labelText: 'الرحلة المرتبطة (اختياري)'),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('بلا رحلة محددة')),
                          ...trips.map(
                            (trip) => DropdownMenuItem<int?>(value: trip.id, child: Text(trip.tripNumber)),
                          ),
                        ],
                        onChanged: (value) => setState(() => _tripId = value),
                      ),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'وصف الحادث *', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _damageController,
                decoration: const InputDecoration(labelText: 'وصف الأضرار', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: 'عنوان الموقع', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: Icon(_lat != null ? Icons.check_circle_outline : Icons.my_location),
                label: Text(_locating
                    ? 'جارٍ تحديد الموقع...'
                    : _lat != null
                        ? 'تم تحديد الموقع الحالي'
                        : 'إرفاق موقعي الحالي (اختياري)'),
                onPressed: _locating ? null : _captureLocation,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _thirdPartyController,
                decoration: const InputDecoration(
                  labelText: 'معلومات الطرف الآخر (اختياري)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _costController,
                decoration: const InputDecoration(labelText: 'التكلفة التقديرية (اختياري)', border: OutlineInputBorder()),
                // Plain `TextInputType.number` (already used elsewhere in
                // this app, e.g. `TwoFactorScreen`) rather than
                // `numberWithOptions(decimal: true)` — no prior use of
                // that constructor in this codebase and no local Flutter
                // SDK to double-check it against the pinned version (PR
                // #46's lesson). `double.tryParse` below still accepts a
                // decimal point typed on any keyboard.
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              Text('الصور (حتى 10)', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._photos.map(
                    (photo) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(File(photo.path), width: 72, height: 72, fit: BoxFit.cover),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: GestureDetector(
                            onTap: () => setState(() => _photos.remove(photo)),
                            child: const CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.black54,
                              child: Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_photos.length < 10)
                    IconButton.filledTonal(onPressed: _addPhoto, icon: const Icon(Icons.add_a_photo_outlined)),
                ],
              ),
              const SizedBox(height: 16),
              Text('محضر الشرطة (اختياري)', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              if (_policeReport != null)
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(_policeReport!.path), width: 72, height: 72, fit: BoxFit.cover),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _policeReport = null),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                )
              else
                OutlinedButton.icon(
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('إرفاق صورة المحضر'),
                  onPressed: _addPoliceReport,
                ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitting ? null : () => _submit(vehicle.id),
                child: _submitting
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('إرسال البلاغ'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('تعذر تحميل بيانات المركبة: $error')),
      ),
    );
  }

  Future<void> _pickOccurredAt() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_occurredAt));

    if (time == null) return;

    setState(() {
      _occurredAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _captureLocation() async {
    setState(() => _locating = true);

    try {
      final position = await Geolocator.getCurrentPosition();

      if (mounted) {
        setState(() {
          _lat = position.latitude;
          _lng = position.longitude;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحديد الموقع: $error')));
      }
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }

  Future<void> _addPhoto() async {
    final source = await _pickSource();

    if (source == null) return;

    final photo = await _picker.pickImage(source: source, imageQuality: 80);

    if (photo != null && mounted) {
      setState(() => _photos.add(photo));
    }
  }

  Future<void> _addPoliceReport() async {
    final source = await _pickSource();

    if (source == null) return;

    final photo = await _picker.pickImage(source: source, imageQuality: 80);

    if (photo != null && mounted) {
      setState(() => _policeReport = photo);
    }
  }

  Future<ImageSource?> _pickSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('الكاميرا'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('معرض الصور'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(int vehicleId) async {
    final driverId = ref.read(authControllerProvider).user?.driverId;

    if (driverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر تحديد حساب السائق')));
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('وصف الحادث مطلوب')));
      return;
    }

    final costText = _costController.text.trim();
    final estimatedCost = costText.isEmpty ? null : double.tryParse(costText);

    if (costText.isNotEmpty && estimatedCost == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('التكلفة التقديرية غير صالحة')));
      return;
    }

    setState(() => _submitting = true);

    try {
      await ref.read(accidentsApiProvider).create(
            vehicleId: vehicleId,
            driverId: driverId,
            tripId: _tripId,
            occurredAt: _occurredAt,
            locationAddress: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
            lat: _lat,
            lng: _lng,
            description: _descriptionController.text.trim(),
            damageDescription: _damageController.text.trim().isEmpty ? null : _damageController.text.trim(),
            thirdPartyNote: _thirdPartyController.text.trim().isEmpty ? null : _thirdPartyController.text.trim(),
            estimatedCost: estimatedCost,
            photoPaths: _photos.map((photo) => photo.path).toList(),
            policeReportPath: _policeReport?.path,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال البلاغ بنجاح')));
        context.pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إرسال البلاغ: $error')));
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');

    return '${local.year}-$m-$d $h:$min';
  }
}

class _NoVehicleAssigned extends StatelessWidget {
  const _NoVehicleAssigned();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'لا توجد مركبة معيّنة لحسابك حاليًا، لذا لا يمكن الإبلاغ عن حادث من هذا التطبيق. تواصل مع الإدارة.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
