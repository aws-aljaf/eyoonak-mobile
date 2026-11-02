import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../family/application/family_providers.dart';
import '../data/exercises_api.dart';

final exercisesApiProvider = Provider((ref) => ExercisesApi(ref.watch(apiClientProvider)));
final memberExercisesProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, int>((ref, memberId) {
  return ref.watch(exercisesApiProvider).forMember(memberId, ref.watch(selectedFamilyIdProvider));
});
final exerciseAssignmentsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, int>((ref, memberId) {
  return ref.watch(exercisesApiProvider).assignments(memberId, ref.watch(selectedFamilyIdProvider));
});
final exerciseDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, int>((ref, exerciseId) {
  return ref.watch(exercisesApiProvider).detail(exerciseId, ref.watch(selectedFamilyIdProvider));
});
