import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

class DeviceLocationSharing extends ChangeNotifier {
  DeviceLocationSharing(this.api, {this.sessionToken});
  final ApiClient api;
  final Future<String?> Function()? sessionToken;
  bool disposed = false;
  void changed() {
    if (!disposed) notifyListeners();
  }

  StreamSubscription<Position>? stream;
  int generation = 0;
  bool starting = false, sending = false;
  String? error;
  DateTime? lastSent;
  bool permissionBlocked = false, locationDisabled = false;
  bool? approximate;
  double? accuracyMeters;
  Future<bool> openPermissionSettings() => Geolocator.openAppSettings();
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
  bool get active => stream != null;
  Future<void> start() async {
    if (active || starting) return;
    starting = true;
    error = null;
    permissionBlocked = false;
    locationDisabled = false;
    approximate = null;
    accuracyMeters = null;
    changed();
    final current = ++generation;
    try {
      final token = await sessionToken?.call();
      if (current != generation) return;
      final sessionApi = sessionToken == null
          ? api
          : ApiClient(getToken: () => Future.value(token));
      final devices = await sessionApi.get('/auth/devices') as List;
      if (current != generation) return;
      final mine =
          devices.cast<Map>().where((v) => v['is_current'] == true).toList();
      final member = mine.isEmpty ? null : mine.first['family_member'] as Map?;
      final id = member?['id'];
      if (id is! int) {
        throw StateError(
            'اربط هذا الجهاز بأحد أفراد العائلة أولاً من خيار ربط الجهاز.');
      }
      final locationEnabled = await Geolocator.isLocationServiceEnabled();
      if (current != generation) return;
      if (!locationEnabled) {
        locationDisabled = true;
        throw StateError(
            'خدمة الموقع مطفأة. فعّلها من إعدادات الموقع ثم أعد المحاولة.');
      }
      var permission = await Geolocator.checkPermission();
      if (current != generation) return;
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (current != generation) return;
      if (permission == LocationPermission.deniedForever) {
        permissionBlocked = true;
        throw StateError(
            'إذن الموقع محظور. افتح إعدادات التطبيق واسمح بالموقع أثناء الاستخدام، ثم أعد المحاولة.');
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        throw StateError('السماح بالموقع مطلوب لبدء المشاركة.');
      }
      try {
        final accuracy = await Geolocator.getLocationAccuracy();
        if (current != generation) return;
        approximate = accuracy == LocationAccuracyStatus.reduced;
      } catch (_) {
        /* Precision reporting is not available on every platform. */
      }
      if (current != generation) return;
      final LocationSettings settings = defaultTargetPlatform ==
              TargetPlatform.android
          ? AndroidSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 25,
              intervalDuration: const Duration(seconds: 30),
              foregroundNotificationConfig: const ForegroundNotificationConfig(
                  notificationTitle: 'مشاركة الموقع مفعّلة',
                  notificationText:
                      'عيونك يشارك موقع هذا الجهاز مع العائلة. أوقف المشاركة من التطبيق.',
                  enableWakeLock: true, setOngoing: true))
          : const LocationSettings(
              accuracy: LocationAccuracy.high, distanceFilter: 25);
      stream = Geolocator.getPositionStream(locationSettings: settings).listen(
          (p) async {
        if (current != generation || sending) return;
        sending = true;
        accuracyMeters = p.accuracy;
        changed();
        try {
          await sessionApi.post('/device/location', data: {
            'id': const Uuid().v4(),
            'lat': p.latitude,
            'lng': p.longitude,
            'accuracy_meters': p.accuracy,
            'recorded_at': p.timestamp.toUtc().toIso8601String()
          });
          if (current == generation) {
            lastSent = DateTime.now();
            error = null;
            changed();
          }
        } on ApiException catch (e) {
          if (current == generation) {
            error = e.isNetwork
                ? 'لا يوجد اتصال؛ يُرسل الموقع التالي عند عودة الشبكة.'
                : e.message;
            if ([401, 403, 404].contains(e.statusCode)) await stop();
            changed();
          }
        } finally {
          sending = false;
        }
      }, onError: (Object e) {
        if (current == generation) {
          error = 'تعذرت قراءة الموقع. تحقق من خدمة الموقع والأذونات.';
          stop();
        }
      });
    } catch (e) {
      if (current == generation) {
        error = e is StateError
            ? e.message.toString()
            : e is ApiException
                ? e.message
                : 'تعذر بدء مشاركة الموقع.';
      }
    } finally {
      starting = false;
      changed();
    }
  }

  Future<void> stop() async {
    generation++;
    final old = stream;
    stream = null;
    lastSent = null;
    accuracyMeters = null;
    approximate = null;
    await old?.cancel();
    changed();
  }

  @override
  void dispose() {
    disposed = true;
    generation++;
    stream?.cancel();
    super.dispose();
  }
}

final deviceLocationSharingProvider =
    ChangeNotifierProvider<DeviceLocationSharing>((ref) {
  final service = DeviceLocationSharing(ref.read(apiClientProvider),
      sessionToken: ref.read(secureTokenStoreProvider).readToken);
  ref.listen(authControllerProvider, (previous, next) {
    if (previous?.user?.id != next.user?.id || !next.isAuthenticated) {
      unawaited(service.stop());
    }
  });
  return service;
});
