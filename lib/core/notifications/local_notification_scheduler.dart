import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:medication_reminder/core/notifications/notification_scheduler.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationScheduler implements NotificationScheduler {
  LocalNotificationScheduler({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> initialize() async {
    tz_data.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(settings: settings);
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
  }

  @override
  Future<void> schedule(ScheduledNotificationRequest request) {
    const androidDetails = AndroidNotificationDetails(
      'medication_reminders',
      '服药提醒',
      channelDescription: '定时提醒并要求确认服药',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    return _plugin.zonedSchedule(
      id: request.id,
      title: request.title,
      body: request.body,
      scheduledDate: tz.TZDateTime.from(request.scheduledAt, tz.local),
      notificationDetails: const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: request.payload,
    );
  }

  @override
  Future<void> cancelAll() {
    return _plugin.cancelAll();
  }
}
