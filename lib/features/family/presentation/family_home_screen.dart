import '../../family_life/presentation/managed_content_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/widgets/family_motion.dart';
import '../../../core/network/api_exception.dart';
import '../../family_tasks/application/family_tasks_providers.dart';
import '../../family_tasks/data/family_task_models.dart';
import '../application/family_providers.dart';
import '../data/family_models.dart';

/// The family-tracking landing screen — the mobile mirror of the web
/// app's FamilyHubPage.vue (backend/resources/js/pages/FamilyHubPage.vue),
/// scoped down to what a first mobile pass needs: the member roster, an
/// unread-alerts count, an SOS button per member, a per-member location
/// history entry point (see FamilyMemberLocationHistoryScreen's docblock),
/// a per-member "generate a pairing code for their device" entry point
/// (see DevicePairingGenerateScreen's docblock — shown only to members who
/// hold `family_tracking.edit`, mirroring the server-side gate so the icon
/// never appears just to 403 on tap), a live map via the app bar's map icon
/// (see FamilyMapScreen's docblock — it also overlays safe zones), and a
/// device-pairing *redeem* entry point (see DevicePairingRedeemScreen's
/// docblock, for pairing *this* device) via the app bar's link icon,
/// (for accounts with `alerts.view`) a bell that opens the full Alerts
/// Center (see FamilyAlertsScreen's docblock) rather than just
/// re-polling the unread count in place, and (for accounts with
/// `sos.view` or `sos.manage_contacts`) an icon into
/// `EmergencyContactsScreen` — a genuinely separate permission family
/// (`sos.*`) from every other icon on this bar, and (for accounts with
/// `sos.view` specifically — see `SosEventsScreen`'s docblock for why
/// that permission alone, not the OR above) an icon into the SOS incident
/// list, where the per-member SOS button below (`_MemberCard._triggerSos`)
/// actually leads once triggered, and (for every account — no gate here,
/// matching `FamilyRelationshipPolicy::viewAny()`'s own broad "any active
/// member" check) a "people" icon into `FamilyMembershipScreen` — the
/// account-membership roster (invite/role/tracking-grants/remove, plus the
/// account's own pending invitations), a genuinely different thing from
/// the tracked-people roster this screen itself shows below (see that
/// screen's docblock for the full distinction), and (also ungated, for the
/// same broad-viewAny reasoning) a "نشاط العائلة" icon into
/// `FamilyTimelineScreen` — a read-only merged activity feed (geofence
/// events, SOS, member/zone additions). There is deliberately no
/// shared bottom-nav shell for accounts that are BOTH a driver and a family
/// member — confirmed with the product owner (2026-09-10) that dual
/// driver+family accounts don't occur in practice, so this is not an
/// open item, just a closed one worth noting here for anyone re-deriving
/// this screen's scope later.
///
/// **Direct member CRUD** (add/edit/delete a tracked-person profile,
/// `_MemberFormDialog` below): verified directly against
/// `FamilyMemberController`/`FamilyMemberPolicy` — the last of the three
/// gaps the pre-PR#45 scan surfaced (the other two, membership management
/// and the merged timeline, shipped as PR #45/#46). This is the manual
/// counterpart to device pairing (PR #35/#37): a member with no device to
/// pair yet (or that will never carry one) still needs a roster row to be
/// visible anywhere else in the app (SOS target, geofence subject, alerts
/// subject). The "add" FAB is gated on `family_tracking.create` (same
/// permission `SafeZoneEditorScreen`'s own FAB checks); per-card edit/delete
/// are gated on `family_tracking.edit`/`family_tracking.delete`
/// respectively — three independent permissions, mirroring
/// `SafeZonesListScreen`'s own "never assume one implies another" note.
///
/// **Rename the family itself** (`Icons.drive_file_rename_outline` in the
/// app bar, `_renameFamily` below) — `PUT /families/{id}`
/// (`FamilyApi.updateFamily()`), the last gap a fresh backend-vs-mobile scan
/// surfaced after PR #48: `FamilyController::update()` was fully built and
/// reachable from neither this app nor the web reference. Gated coarsely on
/// `family_tracking.edit` here (this app has no per-family role lookup to
/// also pre-check `FamilyPolicy::update()`'s stricter owner/admin
/// requirement — see `FamilyApi.updateFamily()`'s own docblock for why that
/// second half is left to the backend's 403), and only offered once a
/// family is actually selected.
///
/// **PR-70 (Family Tasks & Achievements, mobile — final PR of the plan)**:
/// a "👨‍👩‍👧‍👦 عائلتي" summary card (`_FamilyTasksSummaryCard`) plus a
/// six-tile "شبكة الركائز" (`_SixPillarGrid`) are inserted into `_Body`
/// between the family switcher and the tracked-person roster — the
/// smallest change that adds them without touching any pre-existing
/// widget/provider/import on this screen (SOS, geofencing, alerts,
/// timeline, membership, device pairing, etc. from PR #32 through #50-ish
/// are untouched, exactly as the plan scopes this PR). The summary card
/// deliberately fetches TODAY's occurrences via its own dedicated provider
/// (`todayFamilyTaskOccurrencesProvider`), not the "مهامي" screen's own
/// day-paging provider — see that provider's own docblock for why sharing
/// it here would be a real bug (go_router keeps a pushed route's widgets
/// mounted underneath whatever is pushed on top of it). The six-pillar
/// grid consolidates entry points into the `family_tasks` feature
/// specifically (📍التتبع/✅المهام/⭐نقاطي/🏆الإنجازات/🎁المكافآت/📊التقرير);
/// it deliberately does not touch the pre-existing, unrelated app-bar
/// icons above (map/pair-device/membership/timeline/alerts/emergency
/// contacts/SOS), which stay exactly as they are — out of scope for this
/// plan entirely.
class FamilyHomeScreen extends ConsumerWidget {
  const FamilyHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final familiesAsync = ref.watch(myFamiliesProvider);
    final resolvedFamilies = familiesAsync.valueOrNull ?? const <FamilyModel>[];
    final selectedFamilyId = ref.watch(selectedFamilyIdProvider);
    // Mirrors _FamilySwitcher's own "fall back to the first family when
    // nothing is selected yet" default (the common zero/one-family case,
    // before ref.listen below has had a chance to auto-select).
    final currentFamily = resolvedFamilies.isEmpty
        ? null
        : resolvedFamilies.firstWhere((f) => f.id == selectedFamilyId,
            orElse: () => resolvedFamilies.first);

