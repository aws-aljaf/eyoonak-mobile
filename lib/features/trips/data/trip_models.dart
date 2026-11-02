/// Mirrors backend/app/Http/Resources/Api/V1/{Trip,TripStop,TripEvent}Resource.php
/// field-for-field — nothing here is invented, every key matches the real
/// API response exactly.
///
/// **`vehicleId`/`driverId`/`customerId` and the raw origin/destination
/// lat-lng/weight/quantity/distance fields were added for the write half of
/// this feature** (`trips.create`/`edit`/`cancel`, verified directly against
/// `TripController`/`TripPolicy`/both trip FormRequests before building
/// this) — `AdminTripFormScreen` needs the actual ids to pre-select the
/// vehicle/driver picker when editing, not just the display-only
/// `vehiclePlateNumber`/`driverName` already here. Deliberately extended in
/// place rather than forking a separate `AdminTrip` model the way
/// `AdminVehicle`/`AdminDriver` fork from their driver-facing counterparts:
/// unlike those two, this class is still used as-is by the read-only
/// `AdminTripsScreen`/`AdminTripDetailScreen` (module 26's own
/// `TripDetailScreen` too), and every new field here is purely additive
/// (nullable, never read by existing code), so there is nothing to migrate
/// on either side — see `claude/admin-unification-plan.md` for the full
/// reasoning.
class Trip {
  const Trip({
    required this.id,
    required this.tripNumber,
    required this.status,
    required this.nextPossibleStatuses,
    required this.canCancel,
    required this.originAddress,
    required this.destinationAddress,
    this.vehicleId,
    this.vehiclePlateNumber,
    this.driverId,
    this.driverName,
    this.customerId,
    this.customerName,
    this.originLat,
    this.originLng,
    this.destinationLat,
    this.destinationLng,
    this.cargoDescription,
    this.weightKg,
    this.quantity,
    this.distanceKm,
    this.expectedStartAt,
    this.expectedArrivalAt,
    this.actualStartAt,
    this.actualArrivalAt,
    this.notes,
    this.stops = const [],
    this.events = const [],
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    final vehicle = json['vehicle'];
    final driver = json['driver'];
    final customer = json['customer'];

    return Trip(
      id: json['id'] as int,
      tripNumber: json['trip_number'] as String,
      status: json['status'] as String,
      nextPossibleStatuses:
          (json['next_possible_statuses'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      canCancel: json['can_cancel'] as bool? ?? false,
      originAddress: json['origin_address'] as String? ?? '',
      destinationAddress: json['destination_address'] as String? ?? '',
      vehicleId: json['vehicle_id'] as int?,
      vehiclePlateNumber: vehicle is Map ? vehicle['plate_number'] as String? : null,
      driverId: json['driver_id'] as int?,
      driverName: driver is Map ? driver['full_name'] as String? : null,
      customerId: json['customer_id'] as int?,
      customerName: customer is Map ? customer['name'] as String? : null,
      originLat: (json['origin_lat'] as num?)?.toDouble(),
      originLng: (json['origin_lng'] as num?)?.toDouble(),
      destinationLat: (json['destination_lat'] as num?)?.toDouble(),
      destinationLng: (json['destination_lng'] as num?)?.toDouble(),
      cargoDescription: json['cargo_description'] as String?,
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      quantity: json['quantity'] as int?,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      expectedStartAt: _parseDate(json['expected_start_at']),
      expectedArrivalAt: _parseDate(json['expected_arrival_at']),
      actualStartAt: _parseDate(json['actual_start_at']),
      actualArrivalAt: _parseDate(json['actual_arrival_at']),
      notes: json['notes'] as String?,
      stops: (json['stops'] as List?)?.map((e) => TripStop.fromJson(Map<String, dynamic>.from(e as Map))).toList() ??
          const [],
      events: (json['events'] as List?)
              ?.map((e) => TripEvent.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
    );
  }

  final int id;
  final String tripNumber;
  final String status;
  final List<String> nextPossibleStatuses;
  final bool canCancel;
  final String originAddress;
  final String destinationAddress;
  final int? vehicleId;
  final String? vehiclePlateNumber;
  final int? driverId;
  final String? driverName;
  final int? customerId;
  final String? customerName;
  final double? originLat;
  final double? originLng;
  final double? destinationLat;
  final double? destinationLng;
  final String? cargoDescription;
  final double? weightKg;
  final int? quantity;
  final double? distanceKm;
  final DateTime? expectedStartAt;
  final DateTime? expectedArrivalAt;
  final DateTime? actualStartAt;
  final DateTime? actualArrivalAt;
  final String? notes;
  final List<TripStop> stops;
  final List<TripEvent> events;

  /// Mirrors `UpdateTripRequest::withValidator`'s own status guard
  /// (`backend/app/Http/Requests/Api/V1/Trip/UpdateTripRequest.php`,
  /// verified directly before building this) exactly — once a trip moves
  /// past `accepted`, the backend rejects *any* core-field edit as a single
  /// all-or-nothing gate, not a per-field one. `AdminTripFormScreen` uses
  /// this to decide whether to render an editable form at all.
  bool get isCoreEditable => const {'draft', 'assigned', 'accepted'}.contains(status);

  /// Module 28 (GPS Background Service): tracking should only run while a
  /// trip is actually moving — matches the same status set the state
  /// machine considers "in progress" (assigned through arrived, but not
  /// yet delivered/completed/cancelled/failed).
  bool get isActivelyTracked =>
      const {'assigned', 'accepted', 'loading', 'loaded', 'started', 'in_transit', 'arrived'}.contains(status);
}

class TripStop {
  const TripStop({
    required this.id,
    required this.tripId,
    required this.sequenceNo,
    required this.address,
    required this.status,
    this.contactName,
    this.contactPhone,
    this.podSignatureUrl,
    this.podReceiverName,
  });

  factory TripStop.fromJson(Map<String, dynamic> json) {
    final pod = json['pod'] as Map?;

    return TripStop(
      id: json['id'] as int,
      tripId: json['trip_id'] as int,
      sequenceNo: json['sequence_no'] as int,
      address: json['address'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      contactName: json['contact_name'] as String?,
      contactPhone: json['contact_phone'] as String?,
      podSignatureUrl: pod?['signature_url'] as String?,
      podReceiverName: pod?['receiver_name'] as String?,
    );
  }

  final int id;
  final int tripId;
  final int sequenceNo;
  final String address;
  final String status;
  final String? contactName;
  final String? contactPhone;
  final String? podSignatureUrl;
  final String? podReceiverName;

  bool get hasPod => podSignatureUrl != null || podReceiverName != null;
}

class TripEvent {
  const TripEvent({
    required this.id,
    required this.eventType,
    this.oldStatus,
    this.newStatus,
    this.createdAt,
    this.reasonOrNotes,
  });

  factory TripEvent.fromJson(Map<String, dynamic> json) {
    // `meta` is a free-form JSON column (TripEvent model docblock: an
    // append-only status-change log). In practice today TripController
    // only ever writes it as either `{'reason': ...}` (cancel()) or
    // `{'notes': ...}` (updateStatus()) — never both, and often absent
    // entirely — so a single optional display string covers both without
    // the screen needing to know which key produced it.
    final meta = json['meta'] as Map?;

    return TripEvent(
      id: json['id'] as int,
      eventType: json['event_type'] as String? ?? '',
      oldStatus: json['old_status'] as String?,
      newStatus: json['new_status'] as String?,
      createdAt: _parseDate(json['created_at']),
      reasonOrNotes: (meta?['reason'] ?? meta?['notes']) as String?,
    );
  }

  final int id;
  final String eventType;
  final String? oldStatus;
  final String? newStatus;
  final DateTime? createdAt;
  final String? reasonOrNotes;
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;

  return DateTime.tryParse(value as String);
}
