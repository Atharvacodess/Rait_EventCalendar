import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:college_event_calendar/models/notifications/reminder_policy.dart';
import 'package:college_event_calendar/models/notifications/scheduled_notification.dart';
import 'package:college_event_calendar/models/event.dart';
import 'package:college_event_calendar/services/notifications/strategies/reminder_strategy_factory.dart';

class NotificationScheduler {
  static final NotificationScheduler _instance = NotificationScheduler._internal();
  factory NotificationScheduler() => _instance;
  NotificationScheduler._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'scheduled_notifications';

  /// Schedule all notifications for an event based on its reminder policy
  Future<void> scheduleNotificationsForEvent(EventModel event) async {
    if (event.reminderPolicy == null || !event.reminderPolicy!.enabled) {
      print('No active reminder policy for event ${event.id}');
      return;
    }

    final reminderPolicy = event.reminderPolicy!;
    // ✅ Use UTC consistently
    final DateTime eventDateUtc = event.date.toUtc();
    final DateTime nowUtc = DateTime.now().toUtc();

    // Get all recipients for this event
    final recipients = await _getEventRecipients(event);

    for (final timing in reminderPolicy.timings) {
      try {
        final strategy = ReminderStrategyFactory.getStrategy(
          timing,
          customMinutes: reminderPolicy.customMinutes,
        );

        // strategy.calculateScheduleTime() returns a DateTime based on event date
        // Normalize it to UTC for storage & comparison.
        DateTime scheduledUtc =
        strategy.calculateScheduleTime(eventDateUtc).toUtc();

        // Optional: tiny demo clamp (leave disabled by default)
        const bool demoMode = false; // set true only for presentations
        if (demoMode && scheduledUtc.isBefore(nowUtc)) {
          scheduledUtc = nowUtc.add(const Duration(seconds: 20));
        }

        // Skip if the scheduled time is too far in the past (production guard)
        // (Allows "due now" items but skips very old ones, e.g., >1h)
        final tooOldCutoff = nowUtc.subtract(const Duration(hours: 1));
        if (scheduledUtc.isBefore(tooOldCutoff)) {
          print('Skipping very old notification for $timing - scheduled for $scheduledUtc (now=$nowUtc)');
          continue;
        }

        // If you want to skip anything strictly before "now", uncomment:
        // if (scheduledUtc.isBefore(nowUtc)) {
        //   print('Skipping past notification for $timing - scheduled for $scheduledUtc (now=$nowUtc)');
        //   continue;
        // }

        // Create notifications for each recipient and channel
        for (final recipient in recipients) {
          for (final channel in reminderPolicy.channels) {
            await _createScheduledNotification(
              eventId: event.id!,
              reminderPolicyId: reminderPolicy.id,
              recipientId: recipient['id']!,
              recipientType: recipient['type']!,
              timing: timing,
              scheduledFor: scheduledUtc, // ✅ pass UTC
              channel: channel,
              event: event,
            );
          }
        }

        print('Scheduled $timing notifications for event ${event.id}');
      } catch (e) {
        print('Failed to schedule $timing notification: $e');
      }
    }
  }

