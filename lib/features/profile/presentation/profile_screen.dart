import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../drivers/data/driver_profile.dart';

final _driverProfileProvider = FutureProvider.autoDispose<DriverProfile?>((ref) async {
  final driverId = ref.watch(authControllerProvider).user?.driverId;

  if (driverId == null) {
    return null;
  }

  return ref.watch(driversApiProvider).show(driverId);
});

/// Module 31 — "Driver Profile & Documents" (read-only fields; the
/// documents list itself is `DriverDocumentsScreen`, PR #51, reached via
/// `_ProfileDetails`'s own button below now that it's built — an earlier
/// version of this docblock called it "deferred", citing a
/// mobile/README.md scope note that on closer reading never actually
/// existed). "حوادثي" (`AccidentsListScreen`, PR #53) is the other
/// driver-only entry point added here, same reasoning.
///
/// Reached from BOTH account types this app serves — `HomeShell` (driver)
/// and `FamilyHomeScreen`'s own `person_outline` icon (family-only
/// accounts) — even though `_ProfileDetails` below only ever renders for a
/// driver. That's why "الأجهزة النشطة" (`DevicesScreen`, wiring up
/// `AuthController::devices()`/`revokeDevice()`/`logoutAll()`) is placed
/// here rather than folded into `FamilyHomeScreen`'s own app bar: unlike
/// every icon there, session/device management is an account-level
/// concern that applies identically to a driver and a family account, and
/// this is the one screen both kinds of account already reach.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(_driverProfileProvider);
    final authUser = ref.watch(authControllerProvider).user;

    return Scaffold(
      appBar: AppBar(title: const Text('الملف الشخصي')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(authUser?.name ?? '', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          profileAsync.when(
            data: (profile) => profile == null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('بيانات الحساب'),
                      if (authUser?.phone?.isNotEmpty == true)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.phone_outlined),
                          title: Text(authUser!.phone!),
                        ),
                      if (authUser?.email?.isNotEmpty == true)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.email_outlined),
                          title: Text(authUser!.email!),
                        ),
                    ],
                  )
                : _ProfileDetails(profile: profile),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Text('تعذر تحميل الملف: $error'),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(Icons.devices_outlined),
            label: const Text('الأجهزة النشطة'),
            onPressed: () => context.push('/profile/devices'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.person_remove_outlined),
            label: const Text('حذف الحساب وبياناتي'),
            onPressed: () => context.push('/profile/account-deletion'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('تسجيل الخروج'),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}

class _ProfileDetails extends StatelessWidget {
  const _ProfileDetails({required this.profile});

  final DriverProfile profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row('رقم الهاتف', profile.phone),
        _row('رقم الإجازة', profile.licenseNumber),
        _row(
          'انتهاء الإجازة',
          profile.licenseExpiryDate?.toIso8601String().split('T').first,
        ),
        _row('تقييم الأداء', profile.performanceScore?.toString()),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.folder_outlined),
          label: const Text('مستنداتي'),
          onPressed: () => context.push('/profile/documents/${profile.id}'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.car_crash_outlined),
          label: const Text('حوادثي'),
          onPressed: () => context.push('/profile/accidents'),
        ),
      ],
    );
  }

  Widget _row(String label, String? value) {
    if (value == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
