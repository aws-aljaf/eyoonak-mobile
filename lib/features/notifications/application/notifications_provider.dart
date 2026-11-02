import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/notification_models.dart';

final notificationsProvider = FutureProvider.autoDispose<List<DriverNotification>>((ref) async {
  return ref.watch(notificationsApiProvider).list();
});
