import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/features/medications/application/medication_providers.dart';
import 'package:medication_reminder/features/medications/application/save_medication_controller.dart';
import 'package:medication_reminder/features/medications/data/in_memory_medication_repository.dart';

void main() {
  test(
    'saves medication with injected user id and normalized schedule',
    () async {
      final repository = InMemoryMedicationRepository();
      addTearDown(repository.close);

      final container = ProviderContainer(
        overrides: [
          medicationRepositoryProvider.overrideWithValue(repository),
          currentUserIdProvider.overrideWithValue(
            '11111111-1111-4111-8111-111111111111',
          ),
          nowProvider.overrideWithValue(DateTime.utc(2026, 5, 13, 8)),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(saveMedicationControllerProvider)
          .save(
            name: '  维生素 D  ',
            dosage: '  1片  ',
            scheduleInput: '20:00，08:00,08:00',
          );

      final medications = await repository.getMedications();

      expect(medications, hasLength(1));
      expect(medications.single.userId, '11111111-1111-4111-8111-111111111111');
      expect(medications.single.name, '维生素 D');
      expect(medications.single.dosage, '1片');
      expect(medications.single.schedule, ['08:00', '20:00']);
    },
  );

  test('generates course daily plans from weekly dosage template', () async {
    final repository = InMemoryMedicationRepository();
    addTearDown(repository.close);
    final container = _container(repository);
    addTearDown(container.dispose);

    await container
        .read(saveMedicationControllerProvider)
        .save(
          name: '阿莫西林',
          dosage: '默认剂量',
          scheduleInput: '20:00,08:00',
          startDate: DateTime(2026, 5, 11),
          durationDays: 8,
          weeklyDosages: const [
            '周一1粒',
            '周二2粒',
            '周三3粒',
            '周四4粒',
            '周五5粒',
            '周六6粒',
            '周日7粒',
          ],
          dailyDosageOverrides: const {3: '第3天改为半粒'},
        );

    final medication = (await repository.getMedications()).single;

    expect(medication.startDate, DateTime(2026, 5, 11));
    expect(medication.durationDays, 8);
    expect(medication.dosage, '周一1粒');
    expect(medication.schedule, ['08:00', '20:00']);
    expect(medication.dailyPlans, hasLength(8));
    expect(medication.dailyPlans.map((plan) => plan.dayIndex), [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
    ]);
    expect(medication.dailyPlans.map((plan) => plan.dosage), [
      '周一1粒',
      '周二2粒',
      '第3天改为半粒',
      '周四4粒',
      '周五5粒',
      '周六6粒',
      '周日7粒',
      '周一1粒',
    ]);
    for (final plan in medication.dailyPlans) {
      expect(plan.schedule, equals(medication.schedule));
    }
  });

  test('rejects invalid course duration and blank generated dosage', () async {
    final repository = InMemoryMedicationRepository();
    addTearDown(repository.close);
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(saveMedicationControllerProvider);

    await expectLater(
      controller.save(
        name: '阿莫西林',
        dosage: '1粒',
        scheduleInput: '08:00',
        startDate: DateTime(2026, 5, 11),
        durationDays: 0,
        weeklyDosages: const ['1粒', '1粒', '1粒', '1粒', '1粒', '1粒', '1粒'],
      ),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          '服用天数需介于 1 到 366 天',
        ),
      ),
    );

    await expectLater(
      controller.save(
        name: '阿莫西林',
        dosage: '1粒',
        scheduleInput: '08:00',
        startDate: DateTime(2026, 5, 11),
        durationDays: 2,
        weeklyDosages: const ['1粒', ' ', '1粒', '1粒', '1粒', '1粒', '1粒'],
      ),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          '每日剂量不能为空',
        ),
      ),
    );
  });
}

ProviderContainer _container(InMemoryMedicationRepository repository) {
  return ProviderContainer(
    overrides: [
      medicationRepositoryProvider.overrideWithValue(repository),
      currentUserIdProvider.overrideWithValue(
        '11111111-1111-4111-8111-111111111111',
      ),
      nowProvider.overrideWithValue(DateTime.utc(2026, 5, 13, 8)),
    ],
  );
}
