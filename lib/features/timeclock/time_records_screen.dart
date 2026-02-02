import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'time_clock_service.dart';
import '../../config/api_config.dart';
import '../../app_theme.dart';
import '../auth/auth_service.dart';

/// Helper class to group records by day
class DayGroup {
  final DateTime date;
  final List<TimeRecord> records;
  
  DayGroup({required this.date, required this.records});
  
  /// Total minutes worked across all records in this day
  int get totalMinutes => records.fold(0, (sum, r) => sum + r.minutesWorked);
  
  /// Total hours worked
  double get totalHours => totalMinutes / 60;
  
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

/// Time Records Dashboard
/// Shows all users' clock in/out records for managers
class TimeRecordsScreen extends StatefulWidget {
  const TimeRecordsScreen({super.key});

  @override
  State<TimeRecordsScreen> createState() => _TimeRecordsScreenState();
}

class _TimeRecordsScreenState extends State<TimeRecordsScreen> with SingleTickerProviderStateMixin {
  static const String _pictureUrl = ApiConfig.profilePicture;
  static const Color _accent = AppColors.accent;

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  // Default to current week (Monday to today)
  late DateTime _fromDate;
  late DateTime _toDate;

  /// Get the Monday of the current week
  static DateTime _getMondayOfCurrentWeek() {
    final now = DateTime.now();
    // weekday: 1 = Monday, 7 = Sunday
    // Subtract (weekday - 1) days to get Monday
    final daysToSubtract = now.weekday - 1;
    return DateTime(now.year, now.month, now.day - daysToSubtract);
  }
  
  AllRecordsResult? _allRecords;
  DayStatusResult? _dayStatuses;
  bool _isLoading = true;
  String? _error;
  
  String? _selectedUser;
  String _searchQuery = '';
  
  // Track expanded days (for showing individual records)
  final Set<String> _expandedDays = {};
  
  // Profile picture cache
  final Map<String, Uint8List?> _profilePictures = {};
  final Set<String> _loadingPictures = {};

  // Current manager's username for audit trail
  String? _currentManagerUsername;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Initialize date range to current week (Monday to today)
    _fromDate = _getMondayOfCurrentWeek();
    _toDate = DateTime.now();

    _loadCurrentUser();
    _loadRecords();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  Future<void> _loadCurrentUser() async {
    final username = await AuthService.getLoggedInUsername();
    if (mounted) {
      setState(() => _currentManagerUsername = username);
    }
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
  
  /// Calculate unique days from records
  int _getUniqueDays(List<TimeRecord> records) {
    final uniqueDates = <String>{};
    for (final record in records) {
      final dateKey = DateFormat('yyyy-MM-dd').format(record.clockIn);
      uniqueDates.add(dateKey);
    }
    return uniqueDates.length;
  }
  
  /// Group records by day
  List<DayGroup> _groupRecordsByDay(List<TimeRecord> records) {
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
      return DayGroup(
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
    
    // Load both records and day statuses in parallel
    final results = await Future.wait([
      TimeClockService.getAllRecords(from: _fromDate, to: _toDate),
      TimeClockService.getDayStatuses(from: _fromDate, to: _toDate),
    ]);
    
    final allRecords = results[0] as AllRecordsResult?;
    final dayStatuses = results[1] as DayStatusResult?;
    
    if (mounted) {
      setState(() {
        _allRecords = allRecords;
        _dayStatuses = dayStatuses;
        _isLoading = false;
        if (allRecords == null) {
          _error = 'Failed to load time records';
        } else {
          // Load profile pictures for all users
          for (final user in allRecords.byUser) {
            _loadProfilePicture(user.username);
          }
        }
      });
    }
  }
  
  Future<void> _loadProfilePicture(String username) async {
    if (_profilePictures.containsKey(username) || _loadingPictures.contains(username)) {
      return;
    }
    
    _loadingPictures.add(username);
    
    try {
      final response = await http.get(
        Uri.parse('$_pictureUrl?username=${Uri.encodeComponent(username)}'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['picture'] != null) {
          final bytes = base64Decode(data['picture']);
          if (mounted) {
            setState(() {
              _profilePictures[username] = bytes;
            });
          }
        } else {
          _profilePictures[username] = null;
        }
      }
    } catch (e) {
      _profilePictures[username] = null;
    } finally {
      _loadingPictures.remove(username);
    }
  }
  
  Widget _buildProfileAvatar(String username, String displayName, {double radius = 14}) {
    final picture = _profilePictures[username];
    
    return CircleAvatar(
      radius: radius,
      backgroundColor: _accent.withValues(alpha: 0.2),
      backgroundImage: picture != null ? MemoryImage(picture) : null,
      child: picture == null
          ? Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
              style: TextStyle(
                color: _accent,
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.8,
              ),
            )
          : null,
    );
  }
  
  List<UserSummary> get _filteredUsers {
    if (_allRecords == null) return [];
    if (_searchQuery.isEmpty) return _allRecords!.byUser;
    
    return _allRecords!.byUser.where((user) {
      return user.displayName.toLowerCase().contains(_searchQuery) ||
             user.username.toLowerCase().contains(_searchQuery);
    }).toList();
  }
  
  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFF49320),
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
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
  
