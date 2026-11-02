import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';

/// Talks to `/api/v1/trips/*` exactly as documented in
/// documentation/04-api-specification.md — request/response shapes match
/// TripController/TripResource byte-for-byte (see trip_models.dart).
class TripsApi {
  TripsApi(this._client);

  final ApiClient _client;

  Future<ApiEnvelope> myTrips({required int driverId, String? status, int page = 1}) {
    return _client.getPaginated('/trips', query: {
      'driver_id': driverId,
      if (status != null) 'status': status,
      'page': page,
      'per_page': 20,
    });
  }

  Future<Map<String, dynamic>> show(int tripId) async {
    final data = await _client.get('/trips/$tripId');

    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> updateStatus(
    int tripId, {
    required String status,
    double? lat,
    double? lng,
    String? notes,
  }) async {
    final data = await _client.post('/trips/$tripId/status', data: {
      'status': status,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (notes != null) 'notes': notes,
    });

    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> cancel(int tripId, {String? reason}) async {
    final data = await _client.post('/trips/$tripId/cancel', data: {
      if (reason != null) 'reason': reason,
    });

    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> uploadPod(
    int tripId,
    int stopId, {
    required String receiverName,
    String? receiverPhone,
    required double lat,
    required double lng,
    String? notes,
    String? signaturePath,
    List<String> photoPaths = const [],
  }) async {
    // Built manually via `form.files.add(...)` rather than
    // `FormData.fromMap` — a Dart Map literal can only hold ONE value per
    // key, so a `for` entry repeating the same 'photos[]' key would
    // silently collapse to just the LAST photo. `FormData.files` is a
    // `List<MapEntry<...>>`, which is the only way to send multiple
    // parts under the same field name — exactly what Laravel's
    // `photos.*` array-upload validation expects on the other end.
    final form = FormData();
    form.fields
      ..add(MapEntry('receiver_name', receiverName))
      ..add(MapEntry('lat', lat.toString()))
      ..add(MapEntry('lng', lng.toString()));

    if (receiverPhone != null) {
      form.fields.add(MapEntry('receiver_phone', receiverPhone));
    }

    if (notes != null) {
      form.fields.add(MapEntry('notes', notes));
    }

    if (signaturePath != null) {
      form.files.add(MapEntry('signature', await MultipartFile.fromFile(signaturePath)));
    }

    for (final path in photoPaths) {
      form.files.add(MapEntry('photos[]', await MultipartFile.fromFile(path)));
    }

    final data = await _client.postMultipart('/trips/$tripId/stops/$stopId/pod', form);

    return Map<String, dynamic>.from(data as Map);
  }

  /// `GET /trips/{trip}/events` — `TripController::events()`, authorized
  /// via `TripPolicy::viewEvents()` which is a plain alias of `view()`
  /// (see that policy's docblock): the exact same ownership check
  /// `show()` above already relies on, so no new authorization surface at
  /// all. Was never called by this app despite `Trip`/`TripEvent` models
  /// already existing since the Phase-3 baseline — `show()` never eager-
  /// loads the `events` relation, so `Trip.events` was silently always
  /// empty until this method existed. Returns the raw list (like every
  /// other `TripsApi` method) — `TripEvent.fromJson` is applied by the
  /// caller.
  Future<List<dynamic>> events(int tripId) async {
    final data = await _client.get('/trips/$tripId/events');

    return data as List;
  }
}
