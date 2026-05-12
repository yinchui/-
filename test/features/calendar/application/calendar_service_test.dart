import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/features/calendar/application/calendar_service.dart';
import 'package:medication_reminder/features/medications/domain/medication_log.dart';

void main() {
  test('summarizes confirmed and missed logs', () {
    final logs = [
      MedicationLog(
        id: 'l1',
        medicationId: 'm1',
        scheduledTime: DateTime(2026, 5, 12, 8),
        confirmedTime: DateTime(2026, 5, 12, 8, 3),
        status: MedicationLogStatus.confirmed,
        date: DateTime(2026, 5, 12),
      ),
      MedicationLog(
        id: 'l2',
        medicationId: 'm2',
        scheduledTime: DateTime(2026, 5, 12, 20),
        confirmedTime: null,
        status: MedicationLogStatus.missed,
        date: DateTime(2026, 5, 12),
      ),
    ];

    final stats = CalendarService().summarize(logs);

    expect(stats.confirmed, 1);
    expect(stats.missed, 1);
    expect(stats.total, 2);
    expect(stats.rate, 0.5);
  });

  test('marks a day missed when any log is missed', () {
    final status = CalendarService().statusForLogs([
      MedicationLog(
        id: 'l1',
        medicationId: 'm1',
        scheduledTime: DateTime(2026, 5, 12, 8),
        confirmedTime: DateTime(2026, 5, 12, 8, 3),
        status: MedicationLogStatus.confirmed,
        date: DateTime(2026, 5, 12),
      ),
      MedicationLog(
        id: 'l2',
        medicationId: 'm2',
        scheduledTime: DateTime(2026, 5, 12, 20),
        confirmedTime: null,
        status: MedicationLogStatus.missed,
        date: DateTime(2026, 5, 12),
      ),
    ]);

    expect(status, CalendarDayStatus.missed);
  });
}
