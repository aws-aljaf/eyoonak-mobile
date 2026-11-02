import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/driver_document.dart';

/// `.family(driverId)` rather than reading `authControllerProvider` itself
/// (the way `_driverProfileProvider` in `profile_screen.dart` does) — this
/// provider is watched from `DriverDocumentsScreen`, which is only ever
/// reached via `/profile/documents/:id` with the driver's own id already
/// resolved and passed as a path parameter by the caller (see that
/// screen's docblock), so it takes the id directly instead of re-deriving
/// it from auth state a second time.
final driverDocumentsProvider =
    FutureProvider.autoDispose.family<List<DriverDocument>, int>((ref, driverId) async {
  return ref.watch(driversApiProvider).documents(driverId);
});
