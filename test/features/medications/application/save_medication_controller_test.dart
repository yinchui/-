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
}
