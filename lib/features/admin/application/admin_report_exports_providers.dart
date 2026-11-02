import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_envelope.dart';

/// Page state for `AdminReportExportsScreen` — single global page number,
/// same as `AdminVehiclesScreen`/`AdminUsersScreen` (this screen has no
/// per-parent keying need like `adminRoleUsersPageProvider`, there's only
/// ever one exports history).
final adminReportExportsPageProvider = StateProvider.autoDispose<int>((ref) => 1);

/// No timer-driven polling here, unlike `AdminTrackingScreen`'s live map —
/// an export request is a one-shot background job, not a continuously
/// moving value, so a manual pull-to-refresh/refresh-button (same as every
/// other paginated admin list in this app) is enough for a user to check
/// whether their export finished.
final adminReportExportsProvider = FutureProvider.autoDispose<ApiEnvelope>((ref) {
  final page = ref.watch(adminReportExportsPageProvider);

  return ref.watch(adminReportExportsApiProvider).index(page: page);
});
