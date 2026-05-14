import 'dart:async';

import '../domain/medication.dart';
import '../domain/medication_log.dart';
import 'medication_repository.dart';

class InMemoryMedicationRepository implements MedicationRepository {
  final _medicationsById = <String, Medication>{};
  final _logsById = <String, MedicationLog>{};
  final _medicationsController = StreamController<List<Medication>>.broadcast();

  @override
  Stream<List<Medication>> watchMedications() {
    late StreamController<List<Medication>> controller;
    StreamSubscription<List<Medication>>? subscription;
    final queuedUpdates = <List<Medication>>[];
    var emittedInitialSnapshot = false;

    controller = StreamController<List<Medication>>(
      onListen: () async {
        subscription = _medicationsController.stream.listen(
          (medications) {
            if (controller.isClosed) {
              return;
            }

            if (emittedInitialSnapshot) {
              controller.add(medications);
            } else {
              queuedUpdates.add(medications);
            }
          },
          onError: controller.addError,
          onDone: controller.close,
        );

        try {
          final medications = await getMedications();
          if (controller.isClosed) {
            return;
          }

          controller.add(medications);
          emittedInitialSnapshot = true;

          for (final queuedUpdate in queuedUpdates) {
            if (controller.isClosed) {
              return;
            }
            controller.add(queuedUpdate);
          }
          queuedUpdates.clear();
        } catch (error, stackTrace) {
          if (!controller.isClosed) {
            controller.addError(error, stackTrace);
          }
        }
      },
      onCancel: () async {
        await subscription?.cancel();
      },
    );

    return controller.stream;
  }

  @override
  Future<List<Medication>> getMedications() async {
    return _sortedMedications();
  }

  @override
  Future<void> saveMedication(Medication medication) async {
    _medicationsById[medication.id] = medication;
    _notifyMedicationsChanged();
  }

  @override
  Future<void> deleteMedication(String medicationId) async {
    _medicationsById.remove(medicationId);
    _logsById.removeWhere((_, log) => log.medicationId == medicationId);
    _notifyMedicationsChanged();
  }

  @override
  Future<List<MedicationLog>> getLogsForDate(DateTime date) async {
    final logs = _logsById.values
        .where((log) => _sameDate(log.date, date))
        .toList();

    logs.sort((a, b) {
      final timeComparison = a.scheduledTime.compareTo(b.scheduledTime);
      if (timeComparison != 0) {
        return timeComparison;
      }

      return a.id.compareTo(b.id);
    });

    return logs;
  }

  @override
  Future<void> saveLog(MedicationLog log) async {
    _logsById[log.id] = log;
  }

  @override
  Future<void> deleteLog(String logId) async {
    _logsById.remove(logId);
  }

  Future<void> close() async {
    if (_medicationsController.isClosed) {
      return;
    }

    await _medicationsController.close();
  }

  List<Medication> _sortedMedications() {
    final medications = _medicationsById.values.toList();

    medications.sort((a, b) {
      final createdAtComparison = a.createdAt.compareTo(b.createdAt);
      if (createdAtComparison != 0) {
        return createdAtComparison;
      }

      return a.id.compareTo(b.id);
    });

    return medications;
  }

  void _notifyMedicationsChanged() {
    if (_medicationsController.isClosed) {
      return;
    }

    _medicationsController.add(_sortedMedications());
  }

  bool _sameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}
