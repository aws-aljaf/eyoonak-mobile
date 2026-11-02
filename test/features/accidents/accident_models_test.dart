import 'package:fleet_saas_driver/features/accidents/data/accident_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Accident.fromJson', () {
    test('parses a full AccidentResource payload, including photos and police report', () {
      final accident = Accident.fromJson({
        'id': 1,
        'company_id': 3,
        'vehicle_id': 5,
        'driver_id': 7,
        'trip_id': 9,
        'occurred_at': '2026-09-12T10:00:00Z',
        'location_address': 'بغداد - الكرادة',
        'lat': 33.3,
        'lng': 44.4,
        'description': 'اصطدام بسيط',
        'damage_description': 'خدش بالمصد الأمامي',
        'third_party_info': {'note': 'سائق آخر متعاون'},
        'police_report_url': 'https://api.example.iq/files/police?signature=...',
        'photos': [
          {'download_url': 'https://api.example.iq/files/p1', 'mime_type': 'image/jpeg'},
        ],
        'estimated_cost': 150000,
        'status': 'under_review',
        'created_at': '2026-09-12T10:05:00Z',
      });

      expect(accident.id, 1);
      expect(accident.vehicleId, 5);
      expect(accident.driverId, 7);
      expect(accident.tripId, 9);
      expect(accident.locationAddress, 'بغداد - الكرادة');
      expect(accident.lat, 33.3);
      expect(accident.lng, 44.4);
      expect(accident.description, 'اصطدام بسيط');
      expect(accident.damageDescription, 'خدش بالمصد الأمامي');
      expect(accident.policeReportUrl, isNotNull);
      expect(accident.photos, hasLength(1));
      expect(accident.photos.first.mimeType, 'image/jpeg');
      expect(accident.estimatedCost, 150000);
      expect(accident.status, 'under_review');
      expect(accident.statusLabel, 'قيد المراجعة');
    });

    test('tolerates a freshly-filed report with no trip/photos/police report/cost', () {
      final accident = Accident.fromJson({
        'id': 2,
        'vehicle_id': 5,
        'driver_id': 7,
        'occurred_at': '2026-09-12T10:00:00Z',
        'description': 'اصطدام بسيط',
        'status': 'reported',
      });

      expect(accident.tripId, isNull);
      expect(accident.photos, isEmpty);
      expect(accident.policeReportUrl, isNull);
      expect(accident.estimatedCost, isNull);
      expect(accident.statusLabel, 'تم الإبلاغ');
    });

    test('falls back to the raw status string when it is not one of the known values', () {
      final accident = Accident.fromJson({
        'id': 3,
        'vehicle_id': 5,
        'driver_id': 7,
        'description': 'x',
        'status': 'something_new',
      });

      expect(accident.statusLabel, 'something_new');
    });
  });
}
