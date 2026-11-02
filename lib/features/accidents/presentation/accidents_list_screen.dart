import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/providers.dart';
import '../application/accidents_providers.dart';
import '../data/accident_models.dart';

/// "حوادثي" — `AccidentController::index()`
/// (backend/app/Http/Controllers/Api/V1/Trips/AccidentController.php),
/// verified directly against that controller, `AccidentPolicy`, and
/// `StoreAccidentRequest` before building this. `AccidentPolicy::viewAny()`
/// grants any account with a linked driver profile access with no RBAC
/// permission at all, and `index()` itself narrows server-side to that
/// driver's own accidents in that case (see `AccidentsApi.index()`'s
/// docblock) — same "no permission gate on the route/screen, the API call
/// already enforces the real boundary" convention as every family screen
/// in this app.
///
/// Read + report only, no edit: `AccidentPolicy::update()` requires
/// `accidents.edit` (RBAC, office/management review workflow), a
/// permission no driver account holds — a filed report is a fixed record
/// from this app's point of view, same "no edit UI" precedent as
/// `DriverDocumentsScreen`.
///
/// Reached only from `ProfileScreen`'s `_ProfileDetails` (only when a
/// driver profile exists for this account), matching that screen's other
/// driver-only entry points ("مستنداتي", PR #51).
///
/// **Photo/police-report chips download and share, never open
/// `download_url` directly** — same fix, same reason, as
/// `DriverDocumentsScreen` (see `AccidentsApi.downloadFile()`'s docblock):
/// that link needs an `Authorization` header an external browser tab never
/// carries. Replaces an earlier `url_launcher` open that shipped with this
/// screen and would 401 in practice.
class AccidentsListScreen extends ConsumerWidget {
  const AccidentsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accidentsAsync = ref.watch(myAccidentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('حوادثي')),
      body: accidentsAsync.when(
        data: (accidents) => _AccidentList(accidents: accidents),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(myAccidentsProvider),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_alert_outlined),
        label: const Text('الإبلاغ عن حادث'),
        onPressed: () async {
          // Plain `context.push(...)` + unconditional invalidate on return
          // (not a typed `push<bool>`/`pop<bool>` result) — this project
          // has no prior use of go_router's generic push/pop result
          // passing, and there's no local Flutter SDK here to verify it
          // against the pinned go_router version (PR #46's lesson: avoid
          // an unverified API when there's no way to test it before CI).
          // A harmless extra fetch when the driver cancels without
          // submitting is a fine trade for that certainty.
          await context.push('/profile/accidents/report');
          ref.invalidate(myAccidentsProvider);
        },
      ),
    );
  }
}

class _AccidentList extends StatelessWidget {
  const _AccidentList({required this.accidents});

  final List<Accident> accidents;

  @override
  Widget build(BuildContext context) {
    if (accidents.isEmpty) {
      return const Center(child: Text('لا توجد حوادث مسجَّلة بعد.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: accidents.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _AccidentCard(accident: accidents[index]),
    );
  }
}

/// A `ConsumerStatefulWidget` (not `StatelessWidget`, unlike the rest of
/// this screen) purely to track which one of its own photo/police-report
/// chips is downloading right now — same "download-then-share" flow as
/// `_DocumentCard` in `driver_documents_screen.dart`, adapted here for a
/// card that can offer more than one downloadable attachment at once.
class _AccidentCard extends ConsumerStatefulWidget {
  const _AccidentCard({required this.accident});

  final Accident accident;

  @override
  ConsumerState<_AccidentCard> createState() => _AccidentCardState();
}

class _AccidentCardState extends ConsumerState<_AccidentCard> {
  /// The single `download_url` currently being fetched, or `null` — a
  /// driver reporting/reviewing their own accidents taps one attachment at
  /// a time, so one in-flight flag (rather than a `Set`) is enough to
  /// disable just that chip and show its own spinner.
  String? _downloadingUrl;

  Future<void> _share(String url) async {
    setState(() => _downloadingUrl = url);

    try {
      final file = await ref.read(accidentsApiProvider).downloadFile(url);
      await Share.shareXFiles([XFile(file.path)]);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تنزيل الملف: $error')));
      }
    } finally {
      if (mounted) {
        setState(() => _downloadingUrl = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accident = widget.accident;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    accident.description,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Chip(label: Text(accident.statusLabel), visualDensity: VisualDensity.compact),
              ],
            ),
            const SizedBox(height: 8),
            if (accident.occurredAt != null)
              Row(
                children: [
                  const Icon(Icons.event_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(_formatTimestamp(accident.occurredAt!), style: const TextStyle(color: Colors.grey)),
                ],
              ),
            if (accident.locationAddress != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.place_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(child: Text(accident.locationAddress!, style: const TextStyle(color: Colors.grey))),
                ],
              ),
            ],
            if (accident.estimatedCost != null) ...[
              const SizedBox(height: 4),
              Text('التكلفة التقديرية: ${accident.estimatedCost!.toStringAsFixed(0)}'),
            ],
            if (accident.photos.isNotEmpty || accident.policeReportUrl != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ...accident.photos.map(
                    (photo) => ActionChip(
                      avatar: _downloadingUrl == photo.downloadUrl
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.image_outlined, size: 16),
                      label: const Text('صورة'),
                      onPressed: _downloadingUrl != null ? null : () => _share(photo.downloadUrl),
                    ),
                  ),
                  if (accident.policeReportUrl != null)
                    ActionChip(
                      avatar: _downloadingUrl == accident.policeReportUrl
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.description_outlined, size: 16),
                      label: const Text('محضر الشرطة'),
                      onPressed: _downloadingUrl != null ? null : () => _share(accident.policeReportUrl!),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final local = dt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');

    return '$d/$m $h:$min';
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
            Text('تعذر تحميل الحوادث: $message', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
          ],
        ),
      ),
    );
  }
}