  Future<void> _downloadRecords({String? username}) async {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('HH:mm');
    
    List<TimeRecord> records;
    String fileName;
    
    if (username != null) {
      final user = _allRecords!.byUser.firstWhere((u) => u.username == username);
      records = user.records;
      fileName = 'time_records_${user.displayName.replaceAll(' ', '_')}_${dateFormat.format(_fromDate)}_to_${dateFormat.format(_toDate)}.csv';
    } else {
      records = _allRecords!.records;
      fileName = 'time_records_all_${dateFormat.format(_fromDate)}_to_${dateFormat.format(_toDate)}.csv';
    }
    
    // Create CSV content
    final buffer = StringBuffer();
    buffer.writeln('Name,Username,Date,Clock In,Clock Out,Hours Worked,Auto Clock Out,Notes');
    
    for (final record in records) {
      final date = dateFormat.format(record.clockIn);
      final clockIn = timeFormat.format(record.clockIn);
      final clockOut = record.clockOut != null ? timeFormat.format(record.clockOut!) : 'Active';
      final hours = record.hoursWorkedFormatted;
      final auto = record.autoClockOut ? 'Yes' : 'No';
      final notes = (record.notes ?? '').replaceAll(',', ';').replaceAll('\n', ' ');
      
      buffer.writeln('${record.displayName},${record.username ?? ''},$date,$clockIn,$clockOut,$hours,$auto,$notes');
    }
    
    try {
      // Get downloads directory
      Directory? dir;
      if (Platform.isWindows) {
        dir = await getDownloadsDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }
      
      if (dir == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not access downloads folder'), backgroundColor: Colors.red),
          );
        }
        return;
      }
      
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(buffer.toString());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded: $fileName'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () => launchUrl(Uri.file(file.path)),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  /// Download simple summary report (Name, Days, Total Hours, From, To)
  Future<void> _downloadSummaryReport() async {
    if (_allRecords == null) return;

    final dateFormat = DateFormat('yyyy-MM-dd');
    final fromStr = dateFormat.format(_fromDate);
    final toStr = dateFormat.format(_toDate);

    final fileName = 'time_summary_${fromStr}_to_$toStr.csv';

    // Create CSV content
    final buffer = StringBuffer();
    buffer.writeln('Name,Days Worked,Total Hours,From Date,To Date');

    for (final user in _allRecords!.byUser) {
      final uniqueDays = _getUniqueDays(user.records);
      // Escape name if it contains commas
      final safeName = user.displayName.contains(',')
          ? '"${user.displayName}"'
          : user.displayName;
      buffer.writeln('$safeName,$uniqueDays,${user.totalHours.toStringAsFixed(2)},$fromStr,$toStr');
    }

    try {
      // Get downloads directory
      Directory? dir;
      if (Platform.isWindows) {
        dir = await getDownloadsDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      if (dir == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not access downloads folder'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      final file = File('${dir.path}/$fileName');
      await file.writeAsString(buffer.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Summary downloaded: $fileName'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () => launchUrl(Uri.file(file.path)),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Send weekly time report via email
  Future<void> _sendWeeklyEmailReport() async {
    final extraEmailController = TextEditingController();

    // Show confirmation dialog with preview option and extra email field
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Weekly Time Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This will send an email report for the previous week (Monday to Sunday) to:'),
            const SizedBox(height: 12),
            const Text('- dismanager@a-1chimney.com', style: TextStyle(fontFamily: 'monospace')),
            const Text('- dev@a-1chimney.com', style: TextStyle(fontFamily: 'monospace')),
            const SizedBox(height: 16),
            TextField(
              controller: extraEmailController,
              decoration: const InputDecoration(
                labelText: 'Additional Email (optional)',
                hintText: 'Enter extra email address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            const Text('The report includes each employee\'s total hours worked.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, {'action': 'preview', 'extra_email': extraEmailController.text.trim()}),
            child: const Text('Preview'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, {'action': 'send', 'extra_email': extraEmailController.text.trim()}),
            style: ElevatedButton.styleFrom(backgroundColor: _accent),
            child: const Text('Send Report', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == null) return;

    final action = result['action'] as String?;
    final extraEmail = result['extra_email'] as String?;

    if (action == 'preview') {
      // Show preview
      try {
        final response = await http.get(
          Uri.parse('${ApiConfig.weeklyTimeReport}?action=preview'),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true && mounted) {
            _showReportPreview(data, extraEmail: extraEmail);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load preview: $e'), backgroundColor: Colors.red),
          );
        }
      }
      return;
    }

    if (action == 'send') {
      _doSendReport(extraEmail: extraEmail);
    }
  }

  Future<void> _doSendReport({String? extraEmail}) async {
    // Send the report
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sending weekly report...')),
        );
      }

      String url = '${ApiConfig.weeklyTimeReport}?action=send_report&manual=1';
      if (extraEmail != null && extraEmail.isNotEmpty && extraEmail.contains('@')) {
        url += '&extra_email=${Uri.encodeComponent(extraEmail)}';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          if (data['success'] == true) {
            final sentTo = (data['sent_to'] as List?)?.join(', ') ?? '';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Report sent to $sentTo! ${data['employee_count']} employees included.'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 4),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${data['error'] ?? 'Unknown error'}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send report: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showReportPreview(Map<String, dynamic> data, {String? extraEmail}) {
    final employees = List<Map<String, dynamic>>.from(data['employees'] ?? []);
    final dateRange = data['date_range'] ?? {};

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Preview'),
        content: SizedBox(
          width: 400,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.date_range, color: _accent),
                    const SizedBox(width: 8),
                    Text(
                      '${dateRange['start'] ?? ''} to ${dateRange['end'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${employees.length} employees with hours:',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: employees.isEmpty
                    ? const Center(child: Text('No employees with hours this period'))
                    : ListView.builder(
                        itemCount: employees.length,
                        itemBuilder: (context, index) {
                          final emp = employees[index];
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              backgroundColor: _accent.withValues(alpha: 0.2),
                              radius: 16,
                              child: Text(
                                (emp['name'] ?? '?')[0].toUpperCase(),
                                style: const TextStyle(color: _accent, fontSize: 12),
                              ),
                            ),
                            title: Text(emp['name'] ?? 'Unknown'),
                            trailing: Text(
                              emp['hours'] ?? '0:00',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _accent,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _doSendReport(extraEmail: extraEmail);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _accent),
            child: const Text('Send This Report', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Time Records'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : null,
        actions: [
          // Send weekly email report
          IconButton(
            icon: const Icon(Icons.email),
            onPressed: _sendWeeklyEmailReport,
            tooltip: 'Send Weekly Email Report',
          ),
          // Summary report button (simple export)
          IconButton(
            icon: const Icon(Icons.summarize),
            onPressed: _allRecords != null ? _downloadSummaryReport : null,
            tooltip: 'Download Summary Report',
          ),
          // Download all detailed records button
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _allRecords != null ? () => _downloadRecords() : null,
            tooltip: 'Download Detailed Records',
          ),
          // Date range selector
          TextButton.icon(
            onPressed: _selectDateRange,
            icon: const Icon(Icons.date_range),
            label: Text(
              '${DateFormat('MMM d').format(_fromDate)} - ${DateFormat('MMM d').format(_toDate)}',
            ),
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.white : Colors.black87,
            ),
          ),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecords,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFF49320),
          tabs: const [
            Tab(text: 'By User'),
            Tab(text: 'All Records'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadRecords,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildByUserTab(),
                    _buildAllRecordsTab(),
                  ],
                ),
    );
  }
  
  Widget _buildByUserTab() {
    if (_allRecords == null || _allRecords!.byUser.isEmpty) {
      return const Center(
        child: Text('No time records found for this period'),
      );
    }
    
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;
    
    // On mobile, show full screen list or full screen details
    if (isMobile) {
      if (_selectedUser != null) {
        return _buildMobileUserDetails();
      } else {
        return _buildMobileUserList();
      }
    }
    
    // Desktop layout - side by side
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredUsers = _filteredUsers;
    
    return Row(
      children: [
        // User list with search
        SizedBox(
          width: 300,
          child: Card(
            margin: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search users...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Users (${filteredUsers.length})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      final isSelected = _selectedUser == user.username;
                      // Calculate unique days from records
                      final uniqueDays = _getUniqueDays(user.records);
                      
                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: const Color(0xFFF49320).withValues(alpha: 0.1),
                        leading: _buildProfileAvatar(user.username, user.displayName, radius: 18),
                        title: Text(user.displayName),
                        subtitle: Text(
                          '${user.totalHours.toStringAsFixed(1)}h / $uniqueDays days',
                          style: TextStyle(
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        onTap: () {
                          setState(() => _selectedUser = user.username);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // User details
        Expanded(
          child: _selectedUser == null
              ? const Center(
                  child: Text('Select a user to view details'),
                )
              : _buildUserDetails(),
        ),
      ],
    );
  }
  
  /// Mobile-friendly full screen user list
  Widget _buildMobileUserList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredUsers = _filteredUsers;
    
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search users...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                'Users (${filteredUsers.length})',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                'Tap to view records',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: filteredUsers.length,
            itemBuilder: (context, index) {
              final user = filteredUsers[index];
              // Calculate unique days from records
              final uniqueDays = _getUniqueDays(user.records);
              
              return ListTile(
                leading: _buildProfileAvatar(user.username, user.displayName, radius: 20),
                title: Text(user.displayName),
                subtitle: Text(
                  '${user.totalHours.toStringAsFixed(1)}h total / $uniqueDays days',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  setState(() => _selectedUser = user.username);
                },
              );
            },
          ),
        ),
      ],
    );
  }
  
  /// Mobile-friendly full screen user details with back button
  Widget _buildMobileUserDetails() {
    final user = _allRecords!.byUser.firstWhere(
      (u) => u.username == _selectedUser,
      orElse: () => UserSummary(
        username: _selectedUser!,
        displayName: _selectedUser!,
        totalHours: 0,
        totalDays: 0,
        records: [],
      ),
    );
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dayGroups = _groupRecordsByDay(user.records);
    final uniqueDays = dayGroups.length;
    
    return Column(
      children: [
        // Header with back button
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF49320).withValues(alpha: 0.1),
            border: Border(
              bottom: BorderSide(
                color: const Color(0xFFF49320).withValues(alpha: 0.3),
              ),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => setState(() => _selectedUser = null),
                    tooltip: 'Back to list',
                  ),
                  _buildProfileAvatar(user.username, user.displayName, radius: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          user.username,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => _showAddDayDialog(user.username, user.displayName),
                    tooltip: 'Add Time Record',
                  ),
                  IconButton(
                    icon: const Icon(Icons.download),
                    onPressed: () => _downloadRecords(username: user.username),
                    tooltip: 'Download Records',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Stats row - using unique days
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMobileStatCard('Total', '${user.totalHours.toStringAsFixed(1)}h'),
                  _buildMobileStatCard('Days', '$uniqueDays'),
                  _buildMobileStatCard('Avg/Day', uniqueDays > 0 
                      ? '${(user.totalHours / uniqueDays).toStringAsFixed(1)}h'
                      : '0h'),
                ],
              ),
            ],
          ),
        ),
        
        // Day groups list
        Expanded(
          child: dayGroups.isEmpty
              ? const Center(child: Text('No records'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: dayGroups.length,
                  itemBuilder: (context, index) {
                    final day = dayGroups[index];
                    return _buildDayGroupRow(day, user.username);
                  },
                ),
        ),
      ],
    );
  }
  
  Widget _buildMobileStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFFF49320),
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Build a row for a day group (grouped records)
  Widget _buildDayGroupRow(DayGroup day, String username) {
    final dateFormat = DateFormat('EEE, MMM d');
    final timeFormat = DateFormat('h:mm a');
    final dateKey = '${DateFormat('yyyy-MM-dd').format(day.date)}_$username';
    final isExpanded = _expandedDays.contains(dateKey);
    final hasMultipleRecords = day.records.length > 1;
    
    // Check for day status
    final dayStatus = _dayStatuses?.getStatus(username, day.date);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          // Main day row
          InkWell(
            onTap: hasMultipleRecords ? () {
              setState(() {
                if (isExpanded) {
                  _expandedDays.remove(dateKey);
                } else {
                  _expandedDays.add(dateKey);
                }
              });
            } : null,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Expand icon (only if multiple records)
                  if (hasMultipleRecords)
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: Colors.grey,
                    )
                  else
                    const SizedBox(width: 20),
                  const SizedBox(width: 8),
                  
                  // Date
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateFormat.format(day.date),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        if (hasMultipleRecords)
                          Text(
                            '${day.records.length} clock-ins',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Time range
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        const Icon(Icons.login, size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          timeFormat.format(day.firstClockIn),
                          style: const TextStyle(fontSize: 12),
                        ),
                        const Text(' > ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        if (day.hasActiveRecord)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Active',
                              style: TextStyle(color: Colors.green, fontSize: 10),
                            ),
                          )
                        else ...[
                          Icon(Icons.logout, size: 14, color: day.hasAutoClockOut ? Colors.orange : Colors.red),
                          const SizedBox(width: 4),
                          Text(
                            timeFormat.format(day.lastClockOut!),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Total duration for the day
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF49320).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      day.hoursFormatted,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFFF49320),
                      ),
                    ),
                  ),
                  
