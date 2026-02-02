/// Model representing a direct message in the chat system
class ChatMessage {
  final int id;
  final String fromUsername;
  final String toUsername;
  final String message;
  final bool isRead;
  final DateTime createdAt;
  final String? attachmentName;
  final String? attachmentUrl;
  final String? attachmentType;

  ChatMessage({
    required this.id,
    required this.fromUsername,
    required this.toUsername,
    required this.message,
    required this.isRead,
    required this.createdAt,
    this.attachmentName,
    this.attachmentUrl,
    this.attachmentType,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: int.parse(json['id'].toString()),
      fromUsername: json['from_username'] ?? '',
      toUsername: json['to_username'] ?? '',
      message: json['message'] ?? '',
      isRead: json['is_read'] == 1 || json['is_read'] == '1' || json['is_read'] == true,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      attachmentName: json['attachment_name'],
      attachmentUrl: json['attachment_url'],
      attachmentType: json['attachment_type'],
    );
  }

  bool get hasAttachment => attachmentUrl != null && attachmentUrl!.isNotEmpty;
}
