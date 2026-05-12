import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/medication_repository.dart';
import '../domain/medication.dart';
import 'medication_providers.dart';

final saveMedicationControllerProvider = Provider<SaveMedicationController>((
  ref,
) {
  return SaveMedicationController(
    repository: ref.watch(medicationRepositoryProvider),
    now: () => ref.read(nowProvider).toUtc(),
  );
});

class SaveMedicationController {
  SaveMedicationController({
    required MedicationRepository repository,
    DateTime Function()? now,
    Uuid? uuid,
  }) : _repository = repository,
       _now = now ?? (() => DateTime.now().toUtc()),
       _uuid = uuid ?? const Uuid();

  final MedicationRepository _repository;
  final DateTime Function() _now;
  final Uuid _uuid;

  Future<void> save({
    required String name,
    required String dosage,
    required String scheduleInput,
  }) async {
    final trimmedName = name.trim();
    final trimmedDosage = dosage.trim();

    if (trimmedName.isEmpty) {
      throw ArgumentError('药名不能为空');
    }
    if (trimmedDosage.isEmpty) {
      throw ArgumentError('剂量不能为空');
    }

    final schedule = _parseSchedule(scheduleInput);
    final now = _now().toUtc();

    await _repository.saveMedication(
      Medication(
        id: _uuid.v4(),
        userId: 'local',
        name: trimmedName,
        dosage: trimmedDosage,
        schedule: schedule,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  List<String> _parseSchedule(String input) {
    final parts = input.split(',').map((part) => part.trim()).toList();
    if (parts.isEmpty || parts.every((part) => part.isEmpty)) {
      throw ArgumentError('服用时间不能为空');
    }

    final schedule = <String>{};
    for (final part in parts) {
      if (!_isValidTime(part)) {
        throw ArgumentError('服用时间需使用 HH:mm 格式');
      }
      schedule.add(part);
    }

    final sortedSchedule = schedule.toList()..sort();
    return sortedSchedule;
  }

  bool _isValidTime(String value) {
    final match = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(value);
    return match != null;
  }
}
