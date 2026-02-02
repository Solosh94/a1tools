/// Model representing a user in the alert/chat system
class AlertUser {
  final String username;
  final String role;
  final String? firstName;
  final String? lastName;
  final String appStatus; // online, away, offline
  final bool isBirthday;
  // Chat conversation data (for WhatsApp-style list)
  final int unreadCount;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastMessageFrom;

  const AlertUser({
    required this.username,
    required this.role,
    this.firstName,
    this.lastName,
    this.appStatus = 'offline',
    this.isBirthday = false,
    this.unreadCount = 0,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageFrom,
  });

  String get displayName {
    final first = firstName ?? '';
    final last = lastName ?? '';
    String name;
    if (first.isNotEmpty || last.isNotEmpty) {
      name = '$first $last'.trim();
    } else {
      name = username;
    }
    return isBirthday ? '$name 🎂' : name;
  }

  String get displayNameWithoutEmoji {
    final first = firstName ?? '';
    final last = lastName ?? '';
    if (first.isNotEmpty || last.isNotEmpty) {
      return '$first $last'.trim();
    }
    return username;
  }

  bool get hasRealName {
    return (firstName != null && firstName!.isNotEmpty) ||
        (lastName != null && lastName!.isNotEmpty);
  }

  bool get isOnline => appStatus == 'online';
  bool get isAway => appStatus == 'away';
  bool get isOffline => appStatus == 'offline' || appStatus.isEmpty;
  bool get hasUnread => unreadCount > 0;
  bool get hasConversation => lastMessageAt != null;

  /// Create a copy with updated conversation data
  AlertUser copyWithConversation({
    int? unreadCount,
    String? lastMessage,
    DateTime? lastMessageAt,
    String? lastMessageFrom,
  }) {
    return AlertUser(
      username: username,
      role: role,
      firstName: firstName,
      lastName: lastName,
      appStatus: appStatus,
      isBirthday: isBirthday,
      unreadCount: unreadCount ?? this.unreadCount,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessageFrom: lastMessageFrom ?? this.lastMessageFrom,
    );
  }
}
