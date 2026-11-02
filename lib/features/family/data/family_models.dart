/// Mirrors `FamilyResource`
/// (backend/app/Http/Resources/Api/V1/FamilyResource.php) field-for-field.
class FamilyModel {
  const FamilyModel({
    required this.id,
    required this.name,
    required this.status,
    required this.ownerUserId,
    this.plan,
  });

  factory FamilyModel.fromJson(Map<String, dynamic> json) {
    return FamilyModel(
      id: json['id'] as int,
      name: json['name'] as String,
      status: json['status'] as String,
      ownerUserId: json['owner_user_id'] as int,
      plan: json['plan'] as String?,
    );
  }

  final int id;
  final String name;
  final String status;
  final int ownerUserId;
  final String? plan;
}

/// Mirrors the `latest_location` sub-object of `FamilyMemberResource`
/// (backend/app/Http/Resources/Api/V1/FamilyMemberResource.php). Any field
/// here can be `null` either because nothing has been recorded yet, or
/// because the viewer lacks the corresponding tracking capability — the
/// response shape never signals which (see that resource's docblock), so
/// this model doesn't try to either.
class FamilyMemberLatestLocation {
  const FamilyMemberLatestLocation({this.latitude, this.longitude, this.batteryLevel, this.recordedAt});

  factory FamilyMemberLatestLocation.fromJson(Map<String, dynamic> json) {
    return FamilyMemberLatestLocation(
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      batteryLevel: json['battery_level'] as int?,
      recordedAt: json['recorded_at'] as String?,
    );
  }

  final double? latitude;
  final double? longitude;
  final int? batteryLevel;
  final String? recordedAt;
}

/// Mirrors `FamilyMemberResource`. `relationship` is free text on the
/// backend (e.g. "الابن", "الجدة") — never an enum, see
/// `create_family_members_table`'s migration comment — so it's rendered
/// as-is, never mapped through a fixed label table.
class FamilyMemberModel {
  const FamilyMemberModel({
    required this.id,
    required this.fullName,
    required this.relationship,
    required this.status,
    this.phone,
    this.avatarPath,
    this.linkedUserId,
    this.lastSeenAt,
    this.latestLocation,
    this.gender,
    this.birthDate,
    this.ageYears,
    this.exerciseAgeGroup,
  });

  factory FamilyMemberModel.fromJson(Map<String, dynamic> json) {
    return FamilyMemberModel(
      id: json['id'] as int,
      fullName: json['full_name'] as String,
      gender: json['gender'] as String?,
      birthDate: json['birth_date'] as String?,
      ageYears: json['age_years'] as int?,
      exerciseAgeGroup:
          json['exercise_age_group'] == null ? null : Map<String, dynamic>.from(json['exercise_age_group'] as Map),
      relationship: json['relationship'] as String,
      status: json['status'] as String,
      phone: json['phone'] as String?,
      avatarPath: json['avatar_path'] as String?,
      linkedUserId: json['linked_user_id'] as int?,
      lastSeenAt: json['last_seen_at'] as String?,
      latestLocation: json['latest_location'] == null
          ? null
          : FamilyMemberLatestLocation.fromJson(
              Map<String, dynamic>.from(json['latest_location'] as Map),
            ),
    );
  }

  final int id;
  final String fullName;
  final String? gender;
  final String? birthDate;
  final int? ageYears;
  final Map<String, dynamic>? exerciseAgeGroup;
  final String relationship;
  final String status;
  final String? phone;
  final String? avatarPath;
  final int? linkedUserId;
  final String? lastSeenAt;
  final FamilyMemberLatestLocation? latestLocation;

  /// True when this roster row IS the currently logged-in account (a
  /// device-paired-or-invited member viewing their own family) — used to
  /// label the row "أنت" instead of just their name.
  bool isMe(int currentUserId) => linkedUserId == currentUserId;
}

