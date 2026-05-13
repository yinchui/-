import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/core/storage/database_schema.dart';
import 'package:medication_reminder/core/sync/supabase_sync_service.dart';
import 'package:medication_reminder/core/sync/sync_service.dart';
import 'package:medication_reminder/features/medications/domain/medication.dart';
import 'package:medication_reminder/features/medications/domain/medication_daily_plan.dart';
import 'package:medication_reminder/features/medications/domain/medication_log.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(sqfliteFfiInit);

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

  test('pushLocalSnapshot uploads existing rows even when queue is synced', () async {
    final requests = <_CapturedRequest>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) async {
      requests.add(
        _CapturedRequest(
          method: request.method,
          path: request.uri.path,
          body: await utf8.decodeStream(request),
        ),
      );
      request.response
        ..statusCode = HttpStatus.created
        ..headers.contentType = ContentType.json
        ..write('[]');
      await request.response.close();
    });

    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
    );
    await database.execute('PRAGMA foreign_keys = ON');
    for (final statement in DatabaseSchema.createStatements) {
      await database.execute(statement);
    }

    final medication = Medication(
      id: 'medication-1',
      userId: _localUserId,
      name: '维生素 D',
      dosage: '1片',
      schedule: const ['08:00'],
      startDate: DateTime(2026, 5, 13),
      durationDays: 1,
      dailyPlans: [
        MedicationDailyPlan(
          date: DateTime(2026, 5, 13),
          dayIndex: 1,
          dosage: '1片',
          schedule: const ['08:00'],
        ),
      ],
      createdAt: DateTime.utc(2026, 5, 13, 8),
      updatedAt: DateTime.utc(2026, 5, 13, 8),
    );
    final log = MedicationLog(
      id: 'log-1',
      medicationId: medication.id,
      scheduledTime: DateTime.utc(2026, 5, 13, 8),
      confirmedTime: null,
      status: MedicationLogStatus.missed,
      date: DateTime(2026, 5, 13),
    );
    await database.insert('medications', medication.toMap());
    await database.insert('medication_logs', log.toMap());
    await database.insert('sync_queue', {
      'table_name': 'medications',
      'record_id': medication.id,
      'action': 'insert',
      'payload': jsonEncode(medication.toMap()),
      'created_at': DateTime.utc(2026, 5, 13, 8).toIso8601String(),
      'synced': 1,
    });

    final service = SupabaseSyncService(
      database: database,
      client: SupabaseClient(
        'http://${InternetAddress.loopbackIPv4.address}:${server.port}',
        'anon-key',
      ),
      userId: _localUserId,
    );

    final result = await service.pushLocalSnapshot();

    expect(result, isA<SyncResult>());
    expect(result.pushed, 2);
    expect(result.failed, 0);
    expect(requests.map((request) => request.path), [
      '/rest/v1/medications',
      '/rest/v1/medication_logs',
    ]);
    final medicationBody = jsonDecode(requests.first.body) as Map;
    expect(medicationBody['schedule'], ['08:00']);
    expect(medicationBody['daily_plans'], isA<List>());
    final logBody = jsonDecode(requests.last.body) as Map;
    expect(logBody['medication_id'], medication.id);

    await database.close();
    await subscription.cancel();
    await server.close(force: true);
  });
}

const _localUserId = '00000000-0000-4000-8000-000000000000';

class _CapturedRequest {
  const _CapturedRequest({
    required this.method,
    required this.path,
    required this.body,
  });

  final String method;
  final String path;
  final String body;
}
