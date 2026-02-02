/// Model representing a chat group
class ChatGroup {
  final int id;
  final String name;
  final String? description;
  final String icon;
  final String createdBy;
  final int memberCount;
  final int unreadCount;
  final String? lastMessage;
  final String? lastMessageFrom;
  final String? lastMessageFromName;
  final DateTime? lastMessageAt;
  final String myRole;

  const ChatGroup({
    required this.id,
    required this.name,
    this.description,
    this.icon = 'group',
    required this.createdBy,
    this.memberCount = 0,
    this.unreadCount = 0,
    this.lastMessage,
    this.lastMessageFrom,
    this.lastMessageFromName,
    this.lastMessageAt,
    this.myRole = 'member',
  });

  bool get isAdmin => myRole == 'admin';

  factory ChatGroup.fromJson(Map<String, dynamic> json) {
    return ChatGroup(
      id: int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      description: json['description'],
      icon: json['icon'] ?? 'group',
      createdBy: json['created_by'] ?? '',
      memberCount: int.tryParse(json['member_count']?.toString() ?? '0') ?? 0,
      unreadCount: int.tryParse(json['unread_count']?.toString() ?? '0') ?? 0,
      lastMessage: json['last_message'],
      lastMessageFrom: json['last_message_from'],
      lastMessageFromName: json['last_message_from_name'],
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.tryParse(json['last_message_at'])
          : null,
      myRole: json['my_role'] ?? 'member',
    );
  }
}
