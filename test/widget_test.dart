import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/main.dart' as app;

void main() {
  testWidgets('exported app can be pumped inside provider scope', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: app.MedicationReminderApp()),
    );

    expect(find.text('今日'), findsWidgets);
    expect(find.text('药丸'), findsOneWidget);
  });
}
