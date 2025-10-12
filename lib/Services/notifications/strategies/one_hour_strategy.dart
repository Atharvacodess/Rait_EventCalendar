import 'package:college_event_calendar/services/notifications/strategies/reminder_strategy.dart';

class OneHourStrategy implements ReminderStrategy {
  @override
  DateTime calculateScheduleTime(DateTime eventDate) {
    return eventDate.subtract(const Duration(hours: 1));
  }

  @override
  String getTimingLabel() => '1 hour before';

  @override
  int getMinutesBeforeEvent() => 60;
}