import 'package:go_router/go_router.dart';
import '../../family/application/family_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../application/notifications_provider.dart';
import '../data/notification_models.dart';

/// Module 30 — "Driver Notifications". Every action here is
/// ownership-only server-side (see backend NotificationPolicy) — no RBAC
/// permission is involved.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(notificationsApiProvider).markAllRead();
              ref.invalidate(notificationsProvider);
            },
            child: const Text('تحديد الكل كمقروء', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) => _NotificationsList(notifications: notifications),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('تعذر تحميل الإشعارات: $error')),
      ),
    );
  }
}

class _NotificationsList extends ConsumerWidget {
  const _NotificationsList({required this.notifications});

  final List<DriverNotification> notifications;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (notifications.isEmpty) {
      return const Center(child: Text('لا توجد إشعارات.'));
    }

    return ListView.separated(
      itemCount: notifications.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final notification = notifications[index];

        return ListTile(
          leading: Icon(
            notification.type == 'sos' ? Icons.sos : Icons.notifications,
            color: notification.isRead ? Colors.grey : Theme.of(context).colorScheme.primary,
          ),
          title: Text(
            notification.title,
            style: TextStyle(fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold),
          ),
          subtitle: Text(notification.body),
          onTap: () async {
            try {
            if (!notification.isRead) {
              await ref.read(notificationsApiProvider).markRead(notification.id);
              ref.invalidate(notificationsProvider);
            }
            if(notification.destination != null && (notification.destination!.startsWith('/our-home') || const ['/family/alerts','/family/rewards','/family/rewards/mine'].contains(notification.destination)) && context.mounted) {
              if(notification.familyId != null) ref.read(selectedFamilyIdProvider.notifier).state = notification.familyId;
              context.push(notification.destination!);
            }
            } catch(error) { if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر فتح الإشعار: $error'))); }
          },
        );
      },
    );
  }
}
