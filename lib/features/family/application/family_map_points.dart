import '../data/family_models.dart';

/// One family member with a location definite enough to place a marker
/// for — pairs the member (for the popup's name/relationship/last-seen
/// text) with resolved, non-null coordinates.
class FamilyMapPoint {
  const FamilyMapPoint({required this.member, required this.latitude, required this.longitude});

  final FamilyMemberModel member;
  final double latitude;
  final double longitude;
}

/// Pulled out of the map screen as a pure function so the "which members
/// actually get a marker" logic is unit-testable without pumping a real
/// `FlutterMap` widget (which would try to fetch OSM tiles over the
/// network — not something a widget test should depend on). A member with
/// `latestLocation == null`, or one whose `latitude`/`longitude` are
/// individually null (either truly unrecorded yet, or redacted for this
/// viewer's capability — see `FamilyMemberLatestLocation`'s docblock;
/// this function deliberately doesn't try to tell those apart either),
/// is simply left off the map rather than plotted at a default point.
List<FamilyMapPoint> familyMapPoints(List<FamilyMemberModel> members) {
  return [
    for (final member in members)
      if (member.latestLocation?.latitude != null && member.latestLocation?.longitude != null)
        FamilyMapPoint(
          member: member,
          latitude: member.latestLocation!.latitude!,
          longitude: member.latestLocation!.longitude!,
        ),
  ];
}