    // Auto-select the sole family the moment the list resolves, so
    // familyMembersProvider never has to guess — mirrors the disambiguation
    // rule documented on selectedFamilyIdProvider itself.
    ref.listen(myFamiliesProvider, (previous, next) {
      next.whenData((families) {
        final selected = ref.read(selectedFamilyIdProvider);

        if (selected == null && families.length == 1) {
          ref.read(selectedFamilyIdProvider.notifier).state = families.first.id;
        }
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('أفراد عائلتي وأجهزتهم'),
        actions: [
          if (user != null && user.permissions.contains('alerts.view'))
            const _AlertsBadge(),
          PopupMenuButton<String>(
            tooltip: 'أدوات العائلة',
            icon: const Icon(Icons.more_horiz),
            onSelected: (destination) {
              if (destination == 'rename' && currentFamily != null) {
                _renameFamily(context, ref, currentFamily);
              } else {
                context.push(destination);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: '/family/map', child: Text('خريطة العائلة')),
              const PopupMenuItem(
                  value: '/family/pair-device', child: Text('ربط هذا الجهاز')),
              const PopupMenuItem(
                  value: '/family/membership',
                  child: Text('حسابات أفراد العائلة')),
              const PopupMenuItem(
                  value: '/family/timeline', child: Text('نشاط العائلة')),
              if (user != null &&
                  (user.permissions.contains('sos.view') ||
                      user.permissions.contains('sos.manage_contacts')))
                const PopupMenuItem(
                    value: '/family/emergency-contacts',
                    child: Text('جهات الاتصال الطارئة')),
              if (user != null && user.permissions.contains('sos.view'))
                const PopupMenuItem(
                    value: '/family/sos-events',
                    child: Text('حالات الاستغاثة')),
              if (currentFamily != null &&
                  user != null &&
                  user.permissions.contains('family_tracking.edit'))
                const PopupMenuItem(
                    value: 'rename', child: Text('تعديل اسم العائلة')),
              if (user != null && user.isDriver)
                const PopupMenuItem(value: '/home', child: Text('رحلاتي')),
              if (user != null && user.hasManagementAccess)
                const PopupMenuItem(value: '/admin', child: Text('الإدارة')),
              const PopupMenuItem(
                  value: '/profile', child: Text('حسابي وأجهزتي')),
            ],
          ),
        ],
      ),
      body: familiesAsync.when(
        data: (families) => _Body(families: families, currentUserId: user?.id),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(myFamiliesProvider),
        ),
      ),
      // Only offered once a family actually exists (see _NoFamilyState for
      // the "create a family first" path) and only to an account holding
      // family_tracking.create — mirrors FamilyMapScreen's own FAB gate.
      floatingActionButton: (familiesAsync.valueOrNull?.isNotEmpty ?? false) &&
              user != null &&
              user.permissions.contains('family_tracking.create')
          ? FloatingActionButton.extended(
              onPressed: () => _addMember(context, ref),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('إضافة فرد'),
            )
          : null,
    );
  }

