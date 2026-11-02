import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';

/// Talks to the family-tracking endpoints exactly as documented in
/// documentation/04-api-specification.md and implemented server-side by
/// FamilyController / FamilyTracking\FamilyMemberController /
/// FamilyTracking\AlertController / FamilyTracking\SosController
/// (backend/app/Http/Controllers/Api/V1/...). Returns raw decoded JSON —
/// callers (Riverpod providers) turn it into family_models.dart types, the
/// same split trips_api.dart/trip_models.dart already use.
///
/// `familyId`, when given, is sent as `X-Family-Id` — required only when
/// the account belongs to more than one active family (see
/// ResolveFamilyContext's docblock on the backend); omitted entirely for
/// the common case of exactly one (or zero) memberships.
class FamilyApi {
  FamilyApi(this._client);

  final ApiClient _client;

  Map<String, dynamic>? _familyHeader(int? familyId) => familyId == null ? null : {'X-Family-Id': familyId.toString()};

  /// `GET /families` — every family this account belongs to. Not
  /// paginated server-side (FamilyController::index returns a plain
  /// collection, no family has enough rows to need paging).
  Future<List<Map<String, dynamic>>> myFamilies() async {
    final data = await _client.get('/families');

    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// `POST /families` — self-service creation of a new family circle;
  /// requires `family_tracking.create` (see FamilyPolicy::create()).
  Future<Map<String, dynamic>> createFamily({required String name}) async {
    final data = await _client.post('/families', data: {'name': name});

    return Map<String, dynamic>.from(data as Map);
  }

  /// `PUT /families/{id}` — renames one of this account's own families.
  /// Verified directly against `FamilyController::update()`: this route sits
  /// OUTSIDE the `family` middleware group entirely (`routes/api_v1.php`
  /// declares the whole `families` `apiResource` before the `family`
  /// middleware group that wraps `family-members`/`family-geofences`/etc.
  /// below it), so — unlike every other method in this class that takes a
  /// `familyId` — this one sends **no** `X-Family-Id` header at all; the
  /// target family is identified purely by `familyId` in the path, which the
  /// controller resolves through `$request->user()->families()` (a family
  /// this account doesn't belong to 404s, never reaches a bare update).
  ///
  /// Gated by `FamilyPolicy::update()` — `family_tracking.edit` **and**
  /// `hasManagingRole()` (owner/admin specifically for *this* family),
  /// verified directly against that policy — stricter than every other
  /// `family_tracking.edit`-gated method in this file (`updateFamilyMember()`
  /// above only checks active membership, not role). This app has no
  /// per-family role lookup wired up anywhere yet to pre-check that second
  /// half client-side, so — matching this file's established "the request
  /// is the gate" convention for narrower checks it can't cheaply
  /// pre-compute (see `familyAlertsProvider`'s own docblock) — the caller is
  /// expected to surface whatever `ApiException` message a non-owner/admin
  /// with `family_tracking.edit` gets back (a 403), not hide the action
  /// entirely client-side.
  ///
  /// Only `name` is exposed here even though `UpdateFamilyRequest` also
  /// accepts `status` (`Family::STATUSES`: `active`/`suspended`, verified
  /// directly) — suspending one's own family would affect every member's
  /// access at once, a materially bigger and riskier action with no UI
  /// anywhere yet (not even the web reference, which also never calls this
  /// endpoint — verified directly against `FamilyHubPage.vue`), so it's left
  /// out of this first pass deliberately rather than exposed alongside a
  /// simple rename.
  Future<Map<String, dynamic>> updateFamily({required int familyId, required String name}) async {
    final data = await _client.put('/families/$familyId', data: {'name': name});

    return Map<String, dynamic>.from(data as Map);
  }

  /// `GET /family-members` — the roster for the current (or `familyId`)
  /// family. `per_page: 100` covers every realistic family size in one
  /// page; adding real pagination is deferred until a family this large
  /// is ever seen in practice.
  Future<List<Map<String, dynamic>>> members({int? familyId}) async {
    final envelope = await _client.getPaginated(
      '/family-members',
      query: const {'per_page': 100},
      headers: _familyHeader(familyId),
    );

    return envelope.data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// `POST /family-members` — creates a new tracked-person profile directly
  /// (no device pairing required). Verified directly against
  /// `FamilyMemberController::store()`: this is the manual counterpart to
  /// device pairing (PR #35/#37), for a member who won't (or can't yet)
  /// redeem a pairing code themselves — the row starts with
  /// `status: 'pending'` server-side (the migration's own default) and
  /// flips to `'active'` automatically the first time any location ping
  /// arrives for it, exactly like a device-paired member would. `familyId`
  /// is sent as `X-Family-Id` **like every other method in this class
  /// except the family-relationship response endpoints** — verified
  /// directly against `routes/api_v1.php`: unlike
  /// `PUT`/`DELETE /family-relationships/{id}` (PR #45, deliberately
  /// outside the `family` middleware group), `family-members`' entire
  /// `apiResource` — index/store/show/update/destroy alike — sits INSIDE
  /// that group, so a multi-family account must disambiguate here too, not
  /// just on `members()`/`geofences()`. Gated by
  /// `FamilyMemberPolicy::create()` (`family_tracking.create`) — the same
  /// permission `SafeZoneEditorScreen`'s FAB already checks, reused here
  /// for the "add a member" FAB on `FamilyHomeScreen`. `linkedUserId`, when
  /// given, must be an ACTIVE `family_relationships.user_id` in this same
  /// family (verified directly against `StoreFamilyMemberRequest`'s
  /// `Rule::exists` — a stranger's id is rejected 422, not silently
  /// ignored) — this is a genuinely different link from device pairing
  /// (`Device.family_member_id`, set only by `DevicePairingController::redeem()`):
  /// it says "this tracked person also has their own login", not "this
  /// physical device is theirs".
  Future<Map<String, dynamic>> createFamilyMember({
    required String fullName,
    String? gender,
    String? birthDate,
    required String relationship,
    String? phone,
    int? linkedUserId,
    int? familyId,
  }) async {
    final data = await _client.post(
      '/family-members',
      data: {
        'full_name': fullName,
        'relationship': relationship,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (linkedUserId != null) 'linked_user_id': linkedUserId,
      },
      headers: _familyHeader(familyId),
    );

    return Map<String, dynamic>.from(data as Map);
  }

  /// `PUT /family-members/{id}` — edits an existing tracked-person profile.
  /// Every field is `sometimes` server-side (`UpdateFamilyMemberRequest`,
  /// verified directly) so this always sends the complete set this app
  /// knows about rather than a true partial update — same reasoning
  /// `updateCircleGeofence()` gives for doing the same. `status` is
  /// editable here (`pending`/`active`/`inactive`, `FamilyMember::STATUSES`)
  /// — the one field `createFamilyMember()` above never sends, since new
  /// rows always start `pending` server-side; exposing it on edit lets an
  /// admin retire a member's tracking (`inactive`) without deleting their
  /// history. Gated by `FamilyMemberPolicy::update()`
  /// (`family_tracking.edit` + active membership) — same permission
  /// `DevicePairingGenerateScreen`'s entry icon already checks. `familyId`
  /// sent as `X-Family-Id` for the same reason `createFamilyMember()`
  /// documents above.
  Future<Map<String, dynamic>> updateFamilyMember({
    required int familyMemberId,
    required String fullName,
    String? gender,
    String? birthDate,
    required String relationship,
    String? phone,
    required String status,
    int? linkedUserId,
    int? familyId,
  }) async {
    final data = await _client.put(
      '/family-members/$familyMemberId',
      data: {
        'full_name': fullName,
        'relationship': relationship,
        'phone': phone,
        'status': status,
        'linked_user_id': linkedUserId,
      },
      headers: _familyHeader(familyId),
    );

    return Map<String, dynamic>.from(data as Map);
  }

  /// `DELETE /family-members/{id}` — permanently removes a tracked-person
  /// profile (hard delete: `FamilyMember` has no `SoftDeletes`, verified
  /// directly against the model — same as `deleteGeofence()`/
  /// `deleteEmergencyContact()`). This also deletes every device-pairing
  /// link and location-history row that referenced it (the migrations'
  /// own cascading foreign keys), so the caller must confirm this is
  /// understood to be irreversible before calling it — mirrors every other
  /// destructive method in this class. Gated by `FamilyMemberPolicy::delete()`
  /// (`family_tracking.delete`). `familyId` sent as `X-Family-Id` for the
  /// same reason `createFamilyMember()` documents above.
  Future<void> deleteFamilyMember({required int familyMemberId, int? familyId}) async {
    await _client.delete('/family-members/$familyMemberId', headers: _familyHeader(familyId));
  }

  /// `GET /family-relationships` — the membership roster for the current
  /// (or `familyId`) family: who belongs, their role, status, and tracking
  /// grants. Deliberately **inside** the `family` middleware group
  /// (verified directly against `routes/api_v1.php`), unlike every method
  /// from `myInvitations()` down to `declineFamilyInvitation()` below — so
  /// this is the one method in this whole invite/roster/response family
  /// of endpoints that DOES send `X-Family-Id`. Gated by
  /// `FamilyRelationshipPolicy::viewAny()`, which is deliberately broad
  /// (any active member of the family, not just owner/admin) — mirrors
  /// the web app's roster page being visible to everyone in the family,
  /// not just managers.
  Future<List<Map<String, dynamic>>> familyRelationships({int? familyId}) async {
    final data = await _client.get('/family-relationships', headers: _familyHeader(familyId));

    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// `GET /family-invitations` — deliberately **global** across every
  /// family the account has a pending (`status: invited`) row in, not
  /// scoped to "the current family" (verified directly against
  /// `FamilyRelationshipController::myInvitations()`, which queries by
  /// `user_id` alone with no family filter) — so this is called with no
  /// `X-Family-Id` header at all, on purpose, matching the route's own
  /// placement outside the `family` middleware group (an invitee has no
  /// *active* membership yet for `ResolveFamilyContext` to resolve
  /// against). `familyName` on each row (see `FamilyRelationshipModel`)
  /// is what lets the UI say which family each invitation is for, since
  /// there is no `X-Family-Id` context doing that job here.
  Future<List<Map<String, dynamic>>> myInvitations() async {
    final data = await _client.get('/family-invitations');

    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// `POST /family-relationships` — invites an already-registered user (by
  /// phone) into the current (or `familyId`) family. `phone` must belong
  /// to an existing account — verified directly against
  /// `StoreFamilyRelationshipRequest`'s `Rule::exists('users','phone')` —
  /// there is no invite-by-arbitrary-contact/SMS-delivery flow, consistent
  /// with this app never claiming a notification was sent that wasn't.
  /// `role` must be one of `FamilyRelationship::ROLES` **minus** `'owner'`
  /// (verified against that same Form Request) — callers pass one of the
  /// five assignable roles the membership screen offers, mirroring the
  /// web reference's `ASSIGNABLE_ROLES` constant. Gated by
  /// `FamilyRelationshipPolicy::create()` — owner/admin only (`parent` is
  /// NOT a managing role despite being full-access for viewing tracking
  /// data, verified directly against `hasManagingRole()`).
  Future<Map<String, dynamic>> inviteFamilyMember({
    required String phone,
    required String role,
    String? kinship,
    int? familyId,
  }) async {
    final data = await _client.post(
      '/family-relationships',
      data: {'phone': phone, 'role': role, if (kinship != null) 'kinship': kinship},
      headers: _familyHeader(familyId),
    );

    return Map<String, dynamic>.from(data as Map);
  }

  /// `PUT /family-relationships/{id}` — edits an existing membership's
  /// role and/or tracking grants. Deliberately **no** `X-Family-Id`
  /// header (verified against `routes/api_v1.php`: this route sits
  /// outside the `family` middleware group, resolving authorization
  /// directly from the route-bound relationship's own `family_id`
  /// instead). `supervises` is sent **only when `role == 'supervisor'`**
  /// — mirrors the web reference's `submitEdit()` exactly (it omits the
  /// key client-side for every other role) even though the backend would
  /// null it out server-side regardless whenever the *effective* role
  /// isn't `'supervisor'` (verified against
  /// `FamilyRelationshipController::update()`) — sending it anyway for a
  /// non-supervisor role would be silently discarded, not an error, but
  /// there's no reason to send a field the backend is guaranteed to
  /// ignore. `trackingPermissions` is always sent when provided (no such
  /// conditional omission exists for it on the web reference).
  Future<Map<String, dynamic>> updateFamilyRelationship({
    required int relationshipId,
    required String role,
    String? kinship,
    List<String>? trackingPermissions,
    List<int>? supervises,
  }) async {
    final data = await _client.put(
      '/family-relationships/$relationshipId',
      data: {
        'role': role,
        if (kinship != null) 'kinship': kinship,
        if (trackingPermissions != null) 'tracking_permissions': trackingPermissions,
        if (role == 'supervisor' && supervises != null) 'supervises': supervises,
      },
    );

    return Map<String, dynamic>.from(data as Map);
  }

  /// `DELETE /family-relationships/{id}` — a **soft** removal (verified
  /// directly against `FamilyRelationshipController::destroy()`: it sets
  /// `status = 'removed'`, never a hard delete unlike
  /// `deleteGeofence()`/`deleteEmergencyContact()` above). No
  /// `X-Family-Id` header, same reasoning as `updateFamilyRelationship()`
  /// above. The backend also refuses to remove the family's last active
  /// `owner` (`guardLastOwner()`, a 422 with an Arabic message) — this
  /// method doesn't pre-check that client-side, it just surfaces whatever
  /// `ApiException` message comes back, same convention as every other
  /// destructive call in this class.
  Future<void> removeFamilyRelationship({required int relationshipId}) async {
    await _client.delete('/family-relationships/$relationshipId');
  }

  /// `POST /family-relationships/{id}/accept` — accepts a pending
  /// invitation that was extended to *this* account. No `X-Family-Id`
  /// (same route-outside-the-`family`-group reasoning as
  /// `myInvitations()` above) and no request body. Gated by
  /// `FamilyRelationshipPolicy::respond()` — verified directly: only the
  /// invited user themselves, and only while `status == 'invited'`.
  Future<Map<String, dynamic>> acceptFamilyInvitation({required int relationshipId}) async {
    final data = await _client.post('/family-relationships/$relationshipId/accept');

    return Map<String, dynamic>.from(data as Map);
  }

  /// `POST /family-relationships/{id}/decline` — the reject counterpart to
  /// `acceptFamilyInvitation()` above, same gating and no-body/no-header
  /// shape.
  Future<Map<String, dynamic>> declineFamilyInvitation({required int relationshipId}) async {
    final data = await _client.post('/family-relationships/$relationshipId/decline');

    return Map<String, dynamic>.from(data as Map);
  }

  /// `GET /family-timeline` — a read-only merged feed (geofence
  /// enter/exit, safe-zone additions, SOS, member additions), verified
  /// directly against `FamilyTimelineController::index()`. Unlike every
  /// other list method in this class, this one returns the raw
  /// `ApiEnvelope` itself rather than unwrapping to a plain list —
  /// mirroring `TripsApi.myTrips()`'s own precedent — because this is
  /// genuinely paginated with real prev/next navigation the screen needs
  /// (`meta.current_page`/`last_page`), unlike `members()`/`geofences()`/
  /// `alerts()` above, which all document the "fits in one page realistically"
  /// assumption instead. There is **no date-range filter** — verified
  /// directly, the controller reads only `page`/`per_page` — `per_page`
  /// is capped server-side at 50 (`MAX_PER_PAGE`), default 20, matching
  /// the web reference's own hardcoded `per_page: 20`.
  Future<ApiEnvelope> timeline({int page = 1, int perPage = 20, int? familyId}) {
    return _client.getPaginated(
      '/family-timeline',
      query: {'page': page, 'per_page': perPage},
      headers: _familyHeader(familyId),
    );
  }

  /// `GET /family-geofences` — every safe zone for the current (or
  /// `familyId`) family, active or not (filtering to active-only happens
  /// client-side — see `familyGeofenceShapes()` — so a disabled zone can
  /// still be listed/edited later without a second endpoint). `per_page:
  /// 100` for the same reason as `members()` above: covers every realistic
  /// family's safe-zone count in one page.
  Future<List<Map<String, dynamic>>> geofences({int? familyId}) async {
    final envelope = await _client.getPaginated(
      '/family-geofences',
      query: const {'per_page': 100},
      headers: _familyHeader(familyId),
    );

    return envelope.data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// `POST /family-geofences` — creates a new **circular** safe zone. A
  /// separate method rather than one `polygon_or_radius` passthrough
  /// with both shapes' fields optional, because `StoreFamilyGeofenceRequest`
  /// itself rejects a request carrying both a circle and a polygon shape
  /// (see `createPolygonGeofence()` below) — two narrow methods mirror
  /// that server-side exclusivity instead of exposing one method that
  /// could be called in a combination the backend always refuses. The
  /// nested shape structure mirrors the response shape exactly — `StoreFamilyGeofenceRequest`
  /// expects `polygon_or_radius` as a single JSON object, not flat
  /// top-level fields, verified directly against that Form Request's
  /// `withValidator()` circle branch. `family_id`/`created_by_user_id` are
  /// server-assigned and never sent. `is_active` is omitted entirely
  /// (defaults to `true` at the database level, per that column's
  /// migration) — nothing in this first mobile editor ever creates a
  /// zone that starts disabled.
  Future<Map<String, dynamic>> createCircleGeofence({
    required String name,
    required String type,
    required double centerLat,
    required double centerLng,
    required double radiusMeters,
    bool notifyOnEntry = true,
    bool notifyOnExit = true,
    int? familyId,
  }) async {
    final data = await _client.post(
      '/family-geofences',
      data: {
        'name': name,
        'type': type,
        'polygon_or_radius': {'center_lat': centerLat, 'center_lng': centerLng, 'radius_m': radiusMeters},
        'notify_on_entry': notifyOnEntry,
        'notify_on_exit': notifyOnExit,
      },
      headers: _familyHeader(familyId),
    );

    return Map<String, dynamic>.from(data as Map);
  }

  /// `POST /family-geofences` — the polygon counterpart to
  /// `createCircleGeofence()` above. `points` must have at least 3 entries
  /// — verified directly against `StoreFamilyGeofenceRequest`'s
  /// `withValidator()` closure, which rejects `polygon_or_radius.points`
  /// under 3 (not exposed as a plain `rules()` entry, since it lives in
  /// that closure alongside the circle-XOR-polygon exclusivity check —
  /// sending both `center_lat`/`radius_m` *and* `points` in the same
  /// request is rejected too, which is exactly why this and
  /// `createCircleGeofence()` are two separate methods rather than one
  /// with both sets of optional parameters). Each point is sent as a
  /// plain `[lat, lng]` pair — the same shape `FamilyGeofenceShape.fromJson`
  /// already parses back out of `points` when *reading* a polygon zone
  /// (see `family_models.dart`), so this is symmetric with what the app
  /// already consumes, not a new convention invented for this method.
  /// See `updatePolygonGeofence()` below for the edit counterpart.
  Future<Map<String, dynamic>> createPolygonGeofence({
    required String name,
    required String type,
    required List<({double lat, double lng})> points,
    bool notifyOnEntry = true,
    bool notifyOnExit = true,
    int? familyId,
  }) async {
    final data = await _client.post(
      '/family-geofences',
      data: {
        'name': name,
        'type': type,
        'polygon_or_radius': {
          'points': [
            for (final point in points) [point.lat, point.lng]
          ],
        },
        'notify_on_entry': notifyOnEntry,
        'notify_on_exit': notifyOnExit,
      },
      headers: _familyHeader(familyId),
    );

    return Map<String, dynamic>.from(data as Map);
  }

  /// `PUT /family-geofences/{id}` — updates an existing **circular** safe
  /// zone. Mirrors `createCircleGeofence()` above: sends the full circle
  /// shape every time rather than a true partial update, even though
  /// `UpdateFamilyGeofenceRequest` marks every field `sometimes` (verified
  /// directly against that Form Request) — a true partial update would let
  /// a caller send just e.g. `notify_on_entry` and leave `polygon_or_radius`
  /// untouched, but this app's only editor (`SafeZoneEditorScreen`) always
  /// has every field in hand when it saves, so sending the complete shape
  /// every time is simpler and can't accidentally leave the shape
  /// half-updated. Deliberately has no `type`-restriction of its own even
  /// though the mobile UI only ever edits circles it can render: the
  /// backend itself places no restriction on changing `type` after
  /// creation (verified against the controller/request — no such rule
  /// exists), so this mirrors that freedom rather than inventing a
  /// client-side one.
  Future<Map<String, dynamic>> updateCircleGeofence({
    required int geofenceId,
    required String name,
    required String type,
    required double centerLat,
    required double centerLng,
    required double radiusMeters,
    required bool notifyOnEntry,
    required bool notifyOnExit,
    int? familyId,
  }) async {
    final data = await _client.put(
      '/family-geofences/$geofenceId',
      data: {
        'name': name,
        'type': type,
        'polygon_or_radius': {'center_lat': centerLat, 'center_lng': centerLng, 'radius_m': radiusMeters},
        'notify_on_entry': notifyOnEntry,
        'notify_on_exit': notifyOnExit,
      },
      headers: _familyHeader(familyId),
    );

    return Map<String, dynamic>.from(data as Map);
  }

  /// `PUT /family-geofences/{id}` — the polygon counterpart to
  /// `updateCircleGeofence()` above, mirroring `createPolygonGeofence()`'s
  /// point encoding (`points` as plain `[lat, lng]` pairs). Unlike
  /// `StoreFamilyGeofenceRequest`, `UpdateFamilyGeofenceRequest` has no
  /// `withValidator()` closure at all (verified directly against that Form
  /// Request) — the backend does not re-check the circle-XOR-polygon
  /// exclusivity nor the 3-point minimum on update, it trusts the caller
  /// more than it does on create. This method still requires at least 3
  /// points itself (`SafeZoneEditorScreen` also checks before calling it)
  /// so this app can never produce a degenerate polygon server-side even
  /// though the server itself would technically accept one.
  Future<Map<String, dynamic>> updatePolygonGeofence({
    required int geofenceId,
    required String name,
    required String type,
    required List<({double lat, double lng})> points,
    required bool notifyOnEntry,
    required bool notifyOnExit,
    int? familyId,
  }) async {
    assert(points.length >= 3, 'A polygon needs at least 3 points.');

    final data = await _client.put(
      '/family-geofences/$geofenceId',
      data: {
        'name': name,
        'type': type,
        'polygon_or_radius': {
          'points': [
            for (final point in points) [point.lat, point.lng]
          ],
        },
        'notify_on_entry': notifyOnEntry,
        'notify_on_exit': notifyOnExit,
      },
      headers: _familyHeader(familyId),
    );

    return Map<String, dynamic>.from(data as Map);
  }

  /// `DELETE /family-geofences/{id}` — a **hard** delete (verified against
  /// the model/migrations: `FamilyGeofence` has no `SoftDeletes` trait and
  /// no `deleted_at` column exists), so this is not reversible from the
  /// app. Works regardless of the zone's shape (circle or polygon) — unlike
  /// editing, deletion never depends on this app being able to render the
  /// shape it's removing.
  Future<void> deleteGeofence({required int geofenceId, int? familyId}) async {
    await _client.delete('/family-geofences/$geofenceId', headers: _familyHeader(familyId));
  }

  /// `GET /family-members/{id}/locations?from=&to=` — PR-F on the backend.
  /// Gated per-record by `ViewFamilyMemberLocationHistoryRequest`: first
  /// `FamilyMemberPolicy::view()` (active membership + supervisor scoping
  /// to this specific member — same as the roster itself), then the
  /// `location_history` capability specifically, so a viewer who can see
  /// this member's card may still be refused their raw trail. `from`/`to`
  /// are sent as ISO 8601 (every other timestamp in this API uses the same
  /// format); the backend rejects a range over 30 days with a 422.
  /// `per_page: 100` is the backend's own max — no further pagination is
  /// attempted here, matching `members()`'s "covers every realistic case in
  /// one page" reasoning above.
  Future<List<Map<String, dynamic>>> locationHistory({
    required int familyMemberId,
    required DateTime from,
    required DateTime to,
    int? familyId,
  }) async {
    final envelope = await _client.getPaginated(
      '/family-members/$familyMemberId/locations',
      query: {
        'from': from.toIso8601String(),
        'to': to.toIso8601String(),
        'per_page': 100,
      },
      headers: _familyHeader(familyId),
    );

    return envelope.data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// `POST /family-members/{id}/pairing-codes` — generates a fresh,
  /// single-use, 10-minute pairing code for the given family member so
  /// *another* device can attach itself via `redeemDevicePairing()` below.
  /// No request body: `DevicePairingController::store()` takes the family
  /// member straight off the route (`FamilyMember $familyMember`), nothing
  /// else. Sent with `X-Family-Id` like every other family-scoped call here
  /// — unlike `redeemDevicePairing()`, this one DOES live inside the
  /// `family` middleware group, since generating a code requires being an
  /// active member of that specific family.
  ///
  /// Gated by `FamilyMemberPolicy::update()` (deliberately reused rather
  /// than a stricter owner-only rule per the controller's own docblock):
  /// the caller needs `family_tracking.edit`, not just view access — so a
  /// `child`/`member` role who can see a sibling's card may still get a 403
  /// here even though `members()` above already let them list that row.
  Future<Map<String, dynamic>> generatePairingCode({required int familyMemberId, int? familyId}) async {
    final data = await _client.post(
      '/family-members/$familyMemberId/pairing-codes',
      headers: _familyHeader(familyId),
    );

    return Map<String, dynamic>.from(data as Map);
  }

  /// `POST /device-pairing/redeem` — attaches *this* device (identified
  /// server-side by the Sanctum token authenticating the request, not by
  /// anything sent here) to whichever family member the code was
  /// generated for. Deliberately **not** sent with an `X-Family-Id`
  /// header and has nothing to do with `selectedFamilyIdProvider`: per
  /// `DevicePairingController::redeem()`'s docblock, this endpoint lives
  /// outside the `family` middleware group entirely — the device
  /// redeeming a code need not be an active member (or member at all) of
  /// the target family yet, so there is no family context to resolve or
  /// send. The account merely needs to be logged in.
  Future<Map<String,dynamic>> previewDevicePairing({required String code}) async =>
      Map<String,dynamic>.from(await _client.post('/device-pairing/preview',data:{'code':code}) as Map);

  Future<Map<String,dynamic>> confirmDevicePairing({required String code, required int familyMemberId,
      required String viewerKinship, required String deviceRelationship, String? correctedName}) async =>
      Map<String,dynamic>.from(await _client.post('/device-pairing/confirm',data:{
        'code':code,'family_member_id':familyMemberId,'viewer_kinship':viewerKinship,
        'device_relationship':deviceRelationship,if(correctedName!=null)'corrected_name':correctedName,
      }) as Map);

  Future<String?> redeemDevicePairing({required String code}) async {
    final data = await _client.post('/device-pairing/redeem', data: {'code': code});

    return Map<String, dynamic>.from(data as Map)['family_member_name'] as String?;
  }

  /// `GET /emergency-contacts` — the current (or `familyId`) family's
  /// emergency-contact list. Deliberately uses `get()`, not
  /// `getPaginated()`: `EmergencyContactController::index()` returns a
  /// plain (unpaginated) collection (verified directly — no `per_page`
  /// anywhere in that action), the same reasoning `myFamilies()` above
  /// already documents for a list no family has enough rows to need
  /// paging for.
  Future<List<Map<String, dynamic>>> emergencyContacts({int? familyId}) async {
    final data = await _client.get('/emergency-contacts', headers: _familyHeader(familyId));

    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// `POST /emergency-contacts` — gated by `EmergencyContactPolicy::create()`,
  /// which checks `sos.manage_contacts` specifically — **not**
  /// `family_tracking.*` like every geofence/pairing endpoint above. Family
  /// membership isn't separately checked for create (verified against the
  /// policy) — only the permission itself, plus whatever family
  /// `familyId`/`X-Family-Id` context resolves to server-side.
  Future<Map<String, dynamic>> createEmergencyContact({
    required String name,
    required String phone,
    String? relationship,
    bool notifyOnSos = true,
    int? familyId,
  }) async {
    final data = await _client.post(
      '/emergency-contacts',
      data: {
        'name': name,
        'phone': phone,
        'relationship': relationship,
        'notify_on_sos': notifyOnSos,
      },
      headers: _familyHeader(familyId),
    );

    return Map<String, dynamic>.from(data as Map);
  }

  /// `PUT /emergency-contacts/{id}` — every field is `sometimes` server-side
  /// (true partial update, verified against `UpdateEmergencyContactRequest`),
  /// but this always sends the complete set for the same reason
  /// `updateCircleGeofence()` does: the only caller always has every field
  /// in hand, so there's no partial-update case to actually exploit, and
  /// sending everything can't leave a field stale by omission. Gated by
  /// `EmergencyContactPolicy::update()` — `sos.manage_contacts` **and**
  /// active family membership this time (delete delegates to the same
  /// check).
  Future<Map<String, dynamic>> updateEmergencyContact({
    required int contactId,
    required String name,
    required String phone,
    String? relationship,
    required bool notifyOnSos,
    int? familyId,
  }) async {
    final data = await _client.put(
      '/emergency-contacts/$contactId',
      data: {
        'name': name,
        'phone': phone,
        'relationship': relationship,
        'notify_on_sos': notifyOnSos,
      },
      headers: _familyHeader(familyId),
    );

    return Map<String, dynamic>.from(data as Map);
  }

  /// `DELETE /emergency-contacts/{id}` — a **hard** delete (no
  /// `SoftDeletes` on the model, no `deleted_at` column), same as
  /// `deleteGeofence()`. Gated by the same `sos.manage_contacts` +
  /// membership check as update (`EmergencyContactPolicy::delete()`
  /// delegates to `update()`).
  Future<void> deleteEmergencyContact({required int contactId, int? familyId}) async {
    await _client.delete('/emergency-contacts/$contactId', headers: _familyHeader(familyId));
  }

  /// `GET /alerts/unread-count` — same lightweight badge-count endpoint
  /// the web app's AppLayout notification bell polls.
  Future<int> unreadAlertsCount({int? familyId}) async {
    final data = await _client.get('/alerts/unread-count', headers: _familyHeader(familyId));

    return (Map<String, dynamic>.from(data as Map)['count'] as num).toInt();
  }

  /// `GET /alerts` — this family's alerts (geofence entry/exit, SOS, and
  /// whatever other `Alert::TYPES` the backend starts raising later),
  /// however the backend orders them (newest first in practice). `per_page:
  /// 50` is a first-pass choice, not exhaustive pagination — matches
  /// `members()`/`geofences()`'s "covers the realistic case in one page"
  /// reasoning; a family with a genuinely long alert history would need
  /// real pagination added later.
  ///
  /// `status`/`severity`/`type` mirror `AlertController::index()`'s own
  /// three `$request->input(...)` filters exactly (verified directly
  /// against that controller) — each is a plain equality filter applied
  /// server-side before `scopeVisible()`'s permission/supervisor scoping,
  /// so a filtered call can never surface a row an unfiltered call
  /// wouldn't already have shown. All three are optional and independent
  /// (any combination, including none, is valid) — omitted entirely rather
  /// than sent empty when null, matching every other optional-query-param
  /// method in this file (e.g. `locationHistory()`).
  Future<List<Map<String, dynamic>>> alerts({
    int? familyId,
    String? status,
    String? severity,
    String? type,
  }) async {
    final envelope = await _client.getPaginated(
      '/alerts',
      query: {
        'per_page': 50,
        if (status != null) 'status': status,
        if (severity != null) 'severity': severity,
        if (type != null) 'type': type,
      },
      headers: _familyHeader(familyId),
    );

    return envelope.data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// `POST /alerts/{id}/read` — flips `unread` → `read`; a no-op on the
  /// backend for any other current status (idempotent). Gated by
  /// `alerts.view` — the exact same permission that lets this list load at
  /// all — so nothing extra to check client-side before showing this
  /// action.
  Future<Map<String, dynamic>> markAlertRead({required int alertId, int? familyId}) async {
    final data = await _client.post('/alerts/$alertId/read', headers: _familyHeader(familyId));

    return Map<String, dynamic>.from(data as Map);
  }

  /// `POST /alerts/{id}/resolve` — sets `resolved_by_user_id`/`resolved_at`
  /// and flips status to `resolved`. Gated by `alerts.resolve` — a
  /// **separate, stricter** permission from `alerts.view`, verified
  /// directly against `AlertPolicy` — so the resolve action is hidden
  /// client-side (not merely disabled) for anyone without it, mirroring
  /// every other permission-gated control in this app.
  Future<Map<String, dynamic>> resolveAlert({required int alertId, int? familyId}) async {
    final data = await _client.post('/alerts/$alertId/resolve', headers: _familyHeader(familyId));

    return Map<String, dynamic>.from(data as Map);
  }

  /// `POST /family-members/{id}/sos` — see
  /// FamilyMemberPolicy::triggerSos()'s docblock for why this has no
  /// permission gate at all (a safety action must work regardless of what
  /// tracking capabilities an admin has or hasn't granted).
  Future<Map<String, dynamic>> triggerSos({
    required int familyMemberId,
    required double lat,
    required double lng,
    int? batteryLevel,
    int? familyId,
  }) async {
    final data = await _client.post(
      '/family-members/$familyMemberId/sos',
      data: {
        'lat': lat,
        'lng': lng,
        if (batteryLevel != null) 'battery_level': batteryLevel,
      },
      headers: _familyHeader(familyId),
    );

    return Map<String, dynamic>.from(data as Map);
  }

  /// `GET /sos-events` — this family's SOS incidents (a materially richer,
  /// purpose-built record than `alerts()` above for this one incident
  /// type: structured lat/lng, battery level, and a full acknowledge+
  /// resolve audit trail — `AlertResource` carries none of that, only an
  /// untyped `payload`). `status` mirrors the backend's exact-match filter
  /// (`active`/`acknowledged`/`resolved`); `null` omits it entirely and
  /// returns every status, matching how `alerts()` above passes no status
  /// filter at all. `per_page: 50` for the same "first-pass, not
  /// exhaustive pagination" reasoning as `alerts()`.
  Future<List<Map<String, dynamic>>> sosEvents({String? status, int? familyId}) async {
    final envelope = await _client.getPaginated(
      '/sos-events',
      query: {'per_page': 50, if (status != null) 'status': status},
      headers: _familyHeader(familyId),
    );

    return envelope.data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// `POST /sos-events/{id}/acknowledge` — no request body (verified
  /// against the backend: plain `POST`, no validation rules). A no-op
  /// server-side unless the event is still `active` (idempotent, same
  /// pattern as `markAlertRead`). Gated by `sos.acknowledge`.
  Future<Map<String, dynamic>> acknowledgeSosEvent({required int sosEventId, int? familyId}) async {
    final data = await _client.post('/sos-events/$sosEventId/acknowledge', headers: _familyHeader(familyId));

    return Map<String, dynamic>.from(data as Map);
  }

  /// `POST /sos-events/{id}/resolve` — same no-body, idempotent shape as
  /// acknowledge above (a no-op unless the event isn't already
  /// `resolved`). Gated by `sos.resolve` — a **separate** permission from
  /// `sos.acknowledge`, verified directly against `SosEventPolicy`, so
  /// this action is hidden client-side for anyone who can acknowledge but
  /// not resolve, mirroring `alerts.resolve` vs `alerts.view` above.
  Future<Map<String, dynamic>> resolveSosEvent({required int sosEventId, int? familyId}) async {
    final data = await _client.post('/sos-events/$sosEventId/resolve', headers: _familyHeader(familyId));

    return Map<String, dynamic>.from(data as Map);
  }
}
