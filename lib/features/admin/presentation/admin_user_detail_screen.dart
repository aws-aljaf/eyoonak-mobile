import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../auth/data/session_device.dart';
import '../application/admin_users_providers.dart';
import '../data/admin_user_models.dart';

/// Full detail view for one user — reached only by tapping a row on
/// `AdminUsersScreen`, which already required `users.view` to load at all,
/// so (same "the request is the gate" convention as every other screen in
/// this app) this screen has no permission gate of its own either for
/// *viewing*; `UserController::show()`/`UserPolicy::view()` are what
/// actually enforce it server-side.
///
/// The edit/roles/suspend/reactivate/reset-password/force-logout/delete
/// actions below are the exception — each is gated on its own permission
/// (`users.edit`/`manage_status`/`force_logout`/`delete`, verified
/// one-by-one against `UserPolicy` before building this — see
/// `AdminUsersApi`'s own docblock for the full picture). Three of them
/// (suspend/reactivate, force-logout, delete) are ALSO hidden here whenever
/// `userId` is the caller's own account, mirroring a real server-side block
/// (`UserPolicy`: `id !== target.id`) — this app-side hiding is just a
/// cleaner UX (no confusing 403), not the actual gate. `resetPassword` has
/// no such server-side self-block, but is hidden for self anyway (see
/// `_confirmResetPassword` below for why), and `assignRoles` has no
/// self-block at all either server- or client-side — `AdminUserAssignRolesScreen`
/// itself shows a standing warning banner instead when editing your own
/// roles.
class AdminUserDetailScreen extends ConsumerWidget {
  const AdminUserDetailScreen({super.key, required this.userId});

