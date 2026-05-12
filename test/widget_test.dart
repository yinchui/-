import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/main.dart';

void main() {
  testWidgets('app starts on today page', (tester) async {
    await tester.pumpWidget(const MedicationReminderApp());

    expect(find.text('今日'), findsWidgets);
    expect(find.text('药丸'), findsOneWidget);
  });
}
