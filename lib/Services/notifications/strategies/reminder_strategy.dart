abstract class ReminderStrategy {
  DateTime calculateScheduleTime(DateTime eventDate);
  String getTimingLabel();
  int getMinutesBeforeEvent();
}