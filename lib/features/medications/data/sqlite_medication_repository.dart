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
  Stream<List<Medication>> watchMedications() {
    late StreamController<List<Medication>> controller;
    StreamSubscription<List<Medication>>? subscription;
    final queuedUpdates = <List<Medication>>[];
    var emittedInitialSnapshot = false;

    controller = StreamController<List<Medication>>(
      onListen: () async {
        subscription = _medicationsController.stream.listen((medications) {
          if (controller.isClosed) {
            return;
          }

          if (emittedInitialSnapshot) {
            controller.add(medications);
          } else {
            queuedUpdates.add(medications);
          }
        }, onError: controller.addError);

        try {
          final medications = await getMedications();
          if (controller.isClosed) {
            return;
          }

          controller.add(medications);
          emittedInitialSnapshot = true;

          for (final queuedUpdate in queuedUpdates) {
            if (controller.isClosed) {
              return;
            }
            controller.add(queuedUpdate);
          }
          queuedUpdates.clear();
        } catch (error, stackTrace) {
          if (!controller.isClosed) {
            controller.addError(error, stackTrace);
          }
        }
      },
      onCancel: () async {
        await subscription?.cancel();
      },
    );

    return controller.stream;
  }

  @override
  Future<List<Medication>> getMedications() async {
    final rows = await _database.query(
      'medications',
      orderBy: 'created_at ASC, id ASC',
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
      final medicationMap = medication.toMap();

      if (existingRows.isEmpty) {
        await transaction.insert('medications', medicationMap);
      } else {
        await transaction.update(
          'medications',
          medicationMap,
          where: 'id = ?',
          whereArgs: [medication.id],
        );
      }
      await _enqueue(
        transaction,
        tableName: 'medications',
        recordId: medication.id,
        action: action,
        payload: medicationMap,
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
      orderBy: 'scheduled_time ASC, id ASC',
    );
    return rows.map(MedicationLog.fromMap).toList();
  }

  @override
  Future<void> saveLog(MedicationLog log) async {
    await _database.transaction((transaction) async {
      final existingRows = await transaction.query(
        'medication_logs',
        columns: const ['id'],
        where: 'id = ?',
        whereArgs: [log.id],
        limit: 1,
      );
      final action = existingRows.isEmpty
          ? SyncAction.insert
          : SyncAction.update;
      final logMap = log.toMap();

      if (existingRows.isEmpty) {
        await transaction.insert('medication_logs', logMap);
      } else {
        await transaction.update(
          'medication_logs',
          logMap,
          where: 'id = ?',
          whereArgs: [log.id],
        );
      }
      await _enqueue(
        transaction,
        tableName: 'medication_logs',
        recordId: log.id,
        action: action,
        payload: logMap,
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

    final medications = await getMedications();
    if (_medicationsController.isClosed) {
      return;
    }

    _medicationsController.add(medications);
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
