import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../local_db/offline_queue_repository.dart';

/// Module 28 — "GPS Background Service (Android/iOS policies)".
///
/// The Dart-side tracking logic lives entirely here and is fully testable
/// without a device: it adapts sampling frequency to whether a trip is
/// actually in progress (see `start`'s `highFrequency` argument, driven
/// by `Trip.isActivelyTracked`) and never calls the network directly —
/// every fix is written to the offline queue first (`PendingGpsPoints`),
/// exactly like every other mutation in this app, so a fix taken with no
/// connectivity is never lost.
///
/// Android uses geolocator's visible location foreground service while a trip
/// is active. Starting tracking requires user permission in the foreground.
/// Force-stop and manufacturer battery restrictions still require device QA.
class LocationService {
  LocationService({required OfflineQueueRepository queue}) : _queue = queue;

  final OfflineQueueRepository _queue;
  final _uuid = const Uuid();

  StreamSubscription<Position>? _subscription;
  int? _activeTripId;

  bool get isTracking => _subscription != null;

  Future<bool> ensurePermission() async {
    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return permission == LocationPermission.whileInUse || permission == LocationPermission.always;
  }

  /// `highFrequency` should be driven by `Trip.isActivelyTracked` — a
  /// tighter distance filter while the trip is actually moving, a looser
  /// one otherwise, rather than a fixed interval regardless of state.
  void start({required int tripId, bool highFrequency = true}) {
    if (_subscription != null && _activeTripId == tripId) {
      return;
    }

    stop();
    _activeTripId = tripId;

    final LocationSettings settings = defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(accuracy: LocationAccuracy.high,
            distanceFilter: highFrequency ? 25 : 100,
            intervalDuration: const Duration(seconds: 30),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'تتبع الرحلة مفعّل',
              notificationText: 'عيونك يسجل موقع الرحلة. أوقف التتبع من التطبيق.',
              enableWakeLock: true, setOngoing: true))
        : LocationSettings(accuracy: LocationAccuracy.high,
            distanceFilter: highFrequency ? 25 : 100);

    _subscription = Geolocator.getPositionStream(locationSettings: settings).listen(_onPosition);
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _activeTripId = null;
  }

  Future<void> _onPosition(Position position) async {
    await _queue.enqueueGpsPoint(
      id: _uuid.v4(),
      tripId: _activeTripId,
      lat: position.latitude,
      lng: position.longitude,
      speedKph: position.speed >= 0 ? position.speed * 3.6 : null,
      headingDeg: position.heading >= 0 ? position.heading : null,
      accuracyM: position.accuracy,
      recordedAt: position.timestamp,
    );
  }
}
