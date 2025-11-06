import 'package:workmanager/workmanager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:college_event_calendar/services/notifications/notification_manager.dart';
import 'package:college_event_calendar/models/notifications/scheduled_notification.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      print('🔄 Background notification checker started...');

      // Initialize Firebase for background task
      await Firebase.initializeApp();

      // Get current user ID
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) {
        print('⚠️ No user logged in, skipping notification check');
        return Future.value(true);
      }

      // ✅ Use UTC "now"
      final nowUtc = DateTime.now().toUtc();
      final firestore = FirebaseFirestore.instance;

      // IMPORTANT: Only get notifications for THIS user
      // ✅ Use UTC in filter and orderBy scheduledFor (requires composite index)
      final snapshot = await firestore
          .collection('scheduled_notifications')
          .where('status', isEqualTo: 'scheduled')
          .where('recipientId', isEqualTo: currentUserId) // FILTER BY USER
          .where('scheduledFor', isLessThanOrEqualTo: Timestamp.fromDate(nowUtc))
          .orderBy('scheduledFor')
          .limit(10)
          .get();

      print('📋 Found ${snapshot.docs.length} pending notifications for user $currentUserId');

      if (snapshot.docs.isEmpty) {
        print('✅ No pending notifications for this user');
        return Future.value(true);
      }

      final manager = NotificationManager();
      int successCount = 0;

      for (final doc in snapshot.docs) {
        try {
          final notification = ScheduledNotification.fromFirestore(doc);

          // Show local notification
          await manager.showLocalNotification(
            notification.payload.title,
            notification.payload.body,
            notification.eventId,
          );

          // Mark as sent (not deleted, so admin can see delivery status)
          await doc.reference.update({
            'status': 'sent',
            'sentAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Log the notification
          await firestore.collection('notification_logs').add({
            'notificationId': doc.id,
            'eventId': notification.eventId,
            'userId': notification.recipientId,
            'channel': notification.channel.value,
            'status': 'sent',
            'sentAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          });

          successCount++;
          print('✅ Notification sent: ${notification.payload.title}');
        } catch (e) {
          print('❌ Failed to send notification: $e');

          // Mark as failed
          await doc.reference.update({
            'status': 'failed',
            'error': e.toString(),
            'attempts': (doc.data()['attempts'] ?? 0) + 1,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      print('✅ Background task completed: $successCount/${snapshot.docs.length} sent');
      return Future.value(true);
    } catch (e) {
      print('❌ Background task failed: $e');
      return Future.value(false);
    }
  });
}

class NotificationWorker {
  static Future<void> initialize() async {
    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: true, // Set to false in production
      );

      // Register periodic task - runs every 15 minutes
      await Workmanager().registerPeriodicTask(
        'notification_checker',
        'checkScheduledNotifications',
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        // ✅ Using the correct enum for periodic tasks
        existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      );

      print('✅ Notification worker initialized - checks every 15 minutes');
    } catch (e) {
      print('❌ Failed to initialize notification worker: $e');
    }
  }

  static Future<void> cancel() async {
    await Workmanager().cancelAll();
    print('🛑 Notification worker cancelled');
  }

  // Manual trigger for testing
  static Future<void> triggerNow() async {
    await Workmanager().registerOneOffTask(
      'notification_checker_manual',
      'checkScheduledNotifications',
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
    print('🚀 Manual notification check triggered');
  }
}
