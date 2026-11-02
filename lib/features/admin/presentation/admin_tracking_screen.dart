import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../application/admin_tracking_map_points.dart';
import '../application/admin_tracking_providers.dart';
import '../data/admin_vehicle_models.dart';

/// A live map of the whole company's fleet — the mobile mirror of the web
/// dashboard's `TrackingPage.vue`. Reached via `AdminHomeScreen`'s
/// "التتبع الحي" tile, gated on `tracking.view` — see `AdminTrackingApi`'s
/// docblock for the exact endpoint/permission this consumes.
///
/// **Polling, not a websocket subscription.** `TrackingPage.vue` on the
/// web mixes a 30-second poll of `GET /locations/live` with an Echo/Reverb
/// broadcast subscription for near-real-time marker nudges in between —
/// its own comment there is explicit that "the live map's correctness
/// must never depend solely on the WebSocket connection staying up." This
/// app has no Echo/Pusher client dependency at all yet, so it takes only
/// the correctness-bearing half of that design: a plain 30-second
/// `Timer.periodic` invalidating `adminTrackingProvider` (same timer
/// pattern as `DevicePairingGenerateScreen`'s countdown ticker — created
/// in `initState`, cancelled in `dispose`). Adding a push channel later is
/// possible without changing this screen's data flow (the backend event
/// already exists), but it's a deliberate follow-up, not bundled here.
///
/// Uses `flutter_map` + raw OpenStreetMap raster tiles, same as
/// `FamilyMapScreen` — already a dependency, already proven, no
/// proprietary map vendor/API key to provision.
class AdminTrackingScreen extends ConsumerStatefulWidget {
  const AdminTrackingScreen({super.key});

  @override
  ConsumerState<AdminTrackingScreen> createState() => _AdminTrackingScreenState();
}

class _AdminTrackingScreenState extends ConsumerState<AdminTrackingScreen> {
  static const _pollInterval = Duration(seconds: 30);

  final _mapController = MapController();
  Timer? _pollTimer;

  // Baghdad — same reasonable default center as `FamilyMapScreen` uses
  // when nothing has a location yet, rather than the (0, 0) Atlantic
  // default most map widgets fall back to.
  static const _defaultCenter = LatLng(33.3152, 44.3661);

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (mounted) ref.invalidate(adminTrackingProvider);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vehiclesAsync = ref.watch(adminTrackingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('التتبع الحي للأسطول'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: () => ref.invalidate(adminTrackingProvider),
          ),
        ],
      ),
      body: vehiclesAsync.when(
        data: (vehicles) => _Map(
          points: adminTrackingMapPoints(vehicles),
          controller: _mapController,
          defaultCenter: _defaultCenter,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('تعذر تحميل مواقع الأسطول: $error', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(adminTrackingProvider),
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Map extends StatelessWidget {
  const _Map({required this.points, required this.controller, required this.defaultCenter});

  final List<AdminTrackingMapPoint> points;
  final MapController controller;
  final LatLng defaultCenter;

  @override
  Widget build(BuildContext context) {
    final initialCenter = points.isEmpty
        ? defaultCenter
        : LatLng(
            points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length,
            points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length,
          );

    return Stack(
      children: [
        FlutterMap(
          mapController: controller,
          options: MapOptions(initialCenter: initialCenter, initialZoom: points.isEmpty ? 6 : 12),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.eyoonak.fleet_saas_driver',
            ),
            MarkerLayer(
              markers: [
                for (final point in points)
                  Marker(
                    point: LatLng(point.latitude, point.longitude),
                    width: 44,
                    height: 44,
                    child: _VehicleMarker(point: point),
                  ),
              ],
            ),
            const RichAttributionWidget(
              attributions: [TextSourceAttribution('OpenStreetMap contributors')],
            ),
          ],
        ),
        Positioned(
          top: 16,
          left: 16,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text('${points.length} مركبة على الخريطة'),
            ),
          ),
        ),
        if (points.isEmpty)
          const Positioned(
            top: 64,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'لا توجد مواقع متاحة حاليًا لأي مركبة.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Color-coded by `AdminVehicleLocation.status` using the exact same enum
/// values/labels as `vehicleStatusLabels`
/// (features/admin/data/admin_vehicle_models.dart) — reused rather than
/// re-declared a third time, since both `AdminVehicle.status` and this
/// resource's `status` mirror the identical backend enum.
Color _statusColor(String? status) {
  switch (status) {
    case 'moving':
      return Colors.green;
    case 'active':
      return Colors.blue;
    case 'idle':
      return Colors.orange;
    case 'maintenance':
      return Colors.grey;
    case 'out_of_service':
      return Colors.red;
    default:
      return Colors.blueGrey;
  }
}

class _VehicleMarker extends StatelessWidget {
  const _VehicleMarker({required this.point});

  final AdminTrackingMapPoint point;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetails(context),
      child: Container(
        decoration: BoxDecoration(
          color: _statusColor(point.vehicle.status),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: const Icon(Icons.local_shipping, color: Colors.white, size: 20),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    final vehicle = point.vehicle;
    final statusLabel = vehicle.status != null ? vehicleStatusLabels[vehicle.status] ?? vehicle.status! : null;

    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vehicle.plateNumber.isEmpty ? 'مركبة #${vehicle.vehicleId}' : vehicle.plateNumber,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              if (statusLabel != null) Text('الحالة: $statusLabel'),
              if (vehicle.currentDriverId != null) Text('السائق: #${vehicle.currentDriverId}'),
              if (vehicle.lastLocationAt != null) Text('آخر تحديث: ${_formatDateTime(vehicle.lastLocationAt!)}'),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime dt) {
  final local = dt.toLocal();
  final date = '${local.day}/${local.month}/${local.year}';
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');

  return '$date $hour:$minute';
}
