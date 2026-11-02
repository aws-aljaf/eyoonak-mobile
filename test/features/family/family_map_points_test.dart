import 'package:fleet_saas_driver/features/family/application/family_map_points.dart';
import 'package:fleet_saas_driver/features/family/data/family_models.dart';
import 'package:flutter_test/flutter_test.dart';

FamilyMemberModel _member({
  required int id,
  required String name,
  FamilyMemberLatestLocation? location,
}) {
  return FamilyMemberModel(
    id: id,
    fullName: name,
    relationship: 'الابنة',
    status: 'active',
    latestLocation: location,
  );
}

void main() {
  test('a member with no latest_location object at all is left off the map', () {
    final points = familyMapPoints([_member(id: 1, name: 'خالد', location: null)]);

    expect(points, isEmpty);
  });

  test('a member whose latest_location has null lat/lng (never recorded, or redacted) is left off the map', () {
    final points = familyMapPoints([
      _member(
        id: 2,
        name: 'ليلى',
        location: const FamilyMemberLatestLocation(latitude: null, longitude: null),
      ),
    ]);

    expect(points, isEmpty);
  });

  test('a member with resolved coordinates gets exactly one point carrying them', () {
    final points = familyMapPoints([
      _member(
        id: 3,
        name: 'سارة',
        location: const FamilyMemberLatestLocation(latitude: 33.3, longitude: 44.4, batteryLevel: 80),
      ),
    ]);

    expect(points, hasLength(1));
    expect(points.single.latitude, 33.3);
    expect(points.single.longitude, 44.4);
    expect(points.single.member.fullName, 'سارة');
  });

  test('a mixed roster only plots the members with resolved coordinates, preserving order', () {
    final points = familyMapPoints([
      _member(id: 1, name: 'بلا موقع', location: null),
      _member(
        id: 2,
        name: 'أول',
        location: const FamilyMemberLatestLocation(latitude: 1, longitude: 2),
      ),
      _member(
        id: 3,
        name: 'نصف بيانات فقط',
        location: const FamilyMemberLatestLocation(latitude: 5, longitude: null),
      ),
      _member(
        id: 4,
        name: 'ثانٍ',
        location: const FamilyMemberLatestLocation(latitude: 3, longitude: 4),
      ),
    ]);

    expect(points.map((p) => p.member.fullName), ['أول', 'ثانٍ']);
  });
}
