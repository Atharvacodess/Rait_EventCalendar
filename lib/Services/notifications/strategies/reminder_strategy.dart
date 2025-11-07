abstract class ReminderStrategy {
  /// eventDate will always be UTC
  DateTime calculateScheduleTime(DateTime eventDateUtc);

  /// Human-friendly label (ex: "in 15 minutes", "in 1 day")
  String getTimingLabel();

  /// Exact minutes before event (used for debugging & UI display)
  int getMinutesBeforeEvent();
}