  Future<void> _addMember(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<_MemberFormResult>(
      context: context,
      builder: (context) => const _MemberFormDialog(),
    );

    if (result == null) return;

    try {
      final familyId = ref.read(selectedFamilyIdProvider);

      await ref.read(familyApiProvider).createFamilyMember(
            fullName: result.fullName,
            gender: result.gender,
            birthDate: result.birthDate,
            relationship: result.relationship,
            phone: result.phone,
            linkedUserId: result.linkedUserId,
            familyId: familyId,
          );
      ref.invalidate(familyMembersProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تمت إضافة فرد العائلة بنجاح')));
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر إضافة فرد العائلة: $error')));
      }
    }
  }

  Future<void> _renameFamily(
      BuildContext context, WidgetRef ref, FamilyModel family) async {
    final controller = TextEditingController(text: family.name);

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعادة تسمية العائلة'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'اسم العائلة'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    // Also skips the call entirely when the name didn't actually change —
    // no reason to round-trip a PUT that would just echo the same value
    // back, matching this dialog's own "unchanged means cancel" affordance
    // (there's no separate way to press "cancel" once typing has started
    // other than clearing back to the original text or the X/back gesture).
    if (name == null ||
        name.isEmpty ||
        name == family.name ||
        !context.mounted) {
      return;
    }

    try {
      await ref
          .read(familyApiProvider)
          .updateFamily(familyId: family.id, name: name);
      ref.invalidate(myFamiliesProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تحديث اسم العائلة')));
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر تحديث اسم العائلة: $error')));
      }
    }
  }
}

class _AlertsBadge extends ConsumerWidget {
  const _AlertsBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadAlertsCountProvider).valueOrNull ?? 0;

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          tooltip: 'التنبيهات',
          // Used to just re-invalidate the count in place — a bell that
          // showed a number but never let you see what was behind it. Now
          // opens the actual list (FamilyAlertsScreen); that screen's own
          // refresh button/pull-to-refresh covers what this onPressed used
          // to do, and returning from it still leaves this provider to
          // re-fetch naturally on the next rebuild.
          onPressed: () => context.push('/family/alerts'),
        ),
        if (count > 0)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  borderRadius: BorderRadius.circular(10)),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
      ],
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.families, required this.currentUserId});

  final List<FamilyModel> families;
  final int? currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (families.isEmpty) {
      return _NoFamilyState(
          onRefresh: () => ref.invalidate(myFamiliesProvider));
    }

    final selectedFamilyId = ref.watch(selectedFamilyIdProvider);
    final membersAsync = ref.watch(familyMembersProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myFamiliesProvider);
        ref.invalidate(familyMembersProvider);
        ref.invalidate(unreadAlertsCountProvider);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          if (families.length > 1)
            _FamilySwitcher(
                families: families, selectedFamilyId: selectedFamilyId),
          const FamilyHero(
              playful: false,
              title: 'أهل البيت… أقرب لبعض',
              subtitle:
                  'أفراد عائلتك وأجهزتهم ومتابعتهم، بخطوات بسيطة وواضحة.'),
          const ManagedContentPanel(),
          Card(
              child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.link_rounded)),
                  title: const Text('إدخال الكود على هاتف الابن أو البنت'),
                  subtitle: const Text(
                      'الأب أو الأم يولّدون الكود من بطاقة الطفل؛ أدخله هنا على هاتف الطفل نفسه'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => context.push('/family/pair-device'))),
          const _FamilyTasksSummaryCard(),
          const _SixPillarGrid(),
          Card(
              child: ListTile(
                  leading: const Icon(Icons.home_rounded),
                  title: const Text('بيتنا ❤️'),
                  subtitle: const Text('وجباتنا واحتياجاتنا وفرحتنا اليومية'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => context.push('/our-home'))),
          Card(
              child: ListTile(
                  leading: const Icon(Icons.fitness_center),
                  title: const Text('رياضة اليوم'),
                  subtitle: const Text(
                      'تمارين إلك ولجهالك حسب العمر، مع شرح مختصر ومتابعة الإنجاز'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => context.push('/exercises'))),
          if (ref.watch(canManageFamilyTasksProvider) &&
              (membersAsync.valueOrNull ?? []).any((m) => m.birthDate == null))
            const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                    'أكمل تواريخ ميلاد أفراد العائلة من تعديل بياناتهم لعرض التمارين المناسبة.')),
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('أفراد العائلة',
                  style: Theme.of(context).textTheme.titleLarge)),
          membersAsync.when(
            data: (members) =>
                _MemberList(members: members, currentUserId: currentUserId),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => _ErrorState(
                message: error.toString(),
                onRetry: () => ref.invalidate(familyMembersProvider)),
          ),
        ],
      ),
    );
  }
}

