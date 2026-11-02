import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_saas_driver/core/network/api_client.dart';
import 'package:fleet_saas_driver/features/family/application/device_location_sharing.dart';

class DeviceApi extends ApiClient {
  DeviceApi(this.response) : super(getToken: () async => null);
  final Future<dynamic> response;
  @override
  Future<dynamic> get(String path,
          {Map<String, dynamic>? query, Map<String, dynamic>? headers}) =>
      response;
}

class PermissionLocation extends GeolocatorPlatform {
  LocationPermission permission = LocationPermission.deniedForever;
  bool enabled = true;
  int requests = 0, subscriptions = 0;
  Completer<LocationPermission>? pendingPermission;
  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async =>
      pendingPermission == null ? permission : await pendingPermission!.future;
  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return permission;
  }

  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async =>
      LocationAccuracyStatus.reduced;
  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    subscriptions++;
    return const Stream.empty();
  }
}

DeviceLocationSharing pairedService() =>
    DeviceLocationSharing(DeviceApi(Future.value([
      {
        'is_current': true,
        'family_member': {'id': 7}
      }
    ])));
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GeolocatorPlatform original;
  late PermissionLocation location;
  setUp(() {
    original = GeolocatorPlatform.instance;
    location = PermissionLocation();
    GeolocatorPlatform.instance = location;
  });
  tearDown(() => GeolocatorPlatform.instance = original);
  test('permanent denial exposes settings without repeated permission prompt',
      () async {
    final service = pairedService();
    await service.start();
    expect(service.permissionBlocked, isTrue);
    expect(service.active, isFalse);
    expect(location.requests, 0);
    expect(location.subscriptions, 0);
    service.dispose();
  });
  test('disabled location directs user to system location settings', () async {
    location.enabled = false;
    final service = pairedService();
    await service.start();
    expect(service.locationDisabled, isTrue);
    expect(service.permissionBlocked, isFalse);
    expect(location.subscriptions, 0);
    service.dispose();
  });
  test('approximate permission is labelled and cleared on stop', () async {
    location.permission = LocationPermission.whileInUse;
    final service = pairedService();
    await service.start();
    expect(service.approximate, isTrue);
    expect(location.subscriptions, 1);
    await service.stop();
    expect(service.approximate, isNull);
    service.dispose();
  });
  test('logout during permission check cannot request access or subscribe',
      () async {
    location.pendingPermission = Completer<LocationPermission>();
    final service = pairedService();
    final starting = service.start();
    await Future<void>.delayed(Duration.zero);
    await service.stop();
    location.pendingPermission!.complete(LocationPermission.denied);
    await starting;
    expect(location.requests, 0);
    expect(location.subscriptions, 0);
    expect(service.error, isNull);
    service.dispose();
  });
  test('unpaired device cannot start tracking or request GPS', () async {
    final service = DeviceLocationSharing(DeviceApi(Future.value([
      {'is_current': true, 'family_member': null}
    ])));
    await service.start();
    expect(service.active, isFalse);
    expect(service.error, isNotNull);
    service.dispose();
  });
  test('stop while looking up pairing prevents a location subscription',
      () async {
    final pending = Completer<dynamic>();
    final service = DeviceLocationSharing(DeviceApi(pending.future));
    final start = service.start();
    await service.stop();
    pending.complete([
      {
        'is_current': true,
        'family_member': {'id': 7}
      }
    ]);
    await start;
    expect(service.active, isFalse);
    expect(service.error, isNull);
    service.dispose();
  });
}