  final int userId;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, AdminUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف المستخدم'),
        content: Text('هل أنت متأكد من حذف حساب "${user.name}"؟ لن يتمكن هذا الحساب من تسجيل الدخول بعد ذلك.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      await ref.read(adminUsersApiProvider).delete(userId);
      ref.invalidate(adminUsersProvider);

      if (context.mounted) {
        context.pop();
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حذف المستخدم: $error')));
      }
    }
  }

  Future<void> _confirmForceLogout(BuildContext context, WidgetRef ref, AdminUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسجيل الخروج من كل الأجهزة'),
        content: Text('سيتم إبطال كل جلسات وأجهزة "${user.name}" فورًا. متابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('تسجيل الخروج')),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      await ref.read(adminUsersApiProvider).forceLogout(userId);
      ref.invalidate(adminUserDevicesProvider(userId));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل خروج المستخدم من كل الأجهزة')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تسجيل الخروج: $error')));
      }
    }
  }

  Future<void> _toggleSuspend(BuildContext context, WidgetRef ref, AdminUser user) async {
    final suspending = user.status != 'suspended';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(suspending ? 'تعليق المستخدم' : 'إعادة تفعيل المستخدم'),
        content: Text(
          suspending
              ? 'سيُمنع "${user.name}" من استخدام حسابه، لكن أي جلسة/جهاز مسجَّل حاليًا يبقى موصولاً حتى تسجّل خروجه من كل الأجهزة بشكل منفصل. متابعة؟'
              : 'سيُسمح لـ"${user.name}" باستخدام حسابه مجددًا. متابعة؟',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('إلغاء')),
          FilledButton(
            style: suspending ? FilledButton.styleFrom(backgroundColor: Colors.red.shade700) : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(suspending ? 'تعليق' : 'تفعيل'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      final api = ref.read(adminUsersApiProvider);
      if (suspending) {
        await api.suspend(userId);
      } else {
        await api.reactivate(userId);
      }
      ref.invalidate(adminUserDetailProvider(userId));
      ref.invalidate(adminUsersProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحديث حالة المستخدم: $error')));
      }
    }
  }

  /// Hidden for self (see this class's docblock) even though the backend
  /// itself allows it (`resetPassword`'s policy check is the plain `update`
  /// ability, which permits self) — revoking every token for your OWN
  /// account mid-session, from inside the admin panel you're currently
  /// using, would just log the caller straight out with no way back in
  /// through this same flow to retrieve the new password.
  Future<void> _confirmResetPassword(BuildContext context, WidgetRef ref, AdminUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إعادة تعيين كلمة المرور'),
        content: Text(
          'سيتم توليد كلمة مرور مؤقتة جديدة لـ"${user.name}" وإبطال كل جلساته الحالية. متابعة؟',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('إعادة التعيين')),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      final temporaryPassword = await ref.read(adminUsersApiProvider).resetPassword(userId);
      ref.invalidate(adminUserDevicesProvider(userId));

      if (context.mounted) {
        await _showTemporaryPassword(context, temporaryPassword);
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إعادة تعيين كلمة المرور: $error')));
      }
    }
  }

  /// Shown exactly once — the API never returns this value again after this
  /// response (see `AdminUsersApi.resetPassword()`'s own docblock) — so this
  /// dialog cannot be dismissed by tapping outside it, only via its own
  /// explicit "تم النسخ، إغلاق" button, and offers a one-tap clipboard copy.
  Future<void> _showTemporaryPassword(BuildContext context, String temporaryPassword) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('كلمة المرور المؤقتة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('احفظ هذه الكلمة الآن — لن تظهر مرة أخرى بعد إغلاق هذه النافذة:'),
            const SizedBox(height: 12),
            SelectableText(
              temporaryPassword,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'monospace'),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Clipboard.setData(ClipboardData(text: temporaryPassword)),
            icon: const Icon(Icons.copy_outlined),
            label: const Text('نسخ'),
          ),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('تم النسخ، إغلاق')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(adminUserDetailProvider(userId));
    final permissions = ref.watch(authControllerProvider).user?.permissions ?? const [];
    final currentUserId = ref.watch(authControllerProvider).user?.id;
    final isSelf = currentUserId != null && currentUserId == userId;
    final canEdit = permissions.contains('users.edit');
    final canDelete = permissions.contains('users.delete') && !isSelf;
    final canManageStatus = permissions.contains('users.manage_status') && !isSelf;
    final canForceLogout = permissions.contains('users.force_logout') && !isSelf;
    final canResetPassword = canEdit && !isSelf;
    final user = userAsync.valueOrNull;

    final menuItems = <PopupMenuEntry<String>>[
      if (canManageStatus)
        PopupMenuItem(value: 'toggle_status', child: Text(user?.status == 'suspended' ? 'إعادة تفعيل' : 'تعليق')),
      if (canResetPassword) const PopupMenuItem(value: 'reset_password', child: Text('إعادة تعيين كلمة المرور')),
      if (canForceLogout) const PopupMenuItem(value: 'force_logout', child: Text('تسجيل الخروج من كل الأجهزة')),
      if (canDelete)
        PopupMenuItem(value: 'delete', child: Text('حذف المستخدم', style: TextStyle(color: Colors.red.shade700))),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(user?.name ?? 'تفاصيل المستخدم'),
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.badge_outlined),
              tooltip: 'الأدوار',
              onPressed: user == null
                  ? null
                  : () async {
                      final updated = await context.push<bool>('/admin/users/$userId/roles', extra: user);
                      if (updated == true) {
                        ref.invalidate(adminUserDetailProvider(userId));
                      }
                    },
            ),
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'تعديل',
              onPressed: user == null
                  ? null
                  : () async {
                      final updated = await context.push<bool>('/admin/users/$userId/edit', extra: user);
                      if (updated == true) {
                        ref.invalidate(adminUserDetailProvider(userId));
                      }
                    },
            ),
          if (menuItems.isNotEmpty && user != null)
            PopupMenuButton<String>(
              tooltip: 'المزيد',
              itemBuilder: (context) => menuItems,
              onSelected: (value) {
                switch (value) {
                  case 'toggle_status':
                    _toggleSuspend(context, ref, user);
                    break;
                  case 'reset_password':
                    _confirmResetPassword(context, ref, user);
                    break;
                  case 'force_logout':
                    _confirmForceLogout(context, ref, user);
                    break;
                  case 'delete':
                    _confirmDelete(context, ref, user);
                    break;
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: () {
              ref.invalidate(adminUserDetailProvider(userId));
              ref.invalidate(adminUserDevicesProvider(userId));
            },
          ),
        ],
      ),
      body: userAsync.when(
        data: (user) => _DetailBody(user: user),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(adminUserDetailProvider(userId)),
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusLabel = user.status != null ? userStatusLabels[user.status] ?? user.status! : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: Text(user.name, style: Theme.of(context).textTheme.headlineSmall)),
            if (statusLabel != null) Chip(label: Text(statusLabel)),
          ],
        ),
        const SizedBox(height: 4),
        Text(user.email, style: Theme.of(context).textTheme.titleMedium),
        if (user.roles.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: user.roles.map((role) => Chip(label: Text(role), visualDensity: VisualDensity.compact)).toList(),
          ),
        ],
        const SizedBox(height: 16),
        _Section(
          title: 'بيانات الحساب',
          rows: [
            if (user.phone != null) _row('الهاتف', user.phone!),
            if (user.branchName != null) _row('الفرع', user.branchName!),
            _row('اللغة', _localeLabel(user.locale)),
            _row('حساب مسؤول عام', user.isSuperAdmin ? 'نعم' : 'لا'),
            _row('التحقق بخطوتين', user.twoFactorEnabled ? 'مفعَّل' : 'غير مفعَّل'),
            if (user.lastLoginAt != null) _row('آخر تسجيل دخول', _formatTimestamp(user.lastLoginAt!)),
            if (user.createdAt != null) _row('تاريخ الإنشاء', _formatTimestamp(user.createdAt!)),
          ],
        ),
        const SizedBox(height: 8),
        Text('الأجهزة المسجَّلة', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        _DevicesSection(userId: user.id),
      ],
    );
  }

  _DetailRow _row(String label, String value) => _DetailRow(label: label, value: value);

  String _localeLabel(String? locale) {
    switch (locale) {
      case 'ar':
        return 'العربية';
      case 'en':
        return 'الإنجليزية';
      case 'ku':
        return 'الكردية';
      default:
        return locale ?? '—';
    }
  }
}

