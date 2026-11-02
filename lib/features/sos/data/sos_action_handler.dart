import 'dart:convert';

import '../../../core/sync/sync_queue_service.dart';
import 'sos_api.dart';

Map<String, PendingActionHandler> sosActionHandlers(SosApi api) {
  return {
    'sos': (action) async {
      final payload = Map<String, dynamic>.from(jsonDecode(action.payloadJson) as Map);
      await api.trigger(
        lat: (payload['lat'] as num).toDouble(),
        lng: (payload['lng'] as num).toDouble(),
        tripId: action.tripId,
        message: payload['message'] as String?,
      );
    },
  };
}
