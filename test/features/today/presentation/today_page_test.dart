import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/core/theme/app_theme.dart';
import 'package:medication_reminder/features/medications/application/medication_providers.dart';
import 'package:medication_reminder/features/medications/data/in_memory_medication_repository.dart';
import 'package:medication_reminder/features/medications/domain/medication.dart';
import 'package:medication_reminder/features/medications/domain/medication_daily_plan.dart';
import 'package:medication_reminder/features/medications/domain/medication_log.dart';
import 'package:medication_reminder/features/today/presentation/widgets/medication_card.dart';
import 'package:medication_reminder/features/confirm/presentation/slide_to_confirm.dart';
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

  testWidgets('shows missed log as missed after refreshing today doses', (
    tester,
  ) async {
    final repository = InMemoryMedicationRepository();
    addTearDown(repository.close);

    await repository.saveMedication(_medication(schedule: const ['08:00']));

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

    expect(find.text('待服用'), findsOneWidget);

    await repository.saveLog(_missedLog());
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('today-page'))),
      listen: false,
    );
    await container.refresh(todayDosesProvider.future);
    await tester.pumpAndSettle();

    expect(find.text('已完成 0 / 1'), findsOneWidget);
    expect(find.text('漏服'), findsOneWidget);
    expect(find.text('待服用'), findsNothing);
  });

  testWidgets('shows course medication with dosage for selected day', (
    tester,
  ) async {
    final repository = InMemoryMedicationRepository();
    addTearDown(repository.close);

    await repository.saveMedication(
      _medication(
        dailyPlans: [
          MedicationDailyPlan(
            date: DateTime(2026, 5, 13),
            dayIndex: 3,
            dosage: '第3天半粒',
            schedule: const ['09:00'],
          ),
        ],
      ),
    );

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

    expect(find.text('09:00'), findsWidgets);
    expect(find.text('第3天半粒'), findsOneWidget);
    expect(find.text('1片'), findsNothing);
  });

  testWidgets('tapping a pending dose opens confirmation and saves log', (
    tester,
  ) async {
    final repository = InMemoryMedicationRepository();
    addTearDown(repository.close);

    await repository.saveMedication(_medication(schedule: const ['08:00']));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          medicationRepositoryProvider.overrideWithValue(repository),
          todayProvider.overrideWithValue(DateTime(2026, 5, 13)),
          nowProvider.overrideWithValue(DateTime(2026, 5, 13, 8, 5)),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const TodayPage()),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byType(MedicationCard));
    await tester.pumpAndSettle();

    expect(find.text('滑动确认已服用'), findsOneWidget);

    await tester.drag(find.byType(SlideToConfirm), const Offset(500, 0));
    await tester.pumpAndSettle();

    final logs = await repository.getLogsForDate(DateTime(2026, 5, 13));
    expect(logs.single.status, MedicationLogStatus.confirmed);
    expect(logs.single.confirmedTime, DateTime(2026, 5, 13, 8, 5).toUtc());
  });
}

Medication _medication({
  List<String> schedule = const ['08:00', '20:00'],
  List<MedicationDailyPlan> dailyPlans = const [],
}) {
  return Medication(
    id: 'medication-1',
    userId: 'user-1',
    name: '维生素D',
    dosage: '1片',
    schedule: schedule,
    dailyPlans: dailyPlans,
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

MedicationLog _missedLog() {
  return MedicationLog(
    id: 'log-missed-1',
    medicationId: 'medication-1',
    scheduledTime: DateTime(2026, 5, 13, 8),
    confirmedTime: null,
    status: MedicationLogStatus.missed,
    date: DateTime(2026, 5, 13),
  );
}
