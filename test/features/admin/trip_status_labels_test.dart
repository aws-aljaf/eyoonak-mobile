import 'package:fleet_saas_driver/features/admin/data/trip_status_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tripStatusLabels covers every state TripStateMachine::allStates() defines', () {
    // Mirrors backend/app/Services/Trips/TripStateMachine.php's
    // TRANSITIONS keys exactly (draft/assigned/accepted/loading/loaded/
    // started/in_transit/arrived/delivered/completed/cancelled/failed) —
    // verified directly against that file before writing this list.
    const allBackendStates = [
      'draft',
      'assigned',
      'accepted',
      'loading',
      'loaded',
      'started',
      'in_transit',
      'arrived',
      'delivered',
      'completed',
      'cancelled',
      'failed',
    ];

    expect(tripStatusLabels.keys, containsAll(allBackendStates));
    expect(tripStatusLabels.length, allBackendStates.length);
  });
}
