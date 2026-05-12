import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/features/medications/application/schedule_service.dart';
import 'package:medication_reminder/features/medications/domain/medication.dart';
import 'package:medication_reminder/features/medications/domain/medication_dose.dart';
import 'package:medication_reminder/features/medications/domain/medication_log.dart';

void main() {
  group('ScheduleService', () {
    test(
      'buildDosesForDate returns confirmed and pending doses sorted by time',
      () {
        final service = ScheduleService();
        final medication = _medication(schedule: const ['08:00', '20:00']);
        final confirmedLog = _log(
          scheduledTime: _localDateTime(2026, 5, 13, 8),
          confirmedTime: _localDateTime(2026, 5, 13, 8, 5),
          status: MedicationLogStatus.confirmed,
        );

        final doses = service.buildDosesForDate(
          medications: [medication],
          logs: [confirmedLog],
          date: DateTime(2026, 5, 13),
          now: _localDateTime(2026, 5, 13, 12),
        );

        expect(doses, hasLength(2));
        expect(doses.map((dose) => dose.scheduledTime), [
          _localDateTime(2026, 5, 13, 8),
          _localDateTime(2026, 5, 13, 20),
        ]);
        expect(doses[0].medication, medication);
        expect(doses[0].status, DoseStatus.confirmed);
        expect(doses[0].log, confirmedLog);
        expect(doses[1].medication, medication);
        expect(doses[1].status, DoseStatus.pending);
        expect(doses[1].log, isNull);
      },
    );

    test('buildDosesForDate maps missed logs to missed doses', () {
      final service = ScheduleService();
      final medication = _medication(schedule: const ['20:00']);
      final missedLog = _log(
        scheduledTime: _localDateTime(2026, 5, 13, 20),
        status: MedicationLogStatus.missed,
      );

      final doses = service.buildDosesForDate(
        medications: [medication],
        logs: [missedLog],
        date: DateTime(2026, 5, 13),
        now: _localDateTime(2026, 5, 13, 21),
      );

      expect(doses, hasLength(1));
      expect(doses.single.status, DoseStatus.missed);
      expect(doses.single.log, missedLog);
    });

    test(
      'buildDosesForDate returns all medications at the same time with stable sorting',
      () {
        final service = ScheduleService();
        final beta = _medication(
          id: 'medication-b',
          name: 'Beta',
          schedule: const ['08:00'],
        );
        final alpha = _medication(
          id: 'medication-a',
          name: 'Alpha',
          schedule: const ['08:00'],
        );
        final omega = _medication(
          id: 'medication-c',
          name: 'Omega',
          schedule: const ['07:30'],
        );

        final doses = service.buildDosesForDate(
          medications: [beta, alpha, omega],
          logs: const [],
          date: DateTime(2026, 5, 13),
          now: _localDateTime(2026, 5, 13, 8),
        );

        expect(doses.map((dose) => dose.medication.id), [
          'medication-c',
          'medication-a',
          'medication-b',
        ]);
        expect(doses.map((dose) => dose.scheduledTime), [
          _localDateTime(2026, 5, 13, 7, 30),
          _localDateTime(2026, 5, 13, 8),
          _localDateTime(2026, 5, 13, 8),
        ]);
      },
    );

    test(
      'buildDosesForDate matches UTC-normalized log scheduledTime by instant',
      () {
        final service = ScheduleService();
        final medication = _medication(schedule: const ['08:00']);
        final scheduledTime = _localDateTime(2026, 5, 13, 8);
        final confirmedLog = _log(
          scheduledTime: scheduledTime.toUtc(),
          confirmedTime: scheduledTime.add(const Duration(minutes: 2)),
          status: MedicationLogStatus.confirmed,
        );

        final doses = service.buildDosesForDate(
          medications: [medication],
          logs: [confirmedLog],
          date: DateTime(2026, 5, 13),
          now: _localDateTime(2026, 5, 13, 9),
        );

        expect(
          doses.single.scheduledTime.isAtSameMomentAs(scheduledTime),
          true,
        );
        expect(
          doses.single.log!.scheduledTime.isAtSameMomentAs(
            doses.single.scheduledTime,
          ),
          true,
        );
        expect(doses.single.status, DoseStatus.confirmed);
      },
    );
  });
}

Medication _medication({
  String id = 'medication-1',
  String name = 'Daily Vitamin',
  List<String> schedule = const ['08:00', '20:00'],
}) {
  return Medication(
    id: id,
    userId: 'user-1',
    name: name,
    dosage: '1 tablet',
    schedule: schedule,
    createdAt: DateTime.utc(2026, 5, 13, 7, 30),
    updatedAt: DateTime.utc(2026, 5, 13, 7, 30),
  );
}

MedicationLog _log({
  String id = 'log-1',
  String medicationId = 'medication-1',
  DateTime? scheduledTime,
  DateTime? confirmedTime,
  MedicationLogStatus status = MedicationLogStatus.confirmed,
  DateTime? date,
}) {
  return MedicationLog(
    id: id,
    medicationId: medicationId,
    scheduledTime: scheduledTime ?? _localDateTime(2026, 5, 13, 8),
    confirmedTime: confirmedTime,
    status: status,
    date: date ?? DateTime(2026, 5, 13),
  );
}

DateTime _localDateTime(
  int year,
  int month,
  int day,
  int hour, [
  int minute = 0,
]) {
  return DateTime(year, month, day, hour, minute);
}
