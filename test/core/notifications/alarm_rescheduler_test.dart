import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/core/notifications/alarm_rescheduler.dart';
import 'package:medication_reminder/core/notifications/notification_scheduler.dart';
import 'package:medication_reminder/core/notifications/reminder_retry_service.dart';
import 'package:medication_reminder/features/medications/domain/medication.dart';
import 'package:medication_reminder/features/medications/domain/medication_dose.dart';

class FakeNotificationScheduler implements NotificationScheduler {
  final scheduled = <ScheduledNotificationRequest>[];
  var cancelAllCount = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> schedule(ScheduledNotificationRequest request) async {
    scheduled.add(request);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCount += 1;
  }
}

void main() {
  test('rescheduler schedules one reminder per medication time', () async {
    final scheduler = FakeNotificationScheduler();

    await AlarmRescheduler(scheduler).rescheduleAll(
      medications: [
        Medication(
          id: 'm1',
          userId: 'user-1',
          name: '阿莫西林',
          dosage: '2粒',
          schedule: const ['08:00', '20:00'],
          createdAt: DateTime(2026, 5, 12),
          updatedAt: DateTime(2026, 5, 12),
        ),
      ],
      from: DateTime(2026, 5, 12, 7),
    );

    expect(scheduler.cancelAllCount, 1);
    expect(scheduler.scheduled.length, 2);
    expect(scheduler.scheduled.first.title, '该吃药了');
    expect(scheduler.scheduled.first.body, '阿莫西林 · 2粒');
    expect(scheduler.scheduled.first.scheduledAt, DateTime(2026, 5, 12, 8));
    expect(scheduler.scheduled.last.scheduledAt, DateTime(2026, 5, 12, 20));
  });

  test('rescheduler moves elapsed reminders to the next day', () async {
    final scheduler = FakeNotificationScheduler();

    await AlarmRescheduler(scheduler).rescheduleAll(
      medications: [
        Medication(
          id: 'm1',
          userId: 'user-1',
          name: '阿莫西林',
          dosage: '2粒',
          schedule: const ['08:00'],
          createdAt: DateTime(2026, 5, 12),
          updatedAt: DateTime(2026, 5, 12),
        ),
      ],
      from: DateTime(2026, 5, 12, 8),
    );

    expect(scheduler.scheduled.single.scheduledAt, DateTime(2026, 5, 13, 8));
  });

  test(
    'retry service schedules another reminder five minutes later while unconfirmed',
    () async {
      final scheduler = FakeNotificationScheduler();
      final dose = MedicationDose(
        medication: Medication(
          id: 'm1',
          userId: 'user-1',
          name: '阿莫西林',
          dosage: '2粒',
          schedule: const ['08:00'],
          createdAt: DateTime(2026, 5, 12),
          updatedAt: DateTime(2026, 5, 12),
        ),
        scheduledTime: DateTime(2026, 5, 12, 8),
        status: DoseStatus.pending,
        log: null,
      );

      await ReminderRetryService(
        scheduler,
      ).scheduleRetryIfNeeded(dose: dose, now: DateTime(2026, 5, 12, 8, 1));

      expect(scheduler.scheduled.single.title, '还没确认服药');
      expect(
        scheduler.scheduled.single.scheduledAt,
        DateTime(2026, 5, 12, 8, 6),
      );
    },
  );
}
