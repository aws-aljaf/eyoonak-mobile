/// A read-only subset of DriverResource for the driver's own profile
/// screen (module 31).
class DriverProfile {
  const DriverProfile({
    required this.id,
    required this.fullName,
    this.phone,
    this.licenseNumber,
    this.licenseExpiryDate,
    this.performanceScore,
    this.currentVehicleId,
  });

  factory DriverProfile.fromJson(Map<String, dynamic> json) {
    return DriverProfile(
      id: json['id'] as int,
      fullName: json['full_name'] as String? ?? '',
      phone: json['phone'] as String?,
      licenseNumber: json['license_number'] as String?,
      licenseExpiryDate:
          json['license_expiry_date'] != null ? DateTime.tryParse(json['license_expiry_date'] as String) : null,
      performanceScore: json['performance_score'] as int?,
      // Added for the accident self-report screen (module 23): the only
      // vehicle this app can safely pre-fill `vehicle_id` with, since
      // `VehiclesApi` has no `index()` — a driver account has no way to
      // browse/pick from the company's other vehicles from this app at
      // all (see AccidentsApi's docblock for why that's the deliberate
      // scope here, not a gap).
      currentVehicleId: json['current_vehicle_id'] as int?,
    );
  }

  final int id;
  final String fullName;
  final String? phone;
  final String? licenseNumber;
  final DateTime? licenseExpiryDate;
  final int? performanceScore;
  final int? currentVehicleId;
}
