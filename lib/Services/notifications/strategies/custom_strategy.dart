import 'package:college_event_calendar/services/notifications/strategies/reminder_strategy.dart';

class CustomStrategy implements ReminderStrategy {
  final int minutesBefore;

  CustomStrategy(this.minutesBefore);

  @override
  DateTime calculateScheduleTime(DateTime eventDate) {
    return eventDate.subtract(Duration(minutes: minutesBefore));
  }

  @override
  String getTimingLabel() {
    final hours = minutesBefore ~/ 60;
    final minutes = minutesBefore % 60;

    if (hours == 0) return '$minutes minutes before';
    if (minutes == 0) return '$hours hour${hours > 1 ? 's' : ''} before';
    return '${hours}h ${minutes}m before';
  }

  @override
  int getMinutesBeforeEvent() => minutesBefore;
}