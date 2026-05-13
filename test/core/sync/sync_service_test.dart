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

  test('supabase remote medication rows encode json columns for sqlite', () {
    final row = encodeLocalMedicationRow({
      'id': 'm1',
      'user_id': 'user-1',
      'name': '维生素 D',
      'dosage': '1片',
      'schedule': ['08:00'],
      'start_date': '2026-05-13',
      'duration_days': 1,
      'daily_plans': [
        {
          'date': '2026-05-13',
          'dayIndex': 1,
          'dosage': '1片',
          'schedule': ['08:00'],
        },
      ],
      'created_at': '2026-05-13T00:00:00.000Z',
      'updated_at': '2026-05-13T00:00:00.000Z',
    });

    expect(row['schedule'], '["08:00"]');
    expect(row['daily_plans'], contains('"dosage":"1片"'));
  });
}
