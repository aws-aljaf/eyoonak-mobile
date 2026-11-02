/// Mirrors `VehicleTypeResource`
/// (backend/app/Http/Resources/Api/V1/VehicleTypeResource.php), verified
/// directly against that resource and `VehicleTypePolicy` before building
/// this. Used solely to populate the vehicle-type dropdown on
/// `AdminVehicleFormScreen` — `VehicleType` is deliberately NOT
/// company-scoped (system-wide defaults with `company_id == null` sit
/// alongside a company's own custom types, per that model's own docblock),
/// so `isSystemDefault` is kept here even though the form itself doesn't
/// need to distinguish them (both are equally selectable — `viewAny`/`view`
/// only require `vehicles.view`, same permission that already gates this
/// whole screen).
class AdminVehicleType {
  const AdminVehicleType({required this.id, this.name, this.nameAr, this.isSystemDefault = false});

  factory AdminVehicleType.fromJson(Map<String, dynamic> json) {
    return AdminVehicleType(
      id: json['id'] as int,
      name: json['name'] as String?,
      nameAr: json['name_ar'] as String?,
      isSystemDefault: json['is_system_default'] as bool? ?? false,
    );
  }

  final int id;
  final String? name;
  final String? nameAr;
  final bool isSystemDefault;

  String get displayName => nameAr ?? name ?? '#$id';
}
