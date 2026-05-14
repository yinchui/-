import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medication_reminder/app.dart';
import 'package:medication_reminder/core/navigation/app_navigator.dart';
import 'package:medication_reminder/core/notifications/local_notification_scheduler.dart';
import 'package:medication_reminder/core/notifications/notification_tap_handler.dart';
import 'package:medication_reminder/core/notifications/rescheduling_medication_repository.dart';
import 'package:medication_reminder/core/storage/app_database.dart';
import 'package:medication_reminder/core/sync/cloud_sync_config.dart';
import 'package:medication_reminder/core/sync/supabase_sync_service.dart';
import 'package:medication_reminder/features/medications/application/medication_providers.dart';
import 'package:medication_reminder/features/medications/data/medication_repository.dart';
import 'package:medication_reminder/features/medications/data/sqlite_medication_repository.dart';
import 'package:medication_reminder/features/medications/data/syncing_medication_repository.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;

export 'package:medication_reminder/app.dart' show MedicationReminderApp;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  final pendingNotificationPayloads = <String>[];
  NotificationTapHandler? notificationTapHandler;
  void handleNotificationPayload(String payload) {
    final handler = notificationTapHandler;
    if (handler == null) {
      pendingNotificationPayloads.add(payload);
      return;
    }
    unawaited(handler.handle(payload));
  }

  final notificationScheduler = LocalNotificationScheduler(
    onNotificationTap: handleNotificationPayload,
  );
  await notificationScheduler.initialize();
  final launchPayload = await notificationScheduler.takeLaunchPayload();

  final database = AppDatabase();
  final sqlite = await database.instance;
  final sqliteRepository = SqliteMedicationRepository(database: sqlite);
  final repository = await _buildMedicationRepository(
    sqliteRepository: sqliteRepository,
    sqlite: sqlite,
  );
  final reschedulingRepository = ReschedulingMedicationRepository(
    delegate: repository,
    scheduler: notificationScheduler,
  );
  await reschedulingRepository.rescheduleNotifications();
  notificationTapHandler = NotificationTapHandler(
    repository: reschedulingRepository,
    navigatorKey: appNavigatorKey,
  );

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        medicationRepositoryProvider.overrideWithValue(reschedulingRepository),
      ],
      child: const MedicationReminderApp(),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (launchPayload != null) {
      handleNotificationPayload(launchPayload);
    }
    for (final payload in pendingNotificationPayloads.toList()) {
      handleNotificationPayload(payload);
    }
    pendingNotificationPayloads.clear();
  });
}

Future<MedicationRepository> _buildMedicationRepository({
  required SqliteMedicationRepository sqliteRepository,
  required Database sqlite,
}) async {
  final config = CloudSyncConfig.fromEnvironment();
  if (!config.isConfigured) {
    return sqliteRepository;
  }

  try {
    await Supabase.initialize(url: config.url, anonKey: config.anonKey);
    final syncService = SupabaseSyncService(
      database: sqlite,
      client: Supabase.instance.client,
      userId: localUserId,
    );
    await syncService.pushLocalSnapshot();
    await syncService.pushPendingChanges();
    await syncService.pullRemoteChanges();
    return SyncingMedicationRepository(
      delegate: sqliteRepository,
      syncService: syncService,
    );
  } catch (_) {
    return sqliteRepository;
  }
}
