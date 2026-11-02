/// Full admin-facing view of `VehicleResource` — deliberately a separate
/// model from `features/vehicles/data/vehicle_models.dart`'s `VehicleInfo`
/// (that one stays the driver's own read-only "my current vehicle" subset,
/// module 26). This one is for the office/fleet-management RBAC audience
/// (`vehicles.view`) reached via `AdminHomeScreen`, so it carries every
/// field `VehicleResource` returns, including the ones a driver never
/// needs to see about their own vehicle (VIN, engine/chassis numbers,
/// expiry dates, last known location).
///
/// `vehicleTypeId`/`currentDriverId` (the raw foreign keys, alongside the
/// already-present display-only `vehicleTypeName`/`currentDriverName`)
/// were added for the write half of this feature (`vehicles.create`/
/// `edit`/`delete` + driver assignment) — `AdminVehicleFormScreen` needs
/// the actual id to pre-select the right dropdown entry when editing, not
/// just a label to display.
class AdminVehicle {
  const AdminVehicle({
    required this.id,
    this.branchId,
    this.vehicleTypeId,
    this.vehicleTypeName,
    this.plateNumber = '',
    this.plateGovernorate,
    this.brand,
    this.model,
    this.year,
    this.color,
    this.vin,
    this.engineNumber,
    this.chassisNumber,
    this.fuelType,
    this.tankCapacityLiters,
    this.currentMileage,
    this.currentDriverId,
    this.currentDriverName,
    this.status,
    this.insuranceExpiryDate,
    this.registrationExpiryDate,
    this.licenseExpiryDate,
    this.inspectionExpiryDate,
    this.lastKnownLat,
    this.lastKnownLng,
    this.lastLocationAt,
    this.createdAt,
  });

  factory AdminVehicle.fromJson(Map<String, dynamic> json) {
    // `vehicle_type`/`current_driver` are `whenLoaded()` on the backend
    // resource — present as a populated object when eager-loaded (index
    // and show both eager-load them today), otherwise an empty array
    // `[]` rather than `null` (Laravel's `JsonResource::whenLoaded`
    // default) — never assume either is a non-empty Map.
    final vehicleType = json['vehicle_type'];
    final currentDriver = json['current_driver'];

    return AdminVehicle(
      id: json['id'] as int,
      branchId: json['branch_id'] as int?,
      vehicleTypeId: json['vehicle_type_id'] as int?,
      vehicleTypeName: vehicleType is Map ? (vehicleType['name_ar'] ?? vehicleType['name']) as String? : null,
      plateNumber: json['plate_number'] as String? ?? '',
      plateGovernorate: json['plate_governorate'] as String?,
      brand: json['brand'] as String?,
      model: json['model'] as String?,
      year: json['year'] as int?,
      color: json['color'] as String?,
      vin: json['vin'] as String?,
      engineNumber: json['engine_number'] as String?,
      chassisNumber: json['chassis_number'] as String?,
      fuelType: json['fuel_type'] as String?,
      tankCapacityLiters: json['tank_capacity_liters'] as int?,
      currentMileage: json['current_mileage'] as int?,
      currentDriverId: json['current_driver_id'] as int?,
      currentDriverName: currentDriver is Map ? currentDriver['full_name'] as String? : null,
      status: json['status'] as String?,
      insuranceExpiryDate: json['insurance_expiry_date'] as String?,
      registrationExpiryDate: json['registration_expiry_date'] as String?,
      licenseExpiryDate: json['license_expiry_date'] as String?,
      inspectionExpiryDate: json['inspection_expiry_date'] as String?,
      lastKnownLat: (json['last_known_lat'] as num?)?.toDouble(),
      lastKnownLng: (json['last_known_lng'] as num?)?.toDouble(),
      lastLocationAt: json['last_location_at'] != null ? DateTime.tryParse(json['last_location_at'] as String) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  final int id;
  final int? branchId;
  final int? vehicleTypeId;
  final String? vehicleTypeName;
  final String plateNumber;
  final String? plateGovernorate;
  final String? brand;
  final String? model;
  final int? year;
  final String? color;
  final String? vin;
  final String? engineNumber;
  final String? chassisNumber;
  final String? fuelType;
  final int? tankCapacityLiters;
  final int? currentMileage;
  final int? currentDriverId;
  final String? currentDriverName;
  final String? status;
  // Kept as raw `YYYY-MM-DD` strings, same reasoning as
  // `AuditLog.modelType`-adjacent fields elsewhere in this app: these are
  // display-only here (no date arithmetic done on them), so there is no
  // reason to parse into `DateTime` and immediately reformat back.
  final String? insuranceExpiryDate;
  final String? registrationExpiryDate;
  final String? licenseExpiryDate;
  final String? inspectionExpiryDate;
  final double? lastKnownLat;
  final double? lastKnownLng;
  final DateTime? lastLocationAt;
  final DateTime? createdAt;

  String get displayName => [brand, model].where((s) => s != null && s.isNotEmpty).join(' ');
}

/// Mirrors `StoreVehicleRequest`/`UpdateVehicleRequest`'s `status` enum
/// exactly (`backend/app/Http/Requests/Api/V1/Vehicle/*VehicleRequest.php`)
/// — used both to render a readable Arabic label for `AdminVehicle.status`
/// and to drive the status filter chips on `AdminVehiclesScreen`.
const Map<String, String> vehicleStatusLabels = {
  'active': 'نشطة',
  'moving': 'متحركة',
  'idle': 'متوقفة',
  'maintenance': 'صيانة',
  'out_of_service': 'خارج الخدمة',
};
