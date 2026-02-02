/// Timeline View Widget
/// Displays board items in a Gantt-style timeline based on date columns
library;

import 'package:flutter/material.dart';
import '../../../app_theme.dart';
import '../models/sunday_models.dart';

class TimelineView extends StatefulWidget {
  final SundayBoard board;
  final String username;
  final Function(SundayItem) onItemTap;
  final VoidCallback onRefresh;

  const TimelineView({
    super.key,
    required this.board,
    required this.username,
    required this.onItemTap,
    required this.onRefresh,
  });

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView> {
  late DateTime _startDate;
  late DateTime _endDate;
  String? _dateColumn;
  double _dayWidth = 40;
  final ScrollController _horizontalController = ScrollController();

  // Synchronized vertical scroll controllers for items column and timeline rows
  final ScrollController _itemsVerticalController = ScrollController();
  final ScrollController _timelineVerticalController = ScrollController();
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _initializeDates();
    _setupScrollSync();
  }

  void _setupScrollSync() {
    _itemsVerticalController.addListener(() {
      if (!_isSyncing) {
        _isSyncing = true;
        _timelineVerticalController.jumpTo(_itemsVerticalController.offset);
        _isSyncing = false;
      }
    });
    _timelineVerticalController.addListener(() {
      if (!_isSyncing) {
        _isSyncing = true;
        _itemsVerticalController.jumpTo(_timelineVerticalController.offset);
        _isSyncing = false;
      }
    });
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _itemsVerticalController.dispose();
    _timelineVerticalController.dispose();
    super.dispose();
  }

  void _initializeDates() {
    // Set default date range (current month)
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 2, 0);