/// Read-only counterpart of `DevicesScreen` (which only ever shows the
/// caller's own devices) — no revoke/logout-everywhere actions here, same
/// "view-only for this slice" scope as the rest of this screen.
class _DevicesSection extends ConsumerWidget {
  const _DevicesSection({required this.userId});

  final int userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(adminUserDevicesProvider(userId));

    return devicesAsync.when(
      data: (devices) {
        if (devices.isEmpty) {
          return const Text('لا توجد أجهزة نشطة مسجَّلة لهذا الحساب.', style: TextStyle(color: Colors.grey));
        }

        return Column(children: devices.map((d) => _DeviceTile(device: d)).toList());
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (error, stack) => Text('تعذر تحميل الأجهزة: $error', style: const TextStyle(color: Colors.red)),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device});

  final SessionDevice device;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: Icon(_platformIcon(device.platform)),
        title: Text(device.deviceName ?? device.platform ?? 'جهاز غير معروف'),
        subtitle: Text([
          if (device.familyMemberName != null) 'مُقترن بـ"${device.familyMemberName}"',
          if (device.lastActiveAt != null) 'آخر نشاط: ${_relativeTime(device.lastActiveAt!)}',
          if (device.appVersion != null) 'الإصدار ${device.appVersion}',
        ].join(' • ')),
      ),
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});

  final String title;
  final List<_DetailRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 140, child: Text(row.label, style: const TextStyle(color: Colors.grey))),
                    Expanded(child: Text(row.value)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;
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
                  Text('تعذر تحميل بيانات المستخدم: $message', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatTimestamp(DateTime dt) {
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');

  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
}

/// Same small, dependency-free relative-time formatter as
/// `devices_screen.dart`'s own `_relativeTime` — kept as a per-file private
/// copy rather than shared, matching this app's established
/// "underscore-prefixed top-level helpers are file-private in Dart" lesson
/// (PR #48's project-doc note).
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
