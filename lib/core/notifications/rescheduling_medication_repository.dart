import 'package:medication_reminder/core/notifications/alarm_rescheduler.dart';
import 'package:medication_reminder/core/notifications/notification_scheduler.dart';
import 'package:medication_reminder/features/medications/data/medication_repository.dart';
import 'package:medication_reminder/features/medications/domain/medication.dart';
import 'package:medication_reminder/features/medications/domain/medication_log.dart';

class ReschedulingMedicationRepository implements MedicationRepository {
  ReschedulingMedicationRepository({
    required MedicationRepository delegate,
    required NotificationScheduler scheduler,
    DateTime Function()? now,
  }) : _delegate = delegate,
       _scheduler = scheduler,
       _now = now ?? DateTime.now;

  final MedicationRepository _delegate;
  final NotificationScheduler _scheduler;
  final DateTime Function() _now;

  @override
  Stream<List<Medication>> watchMedications() => _delegate.watchMedications();

  @override
  Future<List<Medication>> getMedications() => _delegate.getMedications();

  @override
  Future<void> saveMedication(Medication medication) async {
    await _delegate.saveMedication(medication);
    await rescheduleNotifications();
  }

  @override
  Future<void> deleteMedication(String medicationId) async {
    await _delegate.deleteMedication(medicationId);
    await rescheduleNotifications();
  }

  @override
  Future<List<MedicationLog>> getLogsForDate(DateTime date) {
    return _delegate.getLogsForDate(date);
  }

  @override
  Future<void> saveLog(MedicationLog log) {
    return _delegate.saveLog(log);
  }

  Future<void> rescheduleNotifications() async {
    try {
      final medications = await _delegate.getMedications();
      await AlarmRescheduler(
        _scheduler,
      ).rescheduleAll(medications: medications, from: _now());
    } catch (_) {
      // Medication data must remain usable even when Android notification
      // scheduling is unavailable or denied.
    }
  }
}
