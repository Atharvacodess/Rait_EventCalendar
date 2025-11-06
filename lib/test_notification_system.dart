import 'package:flutter/material.dart';
import 'package:college_event_calendar/services/notifications/notification_scheduler.dart';
import 'package:college_event_calendar/services/notifications/notification_manager.dart';
import 'package:college_event_calendar/services/notifications/notification_worker.dart';
import 'package:college_event_calendar/models/event.dart';
import 'package:college_event_calendar/models/notifications/reminder_policy.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationTestScreen extends StatefulWidget {
  const NotificationTestScreen({Key? key}) : super(key: key);

  @override
  State<NotificationTestScreen> createState() => _NotificationTestScreenState();
}

class _NotificationTestScreenState extends State<NotificationTestScreen> {
  final _notificationManager = NotificationManager();
  final _notificationScheduler = NotificationScheduler();
  final _titleController = TextEditingController(text: 'Test Event Reminder');
  final _bodyController = TextEditingController(text: 'Your event is starting soon!');
  String _status = 'Ready to test';
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    final hasPermission = await _notificationManager.hasNotificationPermission();
    setState(() {
      _hasPermission = hasPermission;
      _status = hasPermission ? 'Notification permission granted' : 'Notification permission denied';
    });
  }

  Future<void> _requestPermission() async {
    setState(() => _status = 'Requesting permission...');
    final granted = await _notificationManager.requestNotificationPermission();
    setState(() {
      _hasPermission = granted;
      _status = granted ? 'Permission granted!' : 'Permission denied';
    });
  }

  Future<void> _testScheduleNotification() async {
    setState(() => _status = 'Creating test event...');

    try {
      final eventsSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (eventsSnapshot.docs.isEmpty) {
        setState(() => _status = 'No events found. Create an event first!');
        return;
      }

      final eventDoc = eventsSnapshot.docs.first;
      final event = EventModel.fromFirestore(eventDoc);

      if (event.reminderPolicyId != null) {
        final policyDoc = await FirebaseFirestore.instance
            .collection('reminder_policies')
            .doc(event.reminderPolicyId)
            .get();

        if (policyDoc.exists) {
          final policy = ReminderPolicy.fromFirestore(policyDoc);
          final eventWithPolicy = event.copyWith(reminderPolicy: policy);

          setState(() => _status = 'Scheduling notifications...');
          await _notificationScheduler.scheduleNotificationsForEvent(eventWithPolicy);

          final scheduledCount = await FirebaseFirestore.instance
              .collection('scheduled_notifications')
              .where('eventId', isEqualTo: event.id)
              .get();

          setState(() => _status = 'Success! ${scheduledCount.docs.length} notifications scheduled');
        } else {
          setState(() => _status = 'Event has no reminder policy');
        }
      } else {
        setState(() => _status = 'Event has no reminder policy ID');
      }
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  Future<void> _checkScheduledNotifications() async {
    setState(() => _status = 'Checking scheduled notifications...');

    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) {
        setState(() => _status = 'Not logged in');
        return;
      }

      // Check notifications for current user
      final snapshot = await FirebaseFirestore.instance
          .collection('scheduled_notifications')
          .where('recipientId', isEqualTo: currentUserId)
          .get();

      if (snapshot.docs.isEmpty) {
        setState(() => _status = 'No scheduled notifications for you');
      } else {
        final scheduled = snapshot.docs.where((d) => d.data()['status'] == 'scheduled').length;
        final sent = snapshot.docs.where((d) => d.data()['status'] == 'sent').length;
        setState(() => _status = 'Total: ${snapshot.docs.length} (Scheduled: $scheduled, Sent: $sent)');
      }
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  Future<void> _sendCustomNotification() async {
    if (_titleController.text.trim().isEmpty || _bodyController.text.trim().isEmpty) {
      setState(() => _status = 'Please enter title and message');
      return;
    }

    try {
      setState(() => _status = 'Sending custom notification...');
      await _notificationManager.showInstantNotification(
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
      );
      setState(() => _status = '✅ Custom notification sent!');
    } catch (e) {
      setState(() => _status = '❌ Failed: $e');
    }
  }

  Future<void> _triggerBackgroundCheck() async {
    try {
      setState(() => _status = 'Triggering background notification check...');
      await NotificationWorker.triggerNow();

      // Wait a moment for the task to complete
      await Future.delayed(const Duration(seconds: 3));

      setState(() => _status = '✅ Background check triggered! Check your notifications.');
    } catch (e) {
      setState(() => _status = '❌ Failed to trigger: $e');
    }
  }

  Future<void> _showCustomNotificationDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Custom Notification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Notification Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bodyController,
              decoration: const InputDecoration(
                labelText: 'Notification Message',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendCustomNotification();
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Notification System'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              color: _hasPermission ? Colors.green.shade50 : Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      _hasPermission ? Icons.check_circle : Icons.error,
                      size: 48,
                      color: _hasPermission ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Permission Section
            if (!_hasPermission) ...[
              const Text(
                '⚠️ Permissions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _requestPermission,
                icon: const Icon(Icons.notifications),
                label: const Text('Request Notification Permission'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              ),
              const SizedBox(height: 24),
            ],

            // Quick Test Section
            const Text(
              '🚀 Quick Tests',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: _showCustomNotificationDialog,
              icon: const Icon(Icons.edit_notifications),
              label: const Text('Send Custom Notification'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: _triggerBackgroundCheck,
              icon: const Icon(Icons.sync),
              label: const Text('Check Notifications Now (Manual)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),

            // Event-Based Tests
            const Text(
              '📅 Event-Based Tests',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: _testScheduleNotification,
              icon: const Icon(Icons.schedule),
              label: const Text('Schedule Notifications for Latest Event'),
            ),
            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: _checkScheduledNotifications,
              icon: const Icon(Icons.list),
              label: const Text('Check My Scheduled Notifications'),
            ),
            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: _checkPermission,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Status'),
            ),
            const SizedBox(height: 24),

            // Instructions
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'How to Test',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInstruction('1', 'Request notification permission first'),
                    _buildInstruction('2', 'Use "Send Custom Notification" for instant test'),
                    _buildInstruction('3', 'Create an event with "Custom: 1 minute" reminder'),
                    _buildInstruction('4', 'Click "Check Notifications Now" after 1 minute'),
                    _buildInstruction('5', 'Or wait - background worker checks every 15 minutes'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstruction(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}