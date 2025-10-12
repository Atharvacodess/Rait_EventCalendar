import 'package:college_event_calendar/models/event.dart';

enum EventAction {
  created,
  updated,
  deleted,
}

abstract class EventObserver {
  Future<void> onEventChanged(EventModel event, EventAction action);
}