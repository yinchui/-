import 'dart:convert';

import 'package:medication_reminder/core/sync/sync_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseSyncService implements SyncService {
  SupabaseSyncService({
    required Database database,
    required SupabaseClient client,
    required String userId,
  }) : _database = database,
       _client = client,
       _userId = userId;

  final Database _database;
  final SupabaseClient _client;
  final String _userId;

  Future<SyncResult> pushLocalSnapshot() async {
    var pushed = 0;
    var failed = 0;

    final medicationRows = await _database.query(
      'medications',
      orderBy: 'created_at ASC, id ASC',
    );
    for (final row in medicationRows) {
      try {
        await _client
            .from('medications')
            .upsert(decodeSupabasePayload('medications', jsonEncode(row)));
        pushed += 1;
      } catch (_) {
        failed += 1;
      }
    }

    final logRows = await _database.query(
      'medication_logs',
      orderBy: 'scheduled_time ASC, id ASC',
    );
    for (final row in logRows) {
      try {
        await _client
            .from('medication_logs')
            .upsert(decodeSupabasePayload('medication_logs', jsonEncode(row)));
        pushed += 1;
      } catch (_) {
        failed += 1;
      }
    }

    return SyncResult(pushed: pushed, failed: failed);
  }

  @override
  Future<SyncResult> pushPendingChanges() async {
    final rows = await _database.query(
      'sync_queue',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );

    var pushed = 0;
    var failed = 0;

    for (final row in rows) {
      try {
        await _pushRow(row);
        await _database.update(
          'sync_queue',
          {'synced': 1},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
        pushed += 1;
      } catch (_) {
        failed += 1;
      }
    }

    return SyncResult(pushed: pushed, failed: failed);
  }

  @override
  Future<SyncResult> pullRemoteChanges() async {
    var pulled = 0;
    var failed = 0;

    try {
      final medicationRows = await _client
          .from('medications')
          .select()
          .eq('user_id', _userId);
      await _database.transaction((transaction) async {
        for (final row in medicationRows) {
          await transaction.insert(
            'medications',
            encodeLocalMedicationRow(Map<String, Object?>.from(row)),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          pulled += 1;
        }
      });
    } catch (_) {
      failed += 1;
    }

    try {
      final logRows = await _client.from('medication_logs').select();
      await _database.transaction((transaction) async {
        for (final row in logRows) {
          await transaction.insert(
            'medication_logs',
            Map<String, Object?>.from(row),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          pulled += 1;
        }
      });
    } catch (_) {
      failed += 1;
    }

    return SyncResult(pushed: pulled, failed: failed);
  }

  Future<void> _pushRow(Map<String, Object?> row) async {
    final table = row['table_name']! as String;
    final action = row['action']! as String;
    final recordId = row['record_id']! as String;
    final payload = row['payload']! as String;

    if (action == 'delete') {
      await _client.from(table).delete().eq('id', recordId);
      return;
    }

    await _client.from(table).upsert(decodeSupabasePayload(table, payload));
  }
}

Map<String, Object?> decodeSupabasePayload(String table, String payload) {
  final decoded = Map<String, Object?>.from(jsonDecode(payload) as Map);

  if (table == 'medications') {
    if (decoded['schedule'] is String) {
      decoded['schedule'] = jsonDecode(decoded['schedule']! as String);
    }
    if (decoded['daily_plans'] is String) {
      decoded['daily_plans'] = jsonDecode(decoded['daily_plans']! as String);
    }
  }

  return decoded;
}

Map<String, Object?> encodeLocalMedicationRow(Map<String, Object?> row) {
  final encoded = Map<String, Object?>.from(row);

  if (encoded['schedule'] is! String) {
    encoded['schedule'] = jsonEncode(encoded['schedule']);
  }
  if (encoded['daily_plans'] is! String) {
    encoded['daily_plans'] = jsonEncode(encoded['daily_plans'] ?? const []);
  }

  return encoded;
}
