import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/medication_repository.dart';
import '../domain/medication.dart';
import '../domain/medication_daily_plan.dart';
import 'medication_providers.dart';

final saveMedicationControllerProvider = Provider<SaveMedicationController>((
  ref,
) {
  return SaveMedicationController(
    repository: ref.watch(medicationRepositoryProvider),
    userId: ref.watch(currentUserIdProvider),
    now: () => ref.read(nowProvider).toUtc(),
  );
});

class SaveMedicationController {
  SaveMedicationController({
    required MedicationRepository repository,
    required String userId,
    DateTime Function()? now,
    Uuid? uuid,
  }) : _repository = repository,
       _userId = userId,
       _now = now ?? (() => DateTime.now().toUtc()),
       _uuid = uuid ?? const Uuid();

  final MedicationRepository _repository;
  final String _userId;
  final DateTime Function() _now;
  final Uuid _uuid;

  Future<void> save({
    required String name,
    required String dosage,
    required String scheduleInput,
    DateTime? startDate,
    int? durationDays,
    List<String>? weeklyDosages,
    Map<int, String>? dailyDosageOverrides,
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
    final dailyPlans = _buildDailyPlans(
      startDate: startDate,
      durationDays: durationDays,
      weeklyDosages: weeklyDosages,
      dailyDosageOverrides: dailyDosageOverrides ?? const {},
      schedule: schedule,
    );
    final now = _now().toUtc();
    final effectiveDosage = dailyPlans.isEmpty
        ? trimmedDosage
        : dailyPlans.first.dosage;

    await _repository.saveMedication(
      Medication(
        id: _uuid.v4(),
        userId: _userId,
        name: trimmedName,
        dosage: effectiveDosage,
        schedule: schedule,
        startDate: dailyPlans.isEmpty ? null : dailyPlans.first.date,
        durationDays: dailyPlans.isEmpty ? null : dailyPlans.length,
        dailyPlans: dailyPlans,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  List<String> _parseSchedule(String input) {
    final parts = input
        .replaceAll('，', ',')
        .split(',')
        .map((part) => part.trim())
        .toList();
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

  List<MedicationDailyPlan> _buildDailyPlans({
    required DateTime? startDate,
    required int? durationDays,
    required List<String>? weeklyDosages,
    required Map<int, String> dailyDosageOverrides,
    required List<String> schedule,
  }) {
    if (startDate == null && durationDays == null && weeklyDosages == null) {
      return const [];
    }

    if (startDate == null || durationDays == null || weeklyDosages == null) {
      throw ArgumentError('疗程开始日期、服用天数和每周剂量都不能为空');
    }
    if (durationDays < 1 || durationDays > 366) {
      throw ArgumentError('服用天数需介于 1 到 366 天');
    }
    if (weeklyDosages.length != 7) {
      throw ArgumentError('每周剂量需要填写周一到周日 7 天');
    }

    final dateOnly = DateTime(startDate.year, startDate.month, startDate.day);
    final plans = <MedicationDailyPlan>[];

    for (var index = 0; index < durationDays; index += 1) {
      final date = dateOnly.add(Duration(days: index));
      final dayIndex = index + 1;
      final templateDosage = weeklyDosages[date.weekday - 1].trim();
      final overrideDosage = dailyDosageOverrides[dayIndex]?.trim();
      final dosage = overrideDosage ?? templateDosage;

      if (dosage.isEmpty) {
        throw ArgumentError('每日剂量不能为空');
      }

      plans.add(
        MedicationDailyPlan(
          date: date,
          dayIndex: dayIndex,
          dosage: dosage,
          schedule: schedule,
        ),
      );
    }

    return plans;
  }

  bool _isValidTime(String value) {
    final match = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(value);
    return match != null;
  }
}
