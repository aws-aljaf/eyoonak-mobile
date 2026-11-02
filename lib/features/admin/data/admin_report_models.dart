/// Mirrors the single shared shape returned by every method on
/// `ReportDataService` (backend/app/Services/Reports/ReportDataService.php)
/// — verified directly against that service's own docblock before
/// building this: `{type, generated_at, filters, summary, columns, rows}`,
/// identical across all six report types (`fleet`/`drivers`/`trips`/
/// `fuel`/`maintenance`/`financial`). One model + one generic renderer
/// covers all six, instead of six bespoke ones — `ReportController`
/// itself is built the same way (`forType()` dispatches by string, one
/// `success()` response shape for every action).
///
/// `summary` is a flat "Arabic label => value" map meant for a row of stat
/// tiles; `columns` maps each `rows` entry's key to its Arabic header;
/// `rows` is the detail table, one loosely-typed map per row (values are
/// already display-ready — strings, numbers, or `null` rendered as "—" —
/// exactly what the backend service itself hands to the CSV/PDF/Excel
/// exporters, so this model never needs to know each report's specific
/// column set).
class AdminReport {
  const AdminReport({
    required this.type,
    required this.generatedAt,
    required this.filterFrom,
    required this.filterTo,
    required this.summary,
    required this.columns,
    required this.rows,
  });

  factory AdminReport.fromJson(Map<String, dynamic> json) {
    final filters = json['filters'] as Map? ?? const {};
    final columns = json['columns'] as Map? ?? const {};
    final rows = (json['rows'] as List? ?? const []).cast<Map>();

    return AdminReport(
      type: json['type'] as String,
      generatedAt: json['generated_at'] != null ? DateTime.tryParse(json['generated_at'] as String) : null,
      filterFrom: filters['from'] as String?,
      filterTo: filters['to'] as String?,
      summary: Map<String, dynamic>.from(json['summary'] as Map? ?? const {}),
      columns: columns.map((key, value) => MapEntry(key as String, value as String)),
      rows: rows.map((row) => Map<String, dynamic>.from(row)).toList(),
    );
  }

  final String type;
  final DateTime? generatedAt;
  final String? filterFrom;
  final String? filterTo;
  final Map<String, dynamic> summary;
  final Map<String, String> columns;
  final List<Map<String, dynamic>> rows;
}

/// The six report types `ReportController`/`ReportDataService` support,
/// paired with their Arabic tile labels — a static list, same pattern as
/// `tripStatusLabels`/`permissionModuleLabels` elsewhere in this app,
/// because the backend has no "list valid report types" endpoint to read
/// this from dynamically.
const Map<String, String> adminReportTypeLabels = {
  'fleet': 'الأسطول',
  'drivers': 'السائقون',
  'trips': 'الرحلات',
  'fuel': 'الوقود',
  'maintenance': 'الصيانة',
  'financial': 'المالية',
};