class _FamilySwitcher extends ConsumerWidget {
  const _FamilySwitcher(
      {required this.families, required this.selectedFamilyId});

  final List<FamilyModel> families;
  final int? selectedFamilyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DropdownButtonFormField<int>(
        // ResolveFamilyContext (backend) rejects an ambiguous request with
        // 422 rather than guessing — this switcher is what lets the app
        // always send an explicit X-Family-Id once there's more than one.
        decoration: const InputDecoration(
            labelText: 'العائلة', border: OutlineInputBorder()),
        // `value` is deprecated in favor of `initialValue` as of Flutter
        // 3.33 — but this field is NOT merely an initial value: it must
        // track selectedFamilyIdProvider on every rebuild (the user can
        // change it, or it can auto-select once myFamiliesProvider
        // resolves — see FamilyHomeScreen.build's ref.listen). `initialValue`
        // alone would freeze at the first render. DropdownButtonFormField
        // still applies `initialValue` on every build in practice (it has
        // no internal state of its own beyond what's passed in), so this
        // is safe — see https://github.com/flutter/flutter/pull/136267.
        initialValue: selectedFamilyId ?? families.first.id,
        items: [
          for (final family in families)
            DropdownMenuItem(value: family.id, child: Text(family.name)),
        ],
        onChanged: (value) =>
            ref.read(selectedFamilyIdProvider.notifier).state = value,
      ),
    );
  }
}

