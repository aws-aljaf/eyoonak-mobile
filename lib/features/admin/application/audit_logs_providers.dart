import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_envelope.dart';

/// Resets to page 1 on every rebuild of this provider's dependents leaving
/// the screen (`.autoDispose`) — mirrors `familyTimelinePageProvider`
/// exactly (see that provider's docblock): reopening this screen later
/// should start from the newest logs, not a stale deep page.
final auditLogsPageProvider = StateProvider.autoDispose<int>((ref) => 1);

/// Free-text `action` filter (e.g. "vehicle.updated") — matches
/// `AuditLogController::index()`'s own `LIKE '{value}%'` prefix match.
final auditLogsActionFilterProvider = StateProvider.autoDispose<String?>((ref) => null);

final auditLogsFromFilterProvider = StateProvider.autoDispose<DateTime?>((ref) => null);

final auditLogsToFilterProvider = StateProvider.autoDispose<DateTime?>((ref) => null);

/// Changing any filter without also resetting the page would silently ask
/// for e.g. page 3 of a now-much-smaller filtered result set — every
/// filter provider above is watched here purely so `ref.listen` in the
/// screen can reset `auditLogsPageProvider` back to 1 whenever one changes
/// (see `AuditLogsScreen`'s own filter bar).
final auditLogsProvider = FutureProvider.autoDispose<ApiEnvelope>((ref) async {
  final page = ref.watch(auditLogsPageProvider);
  final action = ref.watch(auditLogsActionFilterProvider);
  final from = ref.watch(auditLogsFromFilterProvider);
  final to = ref.watch(auditLogsToFilterProvider);

  return ref.watch(auditLogsApiProvider).index(page: page, action: action, from: from, to: to);
});
