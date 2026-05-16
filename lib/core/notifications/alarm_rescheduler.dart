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
      if (medication.dailyPlans.isNotEmpty) {
        await _scheduleCourseMedication(medication, from);
        continue;
      }

      for (final time in medication.schedule) {
        final scheduledAt = _nextOccurrence(from, time);
        await _scheduler.schedule(
          ScheduledNotificationRequest(
            id: stableNotificationId('${medication.id}-$time'),
            title: '该吃药了',
            body: '${medication.name} · ${medication.dosage}',
            scheduledAt: scheduledAt,
            payload: 'medication:${medication.id}:$time',
            repeat: NotificationRepeat.daily,
          ),
        );
      }
    }
  }

  Future<void> _scheduleCourseMedication(
    Medication medication,
    DateTime from,
  ) async {
    final dailyPlans = medication.dailyPlans.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    for (final dailyPlan in dailyPlans) {
      final schedule = dailyPlan.schedule.toList()..sort();
      for (final time in schedule) {
        final scheduledAt = _combine(dailyPlan.date, time);
        if (!scheduledAt.isAfter(from)) {
          continue;
        }

        await _scheduler.schedule(
          ScheduledNotificationRequest(
            id: stableNotificationId(
              '${medication.id}-${_formatDate(dailyPlan.date)}-$time',
            ),
            title: '该吃药了',
            body: '${medication.name} · ${dailyPlan.dosage}',
            scheduledAt: scheduledAt,
            payload:
                'medication:${medication.id}:'
                '${_formatDate(dailyPlan.date)}:$time',
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

  DateTime _combine(DateTime date, String hhmm) {
    final parts = hhmm.split(':').map(int.parse).toList();
    return DateTime(date.year, date.month, date.day, parts[0], parts[1]);
  }
}

int stableNotificationId(String value) {
  var hash = 0;
  for (final code in value.codeUnits) {
    hash = (hash * 31 + code) & 0x7fffffff;
  }
  return hash;
}

String _formatDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
