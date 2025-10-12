import 'package:college_event_calendar/services/events/event_observer.dart';
import 'package:college_event_calendar/models/event.dart';

class EventSubject {
  final List<EventObserver> _observers = [];

  void addObserver(EventObserver observer) {
    if (!_observers.contains(observer)) {
      _observers.add(observer);
    }
  }

  void removeObserver(EventObserver observer) {
    _observers.remove(observer);
  }

  Future<void> notifyObservers(EventModel event, EventAction action) async {
    final futures = _observers.map((observer) async {
      try {
        await observer.onEventChanged(event, action);
      } catch (e) {
        print('Observer notification failed: $e');
      }
    });
    await Future.wait(futures);
  }
}