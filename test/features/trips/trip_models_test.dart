import 'package:fleet_saas_driver/features/trips/data/trip_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Trip.fromJson', () {
    test('parses a full TripResource payload, including nested relations', () {
      final trip = Trip.fromJson({
        'id': 5,
        'trip_number': 'TRP-260101-ABC123',
        'status': 'in_transit',
        'next_possible_statuses': ['arrived', 'failed'],
        'can_cancel': false,
        'origin_address': 'بغداد',
        'destination_address': 'البصرة',
        'vehicle': {'id': 1, 'plate_number': '12345 بغداد'},
        'driver': {'id': 2, 'full_name': 'أحمد علي'},
        'customer': {'id': 3, 'name': 'شركة النقل'},
        'cargo_description': 'مواد غذائية',
        'stops': [
          {
            'id': 10,
            'trip_id': 5,
            'sequence_no': 1,
            'address': 'محطة 1',
            'status': 'pending',
            'pod': {'signature_url': null, 'receiver_name': null},
          },
        ],
        'events': [
          {'id': 100, 'event_type': 'status_change', 'old_status': 'started', 'new_status': 'in_transit'},
        ],
      });

      expect(trip.id, 5);
      expect(trip.tripNumber, 'TRP-260101-ABC123');
      expect(trip.nextPossibleStatuses, ['arrived', 'failed']);
      expect(trip.canCancel, isFalse);
      expect(trip.vehiclePlateNumber, '12345 بغداد');
      expect(trip.driverName, 'أحمد علي');
      expect(trip.customerName, 'شركة النقل');
      expect(trip.stops, hasLength(1));
      expect(trip.stops.first.hasPod, isFalse);
      expect(trip.events, hasLength(1));
    });

    test('tolerates missing optional relations (customer/vehicle can be null)', () {
      final trip = Trip.fromJson({
        'id': 5,
        'trip_number': 'TRP-1',
        'status': 'draft',
        'next_possible_statuses': ['assigned'],
        'can_cancel': true,
        'origin_address': 'A',
        'destination_address': 'B',
      });

      expect(trip.vehiclePlateNumber, isNull);
      expect(trip.driverName, isNull);
      expect(trip.customerName, isNull);
      expect(trip.stops, isEmpty);
      expect(trip.vehicleId, isNull);
      expect(trip.driverId, isNull);
    });

    // Added for the trips write-action feature (PR #77) — `vehicleId`/
    // `driverId`/`customerId` and the raw scalar fields exist purely so
    // `AdminTripFormScreen` can pre-fill its picker/inputs when editing;
    // this confirms `fromJson` actually extracts them from a real
    // `TripResource` shape rather than only the display-only nested names.
    test('parses the raw FK ids and scalar fields added for the write form', () {
      final trip = Trip.fromJson({
        'id': 5,
        'trip_number': 'TRP-1',
        'status': 'draft',
        'next_possible_statuses': ['assigned'],
        'can_cancel': true,
        'origin_address': 'A',
        'origin_lat': 33.3,
        'origin_lng': 44.4,
        'destination_address': 'B',
        'destination_lat': 30.5,
        'destination_lng': 47.8,
        'vehicle_id': 1,
        'vehicle': {'id': 1, 'plate_number': '12345 بغداد'},
        'driver_id': 2,
        'driver': {'id': 2, 'full_name': 'أحمد علي'},
        'customer_id': 3,
        'customer': {'id': 3, 'name': 'شركة النقل'},
        'weight_kg': 250.5,
        'quantity': 10,
        'distance_km': 12.3,
      });

      expect(trip.vehicleId, 1);
      expect(trip.driverId, 2);
      expect(trip.customerId, 3);
      expect(trip.originLat, 33.3);
      expect(trip.originLng, 44.4);
      expect(trip.destinationLat, 30.5);
      expect(trip.destinationLng, 47.8);
      expect(trip.weightKg, 250.5);
      expect(trip.quantity, 10);
      expect(trip.distanceKm, 12.3);
    });

    test('a stop with a signature_url reports hasPod true', () {
      final stop = TripStop.fromJson({
        'id': 1,
        'trip_id': 5,
        'sequence_no': 1,
        'address': 'X',
        'status': 'completed',
        'pod': {'signature_url': 'https://api.example.iq/files/abc?signature=...', 'receiver_name': 'Ali'},
      });

      expect(stop.hasPod, isTrue);
      expect(stop.podReceiverName, 'Ali');
    });
  });

  group('TripEvent.fromJson', () {
    test('extracts reason from meta on a cancellation event', () {
      final event = TripEvent.fromJson({
        'id': 1,
        'event_type': 'status_change',
        'old_status': 'in_transit',
        'new_status': 'cancelled',
        'meta': {'reason': 'عطل بالمركبة'},
        'created_at': '2026-09-12T10:00:00Z',
      });

      expect(event.reasonOrNotes, 'عطل بالمركبة');
    });

    test('extracts notes from meta on a plain status-change event', () {
      final event = TripEvent.fromJson({
        'id': 2,
        'event_type': 'status_change',
        'old_status': 'started',
        'new_status': 'arrived',
        'meta': {'notes': 'وصل مبكرًا'},
      });

      expect(event.reasonOrNotes, 'وصل مبكرًا');
    });

    test('reasonOrNotes is null when meta is absent entirely', () {
      final event = TripEvent.fromJson({
        'id': 3,
        'event_type': 'status_change',
        'old_status': 'assigned',
        'new_status': 'accepted',
      });

      expect(event.reasonOrNotes, isNull);
    });
  });

  group('Trip.isActivelyTracked', () {
    const trackedStatuses = ['assigned', 'accepted', 'loading', 'loaded', 'started', 'in_transit', 'arrived'];
    const untrackedStatuses = ['draft', 'delivered', 'completed', 'cancelled', 'failed'];

    for (final status in trackedStatuses) {
      test('$status is actively tracked', () {
        expect(_tripWithStatus(status).isActivelyTracked, isTrue);
      });
    }

    for (final status in untrackedStatuses) {
      test('$status is NOT actively tracked', () {
        expect(_tripWithStatus(status).isActivelyTracked, isFalse);
      });
    }
  });

  // Added for PR #77 — mirrors `UpdateTripRequest::withValidator`'s own
  // status guard exactly (see `Trip.isCoreEditable`'s docblock).
  group('Trip.isCoreEditable', () {
    const editableStatuses = ['draft', 'assigned', 'accepted'];
    const lockedStatuses = ['loading', 'loaded', 'started', 'in_transit', 'arrived', 'delivered', 'completed', 'cancelled', 'failed'];

    for (final status in editableStatuses) {
      test('$status is core-editable', () {
        expect(_tripWithStatus(status).isCoreEditable, isTrue);
      });
    }

    for (final status in lockedStatuses) {
      test('$status is NOT core-editable', () {
        expect(_tripWithStatus(status).isCoreEditable, isFalse);
      });
    }
  });
}

Trip _tripWithStatus(String status) {
  return Trip.fromJson({
    'id': 1,
    'trip_number': 'TRP-1',
    'status': status,
    'next_possible_statuses': const [],
    'can_cancel': false,
    'origin_address': 'A',
    'destination_address': 'B',
  });
}
