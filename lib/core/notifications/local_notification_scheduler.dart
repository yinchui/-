import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:medication_reminder/core/notifications/notification_scheduler.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationScheduler implements NotificationScheduler {
  LocalNotificationScheduler({
    FlutterLocalNotificationsPlugin? plugin,
    void Function(String payload)? onNotificationTap,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _onNotificationTap = onNotificationTap;

  final FlutterLocalNotificationsPlugin _plugin;
  final void Function(String payload)? _onNotificationTap;

  @override
  Future<void> initialize() async {
    tz_data.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) {
          return;
        }
        _onNotificationTap?.call(payload);
      },
    );
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
  }

  Future<String?> takeLaunchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) {
      return null;
    }

    final payload = details?.notificationResponse?.payload;
    if (payload == null || payload.isEmpty) {
      return null;
    }

    return payload;
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
