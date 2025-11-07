import 'package:college_event_calendar/services/notifications/strategies/reminder_strategy.dart';

class OneWeekStrategy implements ReminderStrategy {
  @override
  DateTime calculateScheduleTime(DateTime eventDateUtc) {
    return eventDateUtc.toUtc().subtract(const Duration(days: 7));
  }

  @override
  String getTimingLabel() => 'in 1 week';

  @override
  int getMinutesBeforeEvent() => 10080; // 7 * 24 * 60
}
