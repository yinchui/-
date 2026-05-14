import 'package:flutter/material.dart';
import 'package:medication_reminder/features/confirm/presentation/confirm_medication_page.dart';
import 'package:medication_reminder/features/medications/application/schedule_service.dart';
import 'package:medication_reminder/features/medications/data/medication_repository.dart';
import 'package:medication_reminder/features/medications/domain/medication_dose.dart';

class NotificationTapHandler {
  NotificationTapHandler({
    required MedicationRepository repository,
    required GlobalKey<NavigatorState> navigatorKey,
    DateTime Function()? now,
    ScheduleService? scheduleService,
  }) : _repository = repository,
       _navigatorKey = navigatorKey,
       _now = now ?? DateTime.now,
       _scheduleService = scheduleService ?? ScheduleService();

  final MedicationRepository _repository;
  final GlobalKey<NavigatorState> _navigatorKey;
  final DateTime Function() _now;
  final ScheduleService _scheduleService;

  Future<void> handle(String payload) async {
    final target = _NotificationPayload.parse(payload, now: _now());
    if (target == null) {
      return;
    }

    final medications = await _repository.getMedications();
    final logs = await _repository.getLogsForDate(target.date);
    final doses = _scheduleService.buildDosesForDate(
      medications: medications,
      logs: logs,
      date: target.date,
      now: _now(),
    );
    final dose = _matchingDose(doses, target);
    if (dose == null) {
      return;
    }

    _navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (context) => ConfirmMedicationPage(doses: [dose]),
      ),
    );
  }

  MedicationDose? _matchingDose(
    List<MedicationDose> doses,
    _NotificationPayload target,
  ) {
    for (final dose in doses) {
      if (dose.medication.id != target.medicationId) {
        continue;
      }
      if (dose.scheduledTime.hour != target.hour ||
          dose.scheduledTime.minute != target.minute) {
        continue;
      }
      if (!_sameDate(dose.scheduledTime, target.date)) {
        continue;
      }
      return dose;
    }

    return null;
  }

  bool _sameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}

class _NotificationPayload {
  const _NotificationPayload({
    required this.medicationId,
    required this.date,
    required this.hour,
    required this.minute,
  });

  final String medicationId;
  final DateTime date;
  final int hour;
  final int minute;

  static _NotificationPayload? parse(String payload, {required DateTime now}) {
    final datedMatch = RegExp(
      r'^medication:([^:]+):(\d{4}-\d{2}-\d{2}):(\d{2}:\d{2})$',
    ).firstMatch(payload);
    final rollingMatch = RegExp(
      r'^medication:([^:]+):(\d{2}:\d{2})$',
    ).firstMatch(payload);
    if (datedMatch == null && rollingMatch == null) {
      return null;
    }

    final medicationId = datedMatch?.group(1) ?? rollingMatch!.group(1)!;
    final date = datedMatch == null
        ? DateTime(now.year, now.month, now.day)
        : DateTime.tryParse(datedMatch.group(2)!);
    final time = datedMatch?.group(3) ?? rollingMatch!.group(2)!;
    final timeParts = time.split(':');
    if (date == null || timeParts.length != 2) {
      return null;
    }

    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }

    return _NotificationPayload(
      medicationId: medicationId,
      date: DateTime(date.year, date.month, date.day),
      hour: hour,
      minute: minute,
    );
  }
}
