import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/core/storage/app_database.dart';
import 'package:medication_reminder/core/storage/database_schema.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  group('DatabaseSchema', () {
    test('uses initial schema version', () {
      expect(DatabaseSchema.version, 1);
    });

    test('creates medication, log, and sync queue tables', () {
      final schemaSql = _normalizedSchemaSql();

      expect(schemaSql, contains('create table medications'));
      expect(schemaSql, contains('create table medication_logs'));
      expect(schemaSql, contains('create table sync_queue'));
    });

    test('requires medication schedule JSON text', () {
      final medications = _normalizedStatementContaining(
        'create table medications',
      );

      expect(medications, contains('schedule text not null'));
    });

    test('constrains medication log status, date, and parent medication', () {
      final logs = _normalizedStatementContaining(
        'create table medication_logs',
      );

      expect(logs, contains('date text not null'));
      expect(
        logs,
        contains(
          "status text not null check (status in ('confirmed', "
          "'missed'))",
        ),
      );
      expect(
        logs,
        contains(
          'foreign key (medication_id) references medications (id) '
          'on delete cascade',
        ),
      );
    });

    test('tracks unsynced sync queue records and creates lookup indexes', () {
      final schemaSql = _normalizedSchemaSql();
      final syncQueue = _normalizedStatementContaining(
        'create table sync_queue',
      );

      expect(syncQueue, contains('synced integer not null default 0'));
      expect(schemaSql, contains('idx_medication_logs_date'));
      expect(schemaSql, contains('idx_sync_queue_unsynced'));
    });

    test('executes all schema DDL statements against sqlite', () async {
      final database = await _openSchemaDatabase();

      final schemaObjects = await database.rawQuery('''
SELECT name
FROM sqlite_master
WHERE type IN ('table', 'index')
  AND name NOT LIKE 'sqlite_%'
''');

      expect(
        schemaObjects.map((object) => object['name']),
        containsAll([
          'medications',
          'medication_logs',
          'sync_queue',
          'idx_medication_logs_date',
          'idx_sync_queue_unsynced',
        ]),
      );
    });

    test('cascades medication deletes to medication logs', () async {
      final database = await _openSchemaDatabase();
      await _insertMedication(database);
      await _insertMedicationLog(database);

      await database.delete(
        'medications',
        where: 'id = ?',
        whereArgs: ['medication-1'],
      );

      final logs = await database.query('medication_logs');
      expect(logs, isEmpty);
    });

    test('rejects invalid medication log statuses', () async {
      final database = await _openSchemaDatabase();
      await _insertMedication(database);

      await expectLater(
        _insertMedicationLog(database, status: 'skipped'),
        throwsA(_isCheckConstraintFailure()),
      );
    });

    test('rejects invalid sync queue actions', () async {
      final database = await _openSchemaDatabase();

      await expectLater(
        database.insert('sync_queue', {
          'table_name': 'medications',
          'record_id': 'medication-1',
          'action': 'merge',
          'payload': '{}',
          'created_at': '2026-05-13T09:00:00Z',
        }),
        throwsA(_isCheckConstraintFailure()),
      );
    });

    test(
      'indexes unsynced sync queue rows by sync state then creation time',
      () async {
        final database = await _openSchemaDatabase();

        final indexes = await database.rawQuery(
          "PRAGMA index_list('sync_queue')",
        );
        expect(
          indexes.map((index) => index['name']),
          contains('idx_sync_queue_unsynced'),
        );

        final indexedColumns = await database.rawQuery(
          "PRAGMA index_info('idx_sync_queue_unsynced')",
        );

        expect(indexedColumns.map((column) => column['name']), [
          'synced',
          'created_at',
        ]);
      },
    );
  });

  group('AppDatabase', () {
    test('exposes instance as an alias for the database getter', () async {
      final database = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
      );
      final appDatabase = AppDatabase(database: database);
      addTearDown(appDatabase.close);

      expect(await appDatabase.instance, same(database));
    });
  });
}

Future<Database> _openSchemaDatabase() async {
  final database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  addTearDown(database.close);

  await database.execute('PRAGMA foreign_keys = ON');
  for (final statement in DatabaseSchema.createStatements) {
    await database.execute(statement);
  }

  return database;
}

Future<void> _insertMedication(Database database) async {
  await database.insert('medications', {
    'id': 'medication-1',
    'user_id': 'user-1',
    'name': 'Daily Vitamin',
    'dosage': '1 tablet',
    'schedule': '{"hour":9}',
    'created_at': '2026-05-13T09:00:00Z',
    'updated_at': '2026-05-13T09:00:00Z',
  });
}

Future<void> _insertMedicationLog(
  Database database, {
  String status = 'confirmed',
}) async {
  await database.insert('medication_logs', {
    'id': 'log-1',
    'medication_id': 'medication-1',
    'scheduled_time': '2026-05-13T09:00:00Z',
    'status': status,
    'date': '2026-05-13',
  });
}

String _normalizedSchemaSql() {
  return DatabaseSchema.createStatements.map(_normalizeSql).join(' ');
}

String _normalizedStatementContaining(String text) {
  return DatabaseSchema.createStatements
      .map(_normalizeSql)
      .singleWhere((statement) => statement.contains(text));
}

String _normalizeSql(String sql) {
  return sql.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

Matcher _isCheckConstraintFailure() {
  return isA<DatabaseException>().having(
    (error) => error.toString().toLowerCase(),
    'message',
    contains('check constraint failed'),
  );
}
