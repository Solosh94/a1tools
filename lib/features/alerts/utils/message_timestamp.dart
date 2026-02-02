/// Format message timestamp as exact local time
String formatMessageTimestamp(DateTime time) {
  // Convert to local time
  final localTime = time.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final messageDate = DateTime(localTime.year, localTime.month, localTime.day);

  // Format time as HH:MM AM/PM
  final hour = localTime.hour > 12
      ? localTime.hour - 12
      : (localTime.hour == 0 ? 12 : localTime.hour);
  final minute = localTime.minute.toString().padLeft(2, '0');
  final period = localTime.hour >= 12 ? 'PM' : 'AM';
  final timeStr = '$hour:$minute $period';

  // If today, show just time
  if (messageDate == today) {
    return timeStr;
  }

  // If yesterday, show "Yesterday" + time
  final yesterday = today.subtract(const Duration(days: 1));
  if (messageDate == yesterday) {
    return 'Yesterday $timeStr';
  }

  // If within this week, show day name + time
  final diff = today.difference(messageDate).inDays;
  if (diff < 7) {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return '${days[localTime.weekday % 7]} $timeStr';
  }

  // Otherwise show date + time
  return '${localTime.month}/${localTime.day} $timeStr';
}
