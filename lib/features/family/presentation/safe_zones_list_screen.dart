import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_exception.dart';
import '../application/family_providers.dart';
import '../data/family_models.dart';

/// The management counterpart to `FamilyMapScreen`'s read-only zone
/// overlay — a plain list (rather than tap-a-shape-on-the-map, which
/// `flutter_map`'s `CircleLayer`/`PolygonLayer` don't support hit-testing
/// for out of the box) of every safe zone, active or not, with edit and
/// delete actions. Mirrors the web app's `SafeZonesPage.vue`, which is
/// likewise a list rather than an on-map picker for management (only
/// *creating* a new zone uses the map, on both platforms).
///
/// **Edit is offered for both shapes** — `SafeZoneEditorScreen` can now
/// create *and* edit circle and polygon zones alike, so every row shows
/// an edit action, gated only by permission (below), not by shape.
/// Delete has no shape restriction either: destroying a zone never
/// depends on this app being able to render it.
///
/// Both actions are additionally gated per-row on the exact backend
/// permission the corresponding endpoint checks — `family_tracking.edit`
/// for `PUT /family-geofences/{id}` and `family_tracking.delete` for
/// `DELETE /family-geofences/{id}` (verified directly against
/// `FamilyGeofencePolicy::update()`/`delete()` — two separate permissions,
/// neither the same as `family_tracking.create` that gates adding a zone
/// at all).
class SafeZonesListScreen extends ConsumerWidget {
  const SafeZonesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final geofencesAsync = ref.watch(familyGeofencesProvider);
    final user = ref.watch(authControllerProvider).user;
    final canCreate = user != null && user.permissions.contains('family_tracking.create');
    final canEdit = user != null && user.permissions.contains('family_tracking.edit');
    final canDelete = user != null && user.permissions.contains('family_tracking.delete');

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المناطق الآمنة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: () => ref.invalidate(familyGeofencesProvider),
          ),
        ],
      ),
      body: geofencesAsync.when(
        data: (geofences) => _ZonesList(geofences: geofences, canEdit: canEdit, canDelete: canDelete),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(familyGeofencesProvider),
        ),
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/family/safe-zones/new'),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('منطقة جديدة'),
            )
          : null,
    );
  }
}

class _ZonesList extends StatelessWidget {
  const _ZonesList({required this.geofences, required this.canEdit, required this.canDelete});

  final List<FamilyGeofenceModel> geofences;
  final bool canEdit;
  final bool canDelete;

  @override
  Widget build(BuildContext context) {
    if (geofences.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: const Center(child: Text('لا توجد مناطق آمنة بعد.')),
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: geofences.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _ZoneCard(
        zone: geofences[index],
        canEdit: canEdit,
        canDelete: canDelete,
      ),
    );
  }
}

class _ZoneCard extends ConsumerStatefulWidget {
  const _ZoneCard({required this.zone, required this.canEdit, required this.canDelete});

  final FamilyGeofenceModel zone;
  final bool canEdit;
  final bool canDelete;

  @override
  ConsumerState<_ZoneCard> createState() => _ZoneCardState();
}

class _ZoneCardState extends ConsumerState<_ZoneCard> {
  // Same non-server-enforced list as SafeZoneEditorScreen — duplicated
  // rather than shared, matching how small single-purpose label maps are
  // handled elsewhere in this feature (e.g. that screen's own
  // `_typeLabels`): four entries, unlikely to change, not worth a shared
  // constants file for.
  static const _typeLabels = {'home': 'المنزل', 'school': 'المدرسة', 'club': 'النادي', 'other': 'أخرى'};

  bool _deleting = false;

  bool get _isCircle => widget.zone.shape is FamilyGeofenceCircle;

  String get _shapeSummary {
    final shape = widget.zone.shape;

    if (shape case FamilyGeofenceCircle(:final radiusMeters)) {
      return 'دائرية — نصف القطر ${radiusMeters.round()} متر';
    }

    if (shape case FamilyGeofencePolygon(:final points)) {
      return 'مضلّعة — ${points.length} نقاط';
    }

    return '';
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المنطقة الآمنة'),
        content: Text('سيتم حذف "${widget.zone.name}" نهائيًا ولا يمكن التراجع عن ذلك. هل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _deleting = true);

    try {
      final familyId = ref.read(selectedFamilyIdProvider);

      await ref.read(familyApiProvider).deleteGeofence(geofenceId: widget.zone.id, familyId: familyId);
      ref.invalidate(familyGeofencesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف المنطقة الآمنة')));
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حذف المنطقة: $error')));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _edit() async {
    await context.push('/family/safe-zones/${widget.zone.id}/edit', extra: widget.zone);
  }

  @override
  Widget build(BuildContext context) {
    final zone = widget.zone;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: zone.isActive ? null : Colors.grey.shade300,
          child: Icon(_isCircle ? Icons.radio_button_unchecked : Icons.pentagon_outlined),
        ),
        title: Text(zone.name),
        subtitle: Text([
          _typeLabels[zone.type] ?? zone.type,
          _shapeSummary,
          if (!zone.isActive) 'معطَّلة',
        ].join(' • ')),
        trailing: _deleting
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.canEdit)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'تعديل',
                      onPressed: _edit,
                    ),
                  if (widget.canDelete)
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
                      tooltip: 'حذف',
                      onPressed: _confirmDelete,
                    ),
                ],
              ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('تعذر تحميل المناطق الآمنة: $message', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
