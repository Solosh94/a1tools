/// Date Cell Widget
/// Displays and edits date column values
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateCell extends StatelessWidget {
  final dynamic value;
  final Function(String) onChanged;

  const DateCell({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    DateTime? date;
    if (value != null) {
      if (value is DateTime) {
        date = value;
      } else if (value is String && value.isNotEmpty) {
        date = DateTime.tryParse(value);
      }
    }

    final isOverdue = date != null && date.isBefore(DateTime.now());
    final isToday = date != null &&
        date.year == DateTime.now().year &&
        date.month == DateTime.now().month &&
        date.day == DateTime.now().day;

    // Default text color based on theme
    final defaultColor = isDark ? Colors.white : Colors.black87;
    final placeholderColor = isDark ? Colors.grey.shade500 : Colors.grey.shade400;

    // Build accessibility label
    String accessibilityLabel;
    if (date == null) {
      accessibilityLabel = 'Date: Not set';
    } else if (isOverdue) {
      accessibilityLabel = 'Date: ${_formatDate(date)}, overdue';
    } else if (isToday) {
      accessibilityLabel = 'Date: Today';
    } else {
      accessibilityLabel = 'Date: ${_formatDate(date)}';
    }

    return Semantics(
      label: accessibilityLabel,
      button: true,
      hint: 'Tap to change date',
      child: InkWell(
        onTap: () => _showDatePicker(context, date),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isOverdue
                ? Colors.red.withValues(alpha: 0.1)
                : isToday
                    ? Colors.blue.withValues(alpha: 0.1)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today,
                size: 12,
                color: isOverdue
                    ? Colors.red
                    : isToday
                        ? Colors.blue
                        : Colors.grey.shade500,
              ),
              const SizedBox(width: 4),
              Text(
                date != null ? _formatDate(date) : 'Set date',
                style: TextStyle(
                  fontSize: 12,
                  color: isOverdue
                      ? Colors.red
                      : isToday
                          ? Colors.blue
                          : date != null
                              ? defaultColor
                              : placeholderColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == tomorrow) {
      return 'Tomorrow';
    } else if (date.year == now.year) {
      return DateFormat('MMM d').format(date);
    } else {
      return DateFormat('MMM d, y').format(date);
    }
  }

  void _showDatePicker(BuildContext context, DateTime? currentDate) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: currentDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (selected != null) {
      onChanged(selected.toIso8601String().split('T').first);
    }
  }
}
