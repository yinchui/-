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

    await _enterTextField(tester, '药名', '维生素 D');
    await _enterTextField(tester, '服用天数', '7');
    await _enterTextField(tester, '服用时间', '08:00,20:00');
    await _enterTextField(tester, '周一剂量', '1片');
    await _enterTextField(tester, '周二剂量', '1片');
    await _enterTextField(tester, '周三剂量', '2片');
    await _enterTextField(tester, '周四剂量', '1片');
    await _enterTextField(tester, '周五剂量', '1片');
    await _enterTextField(tester, '周六剂量', '半片');
    await _enterTextField(tester, '周日剂量', '停服');
    await _enterTextField(tester, '第3天剂量', '第3天改为半片');
    await _scrollMedicationFormUntilVisible(tester, find.text('保存'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('维生素 D'), findsOneWidget);
    expect(find.text('7天疗程 · 08:00, 20:00'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('确认删除药品？'), findsOneWidget);
    expect(find.text('维生素 D'), findsWidgets);

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(find.text('维生素 D'), findsNothing);
    expect(find.text('7天疗程 · 08:00, 20:00'), findsNothing);
  });
}

Future<void> _scrollMedicationFormUntilVisible(
  WidgetTester tester,
  Finder finder,
) async {
  await tester.scrollUntilVisible(
    finder,
    220,
    scrollable: _medicationFormScrollable(),
  );
  await tester.pumpAndSettle();
}

Future<void> _enterTextField(
  WidgetTester tester,
  String label,
  String value,
) async {
  final field = find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
    description: 'TextField with label "$label"',
  );

  final firstField = field.at(0);

  await _scrollMedicationFormUntilVisible(tester, firstField);
  await tester.enterText(firstField, value);
}

Finder _medicationFormScrollable() {
  return find
      .descendant(
        of: find.byKey(const ValueKey('medication-form-scroll')),
        matching: find.byType(Scrollable),
      )
      .first;
}
