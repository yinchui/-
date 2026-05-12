import 'package:medication_reminder/core/notifications/alarm_rescheduler.dart';
import 'package:medication_reminder/core/notifications/notification_scheduler.dart';
import 'package:medication_reminder/features/medications/domain/medication_dose.dart';

class ReminderRetryService {
  ReminderRetryService(this._scheduler);

  final NotificationScheduler _scheduler;

  Future<void> scheduleRetryIfNeeded({
    required MedicationDose dose,
    required DateTime now,
  }) async {
    if (dose.status == DoseStatus.confirmed) {
      return;
    }

    await _scheduler.schedule(
      ScheduledNotificationRequest(
        id: stableNotificationId('retry-${dose.id}'),
        title: '还没确认服药',
        body: '${dose.medication.name} · ${dose.medication.dosage}',
        scheduledAt: now.add(const Duration(minutes: 5)),
        payload: 'retry:${dose.id}',
      ),
    );
  }
}
