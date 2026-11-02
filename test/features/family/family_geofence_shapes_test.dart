import 'package:fleet_saas_driver/features/family/application/family_geofence_shapes.dart';
import 'package:fleet_saas_driver/features/family/data/family_models.dart';
import 'package:flutter_test/flutter_test.dart';

FamilyGeofenceModel _geofence({
  required int id,
  required String name,
  required Map<String, dynamic> shapeJson,
  bool isActive = true,
}) {
  return FamilyGeofenceModel(
    id: id,
    name: name,
    type: 'home',
    shape: FamilyGeofenceShape.fromJson(shapeJson),
    isActive: isActive,
    notifyOnEntry: true,
    notifyOnExit: true,
  );
}

void main() {
  group('FamilyGeofenceShape.fromJson', () {
    test('a shape carrying radius_m is parsed as a circle', () {
      final shape = FamilyGeofenceShape.fromJson({'center_lat': 33.31, 'center_lng': 44.36, 'radius_m': 200});

      expect(shape, isA<FamilyGeofenceCircle>());
      final circle = shape as FamilyGeofenceCircle;
      expect(circle.centerLat, 33.31);
      expect(circle.centerLng, 44.36);
      expect(circle.radiusMeters, 200);
    });

    test('a shape carrying points is parsed as a polygon, preserving vertex order', () {
      final shape = FamilyGeofenceShape.fromJson({
        'points': [
          [33.30, 44.35],
          [33.30, 44.37],
          [33.32, 44.37],
        ],
      });

      expect(shape, isA<FamilyGeofencePolygon>());
      final polygon = shape as FamilyGeofencePolygon;
      expect(polygon.points, hasLength(3));
      expect(polygon.points.first, (lat: 33.30, lng: 44.35));
      expect(polygon.points.last, (lat: 33.32, lng: 44.37));
    });
  });

  group('familyGeofenceShapes', () {
    test('an inactive zone is left off the map entirely', () {
      final drawings = familyGeofenceShapes([
        _geofence(
          id: 1,
          name: 'معطّلة',
          shapeJson: {'center_lat': 33.3, 'center_lng': 44.3, 'radius_m': 100},
          isActive: false,
        ),
      ]);

      expect(drawings, isEmpty);
    });

    test('active circle and polygon zones both come through, preserving order', () {
      final drawings = familyGeofenceShapes([
        _geofence(
          id: 1,
          name: 'المنزل',
          shapeJson: {'center_lat': 33.3, 'center_lng': 44.3, 'radius_m': 150},
        ),
        _geofence(
          id: 2,
          name: 'الحي',
          shapeJson: {
            'points': [
              [33.30, 44.35],
              [33.30, 44.37],
              [33.32, 44.37],
            ],
          },
        ),
      ]);

      expect(drawings.map((d) => d.name), ['المنزل', 'الحي']);
      expect(drawings[0].shape, isA<FamilyGeofenceCircle>());
      expect(drawings[1].shape, isA<FamilyGeofencePolygon>());
    });

    test('a mix of active and inactive zones keeps only the active ones, preserving their relative order', () {
      final drawings = familyGeofenceShapes([
        _geofence(
          id: 1,
          name: 'نشطة أولى',
          shapeJson: {'center_lat': 1, 'center_lng': 2, 'radius_m': 50},
        ),
        _geofence(
          id: 2,
          name: 'معطّلة',
          shapeJson: {'center_lat': 3, 'center_lng': 4, 'radius_m': 50},
          isActive: false,
        ),
        _geofence(
          id: 3,
          name: 'نشطة ثانية',
          shapeJson: {'center_lat': 5, 'center_lng': 6, 'radius_m': 50},
        ),
      ]);

      expect(drawings.map((d) => d.name), ['نشطة أولى', 'نشطة ثانية']);
    });
  });
}
