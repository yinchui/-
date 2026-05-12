import 'dart:async';

import 'package:sqflite/sqflite.dart';

import '../domain/medication.dart';
import '../domain/medication_log.dart';
import '../domain/sync_queue_item.dart';
import 'medication_repository.dart';

class SqliteMedicationRepository implements MedicationRepository {
  SqliteMedicationRepository({required Database database})
    : _database = database;

  final Database _database;
  final _medicationsController = StreamController<List<Medication>>.broadcast();

  @override
  Stream<List<Medication>> watchMedications() async* {
    yield await getMedications();
    yield* _medicationsController.stream;
  }

  @override
  Future<List<Medication>> getMedications() async {
    final rows = await _database.query(
      'medications',
      orderBy: 'created_at ASC',
    );
    return rows.map(Medication.fromMap).toList();
  }

  @override
  Future<void> saveMedication(Medication medication) async {
    await _database.transaction((transaction) async {
      final existingRows = await transaction.query(
        'medications',
        columns: const ['id'],
        where: 'id = ?',
        whereArgs: [medication.id],
        limit: 1,
      );
      final action = existingRows.isEmpty
          ? SyncAction.insert
          : SyncAction.update;

      await transaction.insert(
        'medications',
        medication.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _enqueue(
        transaction,
        tableName: 'medications',
        recordId: medication.id,
        action: action,
        payload: medication.toMap(),
      );
    });

    await _notifyMedicationsChanged();
  }

  @override
  Future<void> deleteMedication(String medicationId) async {
    await _database.transaction((transaction) async {
      await transaction.delete(
        'medications',
        where: 'id = ?',
        whereArgs: [medicationId],
      );
      await _enqueue(
        transaction,
        tableName: 'medications',
        recordId: medicationId,
        action: SyncAction.delete,
        payload: {'id': medicationId},
      );
    });

    await _notifyMedicationsChanged();
  }

  @override
  Future<List<MedicationLog>> getLogsForDate(DateTime date) async {
    final rows = await _database.query(
      'medication_logs',
      where: 'date = ?',
      whereArgs: [_formatDate(date)],
      orderBy: 'scheduled_time ASC',
    );
    return rows.map(MedicationLog.fromMap).toList();
  }

  @override
  Future<void> saveLog(MedicationLog log) async {
    await _database.transaction((transaction) async {
      await transaction.insert(
        'medication_logs',
        log.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _enqueue(
        transaction,
        tableName: 'medication_logs',
        recordId: log.id,
        action: SyncAction.insert,
        payload: log.toMap(),
      );
    });
  }

  Future<void> close() async {
    await _medicationsController.close();
  }

  Future<void> _notifyMedicationsChanged() async {
    if (_medicationsController.isClosed) {
      return;
    }

    _medicationsController.add(await getMedications());
  }

  Future<void> _enqueue(
    DatabaseExecutor executor, {
    required String tableName,
    required String recordId,
    required SyncAction action,
    required Map<String, Object?> payload,
  }) async {
    final item = SyncQueueItem(
      id: null,
      tableName: tableName,
      recordId: recordId,
      action: action,
      payload: payload,
      createdAt: DateTime.now().toUtc(),
      synced: false,
    );

    await executor.insert('sync_queue', item.toMap());
  }
}

String _formatDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
