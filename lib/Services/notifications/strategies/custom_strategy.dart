import 'package:college_event_calendar/services/notifications/strategies/reminder_strategy.dart';

class CustomStrategy implements ReminderStrategy {
  final int minutesBefore;

  CustomStrategy(this.minutesBefore);

  @override
  DateTime calculateScheduleTime(DateTime eventDate) {
    return eventDate.toUtc().subtract(Duration(minutes: minutesBefore));
  }

  @override
  String getTimingLabel() {
    final hours = minutesBefore ~/ 60;
    final minutes = minutesBefore % 60;

    // PURE "in X" STYLE (no "before")
    if (hours == 0) return 'in $minutes minute${minutes == 1 ? '' : 's'}';
    if (minutes == 0) return 'in $hours hour${hours == 1 ? '' : 's'}';
    return 'in $hours hour${hours == 1 ? '' : 's'} and $minutes minute${minutes == 1 ? '' : 's'}';
  }

  @override
  int getMinutesBeforeEvent() => minutesBefore;
}
