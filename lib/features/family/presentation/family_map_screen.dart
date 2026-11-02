import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/providers.dart';
import '../../../core/network/map_tile_provider.dart';
import '../application/family_geofence_shapes.dart';
import '../application/family_map_points.dart';
import '../application/family_providers.dart';
import '../data/family_models.dart';

/// A live map of the current family's members — the mobile mirror of the
/// "خريطة حية" card on the web app's FamilyTrackingPage.vue: markers for
/// whoever has a visible `latest_location` right now, plus a read-only
/// overlay of the family's safe zones (circle and polygon shapes alike —
/// see `family_geofence_shapes.dart`), and a floating action button (shown
/// only to accounts holding `family_tracking.create`, mirroring
/// `FamilyGeofencePolicy::create()`) into `SafeZoneEditorScreen` for adding
/// a new zone — circle or polygon, via that screen's own shape toggle —
/// plus (for accounts holding `family_tracking.edit` or
/// `family_tracking.delete`) an app bar action into `SafeZonesListScreen`
/// for editing/deleting existing ones — the map itself stays
/// read-only-plus-add, since `flutter_map` has no built-in tap-a-shape
/// hit-testing for `CircleLayer`/`PolygonLayer` (see that list screen's
/// own docblock). No route history yet. Likewise QR device pairing is not
/// part of this screen.
///
/// Uses flutter_map + raw OpenStreetMap raster tiles rather than
/// google_maps_flutter: no API key/billing account to provision for a
/// project that has none configured yet, and it keeps the same
/// no-proprietary-map-vendor posture the web app already has with
/// Leaflet.
class FamilyMapScreen extends ConsumerStatefulWidget {
  const FamilyMapScreen({super.key});

  @override
  ConsumerState<FamilyMapScreen> createState() => _FamilyMapScreenState();
}

class _FamilyMapScreenState extends ConsumerState<FamilyMapScreen> {
  final _mapController = MapController();

  // Baghdad — a reasonable default center when no member has a location
  // yet, rather than the (0, 0) Atlantic default most map widgets fall
  // back to. Purely a starting viewport; nothing is plotted here.
  static const _defaultCenter = LatLng(33.3152, 44.3661);

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(familyMembersProvider);
    // Safe zones are genuinely optional dressing on this screen — a family
    // with none yet (or a transient failure fetching them) should still
    // show member markers, so this one is read with .valueOrNull instead
    // of another .when() branch that could blank the whole map over a
    // zones-only error.
    final geofences = ref.watch(familyGeofencesProvider).valueOrNull ??
        const <FamilyGeofenceModel>[];
    final user = ref.watch(authControllerProvider).user;
    // Mirrors FamilyGeofencePolicy::create() — the exact permission
    // StoreFamilyGeofenceRequest checks server-side — so this FAB never
    // appears just to 403 on tap for an account without it.
    final canCreateSafeZone =
        user != null && user.permissions.contains('family_tracking.create');
    // Mirrors FamilyGeofencePolicy::update()/delete() — this app bar
    // action just opens a list, and every row inside gates its own
    // edit/delete button on the matching permission individually, but
    // there's no point showing the entry point at all to an account with
    // neither capability (it would only ever see a read-only duplicate of
    // what this map already shows).
    final canManageSafeZones = user != null &&
        (user.permissions.contains('family_tracking.edit') ||
            user.permissions.contains('family_tracking.delete'));

    return Scaffold(
      appBar: AppBar(
        title: const Text('خريطة العائلة'),
        actions: [
          if (canManageSafeZones)
            IconButton(
              icon: const Icon(Icons.edit_location_alt_outlined),
              tooltip: 'إدارة المناطق الآمنة',
              onPressed: () => context.push('/family/safe-zones'),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: () {
              ref.invalidate(familyMembersProvider);
              ref.invalidate(familyGeofencesProvider);
            },
          ),
        ],
      ),
      body: membersAsync.when(
        data: (members) => _Map(
          points: familyMapPoints(members),
          zones: familyGeofenceShapes(geofences),
          controller: _mapController,
          defaultCenter: _defaultCenter,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('تعذر تحميل مواقع أفراد العائلة: $error',
                textAlign: TextAlign.center),
          ),
        ),
      ),
      floatingActionButton: canCreateSafeZone
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/family/safe-zones/new'),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('منطقة آمنة'),
            )
          : null,
    );
  }
}

class _Map extends StatelessWidget {
  const _Map(
      {required this.points,
      required this.zones,
      required this.controller,
      required this.defaultCenter});

  final List<FamilyMapPoint> points;
  final List<FamilyGeofenceDrawing> zones;
  final MapController controller;
  final LatLng defaultCenter;

  @override
  Widget build(BuildContext context) {
    final initialCenter = points.isEmpty
        ? defaultCenter
        : LatLng(
            points.map((p) => p.latitude).reduce((a, b) => a + b) /
                points.length,
            points.map((p) => p.longitude).reduce((a, b) => a + b) /
                points.length,
          );

    return Stack(
      children: [
        FlutterMap(
          mapController: controller,
          options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: points.isEmpty ? 6 : 13),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.eyoonak.app',
              tileProvider: PublicMapTileProvider(),
            ),
            // Safe zones drawn before the marker layer so member markers
            // always render on top of (never hidden behind) a zone's fill.
            CircleLayer(
              circles: [
                for (final zone in zones)
                  if (zone.shape case final FamilyGeofenceCircle circle)
                    CircleMarker(
                      point: LatLng(circle.centerLat, circle.centerLng),
                      radius: circle.radiusMeters,
                      useRadiusInMeter: true,
                      color: Colors.blue.withValues(alpha: 0.12),
                      borderColor: Colors.blue,
                      borderStrokeWidth: 2,
                    ),
              ],
            ),
            PolygonLayer(
              polygons: [
                for (final zone in zones)
                  if (zone.shape case final FamilyGeofencePolygon polygon)
                    Polygon(
                      points: [
                        for (final vertex in polygon.points)
                          LatLng(vertex.lat, vertex.lng)
                      ],
                      color: Colors.blue.withValues(alpha: 0.12),
                      borderColor: Colors.blue,
                      borderStrokeWidth: 2,
                    ),
              ],
            ),
            MarkerLayer(
              markers: [
                for (final point in points)
                  Marker(
                    point: LatLng(point.latitude, point.longitude),
                    width: 44,
                    height: 44,
                    child: _MemberMarker(point: point),
                  ),
              ],
            ),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors')
              ],
            ),
          ],
        ),
        if (points.isEmpty)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text(
                      'ماكو موقع حي متاح حالياً. أضف أفراد العائلة واربط أجهزتهم، ثم شغّل مشاركة الموقع من الجهاز بموافقة صاحبه.',
                      textAlign: TextAlign.center),
                  TextButton(
                      onPressed: () => context.push('/family'),
                      child: const Text('أفراد العائلة وربط الأجهزة')),
                ]),
              ),
            ),
          ),
      ],
    );
  }
}

class _MemberMarker extends StatelessWidget {
  const _MemberMarker({required this.point});

  final FamilyMapPoint point;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetails(context),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: const Icon(Icons.person, color: Colors.white, size: 22),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    final member = point.member;
    final battery = member.latestLocation?.batteryLevel;

    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(member.fullName,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(member.relationship),
              const SizedBox(height: 8),
              if (battery != null) Text('البطارية: $battery%'),
            ],
          ),
        ),
      ),
    );
  }
}
