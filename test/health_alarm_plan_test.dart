import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_saas_driver/features/health/application/health_reminders.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('stale previous-account response cannot mutate local alarms', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final service = HealthReminders.instance;
    service.activeUserId = 2;
    await service.schedule({'user_id': 1, 'upcoming': []}, null);
    expect(service.activeUserId, 2);
    await service.endSession();
    expect(service.activeUserId, isNull);
  });

  test('sorts, ignores past times, coalesces equal private reminders and caps capacity', () {
    final now = DateTime.utc(2026, 10, 19, 6);
    final plan = healthAlarmPlan({
      'upcoming': [
        {'scheduled_at': '2026-10-19T05:00:00Z'},
        {'scheduled_at': '2026-10-20T09:00:00Z'},
        {'scheduled_at': '2026-10-19T08:00:00Z'},
        {'scheduled_at': '2026-10-19T08:00:00Z'},
      ]
    }, null, now, 1);
    expect(plan, [DateTime.utc(2026, 10, 19, 8)]);
  });
  test('mother cycle reminder uses configured timezone and day offset', () {
    final plan = healthAlarmPlan({
      'upcoming': []
    }, {
      'configured': true,
      'reminders': true,
      'next_start': '2026-10-29',
      'timezone': 'Asia/Baghdad',
      'reminder_time': '09:00',
      'remind_days_before': 1
    }, DateTime.utc(2026, 10, 19), 24);
    expect(plan, [DateTime.utc(2026, 10, 28, 6)]);
  });
  test('disabled or past cycle creates no reminder and never rolls a guessed cycle forward', () {
    final cycle = {
      'configured': true,
      'reminders': false,
      'next_start': '2026-10-10',
      'timezone': 'Asia/Baghdad',
      'reminder_time': '09:00',
      'remind_days_before': 1
    };
    expect(healthAlarmPlan({'upcoming': []}, cycle, DateTime.utc(2026, 10, 19), 24), isEmpty);
    cycle['reminders'] = true;
    expect(healthAlarmPlan({'upcoming': []}, cycle, DateTime.utc(2026, 10, 19), 24), isEmpty);
  });
}
