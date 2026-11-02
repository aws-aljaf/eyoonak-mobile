import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/network/api_client.dart';

/// Talks to `/api/v1/accidents` (`AccidentController`). `AccidentPolicy`
/// lets ANY account with a linked driver profile call `index`/`store`
/// with no RBAC permission at all — `index()` narrows server-side to that
/// driver's own accidents when the account has no `accidents.view`
/// permission (see `AccidentController::index()`'s `when()` clause), and
/// `store()`'s `StoreAccidentRequest::withValidator()` rejects a
/// `driver_id` that isn't the caller's own — so this app never needs to
/// re-check either restriction client-side, matching every other
/// self-service endpoint in this app (`TripsApi`, `DriversApi.documents`).
///
/// `update()` (the review workflow: reported → under_review → resolved)
/// is deliberately NOT wired up here — it requires `accidents.edit`
/// (RBAC, office/management only), a permission no driver account holds,
/// exactly like `DriversApi` never wiring up `uploadDocument()`.
class AccidentsApi {
  AccidentsApi(this._client);

  final ApiClient _client;

  /// `GET /accidents` — flattened to a plain list (pagination `meta`
  /// discarded), matching the convention this app uses everywhere a
  /// screen shows one account's own naturally-small history rather than
  /// a company-wide feed (e.g. `familyMembersProvider`) — a driver
  /// self-reporting accidents is not expected to accumulate enough of
  /// them to need real pagination UI, unlike `TripsApi.myTrips()`.
  Future<List<dynamic>> index() async {
    final envelope = await _client.getPaginated('/accidents', query: {'per_page': 50});

    return envelope.data;
  }

  /// `POST /accidents`, multipart because `photos[]`/`police_report` are
  /// files. Built the same manual `FormData.fields`/`FormData.files` way
  /// as `TripsApi.uploadPod()` — a Dart `Map` literal can only hold one
  /// value per key, so repeated `photos[]` entries need `FormData.files`'s
  /// `List<MapEntry<...>>` shape, not `FormData.fromMap`.
  Future<Map<String, dynamic>> create({
    required int vehicleId,
    required int driverId,
    int? tripId,
    required DateTime occurredAt,
    String? locationAddress,
    double? lat,
    double? lng,
    required String description,
    String? damageDescription,
    String? thirdPartyNote,
    double? estimatedCost,
    List<String> photoPaths = const [],
    String? policeReportPath,
  }) async {
    final form = FormData();
    form.fields
      ..add(MapEntry('vehicle_id', vehicleId.toString()))
      ..add(MapEntry('driver_id', driverId.toString()))
      ..add(MapEntry('occurred_at', occurredAt.toIso8601String()))
      ..add(MapEntry('description', description));

    if (tripId != null) {
      form.fields.add(MapEntry('trip_id', tripId.toString()));
    }

    if (locationAddress != null) {
      form.fields.add(MapEntry('location_address', locationAddress));
    }

    if (lat != null) {
      form.fields.add(MapEntry('lat', lat.toString()));
    }

    if (lng != null) {
      form.fields.add(MapEntry('lng', lng.toString()));
    }

    if (damageDescription != null) {
      form.fields.add(MapEntry('damage_description', damageDescription));
    }

    if (thirdPartyNote != null) {
      // `third_party_info` is validated server-side as `array` — no fixed
      // schema exists anywhere in this codebase (no Resource field, no
      // seeder, no test references specific keys), so a single free-text
      // note wrapped as `third_party_info[note]` satisfies the `array`
      // rule (Laravel treats an associative array as `array`) without
      // inventing a schema this app has no way to confirm.
      form.fields.add(MapEntry('third_party_info[note]', thirdPartyNote));
    }

    if (estimatedCost != null) {
      form.fields.add(MapEntry('estimated_cost', estimatedCost.toString()));
    }

    for (final path in photoPaths) {
      form.files.add(MapEntry('photos[]', await MultipartFile.fromFile(path)));
    }

    if (policeReportPath != null) {
      form.files.add(MapEntry('police_report', await MultipartFile.fromFile(policeReportPath)));
    }

    final data = await _client.postMultipart('/accidents', form);

    return Map<String, dynamic>.from(data as Map);
  }

  /// Downloads a photo or police-report file (both are `download_url`s
  /// minted by `SecureFileService::signedUrl()`) to a local temp path and
  /// hands back the `File` — the caller (`AccidentsListScreen`) then opens
  /// the OS share sheet on it. Goes through `ApiClient.download()`,
  /// **never** a bare `url_launcher` open of the URL — that link also sits
  /// inside the backend's `auth:sanctum` group (verified directly against
  /// `routes/api_v1.php`/`SecureFileController`, same gap documented on
  /// `DriversApi.downloadDocument()`, which this mirrors exactly), so an
  /// external browser tab carrying no Authorization header gets a 401.
  /// Takes a plain `url` rather than an `AccidentPhoto`/typed police-report
  /// field because a police report has no model of its own on this app's
  /// `Accident` (just a bare `String? policeReportUrl`) — one method
  /// covers both call sites. The filename comes entirely from the server's
  /// own `Content-Disposition` header (`ApiClient.download()`'s own
  /// docblock), since neither call site has a reliable extension of its
  /// own to fall back on (a police report doesn't even carry a
  /// `mime_type` field).
  Future<File> downloadFile(String url) async {
    final downloaded = await _client.download(url);
    final dir = await getTemporaryDirectory();
    final filename = downloaded.filename ?? 'accident-file-${DateTime.now().millisecondsSinceEpoch}';
    final file = File('${dir.path}/$filename');

    return file.writeAsBytes(downloaded.bytes, flush: true);
  }
}
