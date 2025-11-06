import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:college_event_calendar/models/notifications/reminder_policy.dart';

class NotificationPayload {
  final String title;
  final String body;
  final String eventId;
  final String eventTitle;
  final DateTime eventDate; // store as UTC in model
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
      // ✅ read UTC
      eventDate: (map['eventDate'] as Timestamp).toDate().toUtc(),
      data: map['data'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'eventId': eventId,
      'eventTitle': eventTitle,
      // ✅ write UTC
      'eventDate': Timestamp.fromDate(eventDate.toUtc()),
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
  final DateTime scheduledFor; // keep UTC in model
  final NotificationStatus status;
  final NotificationChannel channel;
  final NotificationPayload payload;
  final int attempts;
  final DateTime? lastAttemptAt; // UTC
  final DateTime? sentAt;        // UTC
  final DateTime? deliveredAt;   // UTC
  final String? error;
  final DateTime createdAt;      // UTC
  final DateTime updatedAt;      // UTC

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
      // ✅ read UTC
      scheduledFor: (data['scheduledFor'] as Timestamp).toDate().toUtc(),
      status: NotificationStatus.values.byName(data['status']),
      channel: NotificationChannel.fromString(data['channel']),
      payload: NotificationPayload.fromMap(data['payload']),
      attempts: data['attempts'] ?? 0,
      lastAttemptAt: data['lastAttemptAt'] != null
          ? (data['lastAttemptAt'] as Timestamp).toDate().toUtc()
          : null,
      sentAt: data['sentAt'] != null
          ? (data['sentAt'] as Timestamp).toDate().toUtc()
          : null,
      deliveredAt: data['deliveredAt'] != null
          ? (data['deliveredAt'] as Timestamp).toDate().toUtc()
          : null,
      error: data['error'],
      // ✅ read UTC
      createdAt: (data['createdAt'] as Timestamp).toDate().toUtc(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate().toUtc(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'eventId': eventId,
      'reminderPolicyId': reminderPolicyId,
      'recipientId': recipientId,
      'recipientType': recipientType,
      'timing': timing.value,
      // ✅ write UTC
      'scheduledFor': Timestamp.fromDate(scheduledFor.toUtc()),
      'status': status.name,
      'channel': channel.value,
      'payload': payload.toMap(),
      'attempts': attempts,
      'lastAttemptAt': lastAttemptAt != null
          ? Timestamp.fromDate(lastAttemptAt!.toUtc())
          : null,
      'sentAt': sentAt != null ? Timestamp.fromDate(sentAt!.toUtc()) : null,
      'deliveredAt':
      deliveredAt != null ? Timestamp.fromDate(deliveredAt!.toUtc()) : null,
      'error': error,
      // ✅ write UTC
      'createdAt': Timestamp.fromDate(createdAt.toUtc()),
      'updatedAt': Timestamp.fromDate(updatedAt.toUtc()),
    };
  }
}
