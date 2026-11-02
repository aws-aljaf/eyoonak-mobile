import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_exception.dart';
import '../application/family_providers.dart';
import '../data/family_models.dart';

/// Creates or edits a family safe zone — either **circular** or
/// **polygon** shaped, both ways round now. The mobile counterpart to the
/// web app's from-scratch circle-picker on `SafeZonesPage.vue` for the
/// circle case, and the missing half of `FamilyMapScreen`'s read-only
/// zone overlay (PR #34) for both shapes (`FamilyGeofenceShape` already
/// read polygons back fine before this screen could create or edit one).
/// Also `SafeZonesListScreen`'s entry point for a brand-new zone.
///
/// `existingZone` being null is "create" (either shape, via the toggle in
/// `_buildShapeToggle`); non-null is "edit", of **whatever shape the zone
/// already is** — the toggle itself is still create-only (switching an
/// existing zone's shape entirely on edit has no clear use case and would
/// discard its current geometry, so it's simply not offered rather than
/// silently doing something surprising).
///
/// Polygon **creation and editing share the same interaction**: tapping
/// the map appends a vertex at the end of `_polygonPoints` in order, and
/// tapping an *existing* vertex marker removes just that one — no
/// drag-to-move gesture at all. Dragging one specific vertex precisely on
/// a small touch target is exactly the fiddly interaction `_radiusMeters`'s
/// plain **slider** (vs. the web app's drag-a-handle-around-the-edge
/// gesture) already avoids for the circle case, so the same reasoning
/// carries over here: tap-to-add/tap-to-remove are ordinary, thumb-friendly
/// gestures, precise vertex-nudging is not. Reshaping a polygon (moving a
/// vertex) is therefore a remove-then-re-add rather than a drag — since
/// a new vertex always appends at the *end* of the list rather than
/// reinserting at the removed one's position, the live map preview (which
/// always renders the exact current point order) is what tells you
/// whether the result still looks right, the same way it does while
/// drawing from scratch. `StoreFamilyGeofenceRequest` requires at least 3
/// points on create (verified directly against its validator); this
/// screen enforces the same floor on **edit** too even though
/// `UpdateFamilyGeofenceRequest` itself doesn't re-check it (see
/// `FamilyApi.updatePolygonGeofence()`'s docblock) — enforced here before
/// `_save()` ever calls the API either way, with the exact count shown so
/// the requirement is never a surprise at submit time.
class SafeZoneEditorScreen extends ConsumerStatefulWidget {
  const SafeZoneEditorScreen({super.key, this.existingZone});

  final FamilyGeofenceModel? existingZone;

  @override
  ConsumerState<SafeZoneEditorScreen> createState() => _SafeZoneEditorScreenState();
}

class _SafeZoneEditorScreenState extends ConsumerState<SafeZoneEditorScreen> {
  // Same fallback viewport as FamilyMapScreen, for the same reason: a
  // reasonable default center (Baghdad) rather than the (0, 0) Atlantic
  // most map widgets fall back to, until GPS resolves or the user taps.
  // Only ever used in create mode — edit mode always has a real center
  // from `existingZone` from the very first frame.
  static const _defaultCenter = LatLng(33.3152, 44.3661);

  // `type` has no server-side bound beyond `in:home,school,club,other`
  // (see StoreFamilyGeofenceRequest, and confirmed UpdateFamilyGeofenceRequest
  // allows changing it freely too) — this list is exhaustive, not a
  // starter subset.
  static const _typeLabels = {'home': 'المنزل', 'school': 'المدرسة', 'club': 'النادي', 'other': 'أخرى'};

  final _mapController = MapController();
  final _nameController = TextEditingController();

  bool get _isEditing => widget.existingZone != null;

  String _type = 'home';
  // In edit mode this is overwritten in initState to match whatever shape
  // the existing zone already is. In create mode it defaults to 'circle'
  // (the toggle is only built in create mode — see _buildShapeToggle)
  // since a circle is the faster, already-proven path for the common
  // case; polygon is an opt-in for whoever specifically needs one.
  String _shapeType = 'circle';
  LatLng? _center;
  // The backend enforces no min/max on radius_m at all (only `is_numeric`)
  // — this slider's [10, 2000] range is a purely client-side convention,
  // chosen to match the same "min 10" floor the web picker's own radius
  // input already uses, with an upper bound generous enough for a whole
  // neighborhood without inviting an accidental city-sized zone.
  double _radiusMeters = 200;
  final List<LatLng> _polygonPoints = [];
  bool _notifyOnEntry = true;
  bool _notifyOnExit = true;
  bool _saving = false;
  String? _errorMessage;

