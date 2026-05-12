import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/features/medications/application/medication_providers.dart';
import 'package:medication_reminder/features/medications/data/in_memory_medication_repository.dart';
import 'package:medication_reminder/features/medications/domain/medication.dart';
import 'package:medication_reminder/features/medications/domain/medication_dose.dart';
import 'package:medication_reminder/features/medications/domain/medication_log.dart';

void main() {
  group('medication providers', () {
    test(
      'todayDosesProvider builds doses and refreshes saved log status',
      () async {
        final repository = InMemoryMedicationRepository();
        final container = _container(repository);
        addTearDown(() async {
          container.dispose();
          await repository.close();
        });

        final medication = _medication(name: 'Daily Vitamin');
        await repository.saveMedication(medication);

        final doses = await container.read(todayDosesProvider.future);

        expect(doses, hasLength(1));
        expect(doses.single.medication.name, 'Daily Vitamin');
        expect(doses.single.scheduledTime, _localDateTime(2026, 5, 13, 8));
        expect(doses.single.status, DoseStatus.pending);

        await repository.saveLog(_confirmedLog());

        final refreshedDoses = await container.refresh(
          todayDosesProvider.future,
        );

        expect(refreshedDoses, hasLength(1));
        expect(refreshedDoses.single.status, DoseStatus.confirmed);
        expect(refreshedDoses.single.log, isNotNull);
      },
    );

    test('medicationsProvider exposes repository stream values', () async {
      final repository = InMemoryMedicationRepository();
      final container = _container(repository);
      final subscription = container.listen(medicationsProvider, (_, _) {});
      addTearDown(() async {
        subscription.close();
        container.dispose();
        await repository.close();
      });

      expect(await container.read(medicationsProvider.future), isEmpty);

      final medication = _medication(name: 'Morning Pill');
      await repository.saveMedication(medication);
      await container.pump();

      expect(container.read(medicationsProvider).requireValue, [medication]);
    });
  });
}

ProviderContainer _container(InMemoryMedicationRepository repository) {
  return ProviderContainer(
    overrides: [
      medicationRepositoryProvider.overrideWithValue(repository),
      todayProvider.overrideWithValue(DateTime(2026, 5, 13)),
      nowProvider.overrideWithValue(_localDateTime(2026, 5, 13, 12)),
    ],
  );
}

Medication _medication({String name = 'Daily Vitamin'}) {
  return Medication(
    id: 'medication-1',
    userId: 'user-1',
    name: name,
    dosage: '1 tablet',
    schedule: const ['08:00'],
    createdAt: DateTime.utc(2026, 5, 13, 7, 30),
    updatedAt: DateTime.utc(2026, 5, 13, 7, 30),
  );
}

MedicationLog _confirmedLog() {
  return MedicationLog(
    id: 'log-1',
    medicationId: 'medication-1',
    scheduledTime: _localDateTime(2026, 5, 13, 8),
    confirmedTime: _localDateTime(2026, 5, 13, 8, 5),
    status: MedicationLogStatus.confirmed,
    date: DateTime(2026, 5, 13),
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
