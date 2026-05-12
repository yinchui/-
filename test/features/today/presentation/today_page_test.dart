import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/core/theme/app_theme.dart';
import 'package:medication_reminder/features/medications/application/medication_providers.dart';
import 'package:medication_reminder/features/medications/data/in_memory_medication_repository.dart';
import 'package:medication_reminder/features/medications/domain/medication.dart';
import 'package:medication_reminder/features/medications/domain/medication_log.dart';
import 'package:medication_reminder/features/today/presentation/today_page.dart';

void main() {
  testWidgets('shows today doses and refreshes confirmed progress', (
    tester,
  ) async {
    final repository = InMemoryMedicationRepository();
    addTearDown(repository.close);

    await repository.saveMedication(_medication());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          medicationRepositoryProvider.overrideWithValue(repository),
          todayProvider.overrideWithValue(DateTime(2026, 5, 13)),
          nowProvider.overrideWithValue(DateTime(2026, 5, 13, 9, 15)),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const TodayPage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('早上好'), findsOneWidget);
    expect(find.text('08:00'), findsWidgets);
    expect(find.text('20:00'), findsWidgets);
    expect(find.text('维生素D'), findsNWidgets(2));
    expect(find.text('已完成 0 / 2'), findsOneWidget);

    await repository.saveLog(_confirmedLog());
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('today-page'))),
      listen: false,
    );
    await container.refresh(todayDosesProvider.future);
    await tester.pumpAndSettle();

    expect(find.text('已完成 1 / 2'), findsOneWidget);
    expect(find.text('已服用'), findsOneWidget);
  });
}

Medication _medication() {
  return Medication(
    id: 'medication-1',
    userId: 'user-1',
    name: '维生素D',
    dosage: '1片',
    schedule: const ['08:00', '20:00'],
    createdAt: DateTime.utc(2026, 5, 13, 7, 30),
    updatedAt: DateTime.utc(2026, 5, 13, 7, 30),
  );
}

MedicationLog _confirmedLog() {
  return MedicationLog(
    id: 'log-1',
    medicationId: 'medication-1',
    scheduledTime: DateTime(2026, 5, 13, 8),
    confirmedTime: DateTime(2026, 5, 13, 8, 5),
    status: MedicationLogStatus.confirmed,
    date: DateTime(2026, 5, 13),
  );
}
