import 'package:college_event_calendar/services/notifications/strategies/reminder_strategy.dart';

class OneDayStrategy implements ReminderStrategy {
  @override
  DateTime calculateScheduleTime(DateTime eventDateUtc) {
    return eventDateUtc.toUtc().subtract(const Duration(days: 1));
  }

  @override
  String getTimingLabel() => 'in 1 day';

  @override
  int getMinutesBeforeEvent() => 1440; // 24 * 60
}
