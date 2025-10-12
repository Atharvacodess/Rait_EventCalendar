import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:college_event_calendar/models/notifications/reminder_policy.dart';
import 'package:college_event_calendar/models/notifications/scheduled_notification.dart';
import 'package:college_event_calendar/models/notifications/notification_log.dart';

class NotificationDeliveryResult {
  final bool success;
  final String notificationId;
  final NotificationChannel channel;
  final String? error;

  NotificationDeliveryResult({
    required this.success,
    required this.notificationId,
    required this.channel,
    this.error,
  });
}

class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal() {
    _initializeFCM();
    _setupMessageListener();
  }
  /// Show an instant notification (for testing/demo)
  Future<void> showInstantNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await _showLocalNotification(
      title,
      body,
      data ?? {'eventId': 'test_event'},
    );
    print('✅ Instant test notification shown: $title - $body');
  }


  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  final String _logCollection = 'notification_logs';
  String? _fcmToken;
  final List<Function(RemoteMessage)> _inAppHandlers = [];

  /// Initialize Firebase Cloud Messaging
  Future<void> _initializeFCM() async {
    try {
      // Request permission
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        _fcmToken = await _messaging.getToken();
        print('FCM Token obtained: $_fcmToken');
      } else {
        print('Notification permission denied');
      }

      // Initialize local notifications
      await _initializeLocalNotifications();
    } catch (e) {
      print('Failed to initialize FCM: $e');
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create Android notification channel
    const androidChannel = AndroidNotificationChannel(
      'event_reminders',
      'Event Reminders',
      description: 'Notifications for upcoming events',
      importance: Importance.high,
    );

    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(androidChannel);
    }
  }

  /// Setup listener for incoming messages
  void _setupMessageListener() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Message received: ${message.notification?.title}');
      _handleIncomingMessage(message);
    });

    // Handle background messages
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Notification tapped: ${message.data}');
      _handleNotificationTap(message.data);
    });
  }

  /// Handle incoming push notification
  void _handleIncomingMessage(RemoteMessage message) {
    // Trigger in-app handlers
    for (final handler in _inAppHandlers) {
      try {
        handler(message);
      } catch (e) {
        print('In-app handler failed: $e');
      }
    }

    // Show local notification when app is in foreground
    if (message.notification != null) {
      _showLocalNotification(
        message.notification!.title ?? 'Event Reminder',
        message.notification!.body ?? '',
        message.data,
      );
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification(
      String title,
      String body,
      Map<String, dynamic> data,
      ) async {
    const androidDetails = AndroidNotificationDetails(
      'event_reminders',
      'Event Reminders',
      channelDescription: 'Notifications for upcoming events',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: data['eventId'],
    );
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      _handleNotificationTap({'eventId': response.payload});
    }
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    // Navigate to event details
    // This should integrate with your navigation system
    print('Navigate to event: ${data['eventId']}');
  }

  /// Send a scheduled notification (called from Cloud Function)
  Future<NotificationDeliveryResult> sendNotification(
      ScheduledNotification notification,
      ) async {
    try {
      switch (notification.channel) {
        case NotificationChannel.push:
          await _sendPushNotification(notification);
          break;
        case NotificationChannel.email:
          await _sendEmailNotification(notification);
          break;
        case NotificationChannel.inApp:
          await _sendInAppNotification(notification);
          break;
      }

      await _logNotification(notification, NotificationStatus.sent);
      return NotificationDeliveryResult(
        success: true,
        notificationId: notification.id,
        channel: notification.channel,
      );
    } catch (e) {
      final error = e.toString();
      await _logNotification(notification, NotificationStatus.failed, error);
      return NotificationDeliveryResult(
        success: false,
        notificationId: notification.id,
        channel: notification.channel,
        error: error,
      );
    }
  }

  /// Send push notification via FCM (through backend API)
  Future<void> _sendPushNotification(ScheduledNotification notification) async {
    // In production, this should call your backend API
    // The Flutter app cannot directly send push notifications to other users
    print('Simulating push notification for testing...');
    await _showLocalNotification(
      notification.payload.title,
      notification.payload.body,
      {'eventId': notification.eventId},
    );
  }

  /// Send email notification
  Future<void> _sendEmailNotification(ScheduledNotification notification) async {
    // Queue email in Firestore for backend to process
    await _firestore.collection('email_queue').add({
      'recipientId': notification.recipientId,
      'subject': notification.payload.title,
      'body': notification.payload.body,
      'eventId': notification.eventId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Send in-app notification
  Future<void> _sendInAppNotification(ScheduledNotification notification) async {
    await _firestore.collection('in_app_notifications').add({
      'userId': notification.recipientId,
      'title': notification.payload.title,
      'body': notification.payload.body,
      'eventId': notification.eventId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Show in-app banner for fallback
  void showInAppBanner(String title, String body, {String? eventId}) {
    // Trigger in-app handlers to show banner
    // You can implement this using a SnackBar or custom overlay
    print('In-App Banner: $title - $body');
  }

  /// Register in-app notification handler
  void Function() registerInAppHandler(Function(RemoteMessage) handler) {
    _inAppHandlers.add(handler);
    return () => _inAppHandlers.remove(handler);
  }

  /// Check if user has notification permissions
  Future<bool> hasNotificationPermission() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  /// Request notification permission
  Future<bool> requestNotificationPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      await _initializeFCM();
      return true;
    }
    return false;
  }

  /// Log notification delivery
  Future<void> _logNotification(
      ScheduledNotification notification,
      NotificationStatus status, [
        String? error,
      ]) async {
    await _firestore.collection(_logCollection).add({
      'notificationId': notification.id,
      'eventId': notification.eventId,
      'userId': notification.recipientId,
      'channel': notification.channel.value,
      'status': status.name,
      'error': error,
      'sentAt': status == NotificationStatus.sent ? FieldValue.serverTimestamp() : null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get notification logs for a user
  Future<List<NotificationLog>> getUserNotificationLogs(
      String userId, {
        int limit = 50,
      }) async {
    final query = await _firestore
        .collection(_logCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return query.docs.map((doc) => NotificationLog.fromFirestore(doc)).toList();
  }

  /// Get FCM token for current user
  String? getFCMToken() => _fcmToken;

  /// Save FCM token to Firestore
  Future<void> saveTokenToFirestore(String userId) async {
    if (_fcmToken != null) {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': _fcmToken,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}