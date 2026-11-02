/// Mirrors `DriverDocumentResource`
/// (backend/app/Http/Resources/Api/V1/DriverDocumentResource.php) exactly
/// as returned by `GET /drivers/{driver}/documents`.
///
/// `downloadUrl` is a `URL::temporarySignedRoute` (see
/// `SecureFileService::signedUrl()`, 15 minutes) — **but not a plain,
/// unauthenticated link**: `GET /files/{uuid}` sits inside the backend's
/// `auth:sanctum` group in addition to requiring the signature (verified
/// directly against `routes/api_v1.php`/`SecureFileController`'s own
/// docblock — corrected here after that assumption was found wrong and
/// documented in `claude/admin-unification-plan.md`). Fetch it through
/// `DriversApi.downloadDocument()` (the app's authenticated Dio client),
/// never `url_launcher` directly. Nothing here fetches it eagerly; a
/// document is only ever resolved when the driver actually taps to open
/// it (see `DriverDocumentsScreen`), since a stale 15-minute-old link
/// fetched at list-load time could easily have expired by the time it's
/// tapped.
class DriverDocument {
  const DriverDocument({
    required this.id,
    required this.type,
    required this.mimeType,
    required this.sizeBytes,
    required this.expiryDate,
    required this.downloadUrl,
    required this.createdAt,
  });

  factory DriverDocument.fromJson(Map<String, dynamic> json) {
    return DriverDocument(
      id: json['id'] as int,
      type: json['type'] as String? ?? 'other',
      mimeType: json['mime_type'] as String?,
      sizeBytes: json['size_bytes'] as int?,
      expiryDate: json['expiry_date'] as String?,
      downloadUrl: json['download_url'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  final int id;
  final String type;
  final String? mimeType;
  final int? sizeBytes;
  final String? expiryDate;
  final String? downloadUrl;
  final String? createdAt;

  /// Matches `UploadDriverDocumentRequest`'s exact enum
  /// (`license, national_id, contract, other`) — a value outside that set
  /// can't reach this app (validated server-side on upload), but falls
  /// back to the raw string rather than throwing if the backend's enum
  /// ever grows ahead of this switch.
  String get typeLabel {
    switch (type) {
      case 'license':
        return 'رخصة القيادة';
      case 'national_id':
        return 'الهوية الوطنية';
      case 'contract':
        return 'العقد';
      case 'other':
        return 'أخرى';
      default:
        return type;
    }
  }
}
