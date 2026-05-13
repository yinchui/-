import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/core/sync/sync_service.dart';
import 'package:medication_reminder/features/medications/data/in_memory_medication_repository.dart';
import 'package:medication_reminder/features/medications/data/syncing_medication_repository.dart';
import 'package:medication_reminder/features/medications/domain/medication.dart';
import 'package:medication_reminder/features/medications/domain/medication_log.dart';

void main() {
  test('pushes pending changes after local medication mutations', () async {
    final delegate = InMemoryMedicationRepository();
    addTearDown(delegate.close);
    final sync = FakeSyncService();
    final repository = SyncingMedicationRepository(
      delegate: delegate,
      syncService: sync,
    );
    final medication = _medication();

    await repository.saveMedication(medication);
    await repository.deleteMedication(medication.id);

    expect(sync.pushCount, 2);
  });

  test('keeps local save when cloud push fails', () async {
    final delegate = InMemoryMedicationRepository();
    addTearDown(delegate.close);
    final sync = FakeSyncService(throwOnPush: true);
    final repository = SyncingMedicationRepository(
      delegate: delegate,
      syncService: sync,
    );
    final medication = _medication();

    await repository.saveMedication(medication);

    expect(await repository.getMedications(), [medication]);
    expect(sync.pushCount, 1);
  });

  test('pushes pending changes after log mutations', () async {
    final delegate = InMemoryMedicationRepository();
    addTearDown(delegate.close);
    final sync = FakeSyncService();
    final repository = SyncingMedicationRepository(
      delegate: delegate,
      syncService: sync,
    );

    await repository.saveLog(_log());

    expect(sync.pushCount, 1);
  });
}

class FakeSyncService implements SyncService {
  FakeSyncService({this.throwOnPush = false});

  final bool throwOnPush;
  var pushCount = 0;

  @override
  Future<SyncResult> pushPendingChanges() async {
    pushCount += 1;
    if (throwOnPush) {
      throw StateError('offline');
    }
    return const SyncResult(pushed: 1, failed: 0);
  }

  @override
  Future<SyncResult> pullRemoteChanges() async {
    return const SyncResult(pushed: 0, failed: 0);
  }
}

Medication _medication() {
  return Medication(
    id: 'medication-1',
    userId: 'user-1',
    name: '维生素 D',
    dosage: '1片',
    schedule: const ['08:00'],
    createdAt: DateTime.utc(2026, 5, 13),
    updatedAt: DateTime.utc(2026, 5, 13),
  );
}

MedicationLog _log() {
  return MedicationLog(
    id: 'log-1',
    medicationId: 'medication-1',
    scheduledTime: DateTime.utc(2026, 5, 13, 8),
    confirmedTime: null,
    status: MedicationLogStatus.missed,
    date: DateTime(2026, 5, 13),
  );
}
