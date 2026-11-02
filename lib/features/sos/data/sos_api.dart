import '../../../core/network/api_client.dart';

/// `POST /api/v1/sos` exactly as documented in
/// documentation/04-api-specification.md (added in Phase 4 — see
/// backend/app/Http/Controllers/Api/V1/SosController.php).
class SosApi {
  SosApi(this._client);

  final ApiClient _client;

  Future<int> trigger({required double lat, required double lng, int? tripId, String? message}) async {
    final data = await _client.post('/sos', data: {
      'lat': lat,
      'lng': lng,
      if (tripId != null) 'trip_id': tripId,
      if (message != null) 'message': message,
    });

    return (Map<String, dynamic>.from(data as Map)['notified_users'] as num).toInt();
  }
}
