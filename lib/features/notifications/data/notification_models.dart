/// Mirrors backend/app/Http/Resources/Api/V1/NotificationResource.php.
class DriverNotification {
  const DriverNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    this.createdAt,
    this.destination,
    this.familyId,
  });

  factory DriverNotification.fromJson(Map<String, dynamic> json) {
    return DriverNotification(
      id: json['id'] as int,
      destination: json['destination'] as String?,
      familyId: json['family_id'] as int?,
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  final int id;
  final String? destination;
  final int? familyId;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime? createdAt;
}
