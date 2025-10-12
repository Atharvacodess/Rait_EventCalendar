import 'package:college_event_calendar/services/events/event_observer.dart';
import 'package:college_event_calendar/services/notifications/notification_scheduler.dart';
import 'package:college_event_calendar/models/event.dart';

class NotificationObserver implements EventObserver {
  final NotificationScheduler _scheduler = NotificationScheduler();

  @override
  Future<void> onEventChanged(EventModel event, EventAction action) async {
    print('NotificationObserver: Event ${action.name} - ${event.id}');

    try {
      switch (action) {
        case EventAction.created:
          await _handleEventCreated(event);
          break;
        case EventAction.updated:
          await _handleEventUpdated(event);
          break;
        case EventAction.deleted:
          await _handleEventDeleted(event);
          break;
      }
    } catch (e) {
      print('Failed to handle event ${action.name}: $e');
      rethrow;
    }
  }

  Future<void> _handleEventCreated(EventModel event) async {
    if (event.notificationsEnabled && event.reminderPolicy?.enabled == true) {
      await _scheduler.scheduleNotificationsForEvent(event);
      print('Scheduled notifications for new event: ${event.id}');
    }
  }

  Future<void> _handleEventUpdated(EventModel event) async {
    if (event.notificationsEnabled && event.reminderPolicy?.enabled == true) {
      await _scheduler.rescheduleNotificationsForEvent(event);
      print('Rescheduled notifications for updated event: ${event.id}');
    } else {
      // If notifications were disabled, cancel all scheduled notifications
      await _scheduler.cancelNotificationsForEvent(event.id!);
      print('Cancelled notifications for event: ${event.id}');
    }
  }

  Future<void> _handleEventDeleted(EventModel event) async {
    await _scheduler.cancelNotificationsForEvent(event.id!);
    print('Cancelled notifications for deleted event: ${event.id}');
  }
}