import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../sos/presentation/sos_button.dart';
import '../../trips/application/trips_providers.dart';
import '../../trips/data/trip_models.dart';

/// Module 26 — "Driver Home / Trip Screen": the driver's assigned trips,
/// most relevant (active) one first. Tapping a trip opens
/// TripDetailScreen, which is where the actual Start Trip → Complete
/// Trip status buttons live (see that screen's docblock).
///
/// An account that is BOTH a driver and a family member (DriverUser
/// .hasFamilyAccess) still lands here first (see router.dart's
/// _landingRoute — the driver trip list is the richer, pre-existing
/// experience), with a family icon added to reach `/family`. Same
/// reasoning for `hasManagementAccess` (the fleet-admin-in-mobile
/// initiative, see `AdminHomeScreen`'s docblock) — an icon into `/admin`,
/// never a redirect away from this richer trip list. There is no shared
/// bottom-nav shell yet tying all of these together more tightly — see
/// FamilyHomeScreen's docblock for that open item.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(myTripsProvider);
    final pendingCount = ref.watch(pendingActionCountProvider).valueOrNull ?? 0;
    final user = ref.watch(authControllerProvider).user;
    final hasFamilyAccess = user?.hasFamilyAccess ?? false;
    final hasManagementAccess = user?.hasManagementAccess ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('رحلاتي'),
        actions: [
          if (hasFamilyAccess)
            IconButton(
              icon: const Icon(Icons.people_outline),
              tooltip: 'العائلة',
              onPressed: () => context.push('/family'),
            ),
          if (hasManagementAccess)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined),
              tooltip: 'الإدارة',
              onPressed: () => context.push('/admin'),
            ),
          if (pendingCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Chip(
                  avatar: const Icon(Icons.cloud_upload_outlined, size: 16),
                  label: Text('$pendingCount بانتظار المزامنة'),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      floatingActionButton: const SosButton(),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(myTripsProvider.future),
        child: tripsAsync.when(
          data: (trips) => _TripList(trips: trips),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _ErrorState(message: error.toString()),
        ),
      ),
    );
  }
}

class _TripList extends StatelessWidget {
  const _TripList({required this.trips});

  final List<Trip> trips;

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: const Center(child: Text('لا توجد رحلات معينة لك حاليًا.')),
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: trips.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final trip = trips[index];

        return Card(
          child: ListTile(
            title: Text(trip.tripNumber),
            subtitle: Text('${trip.originAddress} → ${trip.destinationAddress}'),
            trailing: _StatusBadge(status: trip.status),
            onTap: () => context.push('/trips/${trip.id}'),
          ),
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(status), visualDensity: VisualDensity.compact);
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('تعذر تحميل الرحلات: $message', textAlign: TextAlign.center),
      ),
    );
  }
}
