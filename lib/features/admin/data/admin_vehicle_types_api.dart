import '../../../core/network/api_client.dart';
import 'admin_vehicle_type_models.dart';

/// Talks to `GET /vehicle-types` (`VehicleTypeController::index()`,
/// backend/app/Http/Controllers/Api/V1/Fleet/VehicleTypeController.php),
/// verified directly against that controller/`VehicleTypePolicy` before
/// building this. Gated by `vehicles.view` — the same permission that
/// already gates `AdminVehiclesApi`, so no separate entry-point gate is
/// needed for this class.
///
/// Unpaginated on purpose: `VehicleTypeController::index()` calls `->get()`,
/// never `->paginate()` — a company's vehicle-type catalogue (its own
/// custom types plus the shared system defaults) is always a short list
/// meant for a dropdown, not a browsable list of its own.
class AdminVehicleTypesApi {
  AdminVehicleTypesApi(this._client);

  final ApiClient _client;

  Future<List<AdminVehicleType>> index() async {
    final data = await _client.get('/vehicle-types');

    return (data as List).map((e) => AdminVehicleType.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }
}
