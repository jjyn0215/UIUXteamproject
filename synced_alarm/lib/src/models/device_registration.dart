class DeviceRegistration {
  const DeviceRegistration({
    required this.id,
    required this.uid,
    required this.groupId,
    required this.platform,
    required this.displayName,
    required this.lastSeenAt,
    this.fcmToken,
    this.notificationsEnabled = false,
  });

  final String id;
  final String uid;
  final String groupId;
  final String platform;
  final String displayName;
  final String? fcmToken;
  final DateTime lastSeenAt;
  final bool notificationsEnabled;

  Map<String, Object?> toJson() {
    return {
      'uid': uid,
      'groupId': groupId,
      'deviceId': id,
      'platform': platform,
      'displayName': displayName,
      'fcmToken': fcmToken,
      'lastSeenAt': lastSeenAt.toIso8601String(),
      'notificationsEnabled': notificationsEnabled,
    };
  }
}