  bool get _isPolygonMode => _shapeType == 'polygon';

  @override
  void initState() {
    super.initState();

    final existing = widget.existingZone;

    if (existing == null) {
      _resolveInitialCenter();
      return;
    }

    _nameController.text = existing.name;
    _type = existing.type;
    _notifyOnEntry = existing.notifyOnEntry;
    _notifyOnExit = existing.notifyOnExit;

    if (existing.shape case FamilyGeofenceCircle(:final centerLat, :final centerLng, :final radiusMeters)) {
      _shapeType = 'circle';
      _center = LatLng(centerLat, centerLng);
      _radiusMeters = radiusMeters;
    } else if (existing.shape case FamilyGeofencePolygon(:final points)) {
      _shapeType = 'polygon';
      _polygonPoints.addAll([for (final point in points) LatLng(point.lat, point.lng)]);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _resolveInitialCenter() async {
    try {
      final position = await Geolocator.getCurrentPosition();

      if (!mounted) return;
      setState(() => _center = LatLng(position.latitude, position.longitude));
      _mapController.move(_center!, 15);
    } catch (_) {
      // Location unavailable, denied, or services off — tapping the map
      // (still centered on _defaultCenter) is the fallback, not an error
      // worth surfacing on a screen whose whole point is picking a point.
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      setState(() => _errorMessage = 'الرجاء إدخال اسم للمنطقة.');
      return;
    }

    if (_isPolygonMode) {
      if (_polygonPoints.length < 3) {
        setState(() => _errorMessage = 'الرجاء تحديد 3 نقاط على الأقل على الخريطة لرسم المضلّع.');
        return;
      }
    } else if (_center == null) {
      setState(() => _errorMessage = 'الرجاء تحديد موقع المنطقة على الخريطة أولاً.');
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final familyId = ref.read(selectedFamilyIdProvider);
      final api = ref.read(familyApiProvider);

      if (_isEditing && _isPolygonMode) {
        await api.updatePolygonGeofence(
          geofenceId: widget.existingZone!.id,
          name: name,
          type: _type,
          points: [for (final point in _polygonPoints) (lat: point.latitude, lng: point.longitude)],
          notifyOnEntry: _notifyOnEntry,
          notifyOnExit: _notifyOnExit,
          familyId: familyId,
        );
      } else if (_isEditing) {
        final center = _center!;

        await api.updateCircleGeofence(
          geofenceId: widget.existingZone!.id,
          name: name,
          type: _type,
          centerLat: center.latitude,
          centerLng: center.longitude,
          radiusMeters: _radiusMeters,
          notifyOnEntry: _notifyOnEntry,
          notifyOnExit: _notifyOnExit,
          familyId: familyId,
        );
      } else if (_isPolygonMode) {
        await api.createPolygonGeofence(
          name: name,
          type: _type,
          points: [for (final point in _polygonPoints) (lat: point.latitude, lng: point.longitude)],
          notifyOnEntry: _notifyOnEntry,
          notifyOnExit: _notifyOnExit,
          familyId: familyId,
        );
      } else {
        final center = _center!;

        await api.createCircleGeofence(
          name: name,
          type: _type,
          centerLat: center.latitude,
          centerLng: center.longitude,
          radiusMeters: _radiusMeters,
          notifyOnEntry: _notifyOnEntry,
          notifyOnExit: _notifyOnExit,
          familyId: familyId,
        );
      }

      ref.invalidate(familyGeofencesProvider);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditing ? 'تم تحديث المنطقة الآمنة بنجاح' : 'تمت إضافة المنطقة الآمنة بنجاح')),
      );
    } on ApiException catch (error) {
      setState(() => _errorMessage = error.message);
    } catch (error) {
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'تعديل منطقة آمنة' : 'إضافة منطقة آمنة')),
      body: Column(
        children: [
          Expanded(child: _buildMap()),
          _buildForm(),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _center ?? _defaultCenter,
        initialZoom: 13,
        onTap: (tapPosition, point) => setState(() {
          if (_isPolygonMode) {
            _polygonPoints.add(point);
          } else {
            _center = point;
          }
        }),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.eyoonak.fleet_saas_driver',
        ),
        if (!_isPolygonMode && _center != null)
          CircleLayer(
            circles: [
              CircleMarker(
                point: _center!,
                radius: _radiusMeters,
                useRadiusInMeter: true,
                color: Colors.blue.withValues(alpha: 0.15),
                borderColor: Colors.blue,
                borderStrokeWidth: 2,
              ),
            ],
          ),
        if (_isPolygonMode && _polygonPoints.length >= 3)
          PolygonLayer(
            polygons: [
              Polygon(
                points: _polygonPoints,
                color: Colors.blue.withValues(alpha: 0.15),
                borderColor: Colors.blue,
                borderStrokeWidth: 2,
              ),
            ],
          ),
        if (_isPolygonMode && _polygonPoints.length >= 2)
          PolylineLayer(
            polylines: [
              // Renders the still-open path (2 points, not yet a valid
              // polygon) so a vertex is never invisible while below the
              // 3-point minimum PolygonLayer above requires to draw at all.
              Polyline(points: _polygonPoints, color: Colors.blue, strokeWidth: 2),
            ],
          ),
        if (_isPolygonMode)
          MarkerLayer(
            markers: [
              for (final (index, point) in _polygonPoints.indexed)
                Marker(
                  point: point,
                  // Larger than the 16x16 dot itself so a thumb tap doesn't
                  // need pixel-precise accuracy to land on it — this is the
                  // "remove this vertex" hit target (see docblock: no
                  // drag-to-move, tap-to-remove instead).
                  width: 32,
                  height: 32,
                  child: GestureDetector(
                    onTap: () => setState(() => _polygonPoints.removeAt(index)),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.shade900,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      margin: const EdgeInsets.all(8),
                    ),
                  ),
                ),
            ],
          )
        else if (_center case final center?)
          MarkerLayer(
            markers: [
              Marker(
                point: center,
                width: 20,
                height: 20,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.shade900,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
        const RichAttributionWidget(
          attributions: [TextSourceAttribution('OpenStreetMap contributors')],
        ),
      ],
    );
  }

  Widget _buildForm() {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Only offered when creating — an existing zone keeps whatever
            // shape it already has when editing (see class docblock on why
            // switching shape mid-edit isn't offered).
            if (!_isEditing) ...[
              _buildShapeToggle(),
              const SizedBox(height: 12),
            ],
            Text(
              _isPolygonMode
                  ? 'اضغط على الخريطة لإضافة نقطة، أو اضغط على نقطة موجودة لحذفها (٣ نقاط على الأقل).'
                  : 'اضغط في أي مكان على الخريطة لتحديد مركز المنطقة.',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'اسم المنطقة', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              // Safe the same way _FamilySwitcher's is (see its own
              // docblock): re-applied on every rebuild since this widget
              // has no state of its own beyond what's passed in, so it
              // tracks `_type` correctly despite the `initialValue` name.
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'نوع المنطقة', border: OutlineInputBorder()),
              items: [
                for (final entry in _typeLabels.entries) DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) => setState(() => _type = value ?? _type),
            ),
            const SizedBox(height: 8),
            if (_isPolygonMode) _buildPolygonControls() else _buildRadiusSlider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('تنبيه عند الدخول'),
              value: _notifyOnEntry,
              onChanged: (value) => setState(() => _notifyOnEntry = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('تنبيه عند الخروج'),
              value: _notifyOnExit,
              onChanged: (value) => setState(() => _notifyOnExit = value),
            ),
            if (_errorMessage case final message?) ...[
              const SizedBox(height: 8),
              Text(message, style: TextStyle(color: Colors.red.shade700)),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_isEditing ? 'حفظ التعديلات' : 'حفظ المنطقة'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShapeToggle() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'circle', label: Text('دائرة'), icon: Icon(Icons.circle_outlined)),
        ButtonSegment(value: 'polygon', label: Text('مضلّع'), icon: Icon(Icons.pentagon_outlined)),
      ],
      selected: {_shapeType},
      onSelectionChanged: (selection) => setState(() => _shapeType = selection.first),
    );
  }

  Widget _buildRadiusSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('نصف القطر: ${_radiusMeters.round()} متر'),
        Slider(
          value: _radiusMeters,
          min: 10,
          max: 2000,
          divisions: 199,
          label: '${_radiusMeters.round()} م',
          onChanged: (value) => setState(() => _radiusMeters = value),
        ),
      ],
    );
  }

  Widget _buildPolygonControls() {
    final count = _polygonPoints.length;
    final enough = count >= 3;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            enough ? Icons.check_circle_outline : Icons.info_outline,
            size: 16,
            color: enough ? Colors.green.shade700 : Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(width: 6),
          Expanded(child: Text('عدد النقاط: $count${enough ? '' : ' (يلزم ٣ على الأقل)'}')),
          TextButton(
            onPressed: _polygonPoints.isEmpty ? null : () => setState(() => _polygonPoints.removeLast()),
            child: const Text('تراجع'),
          ),
          TextButton(
            onPressed: _polygonPoints.isEmpty ? null : () => setState(_polygonPoints.clear),
            child: const Text('مسح الكل'),
          ),
        ],
      ),
    );
  }
}
