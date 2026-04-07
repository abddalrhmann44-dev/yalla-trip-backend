// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Cloud Functions
//  Triggers on property status change → sends FCM to owner
//  Also logs notification to Firestore 'notifications' collection
// ═══════════════════════════════════════════════════════════════

const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

// ── Notification templates per type ─────────────────────────
const NOTIF_TEMPLATES = {
  approved: {
    titleAr: "تم قبول {type}",
    titleEn: "{type} Approved",
    bodyAr: "تمت الموافقة على {name} ويمكن الآن ظهوره للجميع.",
    bodyEn: "{name} has been approved and is now visible to everyone.",
  },
  rejected: {
    titleAr: "تم رفض {type}",
    titleEn: "{type} Rejected",
    bodyAr: "عذرًا، لم يتم قبول {name}. يمكنك المحاولة مرة أخرى.",
    bodyEn: "Sorry, {name} was not approved. You can try again.",
  },
  needs_edit: {
    titleAr: "مطلوب تعديل",
    titleEn: "Edits Required",
    bodyAr: "يرجى تعديل بيانات {name} حسب ملاحظات الإدارة.",
    bodyEn: "Please update {name} according to admin notes.",
  },
};

// ── Map category key to Arabic type name ────────────────────
function getTypeName(category) {
  const map = {
    "شاليه": { ar: "الشاليه", en: "Chalet" },
    "فندق": { ar: "الفندق", en: "Hotel" },
    "منتجع": { ar: "المنتجع", en: "Resort" },
    "فيلا": { ar: "الفيلا", en: "Villa" },
    "بيت شاطئ": { ar: "بيت الشاطئ", en: "Beach House" },
  };
  return map[category] || { ar: "العقار", en: "Property" };
}

// ══════════════════════════════════════════════════════════════
//  MAIN TRIGGER: onDocumentUpdated for properties collection
// ══════════════════════════════════════════════════════════════
exports.onPropertyStatusChange = onDocumentUpdated(
  "properties/{propertyId}",
  async (event) => {
    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();

    // Only trigger when status changes FROM "pending"
    const oldStatus = beforeData.status || "pending";
    const newStatus = afterData.status || "pending";

    if (oldStatus === newStatus) return null;
    if (oldStatus !== "pending") return null;

    // Only handle valid new statuses
    if (!["approved", "rejected", "needs_edit"].includes(newStatus)) {
      return null;
    }

    const propertyId = event.params.propertyId;
    const ownerId = afterData.ownerId;
    const propName = afterData.name || "العقار";
    const category = afterData.category || "";

    if (!ownerId) {
      console.log("No ownerId found for property:", propertyId);
      return null;
    }

    // 1. Get owner's FCM token
    const userDoc = await db.collection("users").doc(ownerId).get();
    if (!userDoc.exists) {
      console.log("User document not found for:", ownerId);
      return null;
    }

    const userData = userDoc.data();
    const fcmToken = userData.fcmToken;
    const typeName = getTypeName(category);
    const template = NOTIF_TEMPLATES[newStatus];

    if (!template) {
      console.log("No template for status:", newStatus);
      return null;
    }

    // 2. Build notification content (Arabic as primary)
    const title = template.titleAr
      .replace("{type}", typeName.ar)
      .replace("{name}", propName);
    const body = template.bodyAr
      .replace("{type}", typeName.ar)
      .replace("{name}", propName);

    // English versions for data payload
    const titleEn = template.titleEn
      .replace("{type}", typeName.en)
      .replace("{name}", propName);
    const bodyEn = template.bodyEn
      .replace("{type}", typeName.en)
      .replace("{name}", propName);

    // 3. Log notification to Firestore
    await db.collection("notifications").add({
      ownerId: ownerId,
      userId: ownerId,
      itemId: propertyId,
      type: newStatus,
      title: title,
      titleEn: titleEn,
      body: body,
      bodyEn: bodyEn,
      seen: false,
      isRead: false,
      createdAt: new Date(),
    });

    console.log(`Notification logged for ${ownerId}: ${newStatus}`);

    // 4. Send FCM push notification
    if (!fcmToken) {
      console.log("No FCM token for user:", ownerId);
      return null;
    }

    const message = {
      token: fcmToken,
      notification: {
        title: title,
        body: body,
      },
      data: {
        type: newStatus,
        propertyId: propertyId,
        propertyName: propName,
        titleAr: title,
        titleEn: titleEn,
        bodyAr: body,
        bodyEn: bodyEn,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "yalla_trip_channel",
          priority: "high",
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: title,
              body: body,
            },
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    try {
      const response = await messaging.send(message);
      console.log("FCM sent successfully:", response);
    } catch (error) {
      console.error("Error sending FCM:", error);

      // If token is invalid, clean it up
      if (
        error.code === "messaging/invalid-registration-token" ||
        error.code === "messaging/registration-token-not-registered"
      ) {
        await db.collection("users").doc(ownerId).update({
          fcmToken: null,
        });
        console.log("Removed invalid FCM token for:", ownerId);
      }
    }

    return null;
  }
);
