/// Full admin-facing view of `DriverResource`
/// (backend/app/Http/Resources/Api/V1/DriverResource.php), verified
/// directly against that resource before building this — reached only by
/// an account with `drivers.view` via `AdminHomeScreen`'s "السائقون" tile.
/// Distinct from the driver's own self-service profile screens elsewhere
/// in this app (`features/drivers/data/driver_profile.dart`), same
/// separation `AdminVehicle` keeps from `VehicleInfo`.
class AdminDriver {
  const AdminDriver({
    required this.id,
    this.branchId,
    this.fullName = '',
    this.phone,
    this.nationalId,
    this.governorate,
    this.address,
    this.birthDate,
    this.licenseNumber,
    this.licenseType,
    this.licenseExpiryDate,
    this.hireDate,
    this.salary,
    this.status,
    this.currentVehicleId,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.performanceScore,
    this.createdAt,
  });

  factory AdminDriver.fromJson(Map<String, dynamic> json) {
    return AdminDriver(
      id: json['id'] as int,
      branchId: json['branch_id'] as int?,
      fullName: json['full_name'] as String? ?? '',
      phone: json['phone'] as String?,
      nationalId: json['national_id'] as String?,
      governorate: json['governorate'] as String?,
      address: json['address'] as String?,
      birthDate: json['birth_date'] as String?,
      licenseNumber: json['license_number'] as String?,
      licenseType: json['license_type'] as String?,
      licenseExpiryDate: json['license_expiry_date'] as String?,
      hireDate: json['hire_date'] as String?,
      salary: (json['salary'] as num?)?.toDouble(),
      status: json['status'] as String?,
      currentVehicleId: json['current_vehicle_id'] as int?,
      emergencyContactName: json['emergency_contact_name'] as String?,
      emergencyContactPhone: json['emergency_contact_phone'] as String?,
      performanceScore: (json['performance_score'] as num?)?.toDouble(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  final int id;
  final int? branchId;
  final String fullName;
  final String? phone;
  final String? nationalId;
  final String? governorate;
  final String? address;
  // Raw `YYYY-MM-DD` strings — display-only here, same reasoning as
  // `AdminVehicle`'s expiry-date fields.
  final String? birthDate;
  final String? licenseNumber;
  final String? licenseType;
  final String? licenseExpiryDate;
  final String? hireDate;
  final double? salary;
  final String? status;
  final int? currentVehicleId;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final double? performanceScore;
  final DateTime? createdAt;
}

/// Mirrors `StoreDriverRequest`/`UpdateDriverRequest`'s `status` enum
/// exactly (`backend/app/Http/Requests/Api/V1/Driver/*DriverRequest.php`).
const Map<String, String> driverStatusLabels = {
  'active': 'نشط',
  'suspended': 'موقوف',
  'terminated': 'منتهي الخدمة',
};
