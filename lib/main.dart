import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medication_reminder/app.dart';
import 'package:medication_reminder/core/notifications/local_notification_scheduler.dart';
import 'package:medication_reminder/core/storage/app_database.dart';
import 'package:medication_reminder/features/medications/application/medication_providers.dart';
import 'package:medication_reminder/features/medications/data/sqlite_medication_repository.dart';
import 'package:timezone/data/latest.dart' as tz;

export 'package:medication_reminder/app.dart' show MedicationReminderApp;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await LocalNotificationScheduler().initialize();

  final database = AppDatabase();
  final sqlite = await database.instance;

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        medicationRepositoryProvider.overrideWithValue(
          SqliteMedicationRepository(database: sqlite),
        ),
      ],
      child: const MedicationReminderApp(),
    ),
  );
}