  /// Cancel all scheduled notifications for an event
  Future<void> cancelNotificationsForEvent(String eventId) async {
    try {
      final query = await _firestore
          .collection(_collection)
          .where('eventId', isEqualTo: eventId)
          .where('status', isEqualTo: NotificationStatus.scheduled.name)
          .get();

      final batch = _firestore.batch();
      for (final doc in query.docs) {
        batch.update(doc.reference, {
          'status': NotificationStatus.cancelled.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      print('Cancelled ${query.docs.length} notifications for event $eventId');
    } catch (e) {
      print('Failed to cancel notifications: $e');
      rethrow;
    }
  }

  /// Reschedule notifications when event details change
  Future<void> rescheduleNotificationsForEvent(EventModel event) async {
    // Cancel existing scheduled notifications
    await cancelNotificationsForEvent(event.id!);

    // Schedule new notifications with updated details
    await scheduleNotificationsForEvent(event);
  }

  /// Create a single scheduled notification
  Future<void> _createScheduledNotification({
    required String eventId,
    required String reminderPolicyId,
    required String recipientId,
    required String recipientType,
    required ReminderTiming timing,
    required DateTime scheduledFor, // expected UTC
    required NotificationChannel channel,
    required EventModel event,
  }) async {
    final payload = _createNotificationPayload(event, timing);

    final notification = {
      'eventId': eventId,
      'reminderPolicyId': reminderPolicyId,
      'recipientId': recipientId,
      'recipientType': recipientType,
      'timing': timing.value,
      // ✅ write UTC to Firestore
      'scheduledFor': Timestamp.fromDate(scheduledFor.toUtc()),
      'status': NotificationStatus.scheduled.name,
      'channel': channel.value,
      'payload': payload.toMap(),
      'attempts': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _firestore.collection(_collection).add(notification);
  }

  /// Create notification payload from event
  NotificationPayload _createNotificationPayload(EventModel event, ReminderTiming timing) {
    final strategy = ReminderStrategyFactory.getStrategy(timing);
    final timingLabel = strategy.getTimingLabel();

    return NotificationPayload(
      title: 'Upcoming: ${event.title}',
      body: '${event.title} is starting $timingLabel',
      eventId: event.id!,
      eventTitle: event.title,
      // ✅ carry UTC in payload (UI can display toLocal())
      eventDate: event.date.toUtc(),
      data: {
        'type': 'event_reminder',
        'eventId': event.id!,
        'timing': timing.value,
      },
    );
  }

  /// Get recipients for an event based on target audience (unchanged)
  Future<List<Map<String, String>>> _getEventRecipients(EventModel event) async {
    final recipients = <Map<String, String>>[];

    try {
      print('🔍 Getting recipients for target audience: ${event.targetAudience}');

      // Map target audience to user roles
      final Set<String> rolesToFetch = {};

      for (final audience in event.targetAudience) {
        final lower = audience.toLowerCase();
        if (lower.contains('students') || lower.contains('year')) {
          rolesToFetch.add('student');
        } else if (lower.contains('faculty') || lower.contains('teacher')) {
          rolesToFetch.addAll(['teacher', 'hod', 'principal', 'staff']);
        } else if (lower.contains('staff')) {
          rolesToFetch.addAll(['staff', 'hod', 'principal']);
        } else if (lower.contains('alumni')) {
          rolesToFetch.add('alumni');
        }
      }

      print('📋 Roles to fetch: $rolesToFetch');

      // Fetch users for each role
      for (final role in rolesToFetch) {
        final usersQuery = await _firestore
            .collection('users')
            .where('role', isEqualTo: role)
            .get();

        print('👥 Found ${usersQuery.docs.length} users with role: $role');

        for (final doc in usersQuery.docs) {
          recipients.add({'id': doc.id, 'type': role});
        }
      }

      print('✅ Total recipients: ${recipients.length}');
    } catch (e) {
      print('❌ Error fetching recipients: $e');
    }

    return recipients;
  }

  /// Get all pending notifications that need to be sent
  Future<List<ScheduledNotification>> getPendingNotifications() async {
    // ✅ compare with UTC "now"
    final Timestamp nowUtcTs = Timestamp.fromDate(DateTime.now().toUtc());
    final query = await _firestore
        .collection(_collection)
        .where('status', isEqualTo: NotificationStatus.scheduled.name)
        .where('scheduledFor', isLessThanOrEqualTo: nowUtcTs)
        .get();

    return query.docs
        .map((doc) => ScheduledNotification.fromFirestore(doc))
        .toList();
  }

  /// Mark notification as sent
  Future<void> markNotificationAsSent(String notificationId) async {
    await _firestore.collection(_collection).doc(notificationId).update({
      'status': NotificationStatus.sent.name,
      'sentAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Mark notification as failed
  Future<void> markNotificationAsFailed(String notificationId, String error) async {
    final docRef = _firestore.collection(_collection).doc(notificationId);
    final doc = await docRef.get();
    final currentAttempts = doc.data()?['attempts'] ?? 0;

    await docRef.update({
      'status': NotificationStatus.failed.name,
      'error': error,
      'attempts': currentAttempts + 1,
      'lastAttemptAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
