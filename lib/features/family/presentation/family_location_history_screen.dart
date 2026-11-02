import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_exception.dart';
import '../application/family_providers.dart';
import '../data/family_models.dart';

/// A family member's location trail over a chosen time window — the mobile
/// mirror of the web app's FamilyMemberLocationHistoryPage.vue: a polyline
/// on the map plus a scrollable timeline list, both reading the same
/// `GET /family-members/{id}/locations` endpoint the web page uses (PR-F,
/// added earlier for the fleet-vehicle side by
/// LocationController::history()'s sibling).
///
/// Deliberately a plain `ConsumerStatefulWidget` managing its own
/// load/error/data state (matching `DevicePairingRedeemScreen`'s approach)
/// rather than a Riverpod provider — the query (`familyMemberId`, `from`,
/// `to`) changes every time the user picks a new range, and there is
/// exactly one screen that ever needs this data, so a shared provider would
/// only add ceremony without giving anything else a value to watch.
class FamilyMemberLocationHistoryScreen extends ConsumerStatefulWidget {
  const FamilyMemberLocationHistoryScreen({super.key, required this.familyMemberId, required this.memberName});

  final int familyMemberId;
  final String memberName;

  @override
  ConsumerState<FamilyMemberLocationHistoryScreen> createState() => _FamilyMemberLocationHistoryScreenState();
}

class _FamilyMemberLocationHistoryScreenState extends ConsumerState<FamilyMemberLocationHistoryScreen> {
  // The backend caps any single request at 30 days (see
  // ViewFamilyMemberLocationHistoryRequest); the web page defaults to the
  // last 24 hours, mirrored here so a first-time visitor sees something
  // useful without having to pick a range first.
  static const _maxRangeDays = 30;

  late DateTime _from;
  late DateTime _to;
  bool _loading = true;
  String? _errorMessage;
  List<FamilyLocationPoint> _points = const [];

  @override
  void initState() {
    super.initState();
    _to = DateTime.now();
    _from = _to.subtract(const Duration(hours: 24));
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final familyId = ref.read(selectedFamilyIdProvider);
      final raw = await ref.read(familyApiProvider).locationHistory(
            familyMemberId: widget.familyMemberId,
            from: _from,
            to: _to,
            familyId: familyId,
          );

      if (!mounted) return;
      setState(() => _points = raw.map(FamilyLocationPoint.fromJson).toList());
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      locale: const Locale('ar'),
    );

    if (picked == null) return;

    if (picked.end.difference(picked.start).inDays > _maxRangeDays) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الفترة الزمنية أطول من الحد الأقصى المسموح ($_maxRangeDays يوم).')),
        );
      }
      return;
    }

    setState(() {
      _from = picked.start;
      // Include the entire end day, matching how a person picking "today"
      // as the end of a range expects to see today's points too.
      _to = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('سجل مواقع ${widget.memberName}'),
        actions: [
          IconButton(icon: const Icon(Icons.date_range), tooltip: 'اختيار فترة', onPressed: _pickRange),
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'تحديث', onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '${_formatTimestamp(_from.toIso8601String())} — ${_formatTimestamp(_to.toIso8601String())}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('تعذر تحميل سجل المواقع: $_errorMessage', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('إعادة المحاولة')),
            ],
          ),
        ),
      );
    }

    if (_points.isEmpty) {
      return const Center(child: Text('لا توجد نقاط موقع مسجَّلة خلال هذه الفترة.'));
    }

    return Column(
      children: [
        Expanded(flex: 3, child: _RouteMap(points: _points)),
        const Divider(height: 1),
        Expanded(flex: 2, child: _PointsTimeline(points: _points)),
      ],
    );
  }
}

class _RouteMap extends StatelessWidget {
  const _RouteMap({required this.points});

  final List<FamilyLocationPoint> points;

  @override
  Widget build(BuildContext context) {
    final latLngs = [for (final point in points) LatLng(point.latitude, point.longitude)];
    final center = LatLng(
      points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length,
      points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length,
    );

    return FlutterMap(
      options: MapOptions(initialCenter: center, initialZoom: 13),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.eyoonak.fleet_saas_driver',
        ),
        PolylineLayer(
          polylines: [Polyline(points: latLngs, strokeWidth: 4, color: Theme.of(context).colorScheme.primary)],
        ),
        MarkerLayer(
          markers: [
            _endpointMarker(latLngs.first, Colors.green.shade700),
            if (latLngs.length > 1) _endpointMarker(latLngs.last, Colors.red.shade700),
          ],
        ),
        const RichAttributionWidget(
          attributions: [TextSourceAttribution('OpenStreetMap contributors')],
        ),
      ],
    );
  }

  Marker _endpointMarker(LatLng point, Color color) {
    return Marker(
      point: point,
      width: 20,
      height: 20,
      child: Container(
        decoration:
            BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
      ),
    );
  }
}

class _PointsTimeline extends StatelessWidget {
  const _PointsTimeline({required this.points});

  final List<FamilyLocationPoint> points;

  @override
  Widget build(BuildContext context) {
    // Newest first in the list, even though the map draws the polyline in
    // the backend's ascending order (oldest → newest) — a person scanning a
    // timeline expects "just now" at the top.
    final reversed = points.reversed.toList();

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: reversed.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final point = reversed[index];

        return ListTile(
          dense: true,
          leading: const Icon(Icons.location_on_outlined),
          title: Text(_formatTimestamp(point.recordedAt)),
          trailing: point.batteryLevel != null ? Text('${point.batteryLevel}%') : null,
        );
      },
    );
  }
}

/// Small, dependency-free "dd/MM HH:mm" formatter — same reasoning as
/// `FamilyHomeScreen`'s `_relativeTime`: no timeago/intl-style package in
/// pubspec.yaml, and this is the only other place that needs to render a
/// raw ISO 8601 timestamp for a person to read.
String _formatTimestamp(String isoTimestamp) {
  final parsed = DateTime.tryParse(isoTimestamp);

  if (parsed == null) {
    return isoTimestamp;
  }

  final local = parsed.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');

  return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
}
