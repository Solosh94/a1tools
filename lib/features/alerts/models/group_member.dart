/// Model representing a member of a chat group
class GroupMember {
  final String username;
  final String displayName;
  final String role;
  final String? appStatus;

  const GroupMember({
    required this.username,
    required this.displayName,
    this.role = 'member',
    this.appStatus,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      username: json['username'] ?? '',
      displayName: json['display_name'] ?? json['username'] ?? '',
      role: json['role'] ?? 'member',
      appStatus: json['app_status'],
    );
  }
}
