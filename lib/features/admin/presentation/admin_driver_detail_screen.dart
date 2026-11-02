import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../application/admin_drivers_providers.dart';
import '../data/admin_driver_models.dart';

/// Full detail view for one driver — reached only by tapping a row on
/// `AdminDriversScreen`, which already required `drivers.view` to load at
/// all, so (same "the request is the gate" convention as every other
/// screen in this app) this screen has no permission gate of its own
/// either for *viewing*; `DriverController::show()`/`DriverPolicy::view()`
/// are what actually enforce it server-side.
///
/// The edit/delete actions in the app bar are the exception: `drivers.edit`/
/// `drivers.delete` are separate permissions from `drivers.view` (verified
/// directly against `DriverPolicy` before building this), so each action
/// checks `permissions.contains(...)` itself — same pattern
/// `AdminVehicleDetailScreen` established. There is no dedicated
/// suspend/reactivate action here (unlike `AdminUserDetailScreen`) —
/// verified directly that `DriverController` has no such endpoint; a
/// status change goes through "تعديل" like any other field.
///
/// Delete's confirmation dialog used to warn about two real backend gaps
/// documented in `AdminDriversApi`'s own docblock — a dangling vehicle
/// assignment and a linked user's tokens staying live after delete. Both
/// are now closed server-side (`DriverController::destroy()` calls
/// `releaseCurrentVehicleAssignment()`/`revokeDriverAccountAccess()`), so
/// the dialog below only surfaces a plain informational note when a
/// vehicle is assigned (the assignment really is released on delete now),
/// not a warning about an unfixed gap.
class AdminDriverDetailScreen extends ConsumerWidget {
  const AdminDriverDetailScreen({super.key, required this.driverId});

  final int driverId;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, AdminDriver driver) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف السائق'),
        content: Text(
          [
            'هل أنت متأكد من حذف السائق "${driver.fullName}"؟ لا يمكن التراجع عن هذا الإجراء من هذا التطبيق.',
            if (driver.currentVehicleId != null)
              'ملاحظة: هذا السائق معيَّن حاليًا للمركبة رقم #${driver.currentVehicleId} — سيُلغى هذا التعيين تلقائيًا عند الحذف.',
          ].join('\n\n'),
        ),
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
      await ref.read(adminDriversApiProvider).delete(driverId);
      ref.invalidate(adminDriversProvider);

      if (context.mounted) {
        context.pop();
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حذف السائق: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driverAsync = ref.watch(adminDriverDetailProvider(driverId));
    final permissions = ref.watch(authControllerProvider).user?.permissions ?? const [];
    final canEdit = permissions.contains('drivers.edit');
    final canDelete = permissions.contains('drivers.delete');

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل السائق'),
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'تعديل',
              onPressed: () async {
                final driver = driverAsync.valueOrNull;
                if (driver == null) {
                  return;
                }

                final updated = await context.push<bool>('/admin/drivers/$driverId/edit', extra: driver);

                if (updated == true) {
                  ref.invalidate(adminDriverDetailProvider(driverId));
                }
              },
            ),
          if (canDelete)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'حذف',
              onPressed: () {
                final driver = driverAsync.valueOrNull;
                if (driver != null) {
                  _confirmDelete(context, ref, driver);
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: () => ref.invalidate(adminDriverDetailProvider(driverId)),
          ),
        ],
      ),
      body: driverAsync.when(
        data: (driver) => _DetailBody(driver: driver),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(adminDriverDetailProvider(driverId)),
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.driver});

  final AdminDriver driver;

  @override
  Widget build(BuildContext context) {
    final statusLabel = driver.status != null ? driverStatusLabels[driver.status] ?? driver.status! : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(driver.fullName, style: Theme.of(context).textTheme.headlineSmall),
            ),
            if (statusLabel != null) Chip(label: Text(statusLabel)),
          ],
        ),
        if (driver.phone != null) ...[
          const SizedBox(height: 4),
          Text(driver.phone!, style: Theme.of(context).textTheme.titleMedium),
        ],
        const SizedBox(height: 16),
        _Section(
          title: 'البيانات الشخصية',
          rows: [
            if (driver.nationalId != null) _row('رقم الهوية', driver.nationalId!),
            if (driver.governorate != null) _row('المحافظة', driver.governorate!),
            if (driver.address != null) _row('العنوان', driver.address!),
            if (driver.birthDate != null) _row('تاريخ الميلاد', driver.birthDate!),
          ],
        ),
        _Section(
          title: 'الرخصة والعمل',
          rows: [
            if (driver.licenseNumber != null) _row('رقم الرخصة', driver.licenseNumber!),
            if (driver.licenseType != null) _row('نوع الرخصة', driver.licenseType!),
            if (driver.licenseExpiryDate != null) _row('انتهاء الرخصة', driver.licenseExpiryDate!),
            if (driver.hireDate != null) _row('تاريخ التعيين', driver.hireDate!),
            if (driver.currentVehicleId != null) _row('المركبة الحالية', '#${driver.currentVehicleId}'),
            if (driver.performanceScore != null) _row('تقييم الأداء', driver.performanceScore!.toStringAsFixed(1)),
          ],
        ),
        if (driver.emergencyContactName != null || driver.emergencyContactPhone != null)
          _Section(
            title: 'جهة اتصال الطوارئ',
            rows: [
              if (driver.emergencyContactName != null) _row('الاسم', driver.emergencyContactName!),
              if (driver.emergencyContactPhone != null) _row('الهاتف', driver.emergencyContactPhone!),
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
                  Text('تعذر تحميل بيانات السائق: $message', textAlign: TextAlign.center),
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
