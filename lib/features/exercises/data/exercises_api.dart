import '../../../core/network/api_client.dart';

class ExercisesApi {
  ExercisesApi(this.client);
  final ApiClient client;
  Map<String, dynamic>? headers(int? familyId) => familyId == null ? null : {'X-Family-Id': '$familyId'};

  Future<Map<String, dynamic>> forMember(int memberId, int? familyId) async => Map<String, dynamic>.from(
      await client.get('/family-members/$memberId/exercises', headers: headers(familyId)) as Map);

  Future<Map<String, dynamic>> detail(int exerciseId, int? familyId) async =>
      Map<String, dynamic>.from(await client.get('/family-exercises/$exerciseId', headers: headers(familyId)) as Map);

  Future<List<Map<String, dynamic>>> assignments(int memberId, int? familyId) async {
    final data = await client.get('/family-members/$memberId/exercise-assignments', headers: headers(familyId));
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> assign(int memberId, int exerciseId, int? familyId, Map<String, dynamic> data) async {
    await client.post('/family-members/$memberId/exercises/$exerciseId/assign', data: data, headers: headers(familyId));
  }

  Future<void> archive(int taskId, int? familyId) async {
    await client.put('/family-tasks/$taskId', data: {'status': 'archived'}, headers: headers(familyId));
  }
}
