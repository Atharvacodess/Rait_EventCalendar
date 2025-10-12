import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../models/event.dart';
import '../models/notifications/reminder_policy.dart';
import '../services/notifications/notification_scheduler.dart';

class AddEventDialog extends StatefulWidget {
  final DateTime selectedDate;
  final VoidCallback onEventAdded;

  const AddEventDialog({
    super.key,
    required this.selectedDate,
    required this.onEventAdded,
  });

  @override
  State<AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<AddEventDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _timeController = TextEditingController();
  final _venueController = TextEditingController();
  final _organizerController = TextEditingController();
  final _customMinutesController = TextEditingController(text: '60');

  String _selectedEventType = 'academic';
  List<String> _selectedAudience = [];
  bool _isLoading = false;

  // Notification fields
  bool _notificationsEnabled = false;
  Set<ReminderTiming> _selectedTimings = {};
  Set<NotificationChannel> _selectedChannels = {NotificationChannel.push};

  final List<String> _eventTypes = [
    'academic',
    'cultural',
    'sports',
    'workshop',
    'seminar',
    'meeting',
    'other'
  ];

  final List<String> _audienceOptions = [
    'All Students',
    'First Year',
    'Second Year',
    'Third Year',
    'Final Year',
    'Faculty',
    'Staff',
    'Alumni'
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _timeController.dispose();
    _venueController.dispose();
    _organizerController.dispose();
    _customMinutesController.dispose();
    super.dispose();
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        _timeController.text = picked.format(context);
      });
    }
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAudience.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select target audience')),
      );
      return;
    }

    // Validate notification settings
    if (_notificationsEnabled) {
      if (_selectedTimings.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one reminder timing')),
        );
        return;
      }
      if (_selectedChannels.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one notification channel')),
        );
        return;
      }
      if (_selectedTimings.contains(ReminderTiming.custom)) {
        final customMinutes = int.tryParse(_customMinutesController.text);
        if (customMinutes == null || customMinutes <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter valid custom minutes')),
          );
          return;
        }
      }
    }

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final firestore = FirebaseFirestore.instance;

      // Create the event first
      final eventRef = await firestore.collection('events').add({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'date': Timestamp.fromDate(widget.selectedDate),
        'time': _timeController.text.trim(),
        'venue': _venueController.text.trim(),
        'organizer': _organizerController.text.trim(),
        'targetAudience': _selectedAudience,
        'eventType': _selectedEventType,
        'createdBy': authService.currentUser!.uid,
        'createdByName': authService.userName ?? 'Admin',
        'createdAt': FieldValue.serverTimestamp(),
        'notificationsEnabled': _notificationsEnabled,
      });

      ReminderPolicy? createdPolicy;

      // Create reminder policy if notifications are enabled
      if (_notificationsEnabled) {
        final customMinutes = _selectedTimings.contains(ReminderTiming.custom)
            ? int.tryParse(_customMinutesController.text)
            : null;

        final policyRef = await firestore.collection('reminder_policies').add({
          'eventId': eventRef.id,
          'timings': _selectedTimings.map((e) => e.value).toList(),
          'customMinutes': customMinutes,
          'enabled': true,
          'channels': _selectedChannels.map((e) => e.value).toList(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Update event with policy reference
        await eventRef.update({'reminderPolicyId': policyRef.id});

        // Fetch the created policy
        final policyDoc = await policyRef.get();
        createdPolicy = ReminderPolicy.fromFirestore(policyDoc);
      }

      // Schedule notifications if enabled
      if (_notificationsEnabled && createdPolicy != null) {
        final eventDoc = await eventRef.get();
        final event = EventModel.fromFirestore(eventDoc);
        final eventWithPolicy = event.copyWith(reminderPolicy: createdPolicy);

        // Schedule the notifications
        final scheduler = NotificationScheduler();
        await scheduler.scheduleNotificationsForEvent(eventWithPolicy);

        print('✅ Notifications scheduled for event ${event.id}');
      }

      widget.onEventAdded();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _notificationsEnabled
                  ? 'Event created with reminders!'
                  : 'Event created successfully!',
            ),
          ),
        );
      }
    } catch (e) {
      print('Error creating event: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating event: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Add Event',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(
              'Date: ${widget.selectedDate.day}/${widget.selectedDate.month}/${widget.selectedDate.year}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),

            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Title
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Event Title *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter event title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description *',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter event description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Time
                      TextFormField(
                        controller: _timeController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Time *',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed: _selectTime,
                            icon: const Icon(Icons.access_time),
                          ),
                        ),
                        onTap: _selectTime,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please select event time';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Venue
                      TextFormField(
                        controller: _venueController,
                        decoration: const InputDecoration(
                          labelText: 'Venue *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter venue';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Organizer
                      TextFormField(
                        controller: _organizerController,
                        decoration: const InputDecoration(
                          labelText: 'Organizer',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Event Type
                      DropdownButtonFormField<String>(
                        value: _selectedEventType,
                        decoration: const InputDecoration(
                          labelText: 'Event Type',
                          border: OutlineInputBorder(),
                        ),
                        items: _eventTypes.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedEventType = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Target Audience
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Target Audience *',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              children: _audienceOptions.map((audience) {
                                return CheckboxListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  value: _selectedAudience.contains(audience),
                                  title: Text(audience),
                                  onChanged: (bool? selected) {
                                    setState(() {
                                      if (selected == true) {
                                        _selectedAudience.add(audience);
                                      } else {
                                        _selectedAudience.remove(audience);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Notification Settings
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blue.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.blue.withOpacity(0.05),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.notifications_active, color: Colors.blue),
                                const SizedBox(width: 8),
                                const Text(
                                  'Event Reminders',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                Switch(
                                  value: _notificationsEnabled,
                                  onChanged: (value) {
                                    setState(() => _notificationsEnabled = value);
                                  },
                                ),
                              ],
                            ),
                            if (_notificationsEnabled) ...[
                              const Divider(height: 24),
                              const Text(
                                'When to send reminders:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...ReminderTiming.values.map((timing) {
                                return CheckboxListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  value: _selectedTimings.contains(timing),
                                  title: Text(timing.label),
                                  onChanged: (bool? selected) {
                                    setState(() {
                                      if (selected == true) {
                                        _selectedTimings.add(timing);
                                      } else {
                                        _selectedTimings.remove(timing);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                              if (_selectedTimings.contains(ReminderTiming.custom))
                                Padding(
                                  padding: const EdgeInsets.only(left: 16, top: 8),
                                  child: TextFormField(
                                    controller: _customMinutesController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Minutes before event',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 16),
                              const Text(
                                'Notification channels:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...NotificationChannel.values.map((channel) {
                                return CheckboxListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  value: _selectedChannels.contains(channel),
                                  title: Text(channel.label),
                                  onChanged: (bool? selected) {
                                    setState(() {
                                      if (selected == true) {
                                        _selectedChannels.add(channel);
                                      } else {
                                        _selectedChannels.remove(channel);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveEvent,
                  child: _isLoading
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Create Event'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}