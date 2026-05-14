import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/core/notifications/notification_tap_handler.dart';
import 'package:medication_reminder/features/medications/application/medication_providers.dart';
import 'package:medication_reminder/features/medications/data/in_memory_medication_repository.dart';
import 'package:medication_reminder/features/medications/domain/medication.dart';
import 'package:medication_reminder/features/medications/domain/medication_daily_plan.dart';

void main() {
  testWidgets('notification tap opens confirmation page for matching dose', (
    tester,
  ) async {
    final repository = InMemoryMedicationRepository();
    addTearDown(repository.close);
    await repository.saveMedication(_medication(schedule: const ['08:00']));
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          medicationRepositoryProvider.overrideWithValue(repository),
          todayProvider.overrideWithValue(DateTime(2026, 5, 13)),
          nowProvider.overrideWithValue(DateTime(2026, 5, 13, 8, 2)),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: Text('首页')),
        ),
      ),
    );

    await NotificationTapHandler(
      repository: repository,
      navigatorKey: navigatorKey,
      now: () => DateTime(2026, 5, 13, 8, 2),
    ).handle('medication:medication-1:08:00');
    await tester.pumpAndSettle();

    expect(find.text('该吃药了'), findsOneWidget);
    expect(find.text('维生素D'), findsOneWidget);
    expect(find.text('滑动确认已服用'), findsOneWidget);
  });

  testWidgets('notification tap supports dated course payloads', (
    tester,
  ) async {
    final repository = InMemoryMedicationRepository();
    addTearDown(repository.close);
    await repository.saveMedication(
      _medication(
        dailyPlans: [
          MedicationDailyPlan(
            date: DateTime(2026, 5, 13),
            dayIndex: 2,
            dosage: '半片',
            schedule: const ['09:00'],
          ),
        ],
      ),
    );
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          medicationRepositoryProvider.overrideWithValue(repository),
          todayProvider.overrideWithValue(DateTime(2026, 5, 13)),
          nowProvider.overrideWithValue(DateTime(2026, 5, 13, 9, 2)),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: Text('首页')),
        ),
      ),
    );

    await NotificationTapHandler(
      repository: repository,
      navigatorKey: navigatorKey,
      now: () => DateTime(2026, 5, 13, 9, 2),
    ).handle('medication:medication-1:2026-05-13:09:00');
    await tester.pumpAndSettle();

    expect(find.text('半片'), findsOneWidget);
    expect(find.text('滑动确认已服用'), findsOneWidget);
  });
}

Medication _medication({
  List<String> schedule = const ['08:00'],
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
