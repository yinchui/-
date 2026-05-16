import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medication_reminder/core/storage/app_database.dart';

import '../data/in_memory_medication_repository.dart';
import '../data/medication_repository.dart';
import '../domain/medication.dart';
import '../domain/medication_dose.dart';
import 'schedule_service.dart';

final medicationRepositoryProvider = Provider<MedicationRepository>((ref) {
  final repository = InMemoryMedicationRepository();
  ref.onDispose(repository.close);
  return repository;
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

final sqliteDatabaseProvider = FutureProvider((ref) async {
  final database = ref.watch(appDatabaseProvider);
  ref.onDispose(() {
    database.close();
  });
  return database.instance;
});

final scheduleServiceProvider = Provider<ScheduleService>((ref) {
  return ScheduleService();
});

final systemClockProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

final clockTickProvider = StreamProvider<DateTime>((ref) {
  final clock = ref.watch(systemClockProvider);
  return Stream<DateTime>.periodic(const Duration(minutes: 1), (_) => clock());
});

final nowProvider = Provider<DateTime>((ref) {
  final tick = ref.watch(clockTickProvider);
  return switch (tick) {
    AsyncData(:final value) => value,
    _ => ref.watch(systemClockProvider)(),
  };
});

const localUserId = '00000000-0000-4000-8000-000000000000';

final currentUserIdProvider = Provider<String>((ref) {
  return localUserId;
});

final todayProvider = Provider<DateTime>((ref) {
  final now = ref.watch(nowProvider);
  return DateTime(now.year, now.month, now.day);
});

final medicationsProvider = StreamProvider<List<Medication>>((ref) {
  final repository = ref.watch(medicationRepositoryProvider);
  return repository.watchMedications();
});

final todayDosesProvider = FutureProvider<List<MedicationDose>>((ref) async {
  final repository = ref.watch(medicationRepositoryProvider);
  final medications = switch (ref.watch(medicationsProvider)) {
    AsyncData(:final value) => value,
    AsyncError(:final error, :final stackTrace) => Error.throwWithStackTrace(
      error,
      stackTrace,
    ),
    _ => await repository.getMedications(),
  };
  final today = ref.watch(todayProvider);
  final now = ref.watch(nowProvider);
  final logs = await repository.getLogsForDate(today);
  final scheduleService = ref.watch(scheduleServiceProvider);

  return scheduleService.buildDosesForDate(
    medications: medications,
    logs: logs,
    date: today,
    now: now,
  );
});
