"use strict";

const crypto = require("crypto");
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
const logger = require("firebase-functions/logger");

initializeApp();

exports.createGroup = onCall({
  invoker: "public",
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in before creating a group.");
  }

  const name = cleanName(request.data.name) || "Alarm Group";
  const inviteCode = cleanInviteCode(request.data.inviteCode);
  if (inviteCode.length < 4) {
    throw new HttpsError("invalid-argument", "Invite code is too short.");
  }

  const db = getFirestore();
  const groupId = await uniqueGroupId(db, name);
  const groupRef = db.collection("groups").doc(groupId);
  const secretRef = db.collection("groupSecrets").doc(groupId);
  const memberRef = groupRef.collection("members").doc(request.auth.uid);
  const userRef = db.collection("users").doc(request.auth.uid);
  const userGroupRef = userRef.collection("groups").doc(groupId);

  await db.runTransaction(async (transaction) => {
    transaction.set(groupRef, {
      name,
      ownerUid: request.auth.uid,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.set(secretRef, {
      inviteCodeHash: hashInviteCode(groupId, inviteCode),
      updatedAt: FieldValue.serverTimestamp(),
    });
    writeMembership(transaction, {
      memberRef,
      userRef,
      userGroupRef,
      auth: request.auth,
      groupId,
      name,
      role: "owner",
    });
  });

  return {groupId, name};
});

exports.joinGroup = onCall({
  invoker: "public",
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in before joining a group.");
  }

  const groupId = cleanId(request.data.groupId);
  const accessCode = cleanInviteCode(
    request.data.inviteCode || request.data.accessCode,
  );

  if (!groupId) {
    throw new HttpsError("invalid-argument", "groupId is required.");
  }

  const db = getFirestore();
  const groupRef = db.collection("groups").doc(groupId);
  const secretRef = db.collection("groupSecrets").doc(groupId);
  const memberRef = groupRef.collection("members").doc(request.auth.uid);
  const userRef = db.collection("users").doc(request.auth.uid);
  const userGroupRef = userRef.collection("groups").doc(groupId);

  await db.runTransaction(async (transaction) => {
    const groupSnap = await transaction.get(groupRef);
    const secretSnap = await transaction.get(secretRef);
    const groupExists = groupSnap.exists;

    if (!groupExists) {
      throw new HttpsError("not-found", "Group was not found.");
    }

    const inviteCodeHash = secretSnap.data()?.inviteCodeHash;
    if (!inviteCodeHash) {
      throw new HttpsError("failed-precondition", "Group invite is not set.");
    }

    if (hashInviteCode(groupId, accessCode) !== inviteCodeHash) {
      throw new HttpsError("permission-denied", "Invalid invite code.");
    }

    const groupName = groupSnap.data()?.name || groupId;
    writeMembership(transaction, {
      memberRef,
      userRef,
      userGroupRef,
      auth: request.auth,
      groupId,
      name: groupName,
      role: "member",
    });
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

function cleanName(value) {
  return String(value || "").trim().slice(0, 80);
}

function cleanInviteCode(value) {
  return String(value || "").trim().slice(0, 128);
}

function hashInviteCode(groupId, inviteCode) {
  return crypto
    .createHash("sha256")
    .update(`${groupId}:${inviteCode}`)
    .digest("hex");
}

async function uniqueGroupId(db, name) {
  const prefix = cleanId(name).toLowerCase().slice(0, 24) || "group";
  for (let attempt = 0; attempt < 6; attempt += 1) {
    const groupId = `${prefix}-${crypto.randomBytes(3).toString("hex")}`;
    const existing = await db.collection("groups").doc(groupId).get();
    if (!existing.exists) return groupId;
  }
  throw new HttpsError("aborted", "Could not allocate a group id.");
}

function writeMembership(transaction, params) {
  const {
    memberRef,
    userRef,
    userGroupRef,
    auth,
    groupId,
    name,
    role,
  } = params;
  const email = auth.token.email || "";
  const displayName = auth.token.name || email.split("@")[0] || "User";
  transaction.set(
    userRef,
    {
      uid: auth.uid,
      email,
      displayName,
      lastActiveGroupId: groupId,
      updatedAt: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
  transaction.set(
    memberRef,
    {
      uid: auth.uid,
      email,
      displayName,
      role,
      joinedAt: FieldValue.serverTimestamp(),
      lastSeenAt: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
  transaction.set(
    userGroupRef,
    {
      groupId,
      name,
      role,
      joinedAt: FieldValue.serverTimestamp(),
      lastSeenAt: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
}
