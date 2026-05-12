import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/core/storage/database_schema.dart';
import 'package:medication_reminder/features/medications/data/sqlite_medication_repository.dart';
import 'package:medication_reminder/features/medications/domain/medication.dart';
import 'package:medication_reminder/features/medications/domain/medication_log.dart';
import 'package:medication_reminder/features/medications/domain/sync_queue_item.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late Database database;
  late SqliteMedicationRepository repository;

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await database.execute('PRAGMA foreign_keys = ON');
    for (final statement in DatabaseSchema.createStatements) {
      await database.execute(statement);
    }

    repository = SqliteMedicationRepository(database: database);
  });

  tearDown(() async {
    await repository.close();
    await database.close();
  });

  test(
    'saveMedication inserts medication, enqueues insert, and watch emits it',
    () async {
      final medication = _medication();

      await repository.saveMedication(medication);

      expect(await repository.watchMedications().first, [medication]);
      expect(await repository.getMedications(), [medication]);

      final queueItems = await _syncQueueItems(database);
      expect(queueItems, hasLength(1));
      expect(queueItems.single.tableName, 'medications');
      expect(queueItems.single.recordId, medication.id);
      expect(queueItems.single.action, SyncAction.insert);
      expect(queueItems.single.payload, medication.toMap());
      expect(queueItems.single.synced, isFalse);
    },
  );

  test(
    'saveMedication enqueues update when medication already exists',
    () async {
      final medication = _medication();
      final updatedMedication = medication.copyWith(
        dosage: '2 tablets',
        updatedAt: DateTime.utc(2026, 5, 13, 9),
      );

      await repository.saveMedication(medication);
      await repository.saveMedication(updatedMedication);

      expect(await repository.getMedications(), [updatedMedication]);

      final queueItems = await _syncQueueItems(database);
      expect(queueItems.map((item) => item.action), [
        SyncAction.insert,
        SyncAction.update,
      ]);
      expect(queueItems.last.payload, updatedMedication.toMap());
    },
  );

  test('saveMedication update preserves existing medication logs', () async {
    final medication = _medication();
    final log = _log();
    final updatedMedication = medication.copyWith(
      dosage: '2 tablets',
      updatedAt: DateTime.utc(2026, 5, 13, 9),
    );

    await repository.saveMedication(medication);
    await repository.saveLog(log);
    await repository.saveMedication(updatedMedication);

    expect(await repository.getMedications(), [updatedMedication]);
    expect(await repository.getLogsForDate(log.date), [log]);
    expect(
      (await database.query('medication_logs')).map(MedicationLog.fromMap),
      [log],
    );
  });

  test('getMedications returns medications by created time then id', () async {
    final createdAt = DateTime.utc(2026, 5, 13, 7, 30);
    final medicationB = _medication(
      id: 'medication-b',
      name: 'Vitamin B',
      createdAt: createdAt,
    );
    final medicationA = _medication(
      id: 'medication-a',
      name: 'Vitamin A',
      createdAt: createdAt,
    );

    await repository.saveMedication(medicationB);
    await repository.saveMedication(medicationA);

    expect(await repository.getMedications(), [medicationA, medicationB]);
  });

  test('deleteMedication removes medication and enqueues delete', () async {
    final medication = _medication();
    await repository.saveMedication(medication);

    await repository.deleteMedication(medication.id);

    expect(await repository.getMedications(), isEmpty);

    final queueItems = await _syncQueueItems(database);
    expect(queueItems.map((item) => item.action), [
      SyncAction.insert,
      SyncAction.delete,
    ]);
    expect(queueItems.last.tableName, 'medications');
    expect(queueItems.last.recordId, medication.id);
    expect(queueItems.last.payload, {'id': medication.id});
    expect(queueItems.last.synced, isFalse);
  });

  test(
    'saveLog inserts log and getLogsForDate returns date logs by schedule time',
    () async {
      final medication = _medication();
      final lateLog = _log(
        id: 'log-late',
        scheduledTime: DateTime.utc(2026, 5, 13, 20),
      );
      final earlyLog = _log(
        id: 'log-early',
        scheduledTime: DateTime.utc(2026, 5, 13, 8),
      );
      final otherDateLog = _log(
        id: 'log-other-date',
        scheduledTime: DateTime.utc(2026, 5, 14, 8),
        date: DateTime(2026, 5, 14, 17),
      );

      await repository.saveMedication(medication);
      await repository.saveLog(lateLog);
      await repository.saveLog(earlyLog);
      await repository.saveLog(otherDateLog);

      expect(await repository.getLogsForDate(DateTime(2026, 5, 13, 17)), [
        earlyLog,
        lateLog,
      ]);

      final storedLogs = await database.query('medication_logs');
      expect(
        storedLogs.map(MedicationLog.fromMap),
        containsAll([earlyLog, lateLog, otherDateLog]),
      );

      final logQueueItems = await _syncQueueItems(
        database,
        tableName: 'medication_logs',
      );
      expect(logQueueItems.map((item) => item.action), [
        SyncAction.insert,
        SyncAction.insert,
        SyncAction.insert,
      ]);
      expect(logQueueItems.map((item) => item.payload), [
        lateLog.toMap(),
        earlyLog.toMap(),
        otherDateLog.toMap(),
      ]);
    },
  );

  test('getLogsForDate returns logs by schedule time then id', () async {
    final medication = _medication();
    final scheduledTime = DateTime.utc(2026, 5, 13, 8);
    final logB = _log(id: 'log-b', scheduledTime: scheduledTime);
    final logA = _log(id: 'log-a', scheduledTime: scheduledTime);

    await repository.saveMedication(medication);
    await repository.saveLog(logB);
    await repository.saveLog(logA);

    expect(await repository.getLogsForDate(DateTime(2026, 5, 13)), [
      logA,
      logB,
    ]);
  });

  test('saveLog enqueues update when log already exists', () async {
    final medication = _medication();
    final log = _log();
    final updatedLog = log.copyWith(
      confirmedTime: DateTime.utc(2026, 5, 13, 8, 5),
      status: MedicationLogStatus.confirmed,
    );

    await repository.saveMedication(medication);
    await repository.saveLog(log);
    await repository.saveLog(updatedLog);

    expect(await repository.getLogsForDate(log.date), [updatedLog]);

    final logQueueItems = await _syncQueueItems(
      database,
      tableName: 'medication_logs',
    );
    expect(logQueueItems.map((item) => item.action), [
      SyncAction.insert,
      SyncAction.update,
    ]);
    expect(logQueueItems.map((item) => item.payload), [
      log.toMap(),
      updatedLog.toMap(),
    ]);
  });

  test('deleteMedication cascades to medication logs', () async {
    final medication = _medication();
    final log = _log();

    await repository.saveMedication(medication);
    await repository.saveLog(log);
    await repository.deleteMedication(medication.id);

    expect(await repository.getLogsForDate(log.date), isEmpty);
    expect(await database.query('medication_logs'), isEmpty);
  });

  test('watchMedications emits active subscription changes', () async {
    final medication = _medication();
    final iterator = StreamIterator(repository.watchMedications());

    try {
      expect(await _moveNext(iterator), isTrue);
      expect(iterator.current, isEmpty);

      await repository.saveMedication(medication);

      expect(await _moveNext(iterator), isTrue);
      expect(iterator.current, [medication]);

      await repository.deleteMedication(medication.id);

      expect(await _moveNext(iterator), isTrue);
      expect(iterator.current, isEmpty);
    } finally {
      await iterator.cancel();
    }
  });
}

