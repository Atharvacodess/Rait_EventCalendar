import 'package:college_event_calendar/services/notifications/strategies/reminder_strategy.dart';

class OneHourStrategy implements ReminderStrategy {
  @override
  DateTime calculateScheduleTime(DateTime eventDateUtc) {
    return eventDateUtc.toUtc().subtract(const Duration(hours: 1));
  }

  @override
  String getTimingLabel() => 'in 1 hour';

  @override
  int getMinutesBeforeEvent() => 60;
}
