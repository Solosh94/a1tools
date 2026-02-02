// Audit Log Screen
//
// Management UI for viewing and exporting audit logs.
// Accessible from the Admin Management section.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../app_theme.dart';
import 'audit_service.dart';

class AuditLogScreen extends StatefulWidget {
  final String currentUsername;
  final String currentRole;

  const AuditLogScreen({
    super.key,
    required this.currentUsername,
    required this.currentRole,
  });

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Logs tab state
  List<AuditLogEntry> _logs = [];
  bool _isLoadingLogs = false;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalLogs = 0;

  // Stats tab state
  AuditStats? _stats;
  bool _isLoadingStats = false;
  int _statsDays = 30;

  // Filters
  String? _filterUsername;
  String? _filterAction;
  String? _filterCategory;
  bool? _filterSuccess;
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Available filter options
  List<String> _categories = [];
  // ignore: unused_field - reserved for future action filter dropdown
  List<String> _actions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLogs();
    _loadStats();
    _loadFilterOptions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoadingLogs = true);

    try {
      final response = await AuditService.instance.getLogs(
        username: _filterUsername,
        action: _filterAction,
        category: _filterCategory,
        success: _filterSuccess,
        startDate: _startDate,
        endDate: _endDate,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        page: _currentPage,
        limit: 50,
      );

      setState(() {
        _logs = response.logs;
        _totalPages = response.totalPages;
        _totalLogs = response.total;
      });
    } catch (e) {
      debugPrint('Error loading audit logs: $e');
    } finally {
      setState(() => _isLoadingLogs = false);
    }
  }

  Future<void> _loadStats() async {
    setState(() => _isLoadingStats = true);

    try {
      final stats = await AuditService.instance.getStats(
        days: _statsDays,
        username: _filterUsername,
      );
      setState(() => _stats = stats);
    } catch (e) {
      debugPrint('Error loading audit stats: $e');
    } finally {
      setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _loadFilterOptions() async {
    final categories = await AuditService.instance.getCategories();
    final actions = await AuditService.instance.getActions();
    setState(() {
      _categories = categories;
      _actions = actions;
    });
  }

  Future<void> _exportLogs() async {
    final csv = await AuditService.instance.exportLogs(
      requestingUser: widget.currentUsername,
      username: _filterUsername,
      action: _filterAction,
      category: _filterCategory,
      startDate: _startDate,
      endDate: _endDate,
    );

    if (csv != null && mounted) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final filename = 'audit_logs_${DateTime.now().millisecondsSinceEpoch}.csv';
        final file = File('${directory.path}/$filename');
        await file.writeAsString(csv);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Exported to: ${file.path}'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Export failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _filterUsername = null;
      _filterAction = null;
      _filterCategory = null;
      _filterSuccess = null;
      _startDate = null;
      _endDate = null;
      _searchQuery = '';
      _searchController.clear();
      _currentPage = 1;
    });
    _loadLogs();
    _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 20, color: AppColors.accent),
            SizedBox(width: 8),
            Text('Audit Logs'),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export to CSV',
            onPressed: _exportLogs,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              _loadLogs();
              _loadStats();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.accent,
          tabs: const [
            Tab(text: 'Activity Log'),
            Tab(text: 'Statistics'),
          ],
        ),
      ),
      backgroundColor: bgColor,
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLogsTab(isDark),
          _buildStatsTab(isDark),
        ],
      ),
    );
  }

  Widget _buildLogsTab(bool isDark) {
    return Column(
      children: [
        _buildFilters(isDark),
        Expanded(
          child: _isLoadingLogs
              ? const Center(child: CircularProgressIndicator())
              : _logs.isEmpty
                  ? const Center(child: Text('No audit logs found'))
                  : ListView.builder(
                      itemCount: _logs.length,
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, index) => _buildLogItem(_logs[index], isDark),
                    ),
        ),
        _buildPagination(isDark),
      ],
    );
  }

  Widget _buildFilters(bool isDark) {
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;

    return Container(
      color: cardColor,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search logs...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                        _loadLogs();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onSubmitted: (value) {
              setState(() {
                _searchQuery = value;
                _currentPage = 1;
              });
              _loadLogs();
            },
          ),
          const SizedBox(height: 8),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: _filterCategory ?? 'Category',
                  isActive: _filterCategory != null,
                  onTap: () => _showCategoryPicker(),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: _filterSuccess == null
                      ? 'Status'
                      : _filterSuccess! ? 'Success' : 'Failed',
                  isActive: _filterSuccess != null,
                  onTap: () => _showStatusPicker(),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: _startDate != null || _endDate != null
                      ? '${_formatDate(_startDate)} - ${_formatDate(_endDate)}'
                      : 'Date Range',
                  isActive: _startDate != null || _endDate != null,
                  onTap: () => _showDateRangePicker(),
                ),
                const SizedBox(width: 8),
                if (_hasActiveFilters())
                  TextButton.icon(
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: const Text('Clear'),
                    onPressed: _clearFilters,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      label: Text(label),
      avatar: isActive ? const Icon(Icons.check, size: 16) : null,
      backgroundColor: isActive ? AppColors.accent.withValues(alpha: 0.2) : null,
      onPressed: onTap,
    );
  }

  bool _hasActiveFilters() {
    return _filterUsername != null ||
        _filterAction != null ||
        _filterCategory != null ||
        _filterSuccess != null ||
        _startDate != null ||
        _endDate != null ||
        _searchQuery.isNotEmpty;
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: const Text('All Categories'),
            onTap: () {
              setState(() {
                _filterCategory = null;
                _currentPage = 1;
              });
              Navigator.pop(context);
              _loadLogs();
            },
          ),
          ..._categories.map((cat) => ListTile(
            title: Text(cat.toUpperCase()),
            trailing: _filterCategory == cat ? const Icon(Icons.check) : null,
            onTap: () {
              setState(() {
                _filterCategory = cat;
                _currentPage = 1;
              });
              Navigator.pop(context);
              _loadLogs();
            },
          )),
        ],
      ),
    );
  }

  void _showStatusPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: const Text('All'),
            onTap: () {
              setState(() {
                _filterSuccess = null;
                _currentPage = 1;
              });
              Navigator.pop(context);
              _loadLogs();
            },
          ),
          ListTile(
            title: const Text('Success'),
            leading: Icon(Icons.check_circle, color: Colors.green.shade600),
            onTap: () {
              setState(() {
                _filterSuccess = true;
                _currentPage = 1;
              });
              Navigator.pop(context);
              _loadLogs();
            },
          ),
          ListTile(
            title: const Text('Failed'),
            leading: Icon(Icons.error, color: Colors.red.shade600),
            onTap: () {
              setState(() {
                _filterSuccess = false;
                _currentPage = 1;
              });
              Navigator.pop(context);
              _loadLogs();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _currentPage = 1;
      });
      _loadLogs();
      _loadStats();
    }
  }

  Widget _buildLogItem(AuditLogEntry log, bool isDark) {
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;
    final successColor = log.success ? Colors.green.shade600 : Colors.red.shade600;

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showLogDetails(log),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getCategoryColor(log.category).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getCategoryIcon(log.category),
                  color: _getCategoryColor(log.category),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            log.action.replaceAll('_', ' ').toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Icon(
                          log.success ? Icons.check_circle : Icons.error,
                          color: successColor,
                          size: 16,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${log.username} • ${_formatDateTime(log.createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (log.targetName != null || log.targetType != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '${log.targetType ?? ''} ${log.targetName ?? log.targetId ?? ''}'.trim(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogDetails(AuditLogEntry log) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(log.category).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getCategoryIcon(log.category),
                    color: _getCategoryColor(log.category),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.action.replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            log.success ? Icons.check_circle : Icons.error,
                            color: log.success ? Colors.green : Colors.red,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            log.success ? 'Successful' : 'Failed',
                            style: TextStyle(
                              color: log.success ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildDetailRow('User', log.username, isDark),
            _buildDetailRow('Category', log.category.toUpperCase(), isDark),
            _buildDetailRow('Timestamp', _formatDateTime(log.createdAt), isDark),
            if (log.targetType != null)
              _buildDetailRow('Target Type', log.targetType!, isDark),
            if (log.targetId != null)
              _buildDetailRow('Target ID', log.targetId!, isDark),
            if (log.targetName != null)
              _buildDetailRow('Target Name', log.targetName!, isDark),
            if (log.ipAddress != null)
              _buildDetailRow('IP Address', log.ipAddress!, isDark),
            if (log.deviceInfo != null)
              _buildDetailRow('Device', log.deviceInfo!, isDark),
            if (log.errorMessage != null)
              _buildDetailRow('Error', log.errorMessage!, isDark, isError: true),
            if (log.details != null && log.details!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Additional Details',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatDetails(log.details!),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isError ? Colors.red.shade600 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDetails(Map<String, dynamic> details) {
    final buffer = StringBuffer();
    details.forEach((key, value) {
      buffer.writeln('$key: $value');
    });
    return buffer.toString().trim();
  }

  Widget _buildPagination(bool isDark) {
    if (_totalPages <= 1) return const SizedBox.shrink();

    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;

    return Container(
      color: cardColor,
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.first_page),
            onPressed: _currentPage > 1
                ? () {
                    setState(() => _currentPage = 1);
                    _loadLogs();
                  }
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 1
                ? () {
                    setState(() => _currentPage--);
                    _loadLogs();
                  }
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Page $_currentPage of $_totalPages ($_totalLogs total)',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < _totalPages
                ? () {
                    setState(() => _currentPage++);
                    _loadLogs();
                  }
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.last_page),
            onPressed: _currentPage < _totalPages
                ? () {
                    setState(() => _currentPage = _totalPages);
                    _loadLogs();
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsTab(bool isDark) {
    if (_isLoadingStats) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_stats == null) {
      return const Center(child: Text('Failed to load statistics'));
    }

    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period selector
          Row(
            children: [
              const Text('Period: '),
              ChoiceChip(
                label: const Text('7 days'),
                selected: _statsDays == 7,
                onSelected: (_) {
                  setState(() => _statsDays = 7);
                  _loadStats();
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('30 days'),
                selected: _statsDays == 30,
                onSelected: (_) {
                  setState(() => _statsDays = 30);
                  _loadStats();
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('90 days'),
                selected: _statsDays == 90,
                onSelected: (_) {
                  setState(() => _statsDays = 90);
                  _loadStats();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Summary cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Actions',
                  _stats!.totalLogs.toString(),
                  Icons.analytics,
                  AppColors.accent,
                  cardColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Failed',
                  _stats!.failedActions.toString(),
                  Icons.error_outline,
                  Colors.red,
                  cardColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Success Rate',
                  '${_stats!.successRate}%',
                  Icons.check_circle_outline,
                  Colors.green,
                  cardColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // By category
          _buildSectionTitle('Actions by Category'),
          const SizedBox(height: 12),
          ...(_stats!.byCategory.map((item) => _buildBarItem(
            item['category']?.toString().toUpperCase() ?? 'UNKNOWN',
            int.tryParse(item['count'].toString()) ?? 0,
            _stats!.totalLogs,
            _getCategoryColor(item['category']?.toString() ?? ''),
            cardColor,
          ))),

          const SizedBox(height: 24),

          // Top actions
          _buildSectionTitle('Top Actions'),
          const SizedBox(height: 12),
          ...(_stats!.topActions.take(5).map((item) => _buildBarItem(
            item['action']?.toString().replaceAll('_', ' ').toUpperCase() ?? 'UNKNOWN',
            int.tryParse(item['count'].toString()) ?? 0,
            _stats!.totalLogs,
            AppColors.accent,
            cardColor,
          ))),

          const SizedBox(height: 24),

          // Most active users
          _buildSectionTitle('Most Active Users'),
          const SizedBox(height: 12),
          ...(_stats!.activeUsers.take(5).map((item) => _buildBarItem(
            item['username']?.toString() ?? 'Unknown',
            int.tryParse(item['count'].toString()) ?? 0,
            _stats!.totalLogs,
            Colors.blue,
            cardColor,
          ))),

          // Recent failures
          if (_stats!.recentFailures.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSectionTitle('Recent Failures'),
            const SizedBox(height: 12),
            ...(_stats!.recentFailures.map((failure) => Card(
              color: cardColor,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(Icons.error, color: Colors.red.shade600),
                title: Text(failure['action']?.toString().replaceAll('_', ' ') ?? ''),
                subtitle: Text(
                  '${failure['username']} • ${failure['error_message'] ?? 'Unknown error'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  _formatDateTime(DateTime.tryParse(failure['created_at'] ?? '') ?? DateTime.now()),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
            ))),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, Color cardColor) {
    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildBarItem(String label, int count, int total, Color color, Color cardColor) {
    final percentage = total > 0 ? (count / total) : 0.0;

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '$count (${(percentage * 100).toStringAsFixed(1)}%)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage,
                backgroundColor: color.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    return switch (category.toLowerCase()) {
      'auth' => Icons.login,
      'user' => Icons.person,
      'data' => Icons.storage,
      'admin' => Icons.admin_panel_settings,
      'system' => Icons.settings,
      'security' => Icons.security,
      _ => Icons.article,
    };
  }

  Color _getCategoryColor(String category) {
    return switch (category.toLowerCase()) {
      'auth' => Colors.blue,
      'user' => Colors.purple,
      'data' => Colors.orange,
      'admin' => Colors.red,
      'system' => Colors.grey,
      'security' => Colors.amber,
      _ => AppColors.accent,
    };
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Any';
    return '${date.month}/${date.day}/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${date.month}/${date.day}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
