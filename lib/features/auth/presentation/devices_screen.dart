import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_exception.dart';
import '../application/session_devices_provider.dart';
import '../data/session_device.dart';

/// "الأجهزة النشطة" — a first frontend for `AuthController::devices()` /
/// `revokeDevice()` / `logoutAll()` (backend/app/Http/Controllers/Api/V1/
/// Auth/AuthController.php), verified directly against that controller and
/// `DeviceResource` before building this. All three have been fully built
/// and authorized since the auth module's own foundation — this is not new
/// backend work, only a new frontend for it, matching the exact pattern
/// PR #49 (family rename) established: a fresh backend-vs-mobile scan can
/// surface a ready endpoint neither this app nor the web reference has
/// ever called (grepped `resources/js` for `auth/devices`/`logout-all`
/// before building this — no hits there either).
///
/// Reachable from `ProfileScreen` regardless of account type (driver or
/// family) — session/device management is an account-level concern, not a
/// driver- or family-specific one, unlike everything else `ProfileScreen`
/// shows today.
class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  /// Per-row busy state (keyed by device id) plus a separate flag for the
  /// "logout everywhere" action — mirrors `_MemberCardState._busy` from
  /// `family_home_screen.dart`, just tracking more than one row at once
  /// since every device on this screen can be revoked independently.
  final Set<int> _revokingIds = {};
  bool _loggingOutEverywhere = false;

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(sessionDevicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الأجهزة النشطة'),
        actions: [
          IconButton(
            icon: _loggingOutEverywhere
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.phonelink_erase_outlined),
            tooltip: 'تسجيل الخروج من كل الأجهزة',
            onPressed: _loggingOutEverywhere ? null : () => _logoutEverywhere(context),
          ),
        ],
      ),
      body: devicesAsync.when(
        data: (devices) => _DeviceList(
          devices: devices,
          revokingIds: _revokingIds,
          onRevoke: (device) => _revoke(context, device),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(sessionDevicesProvider),
        ),
      ),
    );
  }

  Future<void> _revoke(BuildContext context, SessionDevice device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء الجلسة'),
        content: Text(
          device.isCurrent
              ? 'هذا هو الجهاز الحالي — سيتم تسجيل خروجك من هذا التطبيق أيضًا فورًا. هل أنت متأكد؟'
              : 'سيتم تسجيل الخروج فورًا من "${device.deviceName ?? 'هذا الجهاز'}". هل أنت متأكد؟',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إلغاء الجلسة'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    setState(() => _revokingIds.add(device.id));

    try {
      await ref.read(authApiProvider).revokeDevice(device.id);

      // Revoking the device THIS app is running on invalidates the very
      // token this request just used to succeed — there is no longer a
      // session left to show a device list for, so end it locally exactly
      // like tapping "logout" on the profile screen would. AuthController
      // handles this router-side (the auth-gate redirects to /login once
      // its state flips), so no explicit navigation is needed here.
      if (device.isCurrent) {
        await ref.read(authControllerProvider.notifier).logout();
        return;
      }

      ref.invalidate(sessionDevicesProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إلغاء الجلسة')));
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إلغاء الجلسة: $error')));
      }
    } finally {
      if (mounted) setState(() => _revokingIds.remove(device.id));
    }
  }

  Future<void> _logoutEverywhere(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج من كل الأجهزة'),
        content: const Text(
          'سيتم تسجيل الخروج فورًا من كل جهاز مسجّل دخوله بهذا الحساب، بما في ذلك هذا الجهاز. هل أنت متأكد؟',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تسجيل الخروج من الكل'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    setState(() => _loggingOutEverywhere = true);

    // No try/catch needed here — logoutEverywhere() itself already
    // swallows the network call's own failure and always clears the local
    // session (see its docblock), so this screen has nothing left to
    // report either way; the router's auth-gate takes it from here.
    await ref.read(authControllerProvider.notifier).logoutEverywhere();
  }
}

class _DeviceList extends StatelessWidget {
  const _DeviceList({required this.devices, required this.revokingIds, required this.onRevoke});

  final List<SessionDevice> devices;
  final Set<int> revokingIds;
  final void Function(SessionDevice device) onRevoke;

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) {
      return const Center(child: Text('لا توجد جلسات نشطة.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: devices.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final device = devices[index];
        final busy = revokingIds.contains(device.id);

        return Card(
          child: ListTile(
            leading: Icon(_platformIcon(device.platform)),
            title: Text(device.deviceName ?? device.platform ?? 'جهاز غير معروف'),
            subtitle: Text([
              if (device.isCurrent) 'الجهاز الحالي',
              if (device.familyMemberName != null) 'مُقترن بـ"${device.familyMemberName}"',
              if (device.lastActiveAt != null) 'آخر نشاط: ${_relativeTime(device.lastActiveAt!)}',
              if (device.appVersion != null) 'الإصدار ${device.appVersion}',
            ].join(' • ')),
            trailing: busy
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : IconButton(
                    icon: Icon(Icons.logout, color: Colors.red.shade700),
                    tooltip: 'إلغاء الجلسة',
                    onPressed: () => onRevoke(device),
                  ),
          ),
        );
      },
    );
  }

  IconData _platformIcon(String? platform) {
    switch (platform) {
      case 'android':
        return Icons.phone_android;
      case 'ios':
        return Icons.phone_iphone;
      default:
        return Icons.devices_other;
    }
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('تعذر تحميل الأجهزة: $message', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
          ],
        ),
      ),
    );
  }
}

/// Same small, dependency-free relative-time formatter as
/// `family_home_screen.dart`'s own `_relativeTime` — kept as a private
/// per-file copy rather than shared, matching this app's established
/// "underscore-prefixed top-level helpers are file-private in Dart, so
/// don't assume one can be imported across features" lesson (PR #48's
/// project-doc note) — duplicating four lines is simpler than promoting it
/// to a shared util for exactly two call sites.
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
