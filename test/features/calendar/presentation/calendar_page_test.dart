import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/core/theme/app_theme.dart';
import 'package:medication_reminder/features/confirm/presentation/slide_to_confirm.dart';
import 'package:medication_reminder/features/calendar/presentation/calendar_page.dart';
import 'package:medication_reminder/features/medications/application/medication_providers.dart';
import 'package:medication_reminder/features/medications/data/in_memory_medication_repository.dart';
import 'package:medication_reminder/features/medications/domain/medication.dart';
import 'package:medication_reminder/features/medications/domain/medication_daily_plan.dart';
import 'package:medication_reminder/features/medications/domain/medication_log.dart';

void main() {
  testWidgets('calendar page renders month stats and selected day details', (
    tester,
  ) async {
    final repository = InMemoryMedicationRepository();
    addTearDown(repository.close);

    await repository.saveMedication(
      _medication(id: 'm1', name: '维生素 D', schedule: const ['08:00']),
    );
    await repository.saveMedication(
      _medication(id: 'm2', name: '钙片', schedule: const ['20:00']),
    );
    await repository.saveLog(
      _log(
        id: 'l1',
        medicationId: 'm1',
        status: MedicationLogStatus.confirmed,
        scheduledTime: DateTime(2026, 5, 12, 8),
        confirmedTime: DateTime(2026, 5, 12, 8, 4),
      ),
    );
    await repository.saveLog(
      _log(
        id: 'l2',
        medicationId: 'm2',
        status: MedicationLogStatus.missed,
        scheduledTime: DateTime(2026, 5, 12, 20),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          medicationRepositoryProvider.overrideWithValue(repository),
          todayProvider.overrideWithValue(DateTime(2026, 5, 13)),
          nowProvider.overrideWithValue(DateTime(2026, 5, 13, 12)),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const CalendarPage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('2026年5月'), findsOneWidget);
    expect(find.text('已服'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    expect(find.text('漏服'), findsOneWidget);
    expect(find.text('服药率'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);

    await tester.tap(find.text('12'));
    await tester.pumpAndSettle();

    expect(find.text('5月12日'), findsOneWidget);
    expect(find.text('维生素 D'), findsOneWidget);
    expect(find.text('钙片'), findsOneWidget);
    expect(find.text('已服用'), findsOneWidget);
    expect(find.text('20:00 · 漏服'), findsOneWidget);
  });

  testWidgets('calendar page shows future planned course doses', (
    tester,
  ) async {
    final repository = InMemoryMedicationRepository();
    addTearDown(repository.close);

    await repository.saveMedication(
      _medication(
        id: 'course-1',
        name: '头孢',
        schedule: const ['09:00'],
        dailyPlans: [
          MedicationDailyPlan(
            date: DateTime(2026, 5, 15),
            dayIndex: 3,
            dosage: '第3天半片',
            schedule: ['09:00'],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          medicationRepositoryProvider.overrideWithValue(repository),
          todayProvider.overrideWithValue(DateTime(2026, 5, 13)),
          nowProvider.overrideWithValue(DateTime(2026, 5, 13, 12)),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const CalendarPage()),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();

    expect(find.text('5月15日'), findsOneWidget);
    expect(find.text('头孢'), findsOneWidget);
    expect(find.text('第3天半片'), findsOneWidget);
    expect(find.text('09:00 · 计划中'), findsOneWidget);
  });

  testWidgets('calendar page confirms a previous planned dose', (tester) async {
    final repository = InMemoryMedicationRepository();
    addTearDown(repository.close);

    await repository.saveMedication(
      _medication(id: 'm1', name: '维生素 D', schedule: const ['08:00']),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          medicationRepositoryProvider.overrideWithValue(repository),
          todayProvider.overrideWithValue(DateTime(2026, 5, 13)),
          nowProvider.overrideWithValue(DateTime(2026, 5, 13, 12)),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const CalendarPage()),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('12'));
    await tester.pumpAndSettle();

    expect(find.text('08:00 · 计划中'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '确认'));
    await tester.pumpAndSettle();

    expect(find.text('滑动确认已服用'), findsOneWidget);

    await tester.drag(find.byType(SlideToConfirm), const Offset(500, 0));
    await tester.pumpAndSettle();

    final logs = await repository.getLogsForDate(DateTime(2026, 5, 12));
    expect(logs, hasLength(1));
    expect(logs.single.status, MedicationLogStatus.confirmed);
    expect(logs.single.scheduledTime, DateTime(2026, 5, 12, 8).toUtc());
    expect(logs.single.confirmedTime, DateTime(2026, 5, 13, 12).toUtc());

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('08:00 · 已服用'), findsOneWidget);
  });
}

Medication _medication({
  required String id,
  required String name,
  required List<String> schedule,
  List<MedicationDailyPlan> dailyPlans = const [],
}) {
  return Medication(
    id: id,
    userId: 'user-1',
    name: name,
    dosage: '1片',
    schedule: schedule,
    startDate: dailyPlans.isEmpty ? null : dailyPlans.first.date,
    durationDays: dailyPlans.isEmpty ? null : dailyPlans.length,
    dailyPlans: dailyPlans,
    createdAt: DateTime.utc(2026, 5, 1),
    updatedAt: DateTime.utc(2026, 5, 1),
  );
}

MedicationLog _log({
  required String id,
  required String medicationId,
  required MedicationLogStatus status,
  required DateTime scheduledTime,
  DateTime? confirmedTime,
}) {
  return MedicationLog(
    id: id,
    medicationId: medicationId,
    scheduledTime: scheduledTime,
    confirmedTime: confirmedTime,
    status: status,
    date: DateTime(2026, 5, 12),
  );
}
