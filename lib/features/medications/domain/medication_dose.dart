import 'package:medication_reminder/features/medications/domain/medication.dart';
import 'package:medication_reminder/features/medications/domain/medication_log.dart';

enum DoseStatus { confirmed, missed, pending }

class MedicationDose {
  const MedicationDose({
    required this.medication,
    required this.scheduledTime,
    required this.status,
    required this.log,
    String? dosage,
  }) : _dosage = dosage;

  final Medication medication;
  final DateTime scheduledTime;
  final DoseStatus status;
  final MedicationLog? log;
  final String? _dosage;

  String get id => '${medication.id}-${scheduledTime.toIso8601String()}';
  String get dosage => _dosage ?? medication.dosage;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MedicationDose &&
            medication == other.medication &&
            scheduledTime == other.scheduledTime &&
            status == other.status &&
            log == other.log &&
            dosage == other.dosage;
  }

  @override
  int get hashCode =>
      Object.hash(medication, scheduledTime, status, log, dosage);
}
