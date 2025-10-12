import 'package:college_event_calendar/services/notifications/strategies/reminder_strategy.dart';

class OneDayStrategy implements ReminderStrategy {
  @override
  DateTime calculateScheduleTime(DateTime eventDate) {
    return eventDate.subtract(const Duration(days: 1));
  }

  @override
  String getTimingLabel() => '1 day before';

  @override
  int getMinutesBeforeEvent() => 1440;
}