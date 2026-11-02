import 'package:fleet_saas_driver/features/admin/data/admin_report_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdminReport.fromJson', () {
    test('parses a full ReportDataService payload (fleet shape)', () {
      final report = AdminReport.fromJson({
        'type': 'fleet',
        'generated_at': '2026-09-17T10:00:00Z',
        'filters': {'from': '2026-09-01', 'to': '2026-09-17'},
        'summary': {'إجمالي المركبات': 12, 'نشطة': 9},
        'columns': {'plate_number': 'رقم اللوحة', 'status': 'الحالة'},
        'rows': [
          {'plate_number': 'ABC-123', 'status': 'active'},
          {'plate_number': 'XYZ-999', 'status': null},
        ],
      });

      expect(report.type, 'fleet');
      expect(report.generatedAt, isNotNull);
      expect(report.filterFrom, '2026-09-01');
      expect(report.filterTo, '2026-09-17');
      expect(report.summary, {'إجمالي المركبات': 12, 'نشطة': 9});
      expect(report.columns, {'plate_number': 'رقم اللوحة', 'status': 'الحالة'});
      expect(report.rows.length, 2);
      expect(report.rows.first['plate_number'], 'ABC-123');
      expect(report.rows.last['status'], isNull);
    });

    test('tolerates an empty rows/summary payload (no data in range)', () {
      final report = AdminReport.fromJson({
        'type': 'trips',
        'generated_at': '2026-09-17T10:00:00Z',
        'filters': {'from': '2026-09-01', 'to': '2026-09-17'},
        'summary': <String, dynamic>{},
        'columns': {'trip_number': 'رقم الرحلة'},
        'rows': <dynamic>[],
      });

      expect(report.summary, isEmpty);
      expect(report.rows, isEmpty);
    });

    test('tolerates a missing generated_at', () {
      final report = AdminReport.fromJson({
        'type': 'drivers',
        'filters': <String, dynamic>{},
        'summary': <String, dynamic>{},
        'columns': <String, dynamic>{},
        'rows': <dynamic>[],
      });

      expect(report.generatedAt, isNull);
      expect(report.filterFrom, isNull);
      expect(report.filterTo, isNull);
    });
  });

  test('adminReportTypeLabels covers all six ReportDataService report types', () {
    expect(
      adminReportTypeLabels.keys.toSet(),
      {'fleet', 'drivers', 'trips', 'fuel', 'maintenance', 'financial'},
    );
  });
}
