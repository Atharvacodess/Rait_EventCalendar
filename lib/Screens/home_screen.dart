import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../models/event.dart';
import 'add_event_dialog.dart';
import 'edit_event_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ValueNotifier<List<EventModel>> _selectedEvents;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<EventModel>> _events = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
    _loadEvents();
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('events')
          .orderBy('date')
          .get();

      final Map<DateTime, List<EventModel>> events = {};

      for (var doc in snapshot.docs) {
        if (doc.id != 'test') { // Skip our test document
          final event = EventModel.fromFirestore(doc);
          final eventDate = DateTime(event.date.year, event.date.month, event.date.day);

          if (events[eventDate] != null) {
            events[eventDate]!.add(event);
          } else {
            events[eventDate] = [event];
          }
        }
      }

      setState(() {
        _events = events;
        _selectedEvents.value = _getEventsForDay(_selectedDay!);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading events: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading events: $e')),
      );
    }
  }

  List<EventModel> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });

      _selectedEvents.value = _getEventsForDay(selectedDay);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('College Event Calendar'),
            centerTitle: true,
            actions: [
              // User info and logout
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'logout') {
                    await authService.signOut();
                    Navigator.of(context).pushReplacementNamed('/login');
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authService.userName ?? 'User',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          authService.userRole?.toUpperCase() ?? 'STUDENT',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 20),
                        SizedBox(width: 8),
                        Text('Logout'),
                      ],
                    ),
                  ),
                ],
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.blue,
                        child: Text(
                          (authService.userName ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
            children: [
              // Calendar Widget
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TableCalendar<EventModel>(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  eventLoader: _getEventsForDay,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  calendarStyle: const CalendarStyle(
                    outsideDaysVisible: false,
                    weekendTextStyle: TextStyle(color: Colors.red),
                    holidayTextStyle: TextStyle(color: Colors.red),
                    selectedDecoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    markersMaxCount: 3,
                    markerDecoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  onDaySelected: _onDaySelected,
                  onFormatChanged: (format) {
                    if (_calendarFormat != format) {
                      setState(() => _calendarFormat = format);
                    }
                  },
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                  },
                ),
              ),

              const SizedBox(height: 8.0),

              // Events for selected day
              Expanded(
                child: ValueListenableBuilder<List<EventModel>>(
                  valueListenable: _selectedEvents,
                  builder: (context, value, _) {
                    return Column(
                      children: [
                        // Header with date and add button
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Events for ${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              // Only show add button for HODs and Principals
                              if (authService.canManageEvents())
                                FloatingActionButton.small(
                                  heroTag: "addEvent",
                                  onPressed: () => _showAddEventDialog(context),
                                  child: const Icon(Icons.add),
                                ),
                            ],
                          ),
                        ),

                        // Events list
                        Expanded(
                          child: value.isEmpty
                              ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.event_busy,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No events scheduled',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                if (authService.canManageEvents()) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap + to add an event',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          )
                              : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: value.length,
                            itemBuilder: (context, index) {
                              final event = value[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _getEventTypeColor(event.eventType),
                                    child: Icon(
                                      _getEventTypeIcon(event.eventType),
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    event.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(event.time),
                                      Text('Venue: ${event.venue}'),
                                      if (event.organizer.isNotEmpty)
                                        Text('By: ${event.organizer}'),
                                    ],
                                  ),
                                  trailing: authService.canManageEvents()
                                      ? PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        _showEditEventDialog(context, event);
                                      } else if (value == 'delete') {
                                        _deleteEvent(event.id!);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit, size: 20),
                                            SizedBox(width: 8),
                                            Text('Edit'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete, size: 20, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Delete', style: TextStyle(color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  )
                                      : null,
                                  onTap: () => _showEventDetails(context, event),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getEventTypeColor(String eventType) {
    switch (eventType.toLowerCase()) {
      case 'academic':
        return Colors.blue;
      case 'cultural':
        return Colors.purple;
      case 'sports':
        return Colors.green;
      case 'workshop':
        return Colors.orange;
      case 'seminar':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  IconData _getEventTypeIcon(String eventType) {
    switch (eventType.toLowerCase()) {
      case 'academic':
        return Icons.school;
      case 'cultural':
        return Icons.palette;
      case 'sports':
        return Icons.sports;
      case 'workshop':
        return Icons.build;
      case 'seminar':
        return Icons.present_to_all;
      default:
        return Icons.event;
    }
  }

  void _showEventDetails(BuildContext context, EventModel event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(event.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Description', event.description),
              _buildDetailRow('Date', event.formattedDate),
              _buildDetailRow('Time', event.time),
              _buildDetailRow('Venue', event.venue),
              _buildDetailRow('Organizer', event.organizer),
              _buildDetailRow('Event Type', event.eventType.toUpperCase()),
              _buildDetailRow('Target Audience', event.targetAudience.join(', ')),
              _buildDetailRow('Created by', event.createdByName),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          Text(value.isEmpty ? 'Not specified' : value),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  void _showAddEventDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AddEventDialog(
        selectedDate: _selectedDay!,
        onEventAdded: _loadEvents,
      ),
    );
  }

  void _showEditEventDialog(BuildContext context, EventModel event) {
    showDialog(
      context: context,
      builder: (context) => EditEventDialog(
        event: event,
        onEventUpdated: _loadEvents,
      ),
    );
  }

  Future<void> _deleteEvent(String eventId) async {
    try {
      await FirebaseFirestore.instance.collection('events').doc(eventId).delete();
      _loadEvents(); // Refresh events
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting event: $e')),
      );
    }
  }
}