import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/app.dart';

void main() {
  testWidgets('bottom navigation switches between main tabs', (tester) async {
    await tester.pumpWidget(const MedicationReminderApp());

    expect(find.text('今日'), findsWidgets);

    await tester.tap(find.byIcon(Icons.calendar_month));
    await tester.pumpAndSettle();
    expect(find.text('日历'), findsWidgets);

    await tester.tap(find.byIcon(Icons.medication));
    await tester.pumpAndSettle();
    expect(find.text('药品'), findsWidgets);
  });
}
