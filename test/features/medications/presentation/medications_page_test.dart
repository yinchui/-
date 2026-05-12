import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/core/theme/app_theme.dart';
import 'package:medication_reminder/features/medications/application/medication_providers.dart';
import 'package:medication_reminder/features/medications/data/in_memory_medication_repository.dart';
import 'package:medication_reminder/features/medications/presentation/medications_page.dart';

void main() {
  testWidgets('adds a medication from the form and deletes it from the list', (
    tester,
  ) async {
    final repository = InMemoryMedicationRepository();
    addTearDown(repository.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [medicationRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const MedicationsPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(find.bySemanticsLabel('药名'), '维生素 D');
    await tester.enterText(find.bySemanticsLabel('剂量'), '1片');
    await tester.enterText(find.bySemanticsLabel('服用时间'), '08:00,20:00');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('维生素 D'), findsOneWidget);
    expect(find.text('1片 · 08:00, 20:00'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('确认删除药品？'), findsOneWidget);
    expect(find.text('维生素 D'), findsWidgets);

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(find.text('维生素 D'), findsNothing);
    expect(find.text('1片 · 08:00, 20:00'), findsNothing);
  });
}
