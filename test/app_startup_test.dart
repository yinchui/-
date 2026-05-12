import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/app.dart';
import 'package:medication_reminder/features/medications/application/medication_providers.dart';
import 'package:medication_reminder/features/medications/data/in_memory_medication_repository.dart';

void main() {
  testWidgets('app accepts repository override at root', (tester) async {
    final repository = InMemoryMedicationRepository();
    addTearDown(repository.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          medicationRepositoryProvider.overrideWithValue(repository),
          nowProvider.overrideWithValue(DateTime(2026, 5, 13, 8)),
        ],
        child: const MedicationReminderApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('早上好'), findsOneWidget);
  });
}
