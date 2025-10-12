import 'package:college_event_calendar/services/notifications/strategies/reminder_strategy.dart';

class ThreeDaysStrategy implements ReminderStrategy {
  @override
  DateTime calculateScheduleTime(DateTime eventDate) {
    return eventDate.subtract(const Duration(days: 3));
  }

  @override
  String getTimingLabel() => '3 days before';

  @override
  int getMinutesBeforeEvent() => 4320;
}