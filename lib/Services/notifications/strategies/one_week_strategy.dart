import 'package:college_event_calendar/services/notifications/strategies/reminder_strategy.dart';

class OneWeekStrategy implements ReminderStrategy {
  @override
  DateTime calculateScheduleTime(DateTime eventDate) {
    return eventDate.subtract(const Duration(days: 7));
  }

  @override
  String getTimingLabel() => '1 week before';

  @override
  int getMinutesBeforeEvent() => 10080;
}