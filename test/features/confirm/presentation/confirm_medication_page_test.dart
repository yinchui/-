import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/core/theme/app_theme.dart';
import 'package:medication_reminder/features/confirm/presentation/confirm_medication_page.dart';
import 'package:medication_reminder/features/confirm/presentation/slide_to_confirm.dart';
import 'package:medication_reminder/features/medications/application/medication_providers.dart';
import 'package:medication_reminder/features/medications/data/in_memory_medication_repository.dart';
import 'package:medication_reminder/features/medications/data/medication_repository.dart';
import 'package:medication_reminder/features/medications/domain/medication.dart';
import 'package:medication_reminder/features/medications/domain/medication_dose.dart';
import 'package:medication_reminder/features/medications/domain/medication_log.dart';

void main() {
  testWidgets(
    'slide confirmation saves dose log and calls completion callback',
    (tester) async {
      final repository = InMemoryMedicationRepository();
      addTearDown(repository.close);
      var confirmed = false;
      final dose = _dose();
      final confirmedAt = DateTime(2026, 5, 12, 8, 7);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            medicationRepositoryProvider.overrideWithValue(repository),
            nowProvider.overrideWithValue(confirmedAt),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: ConfirmMedicationPage(
              doses: [dose],
              onConfirmed: () => confirmed = true,
            ),
          ),
        ),
      );

      expect(find.text('该吃药了'), findsOneWidget);
      expect(find.text('阿莫西林'), findsOneWidget);
      expect(find.text('2粒'), findsOneWidget);

      await tester.drag(find.byType(SlideToConfirm), const Offset(500, 0));
      await tester.pumpAndSettle();

      final logs = await repository.getLogsForDate(DateTime(2026, 5, 12));

      expect(confirmed, isTrue);
      expect(find.text('已确认'), findsOneWidget);
      expect(logs, hasLength(1));
      expect(logs.single.medicationId, 'm1');
      expect(logs.single.scheduledTime, DateTime(2026, 5, 12, 8).toUtc());
      expect(logs.single.confirmedTime, confirmedAt.toUtc());
      expect(logs.single.status, MedicationLogStatus.confirmed);
    },
  );

  testWidgets('keeps confirmation open when saving log fails', (tester) async {
    final repository = _FailingSaveLogRepository();
    addTearDown(repository.close);
    var confirmed = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          medicationRepositoryProvider.overrideWithValue(repository),
          nowProvider.overrideWithValue(DateTime(2026, 5, 12, 8, 7)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: ConfirmMedicationPage(
            doses: [_dose()],
            onConfirmed: () => confirmed = true,
          ),
        ),
      ),
    );

    await tester.drag(find.byType(SlideToConfirm), const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(confirmed, isFalse);
    expect(find.text('已确认'), findsNothing);
    expect(find.text('确认失败，请稍后再试'), findsOneWidget);
    expect(find.text('该吃药了'), findsOneWidget);
  });

  testWidgets('confirmation can be dismissed without saving a log', (
    tester,
  ) async {
    final repository = InMemoryMedicationRepository();
    addTearDown(repository.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          medicationRepositoryProvider.overrideWithValue(repository),
          nowProvider.overrideWithValue(DateTime(2026, 5, 12, 8, 7)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: Text('今日')),
          routes: {
            '/confirm': (context) => ConfirmMedicationPage(doses: [_dose()]),
          },
        ),
      ),
    );

    Navigator.of(tester.element(find.text('今日'))).pushNamed('/confirm');
    await tester.pumpAndSettle();

    expect(find.text('滑动确认已服用'), findsOneWidget);

    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();

    expect(find.text('今日'), findsOneWidget);
    final logs = await repository.getLogsForDate(DateTime(2026, 5, 12));
    expect(logs, isEmpty);
  });

  testWidgets('slide confirmation uses the available page width', (
    tester,
  ) async {
    final repository = InMemoryMedicationRepository();
    addTearDown(repository.close);
    tester.view.physicalSize = const Size(432, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          medicationRepositoryProvider.overrideWithValue(repository),
          nowProvider.overrideWithValue(DateTime(2026, 5, 12, 8, 7)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: ConfirmMedicationPage(doses: [_dose()]),
        ),
      ),
    );

    final width = tester.getSize(find.byType(SlideToConfirm)).width;

    expect(width, greaterThanOrEqualTo(360));
  });
}

MedicationDose _dose() {
  return MedicationDose(
    medication: Medication(
      id: 'm1',
      userId: 'user-1',
      name: '阿莫西林',
      dosage: '2粒',
      schedule: const ['08:00'],
      createdAt: DateTime.utc(2026, 5, 12),
      updatedAt: DateTime.utc(2026, 5, 12),
    ),
    scheduledTime: DateTime(2026, 5, 12, 8),
    status: DoseStatus.pending,
    log: null,
  );
}

class _FailingSaveLogRepository extends InMemoryMedicationRepository
    implements MedicationRepository {
  @override
  Future<void> saveLog(MedicationLog log) async {
    throw StateError('cannot save log');
  }
}
