import 'dart:convert';

import 'package:medication_reminder/core/sync/sync_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseSyncService implements SyncService {
  SupabaseSyncService({
    required Database database,
    required SupabaseClient client,
  }) : _database = database,
       _client = client;

  final Database _database;
  final SupabaseClient _client;

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

  Future<void> _pushRow(Map<String, Object?> row) async {
    final table = row['table_name']! as String;
    final action = row['action']! as String;
    final recordId = row['record_id']! as String;
    final payload = row['payload']! as String;

    if (action == 'delete') {
      await _client.from(table).delete().eq('id', recordId);
      return;
    }

    await _client.from(table).upsert(_decodePayload(table, payload));
  }

  Map<String, Object?> _decodePayload(String table, String payload) {
    final decoded = Map<String, Object?>.from(jsonDecode(payload) as Map);

    if (table == 'medications' && decoded['schedule'] is String) {
      decoded['schedule'] = jsonDecode(decoded['schedule']! as String);
    }

    return decoded;
  }
}
