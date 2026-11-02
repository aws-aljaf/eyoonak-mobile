/// Mirrors `ReportExportResource`
/// (backend/app/Http/Resources/Api/V1/ReportExportResource.php), verified
/// directly against that resource and `ReportExport` (the model it wraps,
/// `app/Models/ReportExport.php`) before building this — same discipline as
/// every other admin data model in this feature.
///
/// `downloadUrl` is `null` for anything not yet `completed` — the resource
/// itself only mints it `when($this->status === 'completed' &&
/// $this->file_uuid, ...)`, so this model never needs its own "is this
/// ready" guess; a non-null `downloadUrl` *is* the "ready" signal.
class AdminReportExport {
  const AdminReportExport({
    required this.id,
    required this.type,
    required this.format,
    required this.status,
    required this.filters,
    this.errorMessage,
    this.downloadUrl,
    this.completedAt,
    required this.createdAt,
  });

  factory AdminReportExport.fromJson(Map<String, dynamic> json) {
    return AdminReportExport(
      id: json['id'] as int,
      type: json['type'] as String,
      format: json['format'] as String,
      status: json['status'] as String,
      filters: Map<String, dynamic>.from(json['filters'] as Map? ?? const {}),
      errorMessage: json['error_message'] as String?,
      downloadUrl: json['download_url'] as String?,
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at'] as String) : null,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  final int id;
  final String type;
  final String format;
  final String status;
  final Map<String, dynamic> filters;
  final String? errorMessage;
  final String? downloadUrl;
  final DateTime? completedAt;
  final DateTime createdAt;

  bool get isReady => status == 'completed' && downloadUrl != null;
}

/// `ReportExport::FORMATS` — same static-list convention as
/// `adminReportTypeLabels` (no backend "list valid formats" endpoint to
/// read this from). The download file extension for each is handled
/// separately in `AdminReportExportsApi.download()` (`excel` -> `.xlsx`,
/// the two don't share spelling).
const Map<String, String> adminReportExportFormatLabels = {
  'csv': 'CSV',
  'pdf': 'PDF',
  'excel': 'Excel',
};

/// `ReportExport::STATUSES`.
const Map<String, String> adminReportExportStatusLabels = {
  'pending': 'قيد الانتظار',
  'processing': 'قيد المعالجة',
  'completed': 'مكتمل',
  'failed': 'فشل',
};
