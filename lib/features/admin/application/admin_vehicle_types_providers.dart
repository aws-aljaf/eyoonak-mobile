import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/admin_vehicle_type_models.dart';

/// The whole catalogue at once (never paginated server-side either — see
/// `AdminVehicleTypesApi`'s own docblock), fetched once per
/// `AdminVehicleFormScreen` visit and reused for both the create and edit
/// path.
final adminVehicleTypesProvider = FutureProvider.autoDispose<List<AdminVehicleType>>((ref) {
  return ref.watch(adminVehicleTypesApiProvider).index();
});