    // Find date column
    final dateColumns = widget.board.columns.where((c) => c.type == ColumnType.date).toList();
    if (dateColumns.isNotEmpty) {
      _dateColumn = dateColumns.first.key;
    }
  }

  List<DateTime> _getDaysInRange() {
    final days = <DateTime>[];
    var current = _startDate;
    while (!current.isAfter(_endDate)) {
      days.add(current);
      current = current.add(const Duration(days: 1));
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateColumns = widget.board.columns.where((c) => c.type == ColumnType.date).toList();
    final days = _getDaysInRange();

    if (_dateColumn == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.date_range,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No date columns in this board',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a date column to use Timeline view',
              style: TextStyle(
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              ),
            ),
          ),
          child: Row(
            children: [
              // Date column selector
              if (dateColumns.length > 1) ...[
                Text(
                  'Date:',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _dateColumn,
                  underline: const SizedBox(),
                  items: dateColumns.map((col) {
                    return DropdownMenuItem(
                      value: col.key,
                      child: Text(col.title),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _dateColumn = value);
                  },
                ),
                const SizedBox(width: 24),
              ],

              // Navigation
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _startDate = _startDate.subtract(const Duration(days: 7));
                    _endDate = _endDate.subtract(const Duration(days: 7));
                  });
                },
                tooltip: 'Previous week',
              ),
              TextButton(
                onPressed: () {
                  final now = DateTime.now();
                  setState(() {
                    _startDate = DateTime(now.year, now.month, 1);
                    _endDate = DateTime(now.year, now.month + 2, 0);
                  });
                },
                child: const Text('Today'),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _startDate = _startDate.add(const Duration(days: 7));
                    _endDate = _endDate.add(const Duration(days: 7));
                  });
                },
                tooltip: 'Next week',
              ),

              const Spacer(),

              // Zoom controls
              Text(
                'Zoom:',
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              Slider(
                value: _dayWidth,
                min: 20,
                max: 80,
                onChanged: (value) {
                  setState(() => _dayWidth = value);
                },
              ),
            ],
          ),
        ),

        // Timeline content
        Expanded(
          child: Row(
            children: [
              // Items column (fixed)
              Container(
                width: 200,
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    // Header placeholder to match date header height
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                        border: Border(
                          bottom: BorderSide(
                            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Items',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ),
                    // Scrollable items list
                    Expanded(
                      child: _buildItemsColumn(isDark),
                    ),
                  ],
                ),
              ),

              // Timeline grid (scrollable)
              Expanded(
                child: SingleChildScrollView(
                  controller: _horizontalController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: days.length * _dayWidth,
                    child: Column(
                      children: [
                        // Header with dates
                        _buildDateHeader(days, isDark),

                        // Timeline rows
                        Expanded(
                          child: _buildTimelineRows(days, isDark),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemsColumn(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;

    return ListView.builder(
      controller: _itemsVerticalController,
      itemCount: widget.board.groups.expand((g) => g.items).length + widget.board.groups.length,
      itemBuilder: (context, index) {
        int currentIndex = 0;
        for (final group in widget.board.groups) {
          // Group header
          if (currentIndex == index) {
            return Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: group.colorValue.withValues(alpha: isDark ? 0.3 : 0.1),
              ),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: group.colorValue,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      group.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }
          currentIndex++;

          // Items
          for (final item in group.items) {
            if (currentIndex == index) {
              return Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      width: 0.5,
                    ),
                  ),
                ),
                child: InkWell(
                  onTap: () => widget.onItemTap(item),
                  child: Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 13,
                      color: textColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            }
            currentIndex++;
          }
        }
        return const SizedBox();
      },
    );
  }

  Widget _buildDateHeader(List<DateTime> days, bool isDark) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: days.map((day) {
          final isToday = _isToday(day);
          final isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;

          return Container(
            width: _dayWidth,
            decoration: BoxDecoration(
              color: isToday
                  ? AppColors.accent.withValues(alpha: 0.2)
                  : isWeekend
                      ? (isDark ? Colors.grey.shade800.withValues(alpha: 0.5) : Colors.grey.shade200)
                      : null,
              border: Border(
                right: BorderSide(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  width: 0.5,
                ),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _getWeekdayShort(day.weekday),
                  style: TextStyle(
                    fontSize: 10,
                    color: isToday
                        ? AppColors.accent
                        : isDark
                            ? Colors.grey.shade500
                            : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    color: isToday
                        ? AppColors.accent
                        : isDark
                            ? Colors.white
                            : Colors.black87,
                  ),
                ),
                if (day.day == 1)
                  Text(
                    _getMonthShort(day.month),
                    style: TextStyle(
                      fontSize: 9,
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimelineRows(List<DateTime> days, bool isDark) {
    return ListView.builder(
      controller: _timelineVerticalController,
      itemCount: widget.board.groups.expand((g) => g.items).length + widget.board.groups.length,
      itemBuilder: (context, index) {
        int currentIndex = 0;
        for (final group in widget.board.groups) {
          // Group header row
          if (currentIndex == index) {
            return Container(
              height: 40,
              color: group.colorValue.withValues(alpha: isDark ? 0.1 : 0.05),
              child: Row(
                children: days.map((day) {
                  return Container(
                    width: _dayWidth,
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                          width: 0.5,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          }
          currentIndex++;

          // Item rows
          for (final item in group.items) {
            if (currentIndex == index) {
              return _buildItemTimelineRow(item, group, days, isDark);
            }
            currentIndex++;
          }
        }
        return const SizedBox();
      },
    );
  }

  Widget _buildItemTimelineRow(SundayItem item, SundayGroup group, List<DateTime> days, bool isDark) {
    final dateValue = item.columnValues[_dateColumn];
    DateTime? itemDate;
    if (dateValue != null && dateValue.toString().isNotEmpty) {
      itemDate = DateTime.tryParse(dateValue.toString());
    }

    return Container(
      height: 36,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            width: 0.5,
          ),
        ),
      ),
      child: Stack(
        children: [
          // Grid lines
          Row(
            children: days.map((day) {
              final isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
              return Container(
                width: _dayWidth,
                decoration: BoxDecoration(
                  color: isWeekend
                      ? (isDark ? Colors.grey.shade800.withValues(alpha: 0.3) : Colors.grey.shade100)
                      : null,
                  border: Border(
                    right: BorderSide(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      width: 0.5,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          // Item bar or no-date indicator
          if (itemDate != null)
            _buildItemBar(item, group, itemDate, days, isDark)
          else
            Positioned(
              left: 8,
              top: 10,
              child: Tooltip(
                message: '${item.name}\nNo date set',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_busy,
                      size: 14,
                      color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'No date',
                      style: TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemBar(SundayItem item, SundayGroup group, DateTime itemDate, List<DateTime> days, bool isDark) {
    // Find the index of the item's date
    final dayIndex = days.indexWhere((d) =>
        d.year == itemDate.year && d.month == itemDate.month && d.day == itemDate.day);

    if (dayIndex < 0) {
      // Date is outside visible range - show indicator at edge
      final isBeforeRange = itemDate.isBefore(_startDate);
      return Positioned(
        left: isBeforeRange ? 4 : null,
        right: isBeforeRange ? null : 4,
        top: 10,
        child: Tooltip(
          message: '${item.name}\n${_formatDate(itemDate)}\n(${isBeforeRange ? "Before" : "After"} visible range)',
          child: Icon(
            isBeforeRange ? Icons.arrow_back : Icons.arrow_forward,
            size: 16,
            color: group.colorValue.withValues(alpha: 0.7),
          ),
        ),
      );
    }

    final left = dayIndex * _dayWidth + 2;

    return Positioned(
      left: left,
      top: 6,
      child: Tooltip(
        message: '${item.name}\n${_formatDate(itemDate)}',
        child: InkWell(
          onTap: () => widget.onItemTap(item),
          child: Container(
            width: _dayWidth - 4,
            height: 24,
            decoration: BoxDecoration(
              color: group.colorValue,
              borderRadius: BorderRadius.circular(4),
            ),
            child: _dayWidth >= 50
                ? Center(
                    child: Text(
                      item.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  String _getWeekdayShort(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  String _getMonthShort(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  String _formatDate(DateTime date) {
    return '${_getMonthShort(date.month)} ${date.day}, ${date.year}';
  }
}
