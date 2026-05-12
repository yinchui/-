import 'package:medication_reminder/features/medications/domain/medication.dart';
import 'package:medication_reminder/features/medications/domain/medication_dose.dart';
import 'package:medication_reminder/features/medications/domain/medication_log.dart';

class ScheduleService {
  List<MedicationDose> buildDosesForDate({
    required List<Medication> medications,
    required List<MedicationLog> logs,
    required DateTime date,
    required DateTime now,
  }) {
    final doses = <MedicationDose>[];

    for (final medication in medications) {
      for (final scheduleTime in medication.schedule) {
        final scheduledTime = _combine(date, scheduleTime);
        final log = _matchingLog(
          logs: logs,
          medicationId: medication.id,
          date: date,
          scheduledTime: scheduledTime,
        );

        doses.add(
          MedicationDose(
            medication: medication,
            scheduledTime: scheduledTime,
            status: _statusFor(log, now: now),
            log: log,
          ),
        );
      }
    }

    doses.sort(_compareDoses);
    return doses;
  }

  DateTime _combine(DateTime date, String scheduleTime) {
    final parts = scheduleTime.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  MedicationLog? _matchingLog({
    required List<MedicationLog> logs,
    required String medicationId,
    required DateTime date,
    required DateTime scheduledTime,
  }) {
    for (final log in logs) {
      if (log.medicationId != medicationId) {
        continue;
      }
      if (!_sameDate(log.date, date)) {
        continue;
      }
      if (log.scheduledTime.isAtSameMomentAs(scheduledTime)) {
        return log;
      }
    }

    return null;
  }

  DoseStatus _statusFor(MedicationLog? log, {required DateTime now}) {
    if (log == null) {
      return DoseStatus.pending;
    }

    return switch (log.status) {
      MedicationLogStatus.confirmed => DoseStatus.confirmed,
      MedicationLogStatus.missed => DoseStatus.missed,
    };
  }

  bool _sameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  int _compareDoses(MedicationDose a, MedicationDose b) {
    final timeComparison = a.scheduledTime.compareTo(b.scheduledTime);
    if (timeComparison != 0) {
      return timeComparison;
    }

    final idComparison = a.medication.id.compareTo(b.medication.id);
    if (idComparison != 0) {
      return idComparison;
    }

    return a.medication.name.compareTo(b.medication.name);
  }
}
