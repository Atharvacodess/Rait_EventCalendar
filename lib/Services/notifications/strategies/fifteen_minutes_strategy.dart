import 'package:college_event_calendar/services/notifications/strategies/reminder_strategy.dart';

class FifteenMinutesStrategy implements ReminderStrategy {
  @override
  DateTime calculateScheduleTime(DateTime eventDateUtc) {
    return eventDateUtc.toUtc().subtract(const Duration(minutes: 15));
  }

  @override
  String getTimingLabel() => 'in 15 minutes';

  @override
  int getMinutesBeforeEvent() => 15;
}