/// One recorded point from `GET /family-members/{id}/locations`, mirroring
/// `FamilyMemberLocationResource` field-for-field. Unlike
/// `FamilyMemberLatestLocation` above, `latitude`/`longitude` here are
/// never null — every row this endpoint returns already passed both layers
/// of authorization server-side (`FamilyMemberPolicy::view()` +
/// `canViewCapability(..., 'location_history')`), so there is nothing left
/// to redact by the time a point reaches this model.
class FamilyLocationPoint {
  const FamilyLocationPoint({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.accuracyMeters,
    this.batteryLevel,
  });

  factory FamilyLocationPoint.fromJson(Map<String, dynamic> json) {
    return FamilyLocationPoint(
      id: json['id'] as int,
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lng'] as num).toDouble(),
      recordedAt: json['recorded_at'] as String,
      accuracyMeters: (json['accuracy_meters'] as num?)?.toDouble(),
      batteryLevel: json['battery_level'] as int?,
    );
  }

  final int id;
  final double latitude;
  final double longitude;
  final String recordedAt;
  final double? accuracyMeters;
  final int? batteryLevel;
}

/// Mirrors `FamilyRelationshipResource`
/// (backend/app/Http/Resources/Api/V1/FamilyRelationshipResource.php)
/// field-for-field. This is a genuinely different object from
/// `FamilyMemberModel` above — that one is a *tracked person* (may have no
/// app account at all, e.g. a young child carrying a paired device);
/// this one is the *membership row* linking an actual `User` account to a
/// family with a role and permission grants. A user can appear here
/// without ever appearing in `FamilyMemberModel` (e.g. an invited parent
/// who tracks others but isn't themselves a tracked device), and vice
/// versa. `userName`/`userPhone`/`familyName` are all `whenLoaded()` on
/// the backend resource — genuinely absent (not merely null) unless the
/// index query eager-loaded them, so every one of the three is nullable
/// here rather than assumed present.
///
/// `trackingPermissions`/`supervises` default to `[]` (not null) per that
/// resource's own `?? []` fallback — mirrored here with `?? const []` so
/// callers never have to null-check either list.
class FamilyRelationshipModel {
  const FamilyRelationshipModel({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.role,
    required this.status,
    required this.trackingPermissions,
    required this.supervises,
    this.userName,
    this.userPhone,
    this.familyName,
    this.kinship,
    this.invitedAt,
    this.joinedAt,
    this.createdAt,
  });

