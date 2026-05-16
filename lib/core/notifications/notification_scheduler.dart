class ScheduledNotificationRequest {
  const ScheduledNotificationRequest({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledAt,
    required this.payload,
    this.repeat = NotificationRepeat.none,
  });

  final int id;
  final String title;
  final String body;
  final DateTime scheduledAt;
  final String payload;
  final NotificationRepeat repeat;
}

enum NotificationRepeat { none, daily }

abstract class NotificationScheduler {
  Future<void> initialize();

  Future<void> schedule(ScheduledNotificationRequest request);

  Future<void> cancelAll();
}
