import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:college_event_calendar/models/notifications/reminder_policy.dart';

class EventModel {
  final String? id;
  final String title;
  final String description;
  final DateTime date;
  final String time;
  final String venue;
  final String organizer;
  final List<String> targetAudience;
  final String eventType;
  final String status;
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // NEW: Notification fields
  final bool notificationsEnabled;
  final String? reminderPolicyId;
  final ReminderPolicy? reminderPolicy;

  EventModel({
    this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.time,
    required this.venue,
    required this.organizer,
    required this.targetAudience,
    required this.eventType,
    this.status = 'upcoming',
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
    this.updatedAt,
    // NEW: Add these with defaults
    this.notificationsEnabled = false,
    this.reminderPolicyId,
    this.reminderPolicy,
  });

  factory EventModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EventModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      // ✅ Read as UTC
      date: ((data['date'] as Timestamp?)?.toDate().toUtc()) ?? DateTime.now().toUtc(),
      time: data['time'] ?? '',
      venue: data['venue'] ?? '',
      organizer: data['organizer'] ?? '',
      targetAudience: List<String>.from(data['targetAudience'] ?? []),
      eventType: data['eventType'] ?? 'general',
      status: data['status'] ?? 'upcoming',
      createdBy: data['createdBy'] ?? '',
      createdByName: data['createdByName'] ?? '',
      // ✅ Read as UTC
      createdAt: ((data['createdAt'] as Timestamp?)?.toDate().toUtc()) ?? DateTime.now().toUtc(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate().toUtc(),
      // NEW: Add these
      notificationsEnabled: data['notificationsEnabled'] ?? false,
      reminderPolicyId: data['reminderPolicyId'],
      reminderPolicy: null, // Will be loaded separately if needed
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      // ✅ Write as UTC
      'date': Timestamp.fromDate(date.toUtc()),
      'time': time,
      'venue': venue,
      'organizer': organizer,
      'targetAudience': targetAudience,
      'eventType': eventType,
      'status': status,
      'createdBy': createdBy,
      'createdByName': createdByName,
      // ✅ Write as UTC
      'createdAt': Timestamp.fromDate(createdAt.toUtc()),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!.toUtc()) : null,
      // NEW: Add these
      'notificationsEnabled': notificationsEnabled,
      'reminderPolicyId': reminderPolicyId,
    };
  }

  EventModel copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? date,
    String? time,
    String? venue,
    String? organizer,
    List<String>? targetAudience,
    String? eventType,
    String? status,
    String? createdBy,
    String? createdByName,
    DateTime? createdAt,
    DateTime? updatedAt,
    // NEW: Add these
    bool? notificationsEnabled,
    String? reminderPolicyId,
    ReminderPolicy? reminderPolicy,
  }) {
    return EventModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      time: time ?? this.time,
      venue: venue ?? this.venue,
      organizer: organizer ?? this.organizer,
      targetAudience: targetAudience ?? this.targetAudience,
      eventType: eventType ?? this.eventType,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      // NEW: Add these
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      reminderPolicyId: reminderPolicyId ?? this.reminderPolicyId,
      reminderPolicy: reminderPolicy ?? this.reminderPolicy,
    );
  }

  // Helper method to load reminder policy
  Future<EventModel> loadReminderPolicy(FirebaseFirestore firestore) async {
    if (reminderPolicyId == null) return this;

    try {
      final policyDoc = await firestore
          .collection('reminder_policies')
          .doc(reminderPolicyId)
          .get();

      if (!policyDoc.exists) return this;

      return copyWith(reminderPolicy: ReminderPolicy.fromFirestore(policyDoc));
    } catch (e) {
      print('Failed to load reminder policy: $e');
      return this;
    }
  }

  // Existing helper getters (compare using UTC)
  bool get isToday {
    final now = DateTime.now().toUtc(); // ✅
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool get isUpcoming => date.isAfter(DateTime.now().toUtc()); // ✅
  bool get isPast => date.isBefore(DateTime.now().toUtc());    // ✅

  // Display in local timezone for UI
  String get formattedDate {
    final d = date.toLocal(); // ✅ for user-facing text
    return '${d.day}/${d.month}/${d.year}';
  }
}
