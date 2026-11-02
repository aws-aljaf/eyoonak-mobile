import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/admin_tracking_models.dart';

/// `.autoDispose` — same reasoning as every other admin list/detail
/// provider in this feature: `AdminTrackingScreen` is the only reader, so
/// there is no reason to keep polling `/locations/live` once that screen
/// is left. The screen itself drives re-fetches on a timer via
/// `ref.invalidate(adminTrackingProvider)` (see that screen's docblock for
/// why a plain polling timer, not a websocket subscription, is this
/// app's mechanism today).
final adminTrackingProvider = FutureProvider.autoDispose<List<AdminVehicleLocation>>((ref) {
  return ref.watch(adminTrackingApiProvider).live();
});
