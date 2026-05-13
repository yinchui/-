import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/core/sync/supabase_sync_service.dart';
import 'package:medication_reminder/core/sync/sync_service.dart';

void main() {
  test('sync result reports pushed and failed counts', () {
    const result = SyncResult(pushed: 2, failed: 1);

    expect(result.hasFailures, isTrue);
    expect(result.summary, '2 pushed, 1 failed');
  });

  test('supabase medication payload decodes json columns', () {
    final payload = decodeSupabasePayload(
      'medications',
      '{"id":"m1","schedule":"[\\"08:00\\"]","daily_plans":"[{\\"date\\":\\"2026-05-13\\",\\"dayIndex\\":1,\\"dosage\\":\\"1片\\",\\"schedule\\":[\\"08:00\\"]}]"}',
    );

    expect(payload['schedule'], ['08:00']);
    expect(payload['daily_plans'], [
      {
        'date': '2026-05-13',
        'dayIndex': 1,
        'dosage': '1片',
        'schedule': ['08:00'],
      },
    ]);
  });
}
