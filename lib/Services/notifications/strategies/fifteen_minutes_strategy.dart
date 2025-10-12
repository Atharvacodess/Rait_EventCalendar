import 'package:college_event_calendar/services/notifications/strategies/reminder_strategy.dart';

class FifteenMinutesStrategy implements ReminderStrategy {
  @override
  DateTime calculateScheduleTime(DateTime eventDate) {
    return eventDate.subtract(const Duration(minutes: 15));
  }

  @override
  String getTimingLabel() => '15 minutes before';

  @override
  int getMinutesBeforeEvent() => 15;
}