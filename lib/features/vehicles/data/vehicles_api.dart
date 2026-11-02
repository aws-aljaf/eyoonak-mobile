import '../../../core/network/api_client.dart';
import 'vehicle_models.dart';

class VehiclesApi {
  VehiclesApi(this._client);

  final ApiClient _client;

  Future<VehicleInfo> show(int vehicleId) async {
    final data = await _client.get('/vehicles/$vehicleId');

    return VehicleInfo.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
