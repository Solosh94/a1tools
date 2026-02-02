/// Model representing a message in a group chat
class GroupMessage {
  final int id;
  final String fromUsername;
  final String fromDisplayName;
  final String message;
  final String? attachmentName;
  final String? attachmentUrl;
  final String? attachmentType;
  final DateTime createdAt;

  const GroupMessage({
    required this.id,
    required this.fromUsername,
    required this.fromDisplayName,
    required this.message,
    this.attachmentName,
    this.attachmentUrl,
    this.attachmentType,
    required this.createdAt,
  });

  bool get hasAttachment => attachmentUrl != null && attachmentUrl!.isNotEmpty;
  bool get isSystem => fromUsername == 'system';

  factory GroupMessage.fromJson(Map<String, dynamic> json) {
    return GroupMessage(
      id: int.parse(json['id'].toString()),
      fromUsername: json['from_username'] ?? '',
      fromDisplayName: json['from_display_name'] ?? json['from_username'] ?? '',
      message: json['message'] ?? '',
      attachmentName: json['attachment_name'],
      attachmentUrl: json['attachment_url'],
      attachmentType: json['attachment_type'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}
