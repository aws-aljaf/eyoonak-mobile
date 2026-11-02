import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../application/admin_vehicles_providers.dart';
import '../data/admin_vehicle_models.dart';

/// Full detail view for one vehicle — reached only by tapping a row on
/// `AdminVehiclesScreen`, which already required `vehicles.view` to load at
/// all, so (same "the request is the gate" convention as every other
/// screen in this app) this screen has no permission gate of its own
/// either for *viewing*; `VehicleController::show()`/`VehiclePolicy::view()`
/// are what actually enforce it server-side.
///
/// The edit/delete/assign-driver actions in the app bar are the exception:
/// `vehicles.edit`/`vehicles.delete` are separate permissions from
/// `vehicles.view` (verified directly against `VehiclePolicy` before
/// building this), so each action checks `permissions.contains(...)`
/// itself — same pattern established by `AdminReportsScreen`'s "تصدير"
/// action and `AdminVehiclesScreen`'s "+" FAB.
class AdminVehicleDetailScreen extends ConsumerWidget {
  const AdminVehicleDetailScreen({super.key, required this.vehicleId});

  final int vehicleId;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, AdminVehicle vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف المركبة'),
        content: Text('هل أنت متأكد من حذف المركبة "${vehicle.plateNumber}"؟ لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      await ref.read(adminVehiclesApiProvider).delete(vehicleId);
      ref.invalidate(adminVehiclesProvider);

      if (context.mounted) {
        context.pop();
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حذف المركبة: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleAsync = ref.watch(adminVehicleDetailProvider(vehicleId));
    final permissions = ref.watch(authControllerProvider).user?.permissions ?? const [];
    final canEdit = permissions.contains('vehicles.edit');
    final canDelete = permissions.contains('vehicles.delete');

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل المركبة'),
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.person_search_outlined),
              tooltip: 'تعيين سائق',
              onPressed: () async {
                final vehicle = vehicleAsync.valueOrNull;
                if (vehicle == null) {
                  return;
                }

                final assigned = await context.push<bool>(
                  '/admin/vehicles/$vehicleId/assign-driver?currentDriverId=${vehicle.currentDriverId ?? ''}',
                );

                if (assigned == true) {
                  ref.invalidate(adminVehicleDetailProvider(vehicleId));
                }
              },
            ),
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'تعديل',
              onPressed: () async {
                final vehicle = vehicleAsync.valueOrNull;
                if (vehicle == null) {
                  return;
                }

                final updated = await context.push<bool>('/admin/vehicles/$vehicleId/edit', extra: vehicle);

                if (updated == true) {
                  ref.invalidate(adminVehicleDetailProvider(vehicleId));
                }
              },
            ),
          if (canDelete)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'حذف',
              onPressed: () {
                final vehicle = vehicleAsync.valueOrNull;
                if (vehicle != null) {
                  _confirmDelete(context, ref, vehicle);
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: () => ref.invalidate(adminVehicleDetailProvider(vehicleId)),
          ),
        ],
      ),
      body: vehicleAsync.when(
        data: (vehicle) => _DetailBody(vehicle: vehicle),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(adminVehicleDetailProvider(vehicleId)),
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.vehicle});

  final AdminVehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final statusLabel = vehicle.status != null ? vehicleStatusLabels[vehicle.status] ?? vehicle.status! : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                vehicle.plateNumber,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            if (statusLabel != null) Chip(label: Text(statusLabel)),
          ],
        ),
        if (vehicle.displayName.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(vehicle.displayName, style: Theme.of(context).textTheme.titleMedium),
        ],
        const SizedBox(height: 16),
        _Section(
          title: 'البيانات الأساسية',
          rows: [
            if (vehicle.vehicleTypeName != null) _row('النوع', vehicle.vehicleTypeName!),
            if (vehicle.plateGovernorate != null) _row('محافظة اللوحة', vehicle.plateGovernorate!),
            if (vehicle.color != null) _row('اللون', vehicle.color!),
            if (vehicle.year != null) _row('سنة الصنع', vehicle.year!.toString()),
            if (vehicle.fuelType != null) _row('نوع الوقود', vehicle.fuelType!),
            if (vehicle.tankCapacityLiters != null) _row('سعة الخزان', '${vehicle.tankCapacityLiters} لتر'),
            if (vehicle.currentMileage != null) _row('العداد الحالي', '${vehicle.currentMileage} كم'),
          ],
        ),
        _Section(
          title: 'السائق',
          rows: [
            _row('السائق الحالي', vehicle.currentDriverName ?? 'بلا سائق حاليًا'),
          ],
        ),
        if (vehicle.vin != null || vehicle.engineNumber != null || vehicle.chassisNumber != null)
          _Section(
            title: 'أرقام تعريفية',
            rows: [
              if (vehicle.vin != null) _row('رقم الهيكل (VIN)', vehicle.vin!),
              if (vehicle.engineNumber != null) _row('رقم المحرك', vehicle.engineNumber!),
              if (vehicle.chassisNumber != null) _row('رقم الشاصي', vehicle.chassisNumber!),
            ],
          ),
        _Section(
          title: 'تواريخ الانتهاء',
          rows: [
            _row('التأمين', vehicle.insuranceExpiryDate ?? '—'),
            _row('التسجيل', vehicle.registrationExpiryDate ?? '—'),
            _row('الرخصة', vehicle.licenseExpiryDate ?? '—'),
            _row('الفحص الفني', vehicle.inspectionExpiryDate ?? '—'),
          ],
        ),
        if (vehicle.lastKnownLat != null && vehicle.lastKnownLng != null)
          _Section(
            title: 'آخر موقع معروف',
            rows: [
              _row('الإحداثيات', '${vehicle.lastKnownLat!.toStringAsFixed(5)}, ${vehicle.lastKnownLng!.toStringAsFixed(5)}'),
              if (vehicle.lastLocationAt != null) _row('وقت آخر تحديث', _formatTimestamp(vehicle.lastLocationAt!)),
            ],
          ),
      ],
    );
  }

  _DetailRow _row(String label, String value) => _DetailRow(label: label, value: value);
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});

  final String title;
  final List<_DetailRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 130, child: Text(row.label, style: const TextStyle(color: Colors.grey))),
                    Expanded(child: Text(row.value)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;
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
                  Text('تعذر تحميل بيانات المركبة: $message', textAlign: TextAlign.center),
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

String _formatTimestamp(DateTime dt) {
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');

  return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
}
