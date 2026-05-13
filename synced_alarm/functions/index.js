"use strict";

const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const {
  onCall,
  HttpsError,
} = require("firebase-functions/v2/https");
const {
  onDocumentCreated,
  onDocumentWritten,
} = require("firebase-functions/v2/firestore");
const {defineSecret} = require("firebase-functions/params");
const logger = require("firebase-functions/logger");

initializeApp();

const groupAccessCode = defineSecret("GROUP_ACCESS_CODE");

exports.joinGroup = onCall({
  invoker: "public",
  secrets: [groupAccessCode],
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in before joining a group.");
  }

  const groupId = cleanId(request.data.groupId);
  const accessCode = String(request.data.accessCode || "");
  const expectedCode = groupAccessCode.value();

  if (!groupId) {
    throw new HttpsError("invalid-argument", "groupId is required.");
  }
  if (!expectedCode || accessCode !== expectedCode) {
    throw new HttpsError("permission-denied", "Invalid group access code.");
  }

  const db = getFirestore();
  const groupRef = db.collection("groups").doc(groupId);
  const memberRef = groupRef.collection("members").doc(request.auth.uid);

  await db.runTransaction(async (transaction) => {
    transaction.set(
      groupRef,
      {
        name: groupId,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
    transaction.set(
      memberRef,
      {
        uid: request.auth.uid,
        role: "member",
        joinedAt: FieldValue.serverTimestamp(),
        lastSeenAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  });

  return {groupId, uid: request.auth.uid};
});

exports.onAlarmWrite = onDocumentWritten(
  "groups/{groupId}/alarms/{alarmId}",
  async (event) => {
    const after = event.data.after.exists ? event.data.after.data() : null;
    const before = event.data.before.exists ? event.data.before.data() : null;
    const action = after ? (before ? "alarm.updated" : "alarm.created") : "alarm.deleted";

    await fanOutToGroupDevices(event.params.groupId, {
      type: action,
      groupId: event.params.groupId,
      alarmId: event.params.alarmId,
      revision: String(after?.revision ?? before?.revision ?? 0),
    });
  },
);

exports.onCommandCreate = onDocumentCreated(
  "groups/{groupId}/commands/{commandId}",
  async (event) => {
    const command = event.data.data();
    await fanOutToGroupDevices(event.params.groupId, {
      type: "alarm.command",
      groupId: event.params.groupId,
      commandId: event.params.commandId,
      alarmId: String(command.alarmId || ""),
      commandType: String(command.commandType || ""),
      sourceDeviceId: String(command.sourceDeviceId || ""),
    });
  },
);

exports.cleanupInvalidTokens = onCall({invoker: "public"}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in before cleanup.");
  }

  const groupId = cleanId(request.data.groupId);
  const deviceIds = Array.isArray(request.data.deviceIds)
    ? request.data.deviceIds.map(cleanId).filter(Boolean)
    : [];

  if (!groupId || deviceIds.length === 0) {
    throw new HttpsError("invalid-argument", "groupId and deviceIds are required.");
  }

  const db = getFirestore();
  const member = await db
    .doc(`groups/${groupId}/members/${request.auth.uid}`)
    .get();

  if (!member.exists) {
    throw new HttpsError("permission-denied", "Join the group first.");
  }

  await Promise.all(
    deviceIds.map((deviceId) =>
      db.doc(`groups/${groupId}/devices/${deviceId}`).set(
        {
          fcmToken: FieldValue.delete(),
          notificationsEnabled: false,
          lastSeenAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
      ),
    ),
  );

  return {removed: deviceIds.length};
});

async function fanOutToGroupDevices(groupId, data) {
  const db = getFirestore();
  const snapshot = await db
    .collection(`groups/${groupId}/devices`)
    .where("notificationsEnabled", "==", true)
    .get();

  const devices = snapshot.docs
    .map((doc) => ({id: doc.id, ...doc.data()}))
    .filter((device) => typeof device.fcmToken === "string" && device.fcmToken);

  if (devices.length === 0) {
    logger.info("No FCM-capable devices", {groupId, data});
    return;
  }

  const response = await getMessaging().sendEachForMulticast({
    tokens: devices.map((device) => device.fcmToken),
    data: stringifyData(data),
    android: {priority: "high"},
    webpush: {
      headers: {Urgency: "high"},
      notification: {
        title: "Synced Alarm",
        body: data.commandType ? `Alarm ${data.commandType}` : "Alarm updated",
      },
    },
  });

  const cleanup = [];
  response.responses.forEach((result, index) => {
    if (!result.success && isInvalidTokenError(result.error)) {
      cleanup.push(
        db.doc(`groups/${groupId}/devices/${devices[index].id}`).set(
          {
            fcmToken: FieldValue.delete(),
            notificationsEnabled: false,
            lastSeenAt: FieldValue.serverTimestamp(),
          },
          {merge: true},
        ),
      );
    }
  });
  await Promise.all(cleanup);
}

function stringifyData(data) {
  return Object.fromEntries(
    Object.entries(data).map(([key, value]) => [key, String(value ?? "")]),
  );
}

function isInvalidTokenError(error) {
  const code = error?.code || "";
  return code === "messaging/invalid-registration-token" ||
    code === "messaging/registration-token-not-registered";
}

function cleanId(value) {
  return String(value || "")
    .trim()
    .replace(/[^a-zA-Z0-9_-]/g, "")
    .slice(0, 80);
}
