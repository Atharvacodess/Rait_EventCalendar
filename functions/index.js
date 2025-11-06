const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Cloud Function that runs every minute to process pending notifications
 */
exports.processScheduledNotifications = functions.pubsub
    .schedule("every 1 minutes")
    .onRun(async (context) => {
      console.log("Starting notification processor...");

      try {
        const now = admin.firestore.Timestamp.now();

        // Query pending notifications that are due
        const snapshot = await db
            .collection("scheduled_notifications")
            .where("status", "==", "scheduled")
            .where("scheduledFor", "<=", now)
            .limit(50)
            .get();

        console.log(`Found ${snapshot.size} notifications to process`);

        if (snapshot.empty) {
          console.log("No pending notifications");
          return {processed: 0};
        }

        const processPromises = snapshot.docs.map((doc) =>
          processNotification(doc.id, doc.data()),
        );

        const results = await Promise.allSettled(processPromises);

        const succeeded = results.filter(
            (r) => r.status === "fulfilled",
        ).length;
        const failed = results.filter(
            (r) => r.status === "rejected",
        ).length;

        console.log(`Processed: ${succeeded} succeeded, ${failed} failed`);

        return {processed: snapshot.size, succeeded, failed};
      } catch (error) {
        console.error("Notification processor failed:", error);
        throw error;
      }
    });

/**
 * Process a single notification
 * @param {string} notificationId - The notification ID
 * @param {object} data - The notification data
 * @return {Promise<void>}
 */
async function processNotification(notificationId, data) {
  const notificationRef = db
      .collection("scheduled_notifications")
      .doc(notificationId);

  try {
    console.log(`Processing notification ${notificationId}...`);

    // Get recipient's FCM token
    const recipientDoc = await db
        .collection("users")
        .doc(data.recipientId)
        .get();

    if (!recipientDoc.exists) {
      throw new Error(`Recipient not found: ${data.recipientId}`);
    }

    const recipient = recipientDoc.data();

    // Send notification based on channel
    switch (data.channel) {
      case "push":
        await sendPushNotification(recipient, data.payload);
        break;
      case "email":
        await sendEmailNotification(recipient, data.payload);
        break;
      case "in_app":
        await sendInAppNotification(
            data.recipientId,
            data.payload,
            data.eventId,
        );
        break;
    }

    // Mark as sent
    await notificationRef.update({
      status: "sent",
      sentAt: admin.firestore.Timestamp.now(),
      updatedAt: admin.firestore.Timestamp.now(),
    });

    // Log successful delivery
    await logNotification(notificationId, data, "sent");

    console.log(`✅ Notification ${notificationId} sent successfully`);
  } catch (error) {
    console.error(
        `❌ Failed to process notification ${notificationId}:`,
        error,
    );

    // Increment attempts
    const currentAttempts = data.attempts || 0;
    const maxAttempts = 3;

    if (currentAttempts < maxAttempts) {
      // Retry later
      await notificationRef.update({
        attempts: currentAttempts + 1,
        lastAttemptAt: admin.firestore.Timestamp.now(),
        error: error.message,
        updatedAt: admin.firestore.Timestamp.now(),
      });
    } else {
      // Max attempts reached, mark as failed
      await notificationRef.update({
        status: "failed",
        attempts: currentAttempts + 1,
        lastAttemptAt: admin.firestore.Timestamp.now(),
        error: `Max attempts reached: ${error.message}`,
        updatedAt: admin.firestore.Timestamp.now(),
      });

      await logNotification(notificationId, data, "failed", error.message);
    }

    throw error;
  }
}

/**
 * Send push notification via FCM
 * @param {object} recipient - The recipient user object
 * @param {object} payload - The notification payload
 * @return {Promise<void>}
 */
