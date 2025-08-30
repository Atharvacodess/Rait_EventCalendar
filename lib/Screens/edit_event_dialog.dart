import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event.dart';

class EditEventDialog extends StatefulWidget {
  final EventModel event;
  final VoidCallback onEventUpdated;

  const EditEventDialog({
    super.key,
    required this.event,
    required this.onEventUpdated,
  });

  @override
  State<EditEventDialog> createState() => _EditEventDialogState();
}

class _EditEventDialogState extends State<EditEventDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _timeController;
  late final TextEditingController _venueController;
  late final TextEditingController _organizerController;

  late String _selectedEventType;
  late List<String> _selectedAudience;
  late DateTime _selectedDate;
  bool _isLoading = false;

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
  void initState() {
    super.initState();
    // Initialize with existing event data
    _titleController = TextEditingController(text: widget.event.title);
    _descriptionController = TextEditingController(text: widget.event.description);
    _timeController = TextEditingController(text: widget.event.time);
    _venueController = TextEditingController(text: widget.event.venue);
    _organizerController = TextEditingController(text: widget.event.organizer);

    _selectedEventType = widget.event.eventType;
    _selectedAudience = List<String>.from(widget.event.targetAudience);
    _selectedDate = widget.event.date;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _timeController.dispose();
    _venueController.dispose();
    _organizerController.dispose();
    super.dispose();
  }

  Future<void> _selectTime() async {
    // Parse existing time if available
    TimeOfDay initialTime = TimeOfDay.now();
    if (_timeController.text.isNotEmpty) {
      try {
        final timeParts = _timeController.text.split(':');
        if (timeParts.length >= 2) {
          int hour = int.parse(timeParts[0]);
          String minutePart = timeParts[1].replaceAll(RegExp(r'[^0-9]'), '');
          int minute = int.parse(minutePart.substring(0, 2));

          // Handle AM/PM
          if (_timeController.text.toLowerCase().contains('pm') && hour != 12) {
            hour += 12;
          } else if (_timeController.text.toLowerCase().contains('am') && hour == 12) {
            hour = 0;
          }

          initialTime = TimeOfDay(hour: hour, minute: minute);
        }
      } catch (e) {
        // Use current time if parsing fails
        initialTime = TimeOfDay.now();
      }
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      setState(() {
        _timeController.text = picked.format(context);
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _updateEvent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAudience.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select target audience')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final updatedEvent = widget.event.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        date: _selectedDate,
        time: _timeController.text.trim(),
        venue: _venueController.text.trim(),
        organizer: _organizerController.text.trim(),
        targetAudience: _selectedAudience,
        eventType: _selectedEventType,
        updatedAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.event.id)
          .update(updatedEvent.toFirestore());

      widget.onEventUpdated();
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event updated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating event: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Edit Event',
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
            Row(
              children: [
                Text(
                  'Date: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                TextButton(
                  onPressed: _selectDate,
                  child: const Text('Change Date'),
                ),
              ],
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
                  onPressed: _isLoading ? null : _updateEvent,
                  child: _isLoading
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Update Event'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}