                  // Auto clock out indicator
                  if (day.hasAutoClockOut)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Tooltip(
                        message: 'Auto clocked out',
                        child: Icon(Icons.schedule, size: 14, color: Colors.orange.shade300),
                      ),
                    ),
                  
                  // Notes/Edit button - ALWAYS VISIBLE
                  const SizedBox(width: 8),
                  _buildNotesButton(day.records.first, username, day.date),
                ],
              ),
            ),
          ),
          
          // Day status indicator
          if (dayStatus != null && dayStatus.status != 'worked')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              color: dayStatus.statusColor.withValues(alpha: 0.1),
              child: Text(
                dayStatus.statusDisplay + (dayStatus.notes != null ? ': ${dayStatus.notes}' : ''),
                style: TextStyle(
                  fontSize: 11,
                  color: dayStatus.statusColor,
                ),
              ),
            ),
          
          // Notes preview
          if (day.combinedNotes != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.note, size: 12, color: Colors.blue.shade300),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      day.combinedNotes!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          
          // Expanded individual records
          if (isExpanded && hasMultipleRecords)
            Container(
              color: Colors.black.withValues(alpha: 0.03),
              child: Column(
                children: day.records.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final record = entry.value;
                  return _buildIndividualRecordRow(record, idx + 1, username);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
  
  /// Build a row for an individual record within an expanded day
  Widget _buildIndividualRecordRow(TimeRecord record, int index, String username) {
    final timeFormat = DateFormat('h:mm a');
    final isOpen = record.clockOut == null;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Index
          SizedBox(
            width: 28,
            child: Text(
              '#$index',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          
          // Clock in
          const Icon(Icons.login, size: 12, color: Colors.green),
          const SizedBox(width: 4),
          Text(
            timeFormat.format(record.clockIn),
            style: const TextStyle(fontSize: 12),
          ),
          
          const Text(' > ', style: TextStyle(color: Colors.grey, fontSize: 12)),
          
          // Clock out
          if (isOpen)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text('Active', style: TextStyle(color: Colors.green, fontSize: 10)),
            )
          else ...[
            Icon(Icons.logout, size: 12, color: record.autoClockOut ? Colors.orange : Colors.red),
            const SizedBox(width: 4),
            Text(
              timeFormat.format(record.clockOut!),
              style: const TextStyle(fontSize: 12),
            ),
          ],
          
          const Spacer(),
          
          // Duration
          Text(
            record.hoursWorkedFormatted,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
            ),
          ),
          
          // Notes indicator
          if (record.notes != null && record.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Tooltip(
                message: record.notes!,
                child: Icon(Icons.note, size: 12, color: Colors.blue.shade300),
              ),
            ),
          
          // Edit button for individual record
          const SizedBox(width: 4),
          InkWell(
            onTap: () => _showEditNotesDialog(record),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.edit, size: 14, color: Colors.grey.shade600),
            ),
          ),

          // Delete button for individual record
          const SizedBox(width: 4),
          InkWell(
            onTap: () => _showDeleteRecordDialog(record),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.delete_outline, size: 14, color: Colors.red.shade400),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Build the notes/action button for a record
  Widget _buildNotesButton(TimeRecord record, String username, DateTime date) {
    final hasNotes = record.notes != null && record.notes!.isNotEmpty;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => _showDateActionsMenu(context, username, date, record),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(
              color: hasNotes ? Colors.blue.shade300 : Colors.grey.shade400,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasNotes ? Icons.edit_note : Icons.more_horiz,
                size: 16,
                color: hasNotes ? Colors.blue.shade300 : Colors.grey.shade600,
              ),
              if (hasNotes) ...[
                const SizedBox(width: 4),
                Text(
                  'Notes',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue.shade300,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildUserDetails() {
    final user = _allRecords!.byUser.firstWhere(
      (u) => u.username == _selectedUser,
      orElse: () => UserSummary(
        username: _selectedUser!,
        displayName: _selectedUser!,
        totalHours: 0,
        totalDays: 0,
        records: [],
      ),
    );
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dayGroups = _groupRecordsByDay(user.records);
    final uniqueDays = dayGroups.length;
    
    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF49320).withValues(alpha: 0.1),
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFFF49320).withValues(alpha: 0.3),
                ),
              ),
            ),
            child: Row(
              children: [
                _buildProfileAvatar(user.username, user.displayName, radius: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        user.username,
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                // Add Day button
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => _showAddDayDialog(user.username, user.displayName),
                  tooltip: 'Add Time Record',
                ),
                // Download button for this user
                IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: () => _downloadRecords(username: user.username),
                  tooltip: 'Download ${user.displayName}\'s Records',
                ),
                const SizedBox(width: 8),
                // Summary stats - using unique days
                _buildStatCard('Total Hours', '${user.totalHours.toStringAsFixed(1)}h'),
                const SizedBox(width: 16),
                _buildStatCard('Days Worked', '$uniqueDays'),
                const SizedBox(width: 16),
                _buildStatCard('Avg/Day', uniqueDays > 0 
                    ? '${(user.totalHours / uniqueDays).toStringAsFixed(1)}h'
                    : '0h'),
              ],
            ),
          ),
          
          // Day groups list
          Expanded(
            child: dayGroups.isEmpty
                ? const Center(child: Text('No records'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: dayGroups.length,
                    itemBuilder: (context, index) {
                      final day = dayGroups[index];
                      return _buildDayGroupRow(day, user.username);
                    },
                  ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFFF49320),
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAllRecordsTab() {
    if (_allRecords == null || _allRecords!.records.isEmpty) {
      return const Center(
        child: Text('No time records found for this period'),
      );
    }
    
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _allRecords!.records.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final record = _allRecords!.records[index];
        return _buildAllRecordsRow(record);
      },
    );
  }
  
  Widget _buildAllRecordsRow(TimeRecord record) {
    final dateFormat = DateFormat('EEE, MMM d');
    final timeFormat = DateFormat('h:mm a');
    
    final isOpen = record.clockOut == null;
    final wasAutoClockOut = record.autoClockOut;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // User with profile picture
          SizedBox(
            width: 180,
            child: Row(
              children: [
                _buildProfileAvatar(record.username ?? '', record.displayName),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    record.displayName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          
          // Date
          SizedBox(
            width: 100,
            child: Text(dateFormat.format(record.clockIn)),
          ),
          
          // Clock in
          SizedBox(
            width: 90,
            child: Text(timeFormat.format(record.clockIn)),
          ),
          
          // Arrow
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
          ),
          
          // Clock out
          SizedBox(
            width: 90,
            child: isOpen
                ? const Text('Active', style: TextStyle(color: Colors.green))
                : Text(timeFormat.format(record.clockOut!)),
          ),
          
          // Duration
          SizedBox(
            width: 80,
            child: Text(
              record.hoursWorkedFormatted,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          
          // Status icons
          if (wasAutoClockOut)
            Tooltip(
              message: 'Auto clocked out',
              child: Icon(Icons.schedule, size: 16, color: Colors.orange.shade300),
            ),
          
          // Notes indicator
          if (record.notes != null && record.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Tooltip(
                message: record.notes!,
                child: Icon(Icons.note, size: 16, color: Colors.blue.shade300),
              ),
            ),
          
          const Spacer(),

          // Edit button
          _buildNotesButton(record, record.username ?? '', record.clockIn),

          // Delete button
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _showDeleteRecordDialog(record),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.delete_outline, size: 16, color: Colors.red.shade400),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Show dialog to add/edit day status
  Future<void> _showDayStatusDialog(String username, DateTime date) async {
    final existingStatus = _dayStatuses?.getStatus(username, date);
    String selectedStatus = existingStatus?.status ?? 'absent';
    final notesController = TextEditingController(text: existingStatus?.notes ?? '');
    
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.calendar_today, color: _accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  DateFormat('EEEE, MMM d, yyyy').format(date),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User: $username',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                const Text('Status:'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildStatusChip('vacation', 'Vacation', Colors.blue, selectedStatus, (s) {
                      setDialogState(() => selectedStatus = s);
                    }),
                    _buildStatusChip('sick', 'Sick Day', Colors.orange, selectedStatus, (s) {
                      setDialogState(() => selectedStatus = s);
                    }),
                    _buildStatusChip('absent', 'Absent', Colors.red, selectedStatus, (s) {
                      setDialogState(() => selectedStatus = s);
                    }),
                    _buildStatusChip('holiday', 'Holiday', Colors.purple, selectedStatus, (s) {
                      setDialogState(() => selectedStatus = s);
                    }),
                    _buildStatusChip('other', 'Other', Colors.grey, selectedStatus, (s) {
                      setDialogState(() => selectedStatus = s);
                    }),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                    hintText: 'Add any notes...',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    
    if (result == true) {
      final success = await TimeClockService.setDayStatus(
        username: username,
        date: date,
        status: selectedStatus,
        notes: notesController.text.isNotEmpty ? notesController.text : null,
        createdBy: 'manager',
      );
      
      if (success) {
        _loadRecords();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Day status updated for $username')),
          );
        }
      }
    }
  }
  
  Widget _buildStatusChip(String value, String label, Color color, String selected, Function(String) onSelect) {
    final isSelected = value == selected;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelect(value),
      backgroundColor: color.withValues(alpha: 0.1),
      selectedColor: color.withValues(alpha: 0.3),
      checkmarkColor: color,
      labelStyle: TextStyle(
        color: isSelected ? color : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
  
  /// Show dialog to edit record notes
  Future<void> _showEditNotesDialog(TimeRecord record) async {
    final notesController = TextEditingController(text: record.notes ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.note_alt, color: _accent),
            SizedBox(width: 12),
            Text('Edit Notes'),
          ],
        ),
        content: TextField(
          controller: notesController,
          decoration: const InputDecoration(
            labelText: 'Notes',
            border: OutlineInputBorder(),
            hintText: 'Add notes for this time record...',
          ),
          maxLines: 4,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      final success = await TimeClockService.updateRecordNotes(record.id, notesController.text);

      if (success) {
        _loadRecords();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notes updated')),
          );
        }
      }
    }
  }

  /// Show dialog to confirm deleting a time record
  Future<void> _showDeleteRecordDialog(TimeRecord record) async {
    final reasonController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red.shade400),
            const SizedBox(width: 12),
            const Text('Delete Time Record'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Record info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.displayName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('EEEE, MMM d, yyyy').format(record.clockIn),
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Clock In: ${DateFormat('h:mm a').format(record.clockIn)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    if (record.clockOut != null)
                      Text(
                        'Clock Out: ${DateFormat('h:mm a').format(record.clockOut!)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    Text(
                      'Duration: ${record.hoursWorkedFormatted}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    if (record.autoClockOut)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Auto clocked out',
                          style: TextStyle(color: Colors.orange, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Warning message
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red.shade400, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'This action cannot be undone. The record will be permanently deleted.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Reason field
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason for deletion (optional)',
                  border: OutlineInputBorder(),
                  hintText: 'Why is this record being deleted?',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (result == true) {
      final deleteResult = await TimeClockService.deleteRecord(
        recordId: record.id,
        deletedBy: _currentManagerUsername ?? 'unknown',
        reason: reasonController.text.isNotEmpty ? reasonController.text : null,
      );

      if (deleteResult.success) {
        _loadRecords();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Time record deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${deleteResult.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  
  /// Show dialog to add a new time record for a user
  Future<void> _showAddDayDialog(String username, String displayName) async {
    final now = DateTime.now();
    final dateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1))),
    );
    final clockInController = TextEditingController(text: '08:00');
    final clockOutController = TextEditingController(text: '17:00');
    final notesController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.add_circle, color: _accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Add Time Record'),
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date picker
                TextField(
                  controller: dateController,
                  decoration: InputDecoration(
                    labelText: 'Date',
                    border: const OutlineInputBorder(),
                    hintText: 'YYYY-MM-DD',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.tryParse(dateController.text) ?? now,
                          firstDate: DateTime(2024),
                          lastDate: now,
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: Color(0xFFF49320),
                                  surface: Color(0xFF1E1E1E),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (date != null) {
                          dateController.text = DateFormat('yyyy-MM-dd').format(date);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Clock In Time
                TextField(
                  controller: clockInController,
                  decoration: InputDecoration(
                    labelText: 'Clock In Time',
                    border: const OutlineInputBorder(),
                    hintText: 'HH:MM (e.g., 08:00)',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.access_time),
                      onPressed: () async {
                        final parts = clockInController.text.split(':');
                        final initial = TimeOfDay(
                          hour: int.tryParse(parts[0]) ?? 8,
                          minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
                        );
                        final time = await showTimePicker(
                          context: context,
                          initialTime: initial,
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: Color(0xFFF49320),
                                  surface: Color(0xFF1E1E1E),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (time != null) {
                          clockInController.text =
                              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Clock Out Time
                TextField(
                  controller: clockOutController,
                  decoration: InputDecoration(
                    labelText: 'Clock Out Time',
                    border: const OutlineInputBorder(),
                    hintText: 'HH:MM (e.g., 17:00)',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.access_time),
                      onPressed: () async {
                        final parts = clockOutController.text.split(':');
                        final initial = TimeOfDay(
                          hour: int.tryParse(parts[0]) ?? 17,
                          minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
                        );
                        final time = await showTimePicker(
                          context: context,
                          initialTime: initial,
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: Color(0xFFF49320),
                                  surface: Color(0xFF1E1E1E),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (time != null) {
                          clockOutController.text =
                              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Notes
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                    hintText: 'Reason for manual entry...',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add Record'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      final date = dateController.text.trim();
      final clockIn = clockInController.text.trim();
      final clockOut = clockOutController.text.trim();
      final notes = notesController.text.trim();

      // Validate inputs
      if (date.isEmpty || clockIn.isEmpty || clockOut.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Date, clock in, and clock out times are required'), backgroundColor: Colors.red),
        );
        return;
      }

      // Build full datetime strings
      final clockInFull = '$date $clockIn';
      final clockOutFull = '$date $clockOut';

      final createResult = await TimeClockService.createRecord(
        username: username,
        clockIn: clockInFull,
        clockOut: clockOutFull,
        notes: notes.isNotEmpty ? notes : null,
        createdBy: _currentManagerUsername ?? 'unknown',
      );

      if (createResult.success) {
        _loadRecords();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Time record added for $displayName'), backgroundColor: Colors.green),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${createResult.message}'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
  
  /// Show quick action menu for a date
  void _showDateActionsMenu(BuildContext context, String username, DateTime date, TimeRecord? record) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: _accent),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('EEEE, MMM d').format(date),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Edit/Correct Times - Most important action at top
            if (record != null)
              ListTile(
                leading: const Icon(Icons.edit_calendar, color: _accent),
                title: const Text(
                  'Correct Times',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  'In: ${DateFormat('h:mm a').format(record.clockIn)}${record.clockOut != null ? ' | Out: ${DateFormat('h:mm a').format(record.clockOut!)}' : ' | Still active'}',
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCorrectTimesDialog(record, username);
                },
              ),
            // Edit Notes
            if (record != null)
              ListTile(
                leading: Icon(
                  record.notes != null && record.notes!.isNotEmpty 
                      ? Icons.edit_note 
                      : Icons.note_add,
                  color: Colors.blue,
                ),
                title: Text(
                  record.notes != null && record.notes!.isNotEmpty 
                      ? 'Edit Notes' 
                      : 'Add Notes',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: record.notes != null && record.notes!.isNotEmpty
                    ? Text(
                        record.notes!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      )
                    : const Text('Add a note to this time record', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditNotesDialog(record);
                },
              ),
            const Divider(height: 1),
            // Day status options
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 8, bottom: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Mark Day As:',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.beach_access, color: Colors.blue),
              title: const Text('Vacation'),
              onTap: () {
                Navigator.pop(ctx);
                _quickSetStatus(username, date, 'vacation');
              },
            ),
            ListTile(
              leading: const Icon(Icons.sick, color: Colors.orange),
              title: const Text('Sick Day'),
              onTap: () {
                Navigator.pop(ctx);
                _quickSetStatus(username, date, 'sick');
              },
            ),
            ListTile(
              leading: const Icon(Icons.event_busy, color: Colors.red),
              title: const Text('Absent'),
              onTap: () {
                Navigator.pop(ctx);
                _quickSetStatus(username, date, 'absent');
              },
            ),
            ListTile(
              leading: const Icon(Icons.more_horiz, color: Colors.grey),
              title: const Text('Other (with notes)'),
              onTap: () {
                Navigator.pop(ctx);
                _showDayStatusDialog(username, date);
              },
            ),
            const Divider(height: 1),
            // Delete record option
            if (record != null)
              ListTile(
                leading: Icon(Icons.delete_forever, color: Colors.red.shade400),
                title: const Text(
                  'Delete This Record',
                  style: TextStyle(color: Colors.red),
                ),
                subtitle: const Text(
                  'Permanently remove this time record',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteRecordDialog(record);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Show dialog to correct clock in/out times
  Future<void> _showCorrectTimesDialog(TimeRecord record, String username) async {
    final clockInController = TextEditingController(
      text: DateFormat('yyyy-MM-dd HH:mm').format(record.clockIn),
    );
    final clockOutController = TextEditingController(
      text: record.clockOut != null 
          ? DateFormat('yyyy-MM-dd HH:mm').format(record.clockOut!) 
          : '',
    );
    final notesController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.edit_calendar, color: _accent),
              SizedBox(width: 12),
              Text('Correct Time Record'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Record info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Record #${record.id}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        DateFormat('EEEE, MMM d, yyyy').format(record.clockIn),
                        style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                      ),
                      if (record.autoClockOut)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '?? Auto clocked out',
                            style: TextStyle(color: Colors.orange, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Clock In Time
                TextField(
                  controller: clockInController,
                  decoration: InputDecoration(
                    labelText: 'Clock In Time',
                    border: const OutlineInputBorder(),
                    hintText: 'YYYY-MM-DD HH:MM',
                    helperText: 'Original: ${DateFormat('yyyy-MM-dd HH:mm').format(record.clockIn)}',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.access_time),
                      onPressed: () => _pickDateTime(clockInController),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Clock Out Time
                TextField(
                  controller: clockOutController,
                  decoration: InputDecoration(
                    labelText: 'Clock Out Time',
                    border: const OutlineInputBorder(),
                    hintText: 'YYYY-MM-DD HH:MM (leave empty to clear)',
                    helperText: record.clockOut != null 
                        ? 'Original: ${DateFormat('yyyy-MM-dd HH:mm').format(record.clockOut!)}' 
                        : 'No clock out recorded',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.access_time),
                      onPressed: () => _pickDateTime(clockOutController),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Correction Notes
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Correction Reason (optional)',
                    border: OutlineInputBorder(),
                    hintText: 'Why is this being corrected?',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save Correction'),
            ),
          ],
        );
      },
    );
    
    if (result == true) {
      // Validate and submit correction
      final clockIn = clockInController.text.trim();
      final clockOut = clockOutController.text.trim();
      final notes = notesController.text.trim();
      
      // Determine what changed
      final originalClockIn = DateFormat('yyyy-MM-dd HH:mm').format(record.clockIn);
      final originalClockOut = record.clockOut != null 
          ? DateFormat('yyyy-MM-dd HH:mm').format(record.clockOut!) 
          : '';
      
      final String? newClockIn = clockIn != originalClockIn ? clockIn : null;
      String? newClockOut;
      
      if (clockOut != originalClockOut) {
        newClockOut = clockOut.isEmpty ? '' : clockOut;
      }
      
      if (newClockIn == null && newClockOut == null && notes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No changes made')),
        );
        return;
      }
      
      final correctionResult = await TimeClockService.correctRecord(
        recordId: record.id,
        clockIn: newClockIn,
        clockOut: newClockOut,
        notes: notes.isNotEmpty ? notes : null,
        correctedBy: _currentManagerUsername ?? 'unknown',
      );
      
      if (correctionResult.success) {
        _loadRecords();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Time record corrected'), backgroundColor: Colors.green),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${correctionResult.message}'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  /// Pick a date and time
  Future<void> _pickDateTime(TextEditingController controller) async {
    final initialText = controller.text.trim();
    DateTime initialDate = DateTime.now();
    TimeOfDay initialTime = TimeOfDay.now();
    
    if (initialText.isNotEmpty) {
      try {
        final dt = DateFormat('yyyy-MM-dd HH:mm').parse(initialText);
        initialDate = dt;
        initialTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
      } catch (e) {
  debugPrint('[TimeRecordsScreen] Error: $e');
}
    }
    
    // Pick date
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFF49320),
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (date == null) return;
    
    if (!mounted) return;
    // Pick time
    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFF49320),
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (time == null) return;
    
    // Combine and set
    final dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    controller.text = DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
  }
  
  Future<void> _quickSetStatus(String username, DateTime date, String status) async {
    final success = await TimeClockService.setDayStatus(
      username: username,
      date: date,
      status: status,
      createdBy: 'manager',
    );
    
    if (success) {
      _loadRecords();
      if (mounted) {
        final statusName = {
          'vacation': 'Vacation',
          'sick': 'Sick Day',
          'absent': 'Absent',
        }[status] ?? status;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Marked as $statusName')),
        );
      }
    }
  }
}
