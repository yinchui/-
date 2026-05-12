import 'package:medication_reminder/features/medications/domain/medication_log.dart';

enum CalendarDayStatus { none, confirmed, missed }

class CalendarStats {
  const CalendarStats({required this.confirmed, required this.missed});

  final int confirmed;
  final int missed;

  int get total => confirmed + missed;
  double get rate => total == 0 ? 0 : confirmed / total;
}

class CalendarService {
  CalendarStats summarize(Iterable<MedicationLog> logs) {
    var confirmed = 0;
    var missed = 0;

    for (final log in logs) {
      switch (log.status) {
        case MedicationLogStatus.confirmed:
          confirmed += 1;
        case MedicationLogStatus.missed:
          missed += 1;
      }
    }

    return CalendarStats(confirmed: confirmed, missed: missed);
  }

  CalendarDayStatus statusForLogs(Iterable<MedicationLog> logs) {
    final stats = summarize(logs);
    if (stats.missed > 0) {
      return CalendarDayStatus.missed;
    }
    if (stats.confirmed > 0) {
      return CalendarDayStatus.confirmed;
    }
    return CalendarDayStatus.none;
  }
}
