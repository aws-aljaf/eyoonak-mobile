import 'dart:convert';

import '../../../core/sync/sync_queue_service.dart';
import 'family_api.dart';

/// Registered under actionType `'family_sos'` in
/// lib/app/providers.dart's syncQueueServiceProvider — mirrors
/// sos_action_handler.dart's shape exactly.
Map<String, PendingActionHandler> familySosActionHandlers(FamilyApi api) {
  return {
    'family_sos': (action) async {
      final payload = Map<String, dynamic>.from(jsonDecode(action.payloadJson) as Map);

      await api.triggerSos(
        familyMemberId: (payload['family_member_id'] as num).toInt(),
        lat: (payload['lat'] as num).toDouble(),
        lng: (payload['lng'] as num).toDouble(),
        batteryLevel: (payload['battery_level'] as num?)?.toInt(),
        familyId: (payload['family_id'] as num?)?.toInt(),
      );
    },
  };
}
