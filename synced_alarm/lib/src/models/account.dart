class AppUserProfile {
  const AppUserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    this.lastActiveGroupId,
  });

  factory AppUserProfile.fromJson(String uid, Map<String, Object?> json) {
    return AppUserProfile(
      uid: uid,
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'User',
      lastActiveGroupId: json['lastActiveGroupId'] as String?,
    );
  }

  final String uid;
  final String email;
  final String displayName;
  final String? lastActiveGroupId;
}

class AlarmGroupSummary {
  const AlarmGroupSummary({
    required this.groupId,
    required this.name,
    required this.role,
  });

  factory AlarmGroupSummary.fromJson(
    String groupId,
    Map<String, Object?> json,
  ) {
    return AlarmGroupSummary(
      groupId: groupId,
      name: json['name'] as String? ?? groupId,
      role: json['role'] as String? ?? 'member',
    );
  }

  final String groupId;
  final String name;
  final String role;
}
