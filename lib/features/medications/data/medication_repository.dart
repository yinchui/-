import '../domain/medication.dart';
import '../domain/medication_log.dart';

abstract class MedicationRepository {
  Stream<List<Medication>> watchMedications();

  Future<List<Medication>> getMedications();

  Future<void> saveMedication(Medication medication);

  Future<void> deleteMedication(String medicationId);

  Future<List<MedicationLog>> getLogsForDate(DateTime date);

  Future<void> saveLog(MedicationLog log);

  Future<void> deleteLog(String logId);
}