/// PR-70: "👨‍👩‍👧‍👦 عائلتي" — today's date plus a compact family-wide
/// summary (tasks due today / already acted on / points already credited
/// today), then a per-member mini row. Deliberately watches
/// `todayFamilyTaskOccurrencesProvider` (its own dedicated provider — see
/// that provider's own docblock for why it is NOT
/// `familyTaskOccurrencesProvider`/`myTasksDateProvider`, the pair
/// `MyFamilyTasksScreen` pages through) rather than inventing any new
/// backend endpoint: this card only ever shows what
/// `GET /family-task-occurrences` already returns for today, for whichever
/// account is viewing (the whole family's, for a manager; just their own,
/// for a plain member/child — the backend decides which, unchanged from
/// how "مهامي" already works).
class _FamilyTasksSummaryCard extends ConsumerWidget {
  const _FamilyTasksSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final occurrencesAsync = ref.watch(todayFamilyTaskOccurrencesProvider);
    final today = DateTime.now();
    final dateLabel =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              children: [
                const Text('عائلتي',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(dateLabel, style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 12),
            occurrencesAsync.when(
              data: (occurrences) => _TodaySummary(occurrences: occurrences),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
              error: (error, stack) => Text(
                'تعذر تحميل ملخص اليوم.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.occurrences});

  final List<FamilyTaskOccurrenceModel> occurrences;

  @override
  Widget build(BuildContext context) {
    if (occurrences.isEmpty) {
      return const Text('لا توجد مهام مستحقة اليوم.');
    }

    // "مُنجَزة" = occurrences the member has already acted on (either
    // awaiting a parent's decision or already approved) — deliberately
    // excludes `pending` (not yet acted on) and `missed`/`rejected` (never
    // a "completed" state), so this count only ever reflects real,
    // positive action.
    final completed = occurrences
        .where((o) => o.status == 'pending_approval' || o.status == 'approved')
        .length;
    // "نقاط اليوم" only counts already-`approved` occurrences — the exact
    // moment points are actually credited via `FamilyPointsLedger::record()`
    // (see that service's docblock on the backend); a `pending_approval`
    // row's `pointsAwarded` is only a generation-time snapshot, not yet a
    // real credit to anyone's balance.
    final pointsToday = occurrences
        .where((o) => o.status == 'approved')
        .fold<int>(0, (sum, o) => sum + (o.pointsAwarded ?? 0));

    // Grouped in first-seen order (== API response order) — deliberately
    // never sorted by completed/total, same "no client-side ranking"
    // discipline plan judgment call #7 established for the weekly report
    // and the challenge progress board.
    final order = <int>[];
    final byMember = <int, ({String name, int total, int completed})>{};
    for (final occurrence in occurrences) {
      final member = occurrence.member;
      final existing = byMember[member.id];
      final isDone = occurrence.status == 'pending_approval' ||
          occurrence.status == 'approved';

      if (existing == null) order.add(member.id);

      byMember[member.id] = (
        name: member.fullName,
        total: (existing?.total ?? 0) + 1,
        completed: (existing?.completed ?? 0) + (isDone ? 1 : 0),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _StatChip(label: 'مهام اليوم', value: '${occurrences.length}'),
            const SizedBox(width: 8),
            _StatChip(label: 'مُنجَزة', value: '$completed'),
            const SizedBox(width: 8),
            _StatChip(label: 'نقاط اليوم', value: '$pointsToday'),
          ],
        ),
        const SizedBox(height: 12),
        for (final memberId in order)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
                '${byMember[memberId]!.name}: ${byMember[memberId]!.completed}/${byMember[memberId]!.total}'),
          ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}

/// PR-70: "شبكة الركائز الست" — six equal tiles consolidating navigation
/// into the family_tasks feature specifically
/// (📍التتبع/✅المهام/⭐نقاطي/🏆الإنجازات/🎁المكافآت/📊التقرير), exactly the
/// six the plan names. Deliberately does NOT touch any pre-existing
/// app-bar icon on this screen (map/membership/timeline/alerts/emergency
/// contacts/SOS/device pairing) — those are unrelated features out of this
/// plan's scope entirely, see this file's own class docblock. No
/// `GridView` precedent exists elsewhere in this app (verified directly,
/// grepped `mobile/lib` before writing this) — `GridView.count` is the
/// most direct, unambiguous stdlib widget for "N equal tiles in a fixed
/// column count", used here with `shrinkWrap`/`NeverScrollableScrollPhysics`
/// since it sits inside this screen's own outer, non-scrolling `Column`
/// (the roster below scrolls on its own via its own `Expanded`).
class _SixPillarGrid extends StatelessWidget {
  const _SixPillarGrid();

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _PillarTile(
          icon: Icons.location_on_outlined,
          label: 'التتبع',
          onTap: () => context.push('/family/map')),
      _PillarTile(
          icon: Icons.task_alt,
          label: 'المهام',
          onTap: () => context.push('/family/tasks')),
      _PillarTile(
          icon: Icons.stars_outlined,
          label: 'نقاطي',
          onTap: () => context.push('/family/points')),
      _PillarTile(
          icon: Icons.emoji_events_outlined,
          label: 'الإنجازات',
          onTap: () => context.push('/family/achievements')),
      _PillarTile(
          icon: Icons.card_giftcard,
          label: 'المكافآت',
          onTap: () => context.push('/family/rewards')),
      _PillarTile(
          icon: Icons.insights_outlined,
          label: 'التقرير',
          onTap: () => context.push('/family/tasks/weekly-report')),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: .85,
        children: tiles,
      ),
    );
  }
}

class _PillarTile extends StatelessWidget {
  const _PillarTile(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _MemberList extends StatelessWidget {
  const _MemberList({required this.members, required this.currentUserId});

  final List<FamilyMemberModel> members;
  final int? currentUserId;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const Card(
          child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(children: [
                Icon(Icons.family_restroom, size: 44),
                SizedBox(height: 12),
                Text('بعدنا ببداية حكاية العائلة'),
                SizedBox(height: 8),
                Text(
                    'اضغط إضافة فرد لإضافة ابن أو بنت، وبعدها اربط جهازه إذا عنده هاتف.',
                    textAlign: TextAlign.center)
              ])));
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: members.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) => FamilyReveal(
          key: ValueKey(members[index].id),
          child: _MemberCard(
            member: members[index],
            isMe: currentUserId != null && members[index].isMe(currentUserId!),
          )),
    );
  }
}

class _MemberCard extends ConsumerStatefulWidget {
  const _MemberCard({required this.member, required this.isMe});

  final FamilyMemberModel member;
  final bool isMe;

  @override
  ConsumerState<_MemberCard> createState() => _MemberCardState();
}

class _MemberCardState extends ConsumerState<_MemberCard> {
  bool _busy = false;

  FamilyMemberModel get member => widget.member;