  factory FamilyRelationshipModel.fromJson(Map<String, dynamic> json) {
    return FamilyRelationshipModel(
      id: json['id'] as int,
      familyId: json['family_id'] as int,
      userId: json['user_id'] as int,
      userName: json['user_name'] as String?,
      userPhone: json['user_phone'] as String?,
      familyName: json['family_name'] as String?,
      kinship: json['kinship'] as String?,
      role: json['role'] as String,
      status: json['status'] as String,
      trackingPermissions: (json['tracking_permissions'] as List?)?.map((e) => e as String).toList() ?? const [],
      supervises: (json['supervises'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [],
      invitedAt: json['invited_at'] as String?,
      joinedAt: json['joined_at'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  final int id;
  final int familyId;
  final int userId;
  final String? userName;
  final String? userPhone;
  final String? familyName;
  final String? kinship;
  final String role;
  final String status;
  final List<String> trackingPermissions;
  final List<int> supervises;
  final String? invitedAt;
  final String? joinedAt;
  final String? createdAt;

  /// Mirrors `FamilyMemberModel.isMe` above — used the same way, to label
  /// a roster row "أنت" instead of the account's own name.
  bool isMe(int currentUserId) => userId == currentUserId;

  /// Mirrors `FamilyRelationship::FULL_ACCESS_ROLES` on the backend
  /// exactly (`owner`, `parent`, `admin`) — these three always see every
  /// tracking capability regardless of what `trackingPermissions` stores
  /// (verified directly against that model's `can()` method), so the
  /// membership screen never shows a capability checklist for a role in
  /// this set — it would be misleading busywork, since granting/revoking
  /// there has no effect for them.
  bool get hasFullAccess => const {'owner', 'parent', 'admin'}.contains(role);
}

/// One entry from `GET /family-timeline` — verified directly against
/// `FamilyTimelineController::index()`, which has **no dedicated Resource
/// class**: each item is a plain array built inline by one of four private
/// methods (`geofenceEventItems`/`geofenceAddedItems`/`sosItems`/
/// `memberAddedItems`), so this model's fields are a union across all four
/// shapes rather than a single backend class's fields. `status` is
/// genuinely present **only** on `type == 'sos'` items (`sosItems()` is the
/// only one of the four builders that sets it) — every other type omits
/// the key entirely rather than sending it `null`, so it stays optional
/// here too. `familyMemberId`/`familyMemberName` are both `null` for
/// `geofence_added` items specifically (a zone-level event, not tied to a
/// person) — confirmed directly in `geofenceAddedItems()`. `title` is a
/// fully pre-rendered Arabic string built server-side (e.g. "دخول إلى
/// المدرسة") — this model never reconstructs it from `type` + other
/// fields, matching how `FamilyManagementPage.vue`'s timeline reference
/// page also just renders `item.title` verbatim.
class FamilyTimelineItem {
  const FamilyTimelineItem({
    required this.type,
    required this.occurredAt,
    required this.title,
    this.familyMemberId,
    this.familyMemberName,
    this.status,
  });

  factory FamilyTimelineItem.fromJson(Map<String, dynamic> json) {
    return FamilyTimelineItem(
      type: json['type'] as String,
      occurredAt: json['occurred_at'] as String?,
      familyMemberId: json['family_member_id'] as int?,
      familyMemberName: json['family_member_name'] as String?,
      title: json['title'] as String,
      status: json['status'] as String?,
    );
  }

  final String type;
  final String? occurredAt;
  final int? familyMemberId;
  final String? familyMemberName;
  final String title;
  final String? status;
}

/// A drawable safe-zone shape, mirroring the `polygon_or_radius` JSON
/// column shared by `FamilyGeofence`/`Geofence` on the backend (see
/// `backend/app/Models/FamilyGeofence.php` and
/// `GeofenceEvaluator::isInside()`): either a circle
/// (`{center_lat, center_lng, radius_m}`) or a polygon (`{points: [[lat,
/// lng], ...]}`), never both. `radius_m` is already in meters — the same
/// unit `flutter_map`'s `CircleMarker` (and the web app's
/// `L.circle({radius: ...})`) expect natively, so no conversion happens
/// anywhere on this path.
sealed class FamilyGeofenceShape {
  const FamilyGeofenceShape();

  /// `array_key_exists('radius_m', ...)` is exactly how the backend
  /// itself tells the two shapes apart (`FamilyGeofence::isCircle()`) —
  /// mirrored here rather than trusting a `type` discriminator field,
  /// because none exists in `polygon_or_radius` itself.
  factory FamilyGeofenceShape.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('radius_m')) {
      return FamilyGeofenceCircle(
        centerLat: (json['center_lat'] as num).toDouble(),
        centerLng: (json['center_lng'] as num).toDouble(),
        radiusMeters: (json['radius_m'] as num).toDouble(),
      );
    }

    final points = (json['points'] as List).map((point) {
      final pair = point as List;

      return (lat: (pair[0] as num).toDouble(), lng: (pair[1] as num).toDouble());
    }).toList();

    return FamilyGeofencePolygon(points: points);
  }
}

class FamilyGeofenceCircle extends FamilyGeofenceShape {
  const FamilyGeofenceCircle({required this.centerLat, required this.centerLng, required this.radiusMeters});

  final double centerLat;
  final double centerLng;
  final double radiusMeters;
}

class FamilyGeofencePolygon extends FamilyGeofenceShape {
  const FamilyGeofencePolygon({required this.points});

  /// At least 3 `(lat, lng)` vertices — enforced server-side by
  /// `StoreFamilyGeofenceRequest`, never re-validated here.
  final List<({double lat, double lng})> points;
}

/// Mirrors `FamilyGeofenceResource`
/// (backend/app/Http/Resources/Api/V1/FamilyGeofenceResource.php)
/// field-for-field. `notifyOnEntry`/`notifyOnExit` are carried through even
/// though this first mobile pass only ever reads them (never edits a safe
/// zone) — dropping them silently would make a future edit screen have to
/// re-add them, and they cost nothing to keep.
class FamilyGeofenceModel {
  const FamilyGeofenceModel({
    required this.id,
    required this.name,
    required this.type,
    required this.shape,
    required this.isActive,
    required this.notifyOnEntry,
    required this.notifyOnExit,
  });

  factory FamilyGeofenceModel.fromJson(Map<String, dynamic> json) {
    return FamilyGeofenceModel(
      id: json['id'] as int,
      name: json['name'] as String,
      type: json['type'] as String,
      shape: FamilyGeofenceShape.fromJson(Map<String, dynamic>.from(json['polygon_or_radius'] as Map)),
      isActive: json['is_active'] as bool,
      notifyOnEntry: json['notify_on_entry'] as bool,
      notifyOnExit: json['notify_on_exit'] as bool,
    );
  }

  final int id;
  final String name;
  final String type;
  final FamilyGeofenceShape shape;
  final bool isActive;
  final bool notifyOnEntry;
  final bool notifyOnExit;
}

/// The response of `POST /family-members/{id}/pairing-codes` — a freshly
/// generated, single-use, 10-minute pairing code for *some other* device to
/// redeem via `FamilyApi.redeemDevicePairing()`. There is no corresponding
/// request model: `DevicePairingController::store()` takes no body at all,
/// the family member is identified purely by the route segment.
class DevicePairingCode {
  const DevicePairingCode({required this.code, required this.expiresAt, this.familyMemberName});

  factory DevicePairingCode.fromJson(Map<String, dynamic> json) {
    return DevicePairingCode(
      code: json['code'] as String,
      // Always an ISO 8601 UTC offset string server-side
      // (`now()->addMinutes(10)->toIso8601String()`) — `DateTime.parse`
      // (not `tryParse`) on purpose: an unparsable value here means the
      // contract changed and the countdown below would be meaningless
      // anyway, so failing loudly beats silently showing "0:00".
      expiresAt: DateTime.parse(json['expires_at'] as String),
      familyMemberName: json['family_member_name'] as String?,
    );
  }

  final String code;
  final DateTime expiresAt;
  final String? familyMemberName;
}

/// A single row from `GET /alerts` — `AlertResource` on the backend.
/// Deliberately has **no `readAt`/`read_at` field**: confirmed directly
/// against `AlertResource`/the `alerts` migration that no such column
/// exists at all — `status` flipping `unread` → `read` is the only signal
/// a read ever happened, with no timestamp attached. `familyMemberId` is
/// nullable because some alert types (e.g. a future family-wide notice)
/// are not tied to one specific member; today's raised types
/// (`geofence_enter`/`geofence_exit`/`sos`) always carry one in practice,
/// but this model doesn't assume that. `payload` is intentionally left as
/// a raw untyped map — it's type-specific per `Alert::TYPES` and nothing
/// on this first Alerts Center screen needs to reach into it.
class FamilyAlertModel {
  const FamilyAlertModel({
    required this.id,
    required this.type,
    required this.severity,
    required this.status,
    required this.title,
    required this.createdAt,
    this.familyMemberId,
    this.body,
    this.payload,
    this.resolvedByUserId,
    this.resolvedAt,
  });

  factory FamilyAlertModel.fromJson(Map<String, dynamic> json) {
    return FamilyAlertModel(
      id: json['id'] as int,
      familyMemberId: json['family_member_id'] as int?,
      type: json['type'] as String,
      severity: json['severity'] as String,
      status: json['status'] as String,
      title: json['title'] as String,
      body: json['body'] as String?,
      payload: json['payload'] == null ? null : Map<String, dynamic>.from(json['payload'] as Map),
      resolvedByUserId: json['resolved_by_user_id'] as int?,
      resolvedAt: json['resolved_at'] as String?,
      createdAt: json['created_at'] as String,
    );
  }

  final int id;
  final int? familyMemberId;
  final String type;
  final String severity;
  final String status;
  final String title;
  final String? body;
  final Map<String, dynamic>? payload;
  final int? resolvedByUserId;
  final String? resolvedAt;
  final String createdAt;

  bool get isUnread => status == 'unread';
  bool get isResolved => status == 'resolved';
}

/// Mirrors `EmergencyContactResource` field-for-field. Deliberately carries
/// no `familyId`/`createdByUserId` — the resource itself never exposes
/// them (verified directly against its `toArray()`), so there is nothing
/// to parse. `relationship` is genuinely free text server-side (no `in:`
/// list, unlike a safe zone's `type`) — this app never restricts it to a
/// fixed set either.
class EmergencyContactModel {
  const EmergencyContactModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.notifyOnSos,
    required this.createdAt,
    this.relationship,
  });

  factory EmergencyContactModel.fromJson(Map<String, dynamic> json) {
    return EmergencyContactModel(
      id: json['id'] as int,
      name: json['name'] as String,
      phone: json['phone'] as String,
      relationship: json['relationship'] as String?,
      notifyOnSos: json['notify_on_sos'] as bool,
      createdAt: json['created_at'] as String,
    );
  }

  final int id;
  final String name;
  final String phone;
  final String? relationship;
  final bool notifyOnSos;
  final String createdAt;
}

/// Mirrors `SosEventResource` field-for-field. Genuinely richer than
/// `FamilyAlertModel` for this one incident type — structured `lat`/`lng`
/// for map-centering, `batteryLevel`, and a full acknowledge+resolve audit
/// trail with separate actor/timestamp pairs for each step (`Alert` only
/// ever has one `resolvedBy`/`resolvedAt`, no "acknowledged" state at
/// all) — verified directly against the backend resource, not assumed.
/// `familyMemberName` is genuinely absent from the JSON (not merely null)
/// whenever the backend's `index()` query hasn't eager-loaded the
/// relation — confirmed directly against `SosController::index()`, which
/// does not `->with('familyMember')` today (unlike, e.g., the family
/// timeline query) — so callers must have a fallback for a missing name,
/// same as the web app's own `SosPage.vue` reference implementation does.
class SosEventModel {
  const SosEventModel({
    required this.id,
    required this.familyMemberId,
    required this.triggeredByUserId,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.createdAt,
    this.familyMemberName,
    this.batteryLevel,
    this.acknowledgedByUserId,
    this.acknowledgedAt,
    this.resolvedByUserId,
    this.resolvedAt,
    this.notifiedEmergencyContactIds,
  });

