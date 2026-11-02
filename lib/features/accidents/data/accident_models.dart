/// Mirrors `AccidentResource` (backend/app/Http/Resources/Api/V1/AccidentResource.php)
/// field-for-field. This app only ever creates/reads a driver's OWN
/// accidents (see `AccidentPolicy` — a driver account has no
/// `accidents.edit`, so `status`/`estimated_cost` here are always
/// office/management-set values a driver can view but never change from
/// this app).
class Accident {
  const Accident({
    required this.id,
    required this.vehicleId,
    required this.driverId,
    required this.description,
    required this.status,
    this.tripId,
    this.occurredAt,
    this.locationAddress,
    this.lat,
    this.lng,
    this.damageDescription,
    this.policeReportUrl,
    this.photos = const [],
    this.estimatedCost,
    this.createdAt,
  });

  factory Accident.fromJson(Map<String, dynamic> json) {
    return Accident(
      id: json['id'] as int,
      vehicleId: json['vehicle_id'] as int,
      driverId: json['driver_id'] as int,
      tripId: json['trip_id'] as int?,
      occurredAt: _parseDate(json['occurred_at']),
      locationAddress: json['location_address'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      description: json['description'] as String? ?? '',
      damageDescription: json['damage_description'] as String?,
      policeReportUrl: json['police_report_url'] as String?,
      photos: (json['photos'] as List?)
              ?.map((e) => AccidentPhoto.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      estimatedCost: (json['estimated_cost'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'reported',
      createdAt: _parseDate(json['created_at']),
    );
  }

  final int id;
  final int vehicleId;
  final int driverId;
  final int? tripId;
  final DateTime? occurredAt;
  final String? locationAddress;
  final double? lat;
  final double? lng;
  final String description;
  final String? damageDescription;
  final String? policeReportUrl;
  final List<AccidentPhoto> photos;
  final double? estimatedCost;
  final String status;
  final DateTime? createdAt;

  static const statusLabels = {
    'reported': 'تم الإبلاغ',
    'under_review': 'قيد المراجعة',
    'resolved': 'تمت التسوية',
  };

  String get statusLabel => statusLabels[status] ?? status;
}

class AccidentPhoto {
  const AccidentPhoto({required this.downloadUrl, this.mimeType});

  factory AccidentPhoto.fromJson(Map<String, dynamic> json) {
    return AccidentPhoto(
      downloadUrl: json['download_url'] as String? ?? '',
      mimeType: json['mime_type'] as String?,
    );
  }

  final String downloadUrl;
  final String? mimeType;
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;

  return DateTime.tryParse(value as String);
}
