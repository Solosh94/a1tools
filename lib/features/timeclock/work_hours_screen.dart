import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app_theme.dart';
import 'time_clock_service.dart';

/// Helper class to group records by day
class _DayGroup {
  final DateTime date;
  final List<TimeRecord> records;

  _DayGroup({required this.date, required this.records});

  /// Total minutes worked across all records in this day
  int get totalMinutes => records.fold(0, (sum, r) => sum + r.minutesWorked);

  /// Formatted hours worked (e.g., "5h 30m")
  String get hoursFormatted {
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    return '${hours}h ${mins}m';
  }

  /// First clock in of the day
  DateTime get firstClockIn => records.map((r) => r.clockIn).reduce((a, b) => a.isBefore(b) ? a : b);

  /// Last clock out of the day (null if any record is still active)
  DateTime? get lastClockOut {
    if (records.any((r) => r.clockOut == null)) return null;
    return records.map((r) => r.clockOut!).reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// Whether any record in this day is still active
  bool get hasActiveRecord => records.any((r) => r.clockOut == null);

  /// Whether any record was auto clocked out
  bool get hasAutoClockOut => records.any((r) => r.autoClockOut);

  /// Combined notes from all records
  String? get combinedNotes {
    final notes = records.where((r) => r.notes != null && r.notes!.isNotEmpty).map((r) => r.notes!).toList();
    return notes.isEmpty ? null : notes.join('; ');
  }
}

/// Work Hours Screen
/// Shows the current user's own clock in/out records (read-only)
class WorkHoursScreen extends StatefulWidget {
  final String username;

  const WorkHoursScreen({
    super.key,
    required this.username,
  });

  @override
  State<WorkHoursScreen> createState() => _WorkHoursScreenState();
}

class _WorkHoursScreenState extends State<WorkHoursScreen> {
  static const Color _accent = AppColors.accent;

  // Default to current week (Monday to today)
  late DateTime _fromDate;
  late DateTime _toDate;

  List<TimeRecord> _records = [];
  bool _isLoading = true;
  String? _error;

  // Track expanded days
  final Set<String> _expandedDays = {};

  /// Get the Monday of the current week
  static DateTime _getMondayOfCurrentWeek() {
    final now = DateTime.now();
    // weekday: 1 = Monday, 7 = Sunday
    // Subtract (weekday - 1) days to get Monday
    final daysToSubtract = now.weekday - 1;
    return DateTime(now.year, now.month, now.day - daysToSubtract);
  }

  @override
  void initState() {
    super.initState();

    // Initialize date range to current week (Monday to today)
    _fromDate = _getMondayOfCurrentWeek();
    _toDate = DateTime.now();

    _loadRecords();
  }