async function sendPushNotification(recipient, payload) {
  if (!recipient.fcmToken) {
    console.log(`No FCM token for user, creating in-app notification`);
    await sendInAppNotification(recipient.id, payload, payload.eventId);
    return;
  }

  const message = {
    token: recipient.fcmToken,
    notification: {
      title: payload.title,
      body: payload.body,
    },
    data: {
      eventId: payload.eventId,
      type: "event_reminder",
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    android: {
      priority: "high",
      notification: {
        sound: "default",
        channelId: "event_reminders",
        priority: "high",
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          badge: 1,
          contentAvailable: true,
        },
      },
    },
  };

  try {
    await messaging.send(message);
    console.log(`✅ Push notification sent to ${recipient.id}`);
  } catch (error) {
    // Handle token errors
    if (error.code === "messaging/invalid-registration-token" ||
        error.code === "messaging/registration-token-not-registered") {
      // Remove invalid token
      await db.collection("users").doc(recipient.id).update({
        fcmToken: admin.firestore.FieldValue.delete(),
      });

      // Fallback to in-app notification
      await sendInAppNotification(recipient.id, payload, payload.eventId);
    } else {
      throw error;
    }
  }
}

/**
 * Send email notification
 * @param {object} recipient - The recipient user object
 * @param {object} payload - The notification payload
 * @return {Promise<void>}
 */
async function sendEmailNotification(recipient, payload) {
  // Queue email for processing by email service
  await db.collection("email_queue").add({
    to: recipient.email,
    subject: payload.title,
    body: payload.body,
    eventId: payload.eventId,
    templateId: "event_reminder",
    status: "pending",
    createdAt: admin.firestore.Timestamp.now(),
  });

  console.log(`📧 Email queued for ${recipient.email}`);
}

/**
 * Send in-app notification
 * @param {string} userId - The user ID
 * @param {object} payload - The notification payload
 * @param {string} eventId - The event ID
 * @return {Promise<void>}
 */
async function sendInAppNotification(userId, payload, eventId) {
  await db.collection("in_app_notifications").add({
    userId: userId,
    title: payload.title,
    body: payload.body,
    eventId: eventId,
    type: "event_reminder",
    read: false,
    createdAt: admin.firestore.Timestamp.now(),
  });

  console.log(`📱 In-app notification created for user ${userId}`);
}

/**
 * Log notification delivery
 * @param {string} notificationId - The notification ID
 * @param {object} data - The notification data
 * @param {string} status - The notification status
 * @param {string|null} error - The error message if any
 * @return {Promise<void>}
 */
async function logNotification(notificationId, data, status, error = null) {
  await db.collection("notification_logs").add({
    notificationId: notificationId,
    eventId: data.eventId,
    userId: data.recipientId,
    channel: data.channel,
    status: status,
    error: error,
    sentAt: status === "sent" ? admin.firestore.Timestamp.now() : null,
    createdAt: admin.firestore.Timestamp.now(),
  });
}

/**
 * Clean up old processed notifications (run daily)
 */
exports.cleanupOldNotifications = functions.pubsub
    .schedule("every 24 hours")
    .onRun(async (context) => {
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

      const snapshot = await db
          .collection("scheduled_notifications")
          .where("status", "in", ["sent", "failed", "cancelled"])
          .where(
              "updatedAt",
              "<",
              admin.firestore.Timestamp.fromDate(thirtyDaysAgo),
          )
          .limit(500)
          .get();

      const batch = db.batch();
      snapshot.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();

      console.log(`🧹 Cleaned up ${snapshot.size} old notifications`);
      return {cleaned: snapshot.size};
    });

/**
 * HTTP endpoint to manually trigger notification processing (for testing)
 */
exports.triggerNotificationProcessor = functions.https
    .onRequest(async (req, res) => {
      if (req.method !== "POST") {
        res.status(405).send("Method not allowed");
        return;
      }

      try {
        const result = await exports.processScheduledNotifications.run();
        res.status(200).json(result);
      } catch (error) {
        console.error("Manual trigger failed:", error);
        res.status(500).json({error: "Processing failed"});
      }
    });
