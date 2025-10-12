import 'package:flutter/material.dart';
import 'package:college_event_calendar/services/notifications/notification_scheduler.dart';
import 'package:college_event_calendar/services/notifications/notification_manager.dart';
import 'package:college_event_calendar/models/event.dart';
import 'package:college_event_calendar/models/notifications/reminder_policy.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationTestScreen extends StatefulWidget {
  const NotificationTestScreen({Key? key}) : super(key: key);

  @override
  State<NotificationTestScreen> createState() => _NotificationTestScreenState();
}

class _NotificationTestScreenState extends State<NotificationTestScreen> {
  final _notificationManager = NotificationManager();
  final _notificationScheduler = NotificationScheduler();
  String _status = 'Ready to test';
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
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
      final snapshot = await FirebaseFirestore.instance
          .collection('scheduled_notifications')
          .get();

      if (snapshot.docs.isEmpty) {
        setState(() => _status = 'No scheduled notifications found');
      } else {
        setState(() => _status = 'Found ${snapshot.docs.length} scheduled notifications');
      }
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  // 🔔 NEW: Trigger an instant test notification
  Future<void> _sendInstantNotification() async {
    try {
      setState(() => _status = 'Sending test notification...');
      await _notificationManager.showInstantNotification(
        title: 'Test Notification',
        body: 'This is a test push notification for demo purposes.',
      );
      setState(() => _status = 'Test notification sent!');
    } catch (e) {
      setState(() => _status = 'Failed to send notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Notification System'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
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
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!_hasPermission)
              ElevatedButton.icon(
                onPressed: _requestPermission,
                icon: const Icon(Icons.notifications),
                label: const Text('Request Notification Permission'),
              ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _testScheduleNotification,
              icon: const Icon(Icons.schedule),
              label: const Text('Test: Schedule Notifications'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _checkScheduledNotifications,
              icon: const Icon(Icons.list),
              label: const Text('Check Scheduled Notifications'),
            ),

            // 🚀 NEW BUTTON HERE
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _sendInstantNotification,
              icon: const Icon(Icons.notifications_active),
              label: const Text('Send Instant Notification'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            ),

            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _checkPermission,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Status'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Instructions:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('1. Request notification permission'),
            const Text('2. Create an event with notifications enabled'),
            const Text('3. Click "Send Instant Notification" to test immediately'),
            const Text('4. Click "Test: Schedule Notifications" for event-based scheduling'),
          ],
        ),
      ),
    );
  }
}
