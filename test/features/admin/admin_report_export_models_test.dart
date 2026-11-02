import 'package:fleet_saas_driver/features/admin/data/admin_report_export_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdminReportExport.fromJson', () {
    test('parses a completed export with a download link', () {
      final export = AdminReportExport.fromJson({
        'id': 5,
        'type': 'fleet',
        'format': 'pdf',
        'status': 'completed',
        'filters': {'from': '2026-09-01', 'to': '2026-09-30'},
        'download_url': 'https://api.example.test/v1/files/abc?signature=xyz',
        'completed_at': '2026-09-19T10:00:00Z',
        'created_at': '2026-09-19T09:55:00Z',
      });

      expect(export.id, 5);
      expect(export.type, 'fleet');
      expect(export.format, 'pdf');
      expect(export.status, 'completed');
      expect(export.filters['from'], '2026-09-01');
      expect(export.downloadUrl, isNotNull);
      expect(export.completedAt, isNotNull);
      expect(export.isReady, isTrue);
    });

    test('a pending export has no download link and is not ready', () {
      final export = AdminReportExport.fromJson({
        'id': 6,
        'type': 'drivers',
        'format': 'csv',
        'status': 'pending',
        'filters': <String, dynamic>{},
        'created_at': '2026-09-19T09:55:00Z',
      });

      expect(export.downloadUrl, isNull);
      expect(export.completedAt, isNull);
      expect(export.errorMessage, isNull);
      expect(export.isReady, isFalse);
    });

    test('a failed export carries its error message but no download link', () {
      final export = AdminReportExport.fromJson({
        'id': 7,
        'type': 'financial',
        'format': 'excel',
        'status': 'failed',
        'filters': <String, dynamic>{},
        'error_message': 'تعذر توليد الملف',
        'created_at': '2026-09-19T09:55:00Z',
      });

      expect(export.status, 'failed');
      expect(export.errorMessage, 'تعذر توليد الملف');
      expect(export.isReady, isFalse);
    });
  });
}