  @override
  Widget build(BuildContext context) {
    final location = member.latestLocation;
    final hasLastSeen = member.lastSeenAt != null;
    final user = ref.watch(authControllerProvider).user;
    // Mirrors FamilyMemberPolicy::update() — the exact permission
    // DevicePairingController::store() checks server-side — so this icon
    // never appears just to fail with a 403 on tap for a plain member.
    final canGeneratePairingCode =
        user != null && user.permissions.contains('family_tracking.edit');
    final canEdit =
        user != null && user.permissions.contains('family_tracking.edit');
    final canDelete =
        user != null && user.permissions.contains('family_tracking.delete');

    return Card(
      child: Column(children:[ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text(widget.isMe ? '${member.fullName} (أنت)' : member.fullName),
        subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text([
                member.relationship,
                if (hasLastSeen)
                  'آخر ظهور: ${_relativeTime(member.lastSeenAt!)}'
                else
                  'لا توجد بيانات موقع بعد',
                if (location?.batteryLevel != null)
                  'البطارية: ${location!.batteryLevel}%'
              ].join(' • ')),

            ]),
        trailing: _busy
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.history),
                    tooltip: 'سجل المواقع',
                    onPressed: () => context.push(
                        '/family/members/${member.id}/history',
                        extra: member.fullName),
                  ),
                  IconButton(
                    icon: Icon(Icons.sos, color: Colors.red.shade700),
                    tooltip: 'إرسال استغاثة',
                    onPressed: () => _triggerSos(context, ref),
                  ),
                  // A fourth/fifth always-visible IconButton here (on top of
                  // history/pair/SOS above) would crowd a ListTile's
                  // trailing row past what a small touch screen can host
                  // comfortably — same "avoid cramped touch targets"
                  // reasoning PR #38/#43/#44 give for their own map-editor
                  // choices. Edit/delete are lower-frequency actions than
                  // the three above, so they fold into an overflow menu
                  // instead, shown only when at least one of the two
                  // permissions is actually held.
                  if (canEdit || canDelete)
                    PopupMenuButton<String>(
                      tooltip: 'المزيد',
                      onSelected: (value) {
                        if (value == 'edit') {
                          _edit(context, ref);
                        } else if (value == 'delete') {
                          _delete(context, ref);
                        }
                      },
                      itemBuilder: (context) => [
                        if (canEdit)
                          const PopupMenuItem(
                              value: 'edit', child: Text('تعديل بيانات الفرد')),
                        if (canDelete)
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('حذف',
                                style: TextStyle(color: Colors.red.shade700)),
                          ),
                      ],
                    ),
                ],
              ),
      ),
      Padding(padding:const EdgeInsets.fromLTRB(12,0,12,8),child:Column(children:[if (canGeneratePairingCode)
                TextButton.icon(
                    onPressed: () => context.push(
                        '/family/members/${member.id}/pair',
                        extra: member.fullName),
                    icon: const Icon(Icons.qr_code_2),
                    label: Text('توليد كود ربط هاتف ${member.fullName}')),])),
      ]),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<_MemberFormResult>(
      context: context,
      builder: (context) => _MemberFormDialog(existing: member),
    );

    if (result == null || !context.mounted) return;

    setState(() => _busy = true);

    try {
      final familyId = ref.read(selectedFamilyIdProvider);

      await ref.read(familyApiProvider).updateFamilyMember(
            familyMemberId: member.id,
            fullName: result.fullName,
            gender: result.gender,
            birthDate: result.birthDate,
            relationship: result.relationship,
            phone: result.phone,
            status: result.status!,
            linkedUserId: result.linkedUserId,
            familyId: familyId,
          );
      ref.invalidate(familyMembersProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تحديث بيانات فرد العائلة')));
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر تحديث بيانات فرد العائلة: $error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف فرد العائلة'),
        content: Text(
          'سيتم حذف "${member.fullName}" نهائيًا مع كل سجل مواقعه وربط أي جهاز به، ولا يمكن التراجع عن ذلك. '
          'هل أنت متأكد؟',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    setState(() => _busy = true);

    try {
      final familyId = ref.read(selectedFamilyIdProvider);

      await ref
          .read(familyApiProvider)
          .deleteFamilyMember(familyMemberId: member.id, familyId: familyId);
      ref.invalidate(familyMembersProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تم حذف فرد العائلة')));
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر حذف فرد العائلة: $error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _triggerSos(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('نداء استغاثة (SOS)'),
        content: Text(
            'سيتم إرسال نداء استغاثة باسم "${member.fullName}" فورًا إلى العائلة. هل أنت متأكد؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('نعم، أرسل الآن'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      final familyId = ref.read(selectedFamilyIdProvider);

      await ref.read(familySosRepositoryProvider).trigger(
            familyMemberId: member.id,
            lat: position.latitude,
            lng: position.longitude,
            familyId: familyId,
          );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم إرسال نداء الاستغاثة. سيتم التواصل قريبًا.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحديد الموقع لإرسال SOS: $error')),
        );
      }
    }
  }
}

typedef _MemberFormResult = ({
  String? gender,
  String? birthDate,
  String fullName,
  String relationship,
  String? phone,
  // Only meaningful (non-null) when editing — createFamilyMember() never
  // sends a status at all, letting the row start 'pending' server-side
  // like a freshly-paired device would (see that method's own docblock).
  String? status,
  int? linkedUserId,
});

/// The create/edit form for a single tracked-person profile — a dialog
/// rather than a full route, same precedent as `_ContactFormDialog`
/// (`EmergencyContactsScreen`) and `_showCreateFamilyDialog` above for a
/// similarly small, single-object form. `ConsumerStatefulWidget` (unlike
/// those two, plain `StatefulWidget`s) because this one needs
/// `familyRelationshipsProvider` — the account roster (PR #45), a
/// genuinely different list from the tracked-people roster this dialog
/// itself edits a row of — to populate the optional "linked account"
/// dropdown (`linked_user_id`, verified directly against
/// `StoreFamilyMemberRequest`: must be an ACTIVE relationship's user in
/// this same family, or omitted/null entirely).
class _MemberFormDialog extends ConsumerStatefulWidget {
  const _MemberFormDialog({this.existing});

  final FamilyMemberModel? existing;

  @override
  ConsumerState<_MemberFormDialog> createState() => _MemberFormDialogState();
}

class _MemberFormDialogState extends ConsumerState<_MemberFormDialog> {
  late final _nameController =
      TextEditingController(text: widget.existing?.fullName ?? '');
  late final _relationshipController =
      TextEditingController(text: widget.existing?.relationship ?? '');
  late final _phoneController =
      TextEditingController(text: widget.existing?.phone ?? '');
  late String? _gender = widget.existing?.gender;
  late DateTime? _birthDate =
      DateTime.tryParse(widget.existing?.birthDate ?? '');
  late String _status = widget.existing?.status ?? 'pending';
  late int? _linkedUserId = widget.existing?.linkedUserId;
  String? _errorMessage;

  bool get _isEditing => widget.existing != null;

  static const _statusLabels = {
    'pending': 'قيد الانتظار',
    'active': 'نشط',
    'inactive': 'غير نشط'
  };

  @override
  void dispose() {
    _nameController.dispose();
    _relationshipController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    final fullName = _nameController.text.trim();
    final relationship = _relationshipController.text.trim();

    if (fullName.isEmpty || relationship.isEmpty) {
      setState(() => _errorMessage = 'الرجاء إدخال الاسم وصلة القرابة.');
      return;
    }

    final phone = _phoneController.text.trim();

    Navigator.pop(
      context,
      (
        fullName: fullName,
        gender: _gender,
        birthDate: _birthDate == null
            ? null
            : '${_birthDate!.year.toString().padLeft(4, "0")}-${_birthDate!.month.toString().padLeft(2, "0")}-${_birthDate!.day.toString().padLeft(2, "0")}',
        relationship: relationship,
        phone: phone.isEmpty ? null : phone,
        status: _isEditing ? _status : null,
        linkedUserId: _linkedUserId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final relationshipsAsync = ref.watch(familyRelationshipsProvider);

    return AlertDialog(
      title: Text(_isEditing ? 'تعديل بيانات فرد العائلة' : 'إضافة فرد عائلة'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'الاسم الكامل'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _relationshipController.text.isEmpty
                  ? null
                  : _relationshipController.text,
              decoration: const InputDecoration(labelText: 'صلة القرابة'),
              items: [
                for (final label in {
                  ...[
                    'أب',
                    'أم',
                    'ابن',
                    'بنت',
                    'جد',
                    'جدة',
                    'أخ',
                    'أخت',
                    'قريب'
                  ],
                  if (_relationshipController.text.isNotEmpty)
                    _relationshipController.text
                })
                  DropdownMenuItem(value: label, child: Text(label))
              ],
              onChanged: (value) => setState(() {
                _relationshipController.text = value ?? '';
                if (['أم', 'بنت', 'جدة', 'أخت'].contains(value)) {
                  _gender = 'female';
                } else if (['أب', 'ابن', 'جد', 'أخ'].contains(value)) {
                  _gender = 'male';
                }
              }),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration:
                  const InputDecoration(labelText: 'رقم الهاتف (اختياري)'),
            ),
            DropdownButtonFormField<String>(
                key: ValueKey(_gender),
                initialValue: _gender,
                decoration: const InputDecoration(labelText: 'الجنس'),
                items: const [
                  DropdownMenuItem<String>(
                      value: null, child: Text('غير محدد')),
                  DropdownMenuItem(value: 'male', child: Text('ذكر')),
                  DropdownMenuItem(value: 'female', child: Text('أنثى'))
                ],
                onChanged: (v) => setState(() => _gender = v)),
            Row(children: [
              Expanded(
                  child: TextButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                            context: context,
                            initialDate: _birthDate ?? DateTime.now(),
                            firstDate: DateTime(1900, 1, 2),
                            lastDate: DateTime.now());
                        if (date != null) setState(() => _birthDate = date);
                      },
                      child: Text(_birthDate == null
                          ? 'تاريخ الميلاد (للتمارين)'
                          : _birthDate!.toIso8601String().split('T').first))),
              if (_birthDate != null)
                IconButton(
                    onPressed: () => setState(() => _birthDate = null),
                    icon: const Icon(Icons.clear))
            ]),
            if (_isEditing) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'الحالة'),
                items: [
                  for (final entry in _statusLabels.entries)
                    DropdownMenuItem(
                        value: entry.key, child: Text(entry.value)),
                ],
                onChanged: (value) =>
                    setState(() => _status = value ?? _status),
              ),
            ],
            const SizedBox(height: 8),
            // Deliberately a separate concept from device pairing
            // (PR #35/#37, which links a *device* to this member): this
            // links the member's profile itself to an existing family
            // *account* that can log in — e.g. a teenager who both has
            // their own login and appears here as a tracked person.
            // Absent/loading/error states all degrade to just the "no
            // linked account" option rather than blocking the whole form.
            // `DropdownButtonFormField` asserts exactly one item matches its
            // current value — so if this member's existing `linkedUserId`
            // belongs to a relationship no longer in the (possibly still
            // loading, or since-removed) roster, a placeholder item is
            // added for it below rather than leaving the dropdown with a
            // pre-selected value that matches nothing.
            Builder(builder: (context) {
              final relationships = relationshipsAsync.valueOrNull ?? const [];
              final knownIds = relationships.map((r) => r.userId).toSet();
              final missingSelection =
                  _linkedUserId != null && !knownIds.contains(_linkedUserId);

              return DropdownButtonFormField<int?>(
                initialValue: _linkedUserId,
                decoration:
                    const InputDecoration(labelText: 'حساب مرتبط (اختياري)'),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('بلا حساب مرتبط')),
                  if (missingSelection)
                    DropdownMenuItem(
                        value: _linkedUserId,
                        child: Text('مستخدم #$_linkedUserId')),
                  for (final relationship in relationships)
                    DropdownMenuItem(
                      value: relationship.userId,
                      child: Text(
                        relationship.userName ??
                            relationship.userPhone ??
                            'مستخدم #${relationship.userId}',
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _linkedUserId = value),
              );
            }),
            if (_errorMessage case final message?) ...[
              const SizedBox(height: 4),
              Text(message, style: TextStyle(color: Colors.red.shade700)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء')),
        FilledButton(
            onPressed: _submit, child: Text(_isEditing ? 'حفظ' : 'إضافة')),
      ],
    );
  }
}

