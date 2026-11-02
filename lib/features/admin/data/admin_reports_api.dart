import '../../../core/network/api_client.dart';

/// Talks to `GET /reports/{type}` (`ReportController::fleet()`/`drivers()`/
/// `trips()`/`fuel()`/`maintenance()`/`financial()`,
/// backend/app/Http/Controllers/Api/V1/Reports/ReportController.php),
/// verified directly against that controller/`ReportDataService` before
/// building this. The whole `reports.*` route group is gated by
/// `permission:reports.view` in `routes/api_v1.php` — same "the request is
/// the real gate" convention as every other admin API class: this app
/// never re-checks that permission client-side beyond the entry point
/// (`AdminHomeScreen`'s "التقارير" tile).
///
/// Each report is a single synchronous JSON object (not a paginated list —
/// `ReportController` calls `$this->success(...)` directly, no
/// `paginate()` anywhere in `ReportDataService`), so this uses
/// `ApiClient.get()` like `AdminUsersApi.show()`, not `getPaginated()`.
///
/// Deliberately **no `branch_id` filter** here even though every report
/// method accepts one server-side: this app has no branch-listing
/// endpoint anywhere to populate a picker from, and a free-text branch id
/// field would just produce silent empty results for anyone who doesn't
/// already know the numeric id — same reasoning `AuditLogsApi` documents
/// for leaving out `model_type`. `from`/`to` alone cover what an office
/// user can use without one; a branch-scoped view is deferred to whenever
/// this app gains a branch list to pick from.
///
/// **Read-only, and deliberately so** — matching this project's established
/// discipline of shipping the on-screen "view" half of a feature before its
/// "produce a file" half (see e.g. `DriversApi`'s documents screen shipping
/// read-only before any upload UI). `POST /reports/export` (queues a
/// downloadable PDF/Excel/CSV file via `GenerateReportExportJob`) and its
/// `GET /reports/exports[/{id}]` polling endpoints are NOT wired in *this*
/// class — that follow-up piece has since shipped as a separate
/// `AdminReportExportsApi`, kept apart because `reports.export` is a
/// distinct permission from the `reports.view` that gates everything here
/// (see that class's own docblock).
class AdminReportsApi {
  AdminReportsApi(this._client);

  final ApiClient _client;

  static const _types = ['fleet', 'drivers', 'trips', 'fuel', 'maintenance', 'financial'];

  Future<Map<String, dynamic>> fetch(String type, {DateTime? from, DateTime? to}) async {
    assert(_types.contains(type), 'Unknown report type: $type');

    final data = await _client.get(
      '/reports/$type',
      query: {
        if (from != null) 'from': _formatDate(from),
        if (to != null) 'to': _formatDate(to),
      },
    );

    return Map<String, dynamic>.from(data as Map);
  }

  // Same manual `YYYY-MM-DD` formatting as `AuditLogsApi`/`AdminTripsApi` —
  // no `intl` dependency in this app.
  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');

    return '$y-$m-$d';
  }
}
