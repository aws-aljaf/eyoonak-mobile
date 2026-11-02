import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/providers.dart';
import '../application/driver_documents_provider.dart';
import '../data/driver_document.dart';

/// "مستنداتي" — a first frontend for `DriverController::documents()`
/// (backend/app/Http/Controllers/Api/V1/Fleet/DriverController.php),
/// verified directly against that controller, `DriverPolicy`, and
/// `SecureFileService` before building this: fully built and authorized
/// (a driver reading their own record, same ownership fallback `show()`
/// already relies on — see `DriversApi.documents()`'s docblock) since the
/// Phase 2 fleet module, but unreachable from this app until now — the
/// same "server-ready capability, no mobile frontend ever called it" gap
/// PR #49/#50 each found elsewhere.
///
/// Read-only by design: uploading a document requires `drivers.edit`
/// (`DriverPolicy::manageDocuments`), an RBAC permission scoped to
/// fleet/office staff, never a driver account — so unlike almost every
/// other screen in this app, there is deliberately no "add" action here at
/// all, not even a disabled one.
///
/// Reached only from `ProfileScreen`'s `_ProfileDetails` (i.e. only when a
/// driver profile actually exists for this account — see that widget),
/// with the driver's own id passed straight through via the route's path
/// parameter.
///
/// **Tapping a document downloads and shares it, never opens `downloadUrl`
/// directly** — that link requires an `Authorization` header an external
/// browser tab never carries (see `DriverDocument`'s own docblock for the
/// full corrected picture, and `DriversApi.downloadDocument()` for the
/// fix). This replaces an earlier `url_launcher` open that shipped with
/// this screen and would 401 in practice.
class DriverDocumentsScreen extends ConsumerWidget {
  const DriverDocumentsScreen({super.key, required this.driverId});

  final int driverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentsAsync = ref.watch(driverDocumentsProvider(driverId));

    return Scaffold(
      appBar: AppBar(title: const Text('مستنداتي')),
      body: documentsAsync.when(
        data: (documents) => _DocumentList(documents: documents),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(driverDocumentsProvider(driverId)),
        ),
      ),
    );
  }
}

class _DocumentList extends StatelessWidget {
  const _DocumentList({required this.documents});

  final List<DriverDocument> documents;

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) {
      return const Center(child: Text('لا توجد مستندات مرفوعة بعد.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: documents.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _DocumentCard(document: documents[index]),
    );
  }
}

/// One document row — a `ConsumerStatefulWidget` (not `StatelessWidget`,
/// unlike the rest of this screen) purely to track its own "downloading
/// now" spinner, same "one loading flag per row" pattern
/// `_ExportCard`/`_ExportCardState` in `admin_report_exports_screen.dart`
/// established for the identical download-then-share flow.
class _DocumentCard extends ConsumerStatefulWidget {
  const _DocumentCard({required this.document});

  final DriverDocument document;

  @override
  ConsumerState<_DocumentCard> createState() => _DocumentCardState();
}

class _DocumentCardState extends ConsumerState<_DocumentCard> {
  bool _opening = false;

  Future<void> _open() async {
    final document = widget.document;

    if (document.downloadUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رابط المستند غير متاح')));
      return;
    }

    setState(() => _opening = true);

    try {
      final file = await ref.read(driversApiProvider).downloadDocument(document);
      await Share.shareXFiles([XFile(file.path)]);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تنزيل المستند: $error')));
      }
    } finally {
      if (mounted) {
        setState(() => _opening = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final document = widget.document;
    final expired = _isExpired(document.expiryDate);

    return Card(
      child: ListTile(
        leading: Icon(_mimeIcon(document.mimeType), color: expired ? Colors.red.shade700 : null),
        title: Text(document.typeLabel),
        subtitle: Text([
          if (document.expiryDate != null)
            expired ? 'منتهي الصلاحية بتاريخ ${document.expiryDate}' : 'ينتهي بتاريخ ${document.expiryDate}',
          if (document.sizeBytes != null) _formatSize(document.sizeBytes!),
        ].join(' • ')),
        trailing: _opening
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.ios_share),
        onTap: _opening ? null : _open,
      ),
    );
  }

  bool _isExpired(String? isoDate) {
    if (isoDate == null) return false;

    final parsed = DateTime.tryParse(isoDate);

    return parsed != null && parsed.isBefore(DateTime.now());
  }

  IconData _mimeIcon(String? mimeType) {
    if (mimeType == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (mimeType != null && mimeType.startsWith('image/')) return Icons.image_outlined;

    return Icons.insert_drive_file_outlined;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} كيلوبايت';
    }

    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} ميغابايت';
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('تعذر تحميل المستندات: $message', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
          ],
        ),
      ),
    );
  }
}
