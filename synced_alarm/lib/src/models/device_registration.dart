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

  factory DeviceRegistration.fromJson(String id, Map<String, dynamic> json) {
    return DeviceRegistration(
      id: id,
      uid: json['uid'] as String? ?? '',
      groupId: json['groupId'] as String? ?? '',
      platform: json['platform'] as String? ?? 'unknown',
      displayName: json['displayName'] as String? ?? 'Device',
      lastSeenAt: json['lastSeenAt'] != null
          ? DateTime.parse(json['lastSeenAt'] as String)
          : DateTime.now(),
      fcmToken: json['fcmToken'] as String?,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? false,
    );
  }
}
