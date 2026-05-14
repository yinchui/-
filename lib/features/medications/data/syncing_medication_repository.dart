import 'package:medication_reminder/core/sync/sync_service.dart';

import '../domain/medication.dart';
import '../domain/medication_log.dart';
import 'medication_repository.dart';

class SyncingMedicationRepository implements MedicationRepository {
  SyncingMedicationRepository({
    required MedicationRepository delegate,
    required SyncService syncService,
  }) : _delegate = delegate,
       _syncService = syncService;

  final MedicationRepository _delegate;
  final SyncService _syncService;

  @override
  Stream<List<Medication>> watchMedications() => _delegate.watchMedications();

  @override
  Future<List<Medication>> getMedications() => _delegate.getMedications();

  @override
  Future<void> saveMedication(Medication medication) async {
    await _delegate.saveMedication(medication);
    await _tryPush();
  }

  @override
  Future<void> deleteMedication(String medicationId) async {
    await _delegate.deleteMedication(medicationId);
    await _tryPush();
  }

  @override
  Future<List<MedicationLog>> getLogsForDate(DateTime date) {
    return _delegate.getLogsForDate(date);
  }

  @override
  Future<void> saveLog(MedicationLog log) async {
    await _delegate.saveLog(log);
    await _tryPush();
  }

  @override
  Future<void> deleteLog(String logId) async {
    await _delegate.deleteLog(logId);
    await _tryPush();
  }

  Future<void> _tryPush() async {
    try {
      await _syncService.pushPendingChanges();
    } catch (_) {
      // SQLite remains usable when the cloud endpoint is unavailable.
    }
  }
}
