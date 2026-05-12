import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/features/medications/domain/medication.dart';
import 'package:medication_reminder/features/medications/domain/medication_log.dart';
import 'package:medication_reminder/features/medications/domain/sync_queue_item.dart';

void main() {
  group('Medication', () {
    test('serializes schedule as JSON string and restores an equal model', () {
      final medication = Medication(
        id: 'm1',
        userId: 'u1',
        name: '阿莫西林',
        dosage: '2粒',
        schedule: const ['08:00', '12:00', '20:00'],
        createdAt: DateTime(2026, 5, 12, 7, 30),
        updatedAt: DateTime(2026, 5, 12, 8),
      );

      final map = medication.toMap();

      expect(map['schedule'], isA<String>());
      expect(jsonDecode(map['schedule']! as String), medication.schedule);
      expect(Medication.fromMap(map), medication);
    });
  });

  group('MedicationLog', () {
    test('serializes confirmed status and reports isConfirmed', () {
      final log = MedicationLog(
        id: 'l1',
        medicationId: 'm1',
        scheduledTime: DateTime(2026, 5, 12, 8),
        confirmedTime: DateTime(2026, 5, 12, 8, 3),
        status: MedicationLogStatus.confirmed,
        date: DateTime(2026, 5, 12),
      );

      final map = log.toMap();

      expect(map['status'], 'confirmed');
      expect(map['date'], '2026-05-12');
      expect(log.isConfirmed, isTrue);
      expect(MedicationLog.fromMap(map), log);
    });

    test('serializes missed status and reports not confirmed', () {
      final log = MedicationLog(
        id: 'l2',
        medicationId: 'm1',
        scheduledTime: DateTime(2026, 5, 12, 20),
        confirmedTime: null,
        status: MedicationLogStatus.missed,
        date: DateTime(2026, 5, 12),
      );

      final map = log.toMap();

      expect(map['status'], 'missed');
      expect(map['confirmed_time'], isNull);
      expect(log.isConfirmed, isFalse);
      expect(MedicationLog.fromMap(map), log);
    });
  });

  group('SyncQueueItem', () {
    test('serializes insert action, payload JSON, and synced false as 0', () {
      final item = SyncQueueItem(
        id: null,
        tableName: 'medications',
        recordId: 'm1',
        action: SyncAction.insert,
        payload: const {
          'name': '维生素D',
          'schedule': ['08:00'],
        },
        createdAt: DateTime(2026, 5, 12, 9),
        synced: false,
      );

      final map = item.toMap();

      expect(map['id'], isNull);
      expect(map['action'], 'insert');
      expect(map['payload'], isA<String>());
      expect(jsonDecode(map['payload']! as String), item.payload);
      expect(map['synced'], 0);
      expect(SyncQueueItem.fromMap(map), item);
    });

    test('serializes update and delete actions with synced true as 1', () {
      final updateItem = SyncQueueItem(
        id: 2,
        tableName: 'medications',
        recordId: 'm1',
        action: SyncAction.update,
        payload: const {'dosage': '1粒'},
        createdAt: DateTime(2026, 5, 12, 10),
        synced: true,
      );
      final deleteItem = updateItem.copyWith(
        id: 3,
        action: SyncAction.delete,
        payload: const {'id': 'm1'},
      );

      expect(updateItem.toMap()['action'], 'update');
      expect(updateItem.toMap()['synced'], 1);
      expect(SyncQueueItem.fromMap(updateItem.toMap()), updateItem);
      expect(deleteItem.toMap()['action'], 'delete');
      expect(SyncQueueItem.fromMap(deleteItem.toMap()), deleteItem);
    });
  });
}
