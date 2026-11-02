import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';

/// Talks to `GET /audit-logs` (`AuditLogController::index()`), verified
/// directly against that controller/`AuditLogPolicy`/`AuditLogResource`
/// before building this. `AuditLogPolicy::viewAny()` requires
/// `audit_logs.view` — this app never re-checks that client-side beyond
/// gating the entry point (`DriverUser.hasManagementAccess`,
/// `AdminHomeScreen`'s section list), same "the request is the real gate"
/// convention as every family screen.
///
/// Deliberately no `model_type` filter here even though the backend
/// supports one: `AuditLogController::index()` matches it by **exact**
/// full namespaced class string (e.g. `App\Models\Vehicle`), and this app
/// has no endpoint anywhere that lists those values for a dropdown — a
/// free-text field would just produce silent empty results for anyone who
/// doesn't already know Laravel's internal class names. `action`/`from`/
/// `to` cover the filtering an office user can actually use without that
/// knowledge.
class AuditLogsApi {
  AuditLogsApi(this._client);

  final ApiClient _client;

  /// `from`/`to` are sent as `YYYY-MM-DD` — matches
  /// `$request->date('from'/'to')`'s own parsing, and this app has no
  /// `intl` dependency (see this project's established "no `intl` for
  /// manual date formatting" convention) so the digits are built by hand.
  Future<ApiEnvelope> index({
    int page = 1,
    int perPage = 20,
    String? action,
    DateTime? from,
    DateTime? to,
  }) {
    return _client.getPaginated(
      '/audit-logs',
      query: {
        'page': page,
        'per_page': perPage,
        if (action != null && action.isNotEmpty) 'action': action,
        if (from != null) 'from': _formatDate(from),
        if (to != null) 'to': _formatDate(to),
      },
    );
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');

    return '$y-$m-$d';
  }
}
