import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/core/notifications/notification_scheduler.dart';
import 'package:medication_reminder/core/notifications/rescheduling_medication_repository.dart';
import 'package:medication_reminder/features/medications/data/in_memory_medication_repository.dart';
import 'package:medication_reminder/features/medications/domain/medication.dart';

class FakeNotificationScheduler implements NotificationScheduler {
  final scheduled = <ScheduledNotificationRequest>[];
  var cancelAllCount = 0;
  var throwOnSchedule = false;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> schedule(ScheduledNotificationRequest request) async {
    if (throwOnSchedule) {
      throw StateError('notification unavailable');
    }
    scheduled.add(request);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCount += 1;
  }
}

void main() {
  test('saveMedication persists data and reschedules reminders', () async {
    final delegate = InMemoryMedicationRepository();
    final scheduler = FakeNotificationScheduler();
    final repository = ReschedulingMedicationRepository(
      delegate: delegate,
      scheduler: scheduler,
      now: () => DateTime(2026, 5, 14, 7),
    );

    await repository.saveMedication(
      _medication(id: 'm1', name: '阿莫西林', dosage: '2粒'),
    );

    expect((await delegate.getMedications()).single.id, 'm1');
    expect(scheduler.cancelAllCount, 1);
    expect(scheduler.scheduled.single.body, '阿莫西林 · 2粒');
    expect(scheduler.scheduled.single.scheduledAt, DateTime(2026, 5, 14, 8));
  });

  test('deleteMedication reschedules remaining medications', () async {
    final delegate = InMemoryMedicationRepository();
    await delegate.saveMedication(_medication(id: 'm1', name: '药一'));
    await delegate.saveMedication(_medication(id: 'm2', name: '药二'));
    final scheduler = FakeNotificationScheduler();
    final repository = ReschedulingMedicationRepository(
      delegate: delegate,
      scheduler: scheduler,
      now: () => DateTime(2026, 5, 14, 7),
    );

    await repository.deleteMedication('m1');

    expect(
      (await delegate.getMedications()).map((medication) => medication.id),
      ['m2'],
    );
    expect(scheduler.cancelAllCount, 1);
    expect(scheduler.scheduled.single.body, '药二 · 1片');
  });

  test('notification failures do not prevent medication saves', () async {
    final delegate = InMemoryMedicationRepository();
    final scheduler = FakeNotificationScheduler()..throwOnSchedule = true;
    final repository = ReschedulingMedicationRepository(
      delegate: delegate,
      scheduler: scheduler,
      now: () => DateTime(2026, 5, 14, 7),
    );

    await repository.saveMedication(_medication(id: 'm1'));

    expect((await delegate.getMedications()).single.id, 'm1');
    expect(scheduler.cancelAllCount, 1);
  });
}

Medication _medication({
  required String id,
  String name = '维生素 D',
  String dosage = '1片',
}) {
  return Medication(
    id: id,
    userId: 'user-1',
    name: name,
    dosage: dosage,
    schedule: const ['08:00'],
    createdAt: DateTime(2026, 5, 14),
    updatedAt: DateTime(2026, 5, 14),
  );
}
