import '../../../core/network/api_client.dart';
import 'admin_tracking_models.dart';

/// Talks to `LocationController::live()`
/// (backend/app/Http/Controllers/Api/V1/Tracking/LocationController.php) —
/// verified directly against that controller before building this.
/// Gated by `tracking.view` (`abort_unless($request->user()
/// ->hasPermissionTo('tracking.view'), ...)` inside the controller itself,
/// not a policy class) — same "the request is the real gate" convention
/// as every other admin API class in this feature.
///
/// **Reads straight off `vehicles.last_known_lat/lng`, never the raw
/// `vehicle_locations` ping-history table** — the controller's own
/// docblock is explicit about this, and it's exactly why this endpoint is
/// cheap enough to poll on a timer (see `AdminTrackingScreen`) instead of
/// needing a websocket/broadcast client, which this app has no dependency
/// for yet (`App\Events\VehicleLocationUpdated` exists server-side for the
/// web dashboard's Echo/Reverb channel, but nothing here subscribes to
/// it — a deliberate follow-up, not bundled into this first cut).
///
/// **No `branch_id` filter** exposed here, even though the endpoint
/// accepts one — same reasoning as `AdminReportsApi` omitting it: no
/// branch-listing endpoint/provider exists anywhere in this app yet, so
/// there's nothing to populate a picker from.
class AdminTrackingApi {
  AdminTrackingApi(this._client);

  final ApiClient _client;

  Future<List<AdminVehicleLocation>> live() async {
    final data = await _client.get('/locations/live');

    return (data as List).map((e) => AdminVehicleLocation.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }
}
