import 'package:medication_reminder/core/notifications/notification_scheduler.dart';
import 'package:medication_reminder/features/medications/domain/medication.dart';

class AlarmRescheduler {
  AlarmRescheduler(this._scheduler);

  final NotificationScheduler _scheduler;

  Future<void> rescheduleAll({
    required List<Medication> medications,
    required DateTime from,
  }) async {
    await _scheduler.cancelAll();

    for (final medication in medications) {
      for (final time in medication.schedule) {
        final scheduledAt = _nextOccurrence(from, time);
        await _scheduler.schedule(
          ScheduledNotificationRequest(
            id: stableNotificationId('${medication.id}-$time'),
            title: '该吃药了',
            body: '${medication.name} · ${medication.dosage}',
            scheduledAt: scheduledAt,
            payload: 'medication:${medication.id}:$time',
          ),
        );
      }
    }
  }

  DateTime _nextOccurrence(DateTime from, String hhmm) {
    final parts = hhmm.split(':').map(int.parse).toList();
    var candidate = DateTime(
      from.year,
      from.month,
      from.day,
      parts[0],
      parts[1],
    );

    if (!candidate.isAfter(from)) {
      candidate = candidate.add(const Duration(days: 1));
    }

    return candidate;
  }
}

int stableNotificationId(String value) {
  var hash = 0;
  for (final code in value.codeUnits) {
    hash = (hash * 31 + code) & 0x7fffffff;
  }
  return hash;
}
