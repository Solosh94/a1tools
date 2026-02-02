/// Calendar View Widget
/// Displays board items in a calendar layout based on date columns
library;

import 'package:flutter/material.dart';
import '../../../app_theme.dart';
import '../models/sunday_models.dart';

class CalendarView extends StatefulWidget {
  final SundayBoard board;
  final String username;
  final Function(SundayItem) onItemTap;
  final VoidCallback onRefresh;

  const CalendarView({
    super.key,
    required this.board,
    required this.username,
    required this.onItemTap,
    required this.onRefresh,
  });

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  late DateTime _currentMonth;
  late DateTime _selectedDate;
  String? _selectedDateColumn;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime.now();
    _selectedDate = DateTime.now();

    // Find the first date column
    final dateColumns = widget.board.columns.where((c) => c.type == ColumnType.date).toList();
    if (dateColumns.isNotEmpty) {
      _selectedDateColumn = dateColumns.first.key;
    }
  }

  List<SundayItem> _getItemsForDate(DateTime date) {
    if (_selectedDateColumn == null) return [];

    final items = <SundayItem>[];
    for (final group in widget.board.groups) {
      for (final item in group.items) {
        final dateValue = item.columnValues[_selectedDateColumn];
        if (dateValue != null) {
          final itemDate = DateTime.tryParse(dateValue.toString());
          if (itemDate != null &&
              itemDate.year == date.year &&
              itemDate.month == date.month &&
              itemDate.day == date.day) {
            items.add(item);
          }
        }
      }
    }
    return items;
  }

  Map<DateTime, List<SundayItem>> _getItemsByDate() {
    if (_selectedDateColumn == null) return {};

    final itemsByDate = <DateTime, List<SundayItem>>{};
    for (final group in widget.board.groups) {
      for (final item in group.items) {
        final dateValue = item.columnValues[_selectedDateColumn];
        if (dateValue != null) {
          final itemDate = DateTime.tryParse(dateValue.toString());
          if (itemDate != null) {
            final dateKey = DateTime(itemDate.year, itemDate.month, itemDate.day);
            itemsByDate.putIfAbsent(dateKey, () => []).add(item);
          }
        }
      }
    }
    return itemsByDate;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateColumns = widget.board.columns.where((c) => c.type == ColumnType.date).toList();

    return Column(
      children: [
        // Date column selector
        if (dateColumns.length > 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Show dates from:',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _selectedDateColumn,
                  items: dateColumns.map((col) {
                    return DropdownMenuItem(
                      value: col.key,
                      child: Text(col.title),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedDateColumn = value);
                  },
                ),
              ],
            ),
          ),

        // Calendar
        Expanded(
          child: Row(
            children: [
              // Calendar grid
              Expanded(
                flex: 2,
                child: _buildCalendarGrid(isDark),
              ),

              // Selected date items
              Container(
                width: 300,
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    ),
                  ),
                ),
                child: _buildSelectedDateItems(isDark),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(bool isDark) {
    final itemsByDate = _getItemsByDate();
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday % 7; // Sunday = 0

    final daysInMonth = lastDayOfMonth.day;
    final totalCells = ((firstWeekday + daysInMonth) / 7).ceil() * 7;

    return Column(
      children: [
        // Month navigation
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
                  });
                },
              ),
              Text(
                '${_getMonthName(_currentMonth.month)} ${_currentMonth.year}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
                  });
                },
              ),
              const SizedBox(width: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    _currentMonth = DateTime.now();
                    _selectedDate = DateTime.now();
                  });
                },
                child: const Text('Today'),
              ),
            ],
          ),
        ),

        // Day headers
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 8),

        // Calendar cells
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.0,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: totalCells,
            itemBuilder: (context, index) {
              final dayNumber = index - firstWeekday + 1;
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox();
              }

              final date = DateTime(_currentMonth.year, _currentMonth.month, dayNumber);
              final items = itemsByDate[date] ?? [];
              final isToday = _isToday(date);
              final isSelected = _isSameDay(date, _selectedDate);

              return _buildDayCell(date, dayNumber, items, isToday, isSelected, isDark);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDayCell(DateTime date, int dayNumber, List<SundayItem> items, bool isToday, bool isSelected, bool isDark) {
    final bgColor = isSelected
        ? AppColors.accent
        : isToday
            ? AppColors.accent.withValues(alpha: 0.2)
            : isDark
                ? Colors.grey.shade900
                : Colors.grey.shade50;

    final textColor = isSelected
        ? Colors.white
        : isDark
            ? Colors.white
            : Colors.black87;

    return InkWell(
      onTap: () {
        setState(() => _selectedDate = date);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: isToday && !isSelected
              ? Border.all(color: AppColors.accent, width: 2)
              : isDark
                  ? Border.all(color: Colors.grey.shade800)
                  : null,
        ),
        child: Column(
          children: [
            const SizedBox(height: 4),
            Text(
              '$dayNumber',
              style: TextStyle(
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: textColor,
                fontSize: 14,
              ),
            ),
            if (items.isNotEmpty) ...[
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.3) : AppColors.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${items.length}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.accent,
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDateItems(bool isDark) {
    final items = _getItemsForDate(_selectedDate);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              ),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today,
                size: 18,
                color: AppColors.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _formatSelectedDate(_selectedDate),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${items.length} items',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.accent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Items list
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.event_available,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No items on this date',
                        style: TextStyle(color: subtextColor),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _buildItemCard(item, isDark, textColor, subtextColor);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildItemCard(SundayItem item, bool isDark, Color textColor, Color subtextColor) {
    // Find status
    final statusColumn = widget.board.columns.firstWhere(
      (c) => c.type == ColumnType.status,
      orElse: () => widget.board.columns.first,
    );
    final statusValue = item.columnValues[statusColumn.key];
    StatusLabel? statusLabel;
    if (statusValue != null && statusColumn.type == ColumnType.status) {
      statusLabel = statusColumn.statusLabels.firstWhere(
        (l) => l.id == statusValue || l.label == statusValue,
        orElse: () => StatusLabel(id: '', label: statusValue.toString(), color: '#808080'),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isDark ? Colors.grey.shade800 : null,
      child: InkWell(
        onTap: () => widget.onItemTap(item),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (statusLabel != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusLabel.colorValue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusLabel.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: statusLabel.colorValue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June',
                   'July', 'August', 'September', 'October', 'November', 'December'];
    return months[month - 1];
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatSelectedDate(DateTime date) {
    final weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    return '${weekdays[date.weekday % 7]}, ${_getMonthName(date.month)} ${date.day}';
  }
}
