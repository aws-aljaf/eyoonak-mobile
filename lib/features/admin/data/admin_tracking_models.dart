/// Parses `VehicleLiveLocationResource`
/// (backend/app/Http/Resources/Api/V1/VehicleLiveLocationResource.php) —
/// verified directly against that resource before building this. Its own
/// docblock says it deliberately excludes every non-tracking vehicle field
/// (VIN, documents, mileage, ...) — the live map only ever needs identity
/// + position + status — so this model stays intentionally smaller than
/// `AdminVehicle` rather than reusing it.
class AdminVehicleLocation {
  const AdminVehicleLocation({
    required this.vehicleId,
    this.plateNumber = '',
    this.status,
    this.currentDriverId,
    this.lat,
    this.lng,
    this.lastLocationAt,
  });

  factory AdminVehicleLocation.fromJson(Map<String, dynamic> json) {
    return AdminVehicleLocation(
      vehicleId: json['vehicle_id'] as int,
      plateNumber: json['plate_number'] as String? ?? '',
      status: json['status'] as String?,
      currentDriverId: json['current_driver_id'] as int?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      lastLocationAt: json['last_location_at'] != null ? DateTime.tryParse(json['last_location_at'] as String) : null,
    );
  }

  final int vehicleId;
  final String plateNumber;
  final String? status;
  final int? currentDriverId;
  final double? lat;
  final double? lng;
  final DateTime? lastLocationAt;
}
