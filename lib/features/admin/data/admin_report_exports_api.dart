import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';
import 'admin_report_export_models.dart';

/// Talks to `POST /reports/export` + `GET /reports/exports[/{id}]`
/// (`ReportController::export()`/`::exportsIndex()`/`::exportsShow()`,
/// backend/app/Http/Controllers/Api/V1/Reports/ReportController.php),
/// verified directly against that controller — plus `ExportReportRequest`
/// (validation), `ReportExport` (the model), and `ReportExportPolicy`
/// (who may view one specific row) — before building this.
///
/// This is the "produce a file" half `AdminReportsApi`'s docblock left for
/// a follow-up: **`POST /reports/export` is gated by `permission:
/// reports.export`**, a *separate* permission from the `reports.view` that
/// gates the six read endpoints — someone can view reports without being
/// allowed to export them. Unlike every other admin feature in this app
/// (where one permission gates one whole screen, checked only at the entry
/// point), that means the export action itself needs its own
/// `permissions.contains('reports.export')` check inside `AdminReportsScreen`
/// (which otherwise has "no permission gate of its own"), not just at
/// `AdminHomeScreen`.
class AdminReportExportsApi {
  AdminReportExportsApi(this._client);

  final ApiClient _client;

  Future<AdminReportExport> create({
    required String type,
    required String format,
    DateTime? from,
    DateTime? to,
  }) async {
    final data = await _client.post('/reports/export', data: {
      'type': type,
      'format': format,
      if (from != null) 'from': _formatDate(from),
      if (to != null) 'to': _formatDate(to),
    });

    return AdminReportExport.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<ApiEnvelope> index({int page = 1}) {
    return _client.getPaginated('/reports/exports', query: {'page': page});
  }

  Future<AdminReportExport> show(int id) async {
    final data = await _client.get('/reports/exports/$id');

    return AdminReportExport.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Downloads a completed export's file to a local temp path and hands
  /// back the `File` — the caller (`AdminReportExportsScreen`) then opens
  /// the OS share sheet on it. Goes through `ApiClient.downloadBytes()`,
  /// **never** a bare `url_launcher` open of `export.downloadUrl` — see
  /// that method's own docblock for why a plain external-browser open
  /// doesn't work for this route (the same fix later applied to every
  /// other signed download in this app — `DriversApi.downloadDocument()`/
  /// `AccidentsApi.downloadFile()`).
  Future<File> download(AdminReportExport export) async {
    assert(export.isReady, 'download() called on an export that is not completed yet');

    final bytes = await _client.downloadBytes(export.downloadUrl!);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/report-${export.type}-${export.id}.${_extensionFor(export.format)}');

    return file.writeAsBytes(bytes, flush: true);
  }

  // 'excel' doesn't share its own spelling with the file extension it
  // produces (backend/app/Services/Reports/Export/ReportExporter.php writes
  // it as .xlsx) — csv/pdf do.
  String _extensionFor(String format) {
    return format == 'excel' ? 'xlsx' : format;
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');

    return '$y-$m-$d';
  }
}
