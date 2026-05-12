import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medication_reminder/features/medications/application/medication_providers.dart';
import 'package:medication_reminder/features/medications/data/medication_repository.dart';
import 'package:medication_reminder/features/medications/domain/medication_dose.dart';
import 'package:medication_reminder/features/medications/domain/medication_log.dart';
import 'package:uuid/uuid.dart';

final confirmDoseControllerProvider = Provider<ConfirmDoseController>((ref) {
  return ConfirmDoseController(
    repository: ref.watch(medicationRepositoryProvider),
    now: () => ref.read(nowProvider).toUtc(),
    onSaved: () => ref.invalidate(todayDosesProvider),
  );
});

class ConfirmDoseController {
  ConfirmDoseController({
    required MedicationRepository repository,
    required DateTime Function() now,
    required void Function() onSaved,
    Uuid? uuid,
  }) : _repository = repository,
       _now = now,
       _onSaved = onSaved,
       _uuid = uuid ?? const Uuid();

  final MedicationRepository _repository;
  final DateTime Function() _now;
  final void Function() _onSaved;
  final Uuid _uuid;

  Future<void> confirm(List<MedicationDose> doses) async {
    final confirmedAt = _now().toUtc();

    for (final dose in doses) {
      await _repository.saveLog(_confirmedLog(dose, confirmedAt));
    }

    _onSaved();
  }

  MedicationLog _confirmedLog(MedicationDose dose, DateTime confirmedAt) {
    final existingLog = dose.log;
    if (existingLog != null) {
      return existingLog.copyWith(
        confirmedTime: confirmedAt,
        status: MedicationLogStatus.confirmed,
      );
    }

    final scheduledTime = dose.scheduledTime;
    return MedicationLog(
      id: _uuid.v4(),
      medicationId: dose.medication.id,
      scheduledTime: scheduledTime,
      confirmedTime: confirmedAt,
      status: MedicationLogStatus.confirmed,
      date: DateTime(
        scheduledTime.year,
        scheduledTime.month,
        scheduledTime.day,
      ),
    );
  }
}
