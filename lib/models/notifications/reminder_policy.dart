import 'package:cloud_firestore/cloud_firestore.dart';

enum ReminderTiming {
  fifteenMinutes('15_minutes', '15 minutes before'),
  oneHour('1_hour', '1 hour before'),
  oneDay('1_day', '1 day before'),
  threeDays('3_days', '3 days before'),
  oneWeek('1_week', '1 week before'),
  custom('custom', 'Custom time');

  final String value;
  final String label;
  const ReminderTiming(this.value, this.label);

  static ReminderTiming fromString(String value) {
    return ReminderTiming.values.firstWhere(
          (e) => e.value == value,
      orElse: () => ReminderTiming.oneDay,
    );
  }
}

enum NotificationChannel {
  push('push', 'Push Notification'),
  email('email', 'Email'),
  inApp('in_app', 'In-App Alert');

  final String value;
  final String label;
  const NotificationChannel(this.value, this.label);

  static NotificationChannel fromString(String value) {
    return NotificationChannel.values.firstWhere(
          (e) => e.value == value,
      orElse: () => NotificationChannel.push,
    );
  }
}

enum NotificationStatus {
  scheduled,
  sent,
  delivered,
  failed,
  cancelled
}

class ReminderPolicy {
  final String id;
  final String eventId;
  final List<ReminderTiming> timings;
  final int? customMinutes;
  final bool enabled;
  final List<NotificationChannel> channels;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReminderPolicy({
    required this.id,
    required this.eventId,
    required this.timings,
    this.customMinutes,
    required this.enabled,
    required this.channels,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReminderPolicy.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReminderPolicy(
      id: doc.id,
      eventId: data['eventId'] ?? '',
      timings: (data['timings'] as List<dynamic>?)
          ?.map((e) => ReminderTiming.fromString(e.toString()))
          .toList() ??
          [],
      customMinutes: data['customMinutes'],
      enabled: data['enabled'] ?? true,
      channels: (data['channels'] as List<dynamic>?)
          ?.map((e) => NotificationChannel.fromString(e.toString()))
          .toList() ??
          [NotificationChannel.push],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'eventId': eventId,
      'timings': timings.map((e) => e.value).toList(),
      'customMinutes': customMinutes,
      'enabled': enabled,
      'channels': channels.map((e) => e.value).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  ReminderPolicy copyWith({
    String? id,
    String? eventId,
    List<ReminderTiming>? timings,
    int? customMinutes,
    bool? enabled,
    List<NotificationChannel>? channels,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReminderPolicy(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      timings: timings ?? this.timings,
      customMinutes: customMinutes ?? this.customMinutes,
      enabled: enabled ?? this.enabled,
      channels: channels ?? this.channels,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}