Medication _medication({
  String id = 'medication-1',
  String name = 'Daily Vitamin',
  String dosage = '1 tablet',
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return Medication(
    id: id,
    userId: 'user-1',
    name: name,
    dosage: dosage,
    schedule: const ['08:00', '20:00'],
    createdAt: createdAt ?? DateTime.utc(2026, 5, 13, 7, 30),
    updatedAt: updatedAt ?? DateTime.utc(2026, 5, 13, 7, 30),
  );
}

MedicationLog _log({
  String id = 'log-1',
  DateTime? scheduledTime,
  DateTime? confirmedTime,
  MedicationLogStatus status = MedicationLogStatus.missed,
  DateTime? date,
}) {
  return MedicationLog(
    id: id,
    medicationId: 'medication-1',
    scheduledTime: scheduledTime ?? DateTime.utc(2026, 5, 13, 8),
    confirmedTime: confirmedTime,
    status: status,
    date: date ?? DateTime(2026, 5, 13),
  );
}

Future<bool> _moveNext(StreamIterator<List<Medication>> iterator) {
  return iterator.moveNext().timeout(const Duration(seconds: 1));
}

Future<List<SyncQueueItem>> _syncQueueItems(
  Database database, {
  String? tableName,
}) async {
  final rows = await database.query(
    'sync_queue',
    where: tableName == null ? null : 'table_name = ?',
    whereArgs: tableName == null ? null : [tableName],
    orderBy: 'id ASC',
  );
  return rows.map(SyncQueueItem.fromMap).toList();
}
