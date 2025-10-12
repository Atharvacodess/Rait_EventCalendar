import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:college_event_calendar/models/notifications/reminder_policy.dart';

class NotificationPayload {
  final String title;
  final String body;
  final String eventId;
  final String eventTitle;
  final DateTime eventDate;
  final Map<String, dynamic>? data;

  NotificationPayload({
    required this.title,
    required this.body,
    required this.eventId,
    required this.eventTitle,
    required this.eventDate,
    this.data,
  });

  factory NotificationPayload.fromMap(Map<String, dynamic> map) {
    return NotificationPayload(
      title: map['title'],
      body: map['body'],
      eventId: map['eventId'],
      eventTitle: map['eventTitle'],
      eventDate: (map['eventDate'] as Timestamp).toDate(),
      data: map['data'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'eventId': eventId,
      'eventTitle': eventTitle,
      'eventDate': Timestamp.fromDate(eventDate),
      'data': data,
    };
  }
}

class ScheduledNotification {
  final String id;
  final String eventId;
  final String reminderPolicyId;
  final String recipientId;
  final String recipientType;
  final ReminderTiming timing;
  final DateTime scheduledFor;
  final NotificationStatus status;
  final NotificationChannel channel;
  final NotificationPayload payload;
  final int attempts;
  final DateTime? lastAttemptAt;
  final DateTime? sentAt;
  final DateTime? deliveredAt;
  final String? error;
  final DateTime createdAt;
  final DateTime updatedAt;

  ScheduledNotification({
    required this.id,
    required this.eventId,
    required this.reminderPolicyId,
    required this.recipientId,
    required this.recipientType,
    required this.timing,
    required this.scheduledFor,
    required this.status,
    required this.channel,
    required this.payload,
    this.attempts = 0,
    this.lastAttemptAt,
    this.sentAt,
    this.deliveredAt,
    this.error,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ScheduledNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ScheduledNotification(
      id: doc.id,
      eventId: data['eventId'],
      reminderPolicyId: data['reminderPolicyId'],
      recipientId: data['recipientId'],
      recipientType: data['recipientType'],
      timing: ReminderTiming.fromString(data['timing']),
      scheduledFor: (data['scheduledFor'] as Timestamp).toDate(),
      status: NotificationStatus.values.byName(data['status']),
      channel: NotificationChannel.fromString(data['channel']),
      payload: NotificationPayload.fromMap(data['payload']),
      attempts: data['attempts'] ?? 0,
      lastAttemptAt: data['lastAttemptAt'] != null
          ? (data['lastAttemptAt'] as Timestamp).toDate()
          : null,
      sentAt: data['sentAt'] != null
          ? (data['sentAt'] as Timestamp).toDate()
          : null,
      deliveredAt: data['deliveredAt'] != null
          ? (data['deliveredAt'] as Timestamp).toDate()
          : null,
      error: data['error'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'eventId': eventId,
      'reminderPolicyId': reminderPolicyId,
      'recipientId': recipientId,
      'recipientType': recipientType,
      'timing': timing.value,
      'scheduledFor': Timestamp.fromDate(scheduledFor),
      'status': status.name,
      'channel': channel.value,
      'payload': payload.toMap(),
      'attempts': attempts,
      'lastAttemptAt': lastAttemptAt != null ? Timestamp.fromDate(lastAttemptAt!) : null,
      'sentAt': sentAt != null ? Timestamp.fromDate(sentAt!) : null,
      'deliveredAt': deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
      'error': error,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}