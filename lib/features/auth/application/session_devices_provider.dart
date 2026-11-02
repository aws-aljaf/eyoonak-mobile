import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/session_device.dart';

/// Backs `DevicesScreen` — every still-active session on this account,
/// across BOTH account types this app serves (a driver's own phone, a
/// family member's phone, or a device paired to a tracked family member
/// with no login of its own — see `SessionDevice.familyMemberName`). No
/// permission gate anywhere in this feature (mirrors `AuthController`
/// itself): `GET/DELETE /auth/devices*` and `POST /auth/logout-all` all
/// only ever require *some* authenticated account, the same "the request
/// is the gate" convention already used throughout `family_providers.dart`
/// for checks this app has no cheap way to pre-compute — there is nothing
/// to pre-compute here at all, since every account may always manage its
/// own sessions.
final sessionDevicesProvider = FutureProvider.autoDispose<List<SessionDevice>>((ref) async {
  return ref.watch(authApiProvider).devices();
});
