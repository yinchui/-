import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/core/storage/database_schema.dart';

void main() {
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
