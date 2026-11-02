import '../../../core/network/api_client.dart';
import 'notification_models.dart';

class NotificationsApi {
  NotificationsApi(this._client);

  final ApiClient _client;

  Future<List<DriverNotification>> list({bool? isRead}) async {
    final envelope = await _client.getPaginated('/notifications', query: {
      if (isRead != null) 'is_read': isRead,
      'per_page': 50,
    });

    return envelope.data
        .map((e) => DriverNotification.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> markRead(int id) => _client.post('/notifications/$id/read');

  Future<void> markAllRead() => _client.post('/notifications/read-all');
}
