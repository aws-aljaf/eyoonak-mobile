import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/admin_report_models.dart';

/// Which of the six report types (`adminReportTypeLabels`' keys) is
/// currently selected — resets to `'fleet'` (the first tile) whenever this
/// screen is left and reopened, same `.autoDispose` reasoning as every
/// other admin filter provider in this app.
final adminReportTypeProvider = StateProvider.autoDispose<String>((ref) => 'fleet');

/// `null` for either means "let the backend apply its own default" —
/// `ReportDataService::range()` falls back to the current calendar month
/// when `from`/`to` are omitted, so this screen doesn't need to guess or
/// duplicate that default client-side.
final adminReportsFromFilterProvider = StateProvider.autoDispose<DateTime?>((ref) => null);

final adminReportsToFilterProvider = StateProvider.autoDispose<DateTime?>((ref) => null);

final adminReportProvider = FutureProvider.autoDispose<AdminReport>((ref) async {
  final type = ref.watch(adminReportTypeProvider);
  final from = ref.watch(adminReportsFromFilterProvider);
  final to = ref.watch(adminReportsToFilterProvider);

  final json = await ref.watch(adminReportsApiProvider).fetch(type, from: from, to: to);

  return AdminReport.fromJson(json);
});
