import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../core/network/api_client.dart';
import 'driver_document.dart';
import 'driver_profile.dart';

class DriversApi {
  DriversApi(this._client);

  final ApiClient _client;

  Future<DriverProfile> show(int driverId) async {
    final data = await _client.get('/drivers/$driverId');

    return DriverProfile.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// `GET /drivers/{driver}/documents` — `DriverController::documents()`
  /// authorizes via `DriverPolicy::view`, the exact same policy method
  /// `show()` above already relies on to let a driver read their own
  /// record with no RBAC permission at all (`$driver->user_id ===
  /// $user->id` fallback — see that policy's docblock). This app never
  /// calls this for any driver id but the caller's own
  /// (`AuthController.user.driverId`), so no separate check is needed
  /// client-side either. `uploadDocument()` is deliberately NOT wired up
  /// here — it requires `DriverPolicy::manageDocuments` (`drivers.edit`,
  /// an RBAC permission no driver account holds), so this app can only
  /// ever read documents fleet/office staff already uploaded from the web
  /// admin, never add its own.
  Future<List<DriverDocument>> documents(int driverId) async {
    final data = await _client.get('/drivers/$driverId/documents');

    return (data as List)
        .map((e) => DriverDocument.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Downloads a document's file to a local temp path and hands back the
  /// `File` — the caller (`DriverDocumentsScreen`) then opens the OS share
  /// sheet on it. Goes through `ApiClient.download()`, **never** a bare
  /// `url_launcher` open of `document.downloadUrl` — that link is a
  /// `URL::temporarySignedRoute` that also sits inside the backend's
  /// `auth:sanctum` group (verified directly against `routes/api_v1.php`
  /// and `SecureFileController`'s own docblock: "Two independent checks
  /// must both pass"), so an external browser tab carrying no
  /// Authorization header gets a 401 — a real, previously-shipped gap this
  /// method exists to fix (see `claude/admin-unification-plan.md`, the
  /// deferred item this closes), not a hypothetical one. Same
  /// `AdminReportExportsApi.download()` pattern, but the filename comes
  /// from the server's own `Content-Disposition` header
  /// (`ApiClient.download()`'s own docblock) rather than being
  /// reconstructed from `document.mimeType`, since that field is nullable
  /// here and the server already computed the correct extension.
  Future<File> downloadDocument(DriverDocument document) async {
    assert(document.downloadUrl != null, 'downloadDocument() called on a document with no download_url');

    final downloaded = await _client.download(document.downloadUrl!);
    final dir = await getTemporaryDirectory();
    final filename = downloaded.filename ?? 'driver-document-${document.id}';
    final file = File('${dir.path}/$filename');

    return file.writeAsBytes(downloaded.bytes, flush: true);
  }
}
