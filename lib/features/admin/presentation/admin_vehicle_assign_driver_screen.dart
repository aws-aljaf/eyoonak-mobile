import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../application/admin_vehicles_providers.dart';
import '../data/admin_driver_models.dart';

/// "تعيين سائق" — `VehicleController::assignDriver()` (gated on
/// `VehiclePolicy::manageDocuments()`, i.e. `vehicles.edit` — verified
/// directly against `AssignDriverRequest`/`VehiclePolicy` before building
/// this), reached only from `AdminVehicleDetailScreen`'s own action (itself
/// gated on `vehicles.edit`), so this screen carries no permission gate of
/// its own either.
///
/// A plain search-and-tap picker rather than a full paginated list screen
/// like `AdminDriversScreen` — assigning a driver is a one-shot pick, not
/// something a user browses page by page, and `DriverController::index()`'s
/// own `q` (name/phone) search already narrows a large roster down to a
/// handful of rows without needing `_PagerBar` here too.
class AdminVehicleAssignDriverScreen extends ConsumerStatefulWidget {
  const AdminVehicleAssignDriverScreen({super.key, required this.vehicleId, this.currentDriverId});

  final int vehicleId;
  final int? currentDriverId;

  @override
  ConsumerState<AdminVehicleAssignDriverScreen> createState() => _AdminVehicleAssignDriverScreenState();
}

class _AdminVehicleAssignDriverScreenState extends ConsumerState<AdminVehicleAssignDriverScreen> {
  final _searchController = TextEditingController();
  List<AdminDriver> _drivers = const [];
  bool _loading = true;
  bool _assigning = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({String? q}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final envelope = await ref.read(adminDriversApiProvider).index(q: q, perPage: 50);
      final drivers = envelope.data.map((e) => AdminDriver.fromJson(Map<String, dynamic>.from(e as Map))).toList();

      if (mounted) {
        setState(() {
          _drivers = drivers;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _assign(int? driverId) async {
    setState(() => _assigning = true);

    try {
      await ref.read(adminVehiclesApiProvider).assignDriver(widget.vehicleId, driverId);
      ref.invalidate(adminVehicleDetailProvider(widget.vehicleId));
      ref.invalidate(adminVehiclesProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _assigning = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحديث سائق المركبة: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تعيين سائق')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'بحث بالاسم أو الهاتف',
                isDense: true,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'بحث',
                  onPressed: () => _load(q: _searchController.text.trim().isEmpty ? null : _searchController.text.trim()),
                ),
              ),
              onSubmitted: (value) => _load(q: value.trim().isEmpty ? null : value.trim()),
            ),
          ),
          if (widget.currentDriverId != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _assigning ? null : () => _assign(null),
                  icon: const Icon(Icons.person_off_outlined),
                  label: const Text('إلغاء تعيين السائق الحالي'),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text('تعذر تحميل قائمة السائقين: $_error', textAlign: TextAlign.center));
    }

    if (_drivers.isEmpty) {
      return const Center(child: Text('لا يوجد سائقون مطابقون.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: _drivers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final driver = _drivers[index];
        final isCurrent = driver.id == widget.currentDriverId;

        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text(driver.fullName),
            subtitle: Text(driver.phone ?? '—'),
            trailing: isCurrent ? const Chip(label: Text('الحالي'), visualDensity: VisualDensity.compact) : null,
            enabled: !_assigning && !isCurrent,
            onTap: isCurrent ? null : () => _assign(driver.id),
          ),
        );
      },
    );
  }
}