class _NoFamilyState extends ConsumerWidget {
  const _NoFamilyState({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final canCreate =
        user != null && user.permissions.contains('family_tracking.create');

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
                  const Text('لا توجد عائلة مرتبطة بحسابك بعد.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  if (canCreate)
                    FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('إنشاء عائلة'),
                      onPressed: () => _showCreateFamilyDialog(context, ref),
                    )
                  else
                    const Text(
                      'تواصل مع مدير حسابكم لإضافتك إلى عائلة موجودة.',
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateFamilyDialog(
      BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إنشاء عائلة'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'اسم العائلة'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty || !context.mounted) {
      return;
    }

    try {
      await ref.read(familyApiProvider).createFamily(name: name);
      ref.invalidate(myFamiliesProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إنشاء العائلة بنجاح')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر إنشاء العائلة: $error')));
      }
    }
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
                  Text('تعذر تحميل بيانات العائلة: $message',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(
                      onPressed: onRetry, child: const Text('إعادة المحاولة')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small, dependency-free "N minutes/hours/days ago" formatter — the app
/// has no timeago-style package (see pubspec.yaml), and this is the only
/// place that currently needs one. `isoTimestamp` is whatever the backend
/// sent for `last_seen_at` (ISO 8601, per every other timestamp field in
/// the API — see documentation/04-api-specification.md section 1).
String _relativeTime(String isoTimestamp) {
  final parsed = DateTime.tryParse(isoTimestamp);

  if (parsed == null) {
    return isoTimestamp;
  }

  final diff = DateTime.now().difference(parsed);

  if (diff.inMinutes < 1) {
    return 'الآن';
  }

  if (diff.inMinutes < 60) {
    return 'منذ ${diff.inMinutes} دقيقة';
  }

  if (diff.inHours < 24) {
    return 'منذ ${diff.inHours} ساعة';
  }

  return 'منذ ${diff.inDays} يوم';
}