  /// Group records by day
  List<_DayGroup> _groupRecordsByDay(List<TimeRecord> records) {
    final Map<String, List<TimeRecord>> grouped = {};

    for (final record in records) {
      final dateKey = DateFormat('yyyy-MM-dd').format(record.clockIn);
      grouped.putIfAbsent(dateKey, () => []);
      grouped[dateKey]!.add(record);
    }

    // Sort each day's records by clock in time
    for (final records in grouped.values) {
      records.sort((a, b) => a.clockIn.compareTo(b.clockIn));
    }

    // Convert to list of DayGroup and sort by date descending (newest first)
    final days = grouped.entries.map((e) {
      return _DayGroup(
        date: DateTime.parse(e.key),
        records: e.value,
      );
    }).toList();

    days.sort((a, b) => b.date.compareTo(a.date));
    return days;
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final records = await TimeClockService.getRecords(
        widget.username,
        from: _fromDate,
        to: _toDate,
      );

      if (!mounted) return;

      setState(() {
        _records = records;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: _accent,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
      _loadRecords();
    }
  }

  /// Calculate total hours worked
  double get _totalHours {
    int totalMinutes = 0;
    for (final record in _records) {
      totalMinutes += record.minutesWorked;
    }
    return totalMinutes / 60;
  }

  /// Calculate unique days worked
  int get _uniqueDays {
    final uniqueDates = <String>{};
    for (final record in _records) {
      final dateKey = DateFormat('yyyy-MM-dd').format(record.clockIn);
      uniqueDates.add(dateKey);
    }
    return uniqueDates.length;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Column(
          children: [
            const Text('My Work Hours'),
            Text(
              widget.username,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: 'Change date range',
            onPressed: _selectDateRange,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadRecords,
          ),
        ],
      ),
      backgroundColor: bgColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadRecords,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRecords,
                  color: _accent,
                  child: CustomScrollView(
                    slivers: [
                      // Date range header
                      SliverToBoxAdapter(
                        child: GestureDetector(
                          onTap: _selectDateRange,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.calendar_today, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  '${DateFormat('MMM d, yyyy').format(_fromDate)} - ${DateFormat('MMM d, yyyy').format(_toDate)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.expand_more, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Summary card
                      SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _accent.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildSummaryItem(
                                icon: Icons.access_time,
                                value: '${_totalHours.toStringAsFixed(1)}h',
                                label: 'Total Hours',
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.grey.withValues(alpha: 0.3),
                              ),
                              _buildSummaryItem(
                                icon: Icons.calendar_today,
                                value: _uniqueDays.toString(),
                                label: 'Days Worked',
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.grey.withValues(alpha: 0.3),
                              ),
                              _buildSummaryItem(
                                icon: Icons.receipt_long,
                                value: _records.length.toString(),
                                label: 'Records',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 16),
                      ),
                      // Records list
                      if (_records.isEmpty)
                        SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(48),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.schedule,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No records found',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Try selecting a different date range',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final dayGroups = _groupRecordsByDay(_records);
                              if (index >= dayGroups.length) return null;
                              final dayGroup = dayGroups[index];
                              return _buildDayCard(dayGroup, cardColor, isDark);
                            },
                            childCount: _groupRecordsByDay(_records).length,
                          ),
                        ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 32),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: _accent),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildDayCard(_DayGroup dayGroup, Color cardColor, bool isDark) {
    final dateKey = DateFormat('yyyy-MM-dd').format(dayGroup.date);
    final isExpanded = _expandedDays.contains(dateKey);
    final isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == dateKey;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: isToday
            ? Border.all(color: _accent, width: 2)
            : Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          // Day header (tappable)
          InkWell(
            onTap: dayGroup.records.length > 1
                ? () {
                    setState(() {
                      if (isExpanded) {
                        _expandedDays.remove(dateKey);
                      } else {
                        _expandedDays.add(dateKey);
                      }
                    });
                  }
                : null,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Date column
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isToday ? _accent : _accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('d').format(dayGroup.date),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isToday ? Colors.white : _accent,
                          ),
                        ),
                        Text(
                          DateFormat('EEE').format(dayGroup.date),
                          style: TextStyle(
                            fontSize: 11,
                            color: isToday ? Colors.white70 : _accent.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              DateFormat('MMMM d, yyyy').format(dayGroup.date),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (isToday) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _accent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Today',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                            if (dayGroup.hasActiveRecord) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Active',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              dayGroup.hoursFormatted,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white70 : Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              '${DateFormat('h:mm a').format(dayGroup.firstClockIn)} - ${dayGroup.lastClockOut != null ? DateFormat('h:mm a').format(dayGroup.lastClockOut!) : 'Active'}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        // Notes hidden from user view - only visible in Management > Time Records
                      ],
                    ),
                  ),
                  // Expand indicator (only if multiple records)
                  if (dayGroup.records.length > 1) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${dayGroup.records.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Expanded individual records
          if (isExpanded && dayGroup.records.length > 1)
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.black12 : Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Column(
                children: [
                  const Divider(height: 1),
                  ...dayGroup.records.map((record) => _buildRecordRow(record, isDark)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecordRow(TimeRecord record, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(
            record.clockOut == null ? Icons.login : Icons.schedule,
            size: 16,
            color: record.clockOut == null ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 12),
          Text(
            DateFormat('h:mm a').format(record.clockIn),
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            record.clockOut != null
                ? DateFormat('h:mm a').format(record.clockOut!)
                : 'Active',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: record.clockOut == null ? Colors.green : null,
            ),
          ),
          const Spacer(),
          if (record.minutesWorked > 0)
            Text(
              '${record.minutesWorked ~/ 60}h ${record.minutesWorked % 60}m',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          if (record.autoClockOut) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: 'Auto clocked out',
              child: Icon(
                Icons.warning_amber,
                size: 16,
                color: Colors.orange.shade400,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
