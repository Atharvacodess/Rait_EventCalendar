import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:college_event_calendar/models/notifications/reminder_policy.dart';

class NotificationLog {
  final String id;
  final String notificationId;
  final String eventId;
  final String userId;
  final NotificationChannel channel;
  final NotificationStatus status;
  final DateTime? sentAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final String? error;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  NotificationLog({
    required this.id,
    required this.notificationId,
    required this.eventId,
    required this.userId,
    required this.channel,
    required this.status,
    this.sentAt,
    this.deliveredAt,
    this.readAt,
    this.error,
    this.metadata,
    required this.createdAt,
  });

  factory NotificationLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationLog(
      id: doc.id,
      notificationId: data['notificationId'],
      eventId: data['eventId'],
      userId: data['userId'],
      channel: NotificationChannel.fromString(data['channel']),
      status: NotificationStatus.values.byName(data['status']),
      sentAt: data['sentAt'] != null ? (data['sentAt'] as Timestamp).toDate() : null,
      deliveredAt: data['deliveredAt'] != null ? (data['deliveredAt'] as Timestamp).toDate() : null,
      readAt: data['readAt'] != null ? (data['readAt'] as Timestamp).toDate() : null,
      error: data['error'],
      metadata: data['metadata'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}