  factory SosEventModel.fromJson(Map<String, dynamic> json) {
    return SosEventModel(
      id: json['id'] as int,
      familyMemberId: json['family_member_id'] as int,
      familyMemberName: json['family_member_name'] as String?,
      triggeredByUserId: json['triggered_by_user_id'] as int?,
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lng'] as num).toDouble(),
      batteryLevel: json['battery_level'] as int?,
      status: json['status'] as String,
      acknowledgedByUserId: json['acknowledged_by_user_id'] as int?,
      acknowledgedAt: json['acknowledged_at'] as String?,
      resolvedByUserId: json['resolved_by_user_id'] as int?,
      resolvedAt: json['resolved_at'] as String?,
      notifiedEmergencyContactIds:
          (json['notified_emergency_contact_ids'] as List?)?.map((e) => (e as num).toInt()).toList(),
      createdAt: json['created_at'] as String,
    );
  }

  final int id;
  final int familyMemberId;
  final String? familyMemberName;
  final int? triggeredByUserId;
  final double latitude;
  final double longitude;
  final int? batteryLevel;
  final String status;
  final int? acknowledgedByUserId;
  final String? acknowledgedAt;
  final int? resolvedByUserId;
  final String? resolvedAt;
  final List<int>? notifiedEmergencyContactIds;
  final String createdAt;

  bool get isActive => status == 'active';
  bool get isAcknowledged => status == 'acknowledged';
  bool get isResolved => status == 'resolved';
}
