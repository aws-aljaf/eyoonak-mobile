/// A read-only subset of VehicleResource — the driver app only ever
/// displays its own assigned vehicle, never edits it (module 26:
/// "read-only لمعلومات المركبة الحالية").
class VehicleInfo {
  const VehicleInfo({
    required this.id,
    required this.plateNumber,
    this.brand,
    this.model,
    this.color,
    this.currentMileage,
  });

  factory VehicleInfo.fromJson(Map<String, dynamic> json) {
    return VehicleInfo(
      id: json['id'] as int,
      plateNumber: json['plate_number'] as String? ?? '',
      brand: json['brand'] as String?,
      model: json['model'] as String?,
      color: json['color'] as String?,
      currentMileage: json['current_mileage'] as int?,
    );
  }

  final int id;
  final String plateNumber;
  final String? brand;
  final String? model;
  final String? color;
  final int? currentMileage;
}
