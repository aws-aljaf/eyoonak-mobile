import 'dart:convert';

import '../../../core/sync/sync_queue_service.dart';
import 'trips_api.dart';

/// The ONE place a queued `trip_status`/`trip_cancel`/`pod_upload` action
/// is ever turned into a real network call — see SyncQueueService's
/// docblock. Registered once in lib/app/providers.dart.
Map<String, PendingActionHandler> tripActionHandlers(TripsApi api) {
  return {
    'trip_status': (action) async {
      final payload = _decode(action.payloadJson);
      await api.updateStatus(
        action.tripId!,
        status: payload['status'] as String,
        lat: (payload['lat'] as num?)?.toDouble(),
        lng: (payload['lng'] as num?)?.toDouble(),
        notes: payload['notes'] as String?,
      );
    },
    'trip_cancel': (action) async {
      final payload = _decode(action.payloadJson);
      await api.cancel(action.tripId!, reason: payload['reason'] as String?);
    },
    'pod_upload': (action) async {
      final payload = _decode(action.payloadJson);
      await api.uploadPod(
        action.tripId!,
        action.stopId!,
        receiverName: payload['receiver_name'] as String,
        receiverPhone: payload['receiver_phone'] as String?,
        lat: (payload['lat'] as num).toDouble(),
        lng: (payload['lng'] as num).toDouble(),
        notes: payload['notes'] as String?,
        signaturePath: payload['signature_path'] as String?,
        photoPaths: (payload['photo_paths'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      );
    },
  };
}

Map<String, dynamic> _decode(String json) => Map<String, dynamic>.from(jsonDecode(json) as Map);
