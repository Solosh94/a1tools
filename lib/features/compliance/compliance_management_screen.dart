import 'dart:async';
import 'package:flutter/material.dart';
import '../../app_theme.dart';
import 'compliance_service.dart';

/// Compliance Management Screen
/// Shows real-time compliance status for all clocked-in users,
/// allows extending timeout, and viewing compliance logs.
class ComplianceManagementScreen extends StatefulWidget {
  final String currentUsername;
  final String currentRole;

  const ComplianceManagementScreen({
    super.key,
    required this.currentUsername,
    required this.currentRole,
  });

  @override
  State<ComplianceManagementScreen> createState() => _ComplianceManagementScreenState();
}

class _ComplianceManagementScreenState extends State<ComplianceManagementScreen>
    with SingleTickerProviderStateMixin {
  static const Color _accent = AppColors.accent;

  late TabController _tabController;
  Timer? _refreshTimer;

  // Status tab
  ComplianceStatusResult? _statusResult;
  bool _loadingStatus = true;

  // Logs tab
  List<ComplianceLog> _logs = [];
  bool _loadingLogs = false;
  String? _logFilterUsername;

  // Settings
  bool _editingSettings = false;
  int _settingsTimeout = 20;
  int _settingsGrace = 30;
  bool _settingsEnabled = true;
  bool _settingsNotify = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadStatus();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index == 1 && _logs.isEmpty) {
      _loadLogs();
    }
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_tabController.index == 0) {
        _loadStatus();
      }
    });
  }

  Future<void> _loadStatus() async {
    final result = await ComplianceService.getStatus();
    if (mounted) {
      setState(() {
        _statusResult = result;
        _loadingStatus = false;
        if (result != null && !_editingSettings) {
          _settingsTimeout = result.settings.heartbeatTimeoutMinutes;
          _settingsGrace = result.settings.gracePeriodMinutes;
          _settingsEnabled = result.settings.enabled;
          _settingsNotify = result.settings.notifyOnAutoClockout;
        }
      });
    }
  }

  Future<void> _loadLogs() async {
    setState(() => _loadingLogs = true);
    final logs = await ComplianceService.getLogs(
      username: _logFilterUsername,
      limit: 100,
    );
    if (mounted) {
      setState(() {
        _logs = logs;
        _loadingLogs = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    final success = await ComplianceService.updateSettings(
      heartbeatTimeoutMinutes: _settingsTimeout,
      gracePeriodMinutes: _settingsGrace,
      enabled: _settingsEnabled,
      notifyOnAutoClockout: _settingsNotify,
      updatedBy: widget.currentUsername,
    );

    if (mounted) {
      if (success) {
        setState(() => _editingSettings = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved'),
            backgroundColor: Colors.green,
          ),
        );
        _loadStatus();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save settings'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showExtendDialog(UserComplianceStatus user) async {
    int minutes = 60;
    String reason = '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Extend Timeout for ${user.displayName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current status: ${user.statusText}',
                style: TextStyle(color: Color(user.statusColor)),
              ),
              if (user.minutesSinceHeartbeat != null)
                Text('Last heartbeat: ${user.minutesSinceHeartbeat} min ago'),
              const SizedBox(height: 16),
              const Text('Extend timeout by:'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [30, 60, 120, 240].map((m) {
                  return ChoiceChip(
                    label: Text('${m}m'),
                    selected: minutes == m,
                    selectedColor: _accent,
                    onSelected: (selected) {
                      if (selected) setDialogState(() => minutes = m);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  hintText: 'e.g., Internet issues',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => reason = v,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: _accent),
              child: const Text('Extend'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final success = await ComplianceService.extendTimeout(
        username: user.username,
        minutes: minutes,
        extendedBy: widget.currentUsername,
        reason: reason.isNotEmpty ? reason : null,
      );

      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Timeout extended by $minutes minutes for ${user.displayName}'),
            backgroundColor: Colors.green,
          ),
        );
        _loadStatus();
        _loadLogs();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to extend timeout'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _runManualCheck() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Running compliance check...')),
    );

    final result = await ComplianceService.checkCompliance();

    if (mounted) {
      if (result != null && result['success'] == true) {
        final checked = result['checked'] ?? 0;
        final clockedOut = result['clocked_out'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Checked $checked users, $clockedOut auto clock-outs'),
            backgroundColor: clockedOut > 0 ? Colors.orange : Colors.green,
          ),
        );
        _loadStatus();
        _loadLogs();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Check failed: ${result?['error'] ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showClearLogsDialog() async {
    int? olderThanDays;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Clear Compliance Logs'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Choose which logs to delete:'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All logs'),
                    selected: olderThanDays == null,
                    selectedColor: Colors.red.shade200,
                    onSelected: (selected) {
                      if (selected) setDialogState(() => olderThanDays = null);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Older than 7 days'),
                    selected: olderThanDays == 7,
                    selectedColor: _accent,
                    onSelected: (selected) {
                      if (selected) setDialogState(() => olderThanDays = 7);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Older than 30 days'),
                    selected: olderThanDays == 30,
                    selectedColor: _accent,
                    onSelected: (selected) {
                      if (selected) setDialogState(() => olderThanDays = 30);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Older than 90 days'),
                    selected: olderThanDays == 90,
                    selectedColor: _accent,
                    onSelected: (selected) {
                      if (selected) setDialogState(() => olderThanDays = 90);
                    },
                  ),
                ],
              ),
              if (olderThanDays == null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This will permanently delete ALL compliance logs.',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: olderThanDays == null ? Colors.red : _accent,
              ),
              child: const Text('Clear'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final result = await ComplianceService.clearLogs(
        clearedBy: widget.currentUsername,
        olderThanDays: olderThanDays,
      );

      if (!mounted) return;
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cleared ${result.deletedCount} log entries'),
            backgroundColor: Colors.green,
          ),
        );
        _loadLogs();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear logs: ${result.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Image.asset(
          isDark ? 'assets/images/logo-white.png' : 'assets/images/logo.png',
          height: 40,
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _accent,
          labelColor: _accent,
          tabs: const [
            Tab(icon: Icon(Icons.monitor_heart), text: 'Live Status'),
            Tab(icon: Icon(Icons.history), text: 'Logs'),
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
          ],
        ),
        actions: [
          if (_tabController.index == 0)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadStatus,
              tooltip: 'Refresh',
            ),
          IconButton(
            icon: const Icon(Icons.play_circle_outline),
            onPressed: _runManualCheck,
            tooltip: 'Run compliance check now',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStatusTab(isDark),
          _buildLogsTab(isDark),
          _buildSettingsTab(isDark),
        ],
      ),
    );
  }

  Widget _buildStatusTab(bool isDark) {
    if (_loadingStatus) {
      return const Center(child: CircularProgressIndicator(color: _accent));
    }

    if (_statusResult == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Failed to load compliance status'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadStatus,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final users = _statusResult!.users;

    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No users currently clocked in',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Server time: ${_statusResult!.serverTime}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    // Sort by status severity (critical first)
    final sortedUsers = List<UserComplianceStatus>.from(users);
    final statusOrder = {'critical': 0, 'warning': 1, 'no_heartbeat': 2, 'active': 3, 'online': 4};
    sortedUsers.sort((a, b) {
      final orderA = statusOrder[a.status] ?? 5;
      final orderB = statusOrder[b.status] ?? 5;
      return orderA.compareTo(orderB);
    });

    return RefreshIndicator(
      onRefresh: _loadStatus,
      color: _accent,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sortedUsers.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            // Header with stats
            return _buildStatsHeader(users, isDark);
          }
          final user = sortedUsers[index - 1];
          return _buildUserCard(user, isDark);
        },
      ),
    );
  }

  Widget _buildStatsHeader(List<UserComplianceStatus> users, bool isDark) {
    final online = users.where((u) => u.status == 'online' || u.status == 'active').length;
    final warning = users.where((u) => u.status == 'warning').length;
    final critical = users.where((u) => u.status == 'critical' || u.status == 'no_heartbeat').length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Online', online, Colors.green),
          _buildStatItem('Warning', warning, Colors.orange),
          _buildStatItem('Critical', critical, Colors.red),
          _buildStatItem('Total', users.length, _accent),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildUserCard(UserComplianceStatus user, bool isDark) {
    final statusColor = Color(user.statusColor);
    final bgColor = isDark ? const Color(0xFF252525) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.5),
          width: user.status == 'critical' ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showExtendDialog(user),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        boxShadow: user.status == 'critical'
                            ? [BoxShadow(color: statusColor.withValues(alpha: 0.5), blurRadius: 8)]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            '@${user.username} - ${user.role}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        user.statusText,
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.computer, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      user.computerName ?? 'Unknown',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      user.minutesSinceHeartbeat != null
                          ? '${user.minutesSinceHeartbeat}m ago'
                          : 'No signal',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    if (user.scheduledEnd != null) ...[
                      const SizedBox(width: 16),
                      Icon(Icons.schedule, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        'End: ${user.scheduledEnd}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ],
                ),
                if (user.isExtended) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer, size: 14, color: Colors.blue),
                        const SizedBox(width: 4),
                        Text(
                          'Extended by ${user.extendedBy ?? "admin"}',
                          style: const TextStyle(color: Colors.blue, fontSize: 12),
                        ),
                        if (user.extensionReason != null && user.extensionReason!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            '(${user.extensionReason})',
                            style: TextStyle(color: Colors.blue.shade300, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (user.status == 'warning' || user.status == 'critical') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber,
                        size: 14,
                        color: statusColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        user.minutesUntilTimeout != null && user.minutesUntilTimeout! > 0
                            ? 'Auto clock-out in ${user.minutesUntilTimeout} min'
                            : 'Will be clocked out soon',
                        style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _showExtendDialog(user),
                        icon: const Icon(Icons.add_alarm, size: 16),
                        label: const Text('Extend'),
                        style: TextButton.styleFrom(
                          foregroundColor: _accent,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogsTab(bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF252525) : Colors.grey.shade100,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Filter by username...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: isDark ? Colors.black26 : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (v) {
                    _logFilterUsername = v.isNotEmpty ? v : null;
                  },
                  onSubmitted: (_) => _loadLogs(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadLogs,
                tooltip: 'Refresh logs',
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep),
                onPressed: _showClearLogsDialog,
                tooltip: 'Clear logs',
                color: Colors.red.shade400,
              ),
            ],
          ),
        ),
        if (_loadingLogs)
          const Expanded(
            child: Center(child: CircularProgressIndicator(color: _accent)),
          )
        else if (_logs.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No compliance logs found',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                return _buildLogEntry(log, isDark);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildLogEntry(ComplianceLog log, bool isDark) {
    IconData icon;
    Color color;

    switch (log.actionType) {
      case 'auto_clock_out':
        icon = Icons.logout;
        color = Colors.red;
        break;
      case 'timeout_extended':
        icon = Icons.add_alarm;
        color = Colors.blue;
        break;
      case 'warning_sent':
        icon = Icons.warning_amber;
        color = Colors.orange;
        break;
      default:
        icon = Icons.info_outline;
        color = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      log.actionTypeDisplay,
                      style: TextStyle(fontWeight: FontWeight.bold, color: color),
                    ),
                    const Spacer(),
                    Text(
                      _formatDateTime(log.createdAt),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  log.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (log.reason != null && log.reason!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    log.reason!,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
                if (log.minutesInactive != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Inactive for ${log.minutesInactive} minutes',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
                if (log.performedBy != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'By: ${log.performedBy}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red.shade300, size: 20),
            onPressed: () => _deleteLogEntry(log),
            tooltip: 'Delete this log entry',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteLogEntry(ComplianceLog log) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Log Entry'),
        content: Text(
          'Delete this ${log.actionTypeDisplay} entry for ${log.displayName}?\n\nThis cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await ComplianceService.deleteLog(
        logId: log.id,
        deletedBy: widget.currentUsername,
      );

      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Log entry deleted'),
            backgroundColor: Colors.green,
          ),
        );
        _loadLogs();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete log entry'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSettingsTab(bool isDark) {
    final bgColor = isDark ? const Color(0xFF252525) : Colors.white;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _accent.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.settings, color: _accent),
                    const SizedBox(width: 8),
                    const Text(
                      'Compliance Settings',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    if (!_editingSettings)
                      TextButton.icon(
                        onPressed: () => setState(() => _editingSettings = true),
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit'),
                      )
                    else
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() => _editingSettings = false);
                              _loadStatus();
                            },
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _saveSettings,
                            style: FilledButton.styleFrom(backgroundColor: _accent),
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                  ],
                ),
                const Divider(height: 24),
                SwitchListTile(
                  title: const Text('Enable Compliance Monitoring'),
                  subtitle: const Text('Auto clock-out users without heartbeat'),
                  value: _settingsEnabled,
                  onChanged: _editingSettings
                      ? (v) => setState(() => _settingsEnabled = v)
                      : null,
                  activeTrackColor: _accent.withValues(alpha: 0.5),
                  activeThumbColor: _accent,
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Heartbeat Timeout'),
                  subtitle: Text('Auto clock-out after $_settingsTimeout minutes without heartbeat'),
                  trailing: _editingSettings
                      ? SizedBox(
                          width: 100,
                          child: DropdownButtonFormField<int>(
                            initialValue: _settingsTimeout,
                            items: [10, 15, 20, 30, 45, 60]
                                .map((m) => DropdownMenuItem(value: m, child: Text('$m min')))
                                .toList(),
                            onChanged: (v) => setState(() => _settingsTimeout = v!),
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 12),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        )
                      : Text('$_settingsTimeout min'),
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: const Text('Grace Period After Shift'),
                  subtitle: Text('Extra time after scheduled end: $_settingsGrace minutes'),
                  trailing: _editingSettings
                      ? SizedBox(
                          width: 100,
                          child: DropdownButtonFormField<int>(
                            initialValue: _settingsGrace,
                            items: [15, 30, 45, 60, 90, 120]
                                .map((m) => DropdownMenuItem(value: m, child: Text('$m min')))
                                .toList(),
                            onChanged: (v) => setState(() => _settingsGrace = v!),
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 12),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        )
                      : Text('$_settingsGrace min'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Send Notifications'),
                  subtitle: const Text('Alert admins when users are auto clocked-out'),
                  value: _settingsNotify,
                  onChanged: _editingSettings
                      ? (v) => setState(() => _settingsNotify = v)
                      : null,
                  activeTrackColor: _accent.withValues(alpha: 0.5),
                  activeThumbColor: _accent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'How It Works',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInfoRow('1.', 'App sends heartbeat every 2 minutes while user is clocked in'),
                _buildInfoRow('2.', 'Server monitors heartbeats and detects inactive users'),
                _buildInfoRow('3.', 'Users exceeding timeout threshold are auto clocked-out'),
                _buildInfoRow('4.', 'Managers can extend timeout for specific users if needed'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Use "Extend Timeout" for legitimate cases like internet issues. All extensions are logged.',
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(number, style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: Colors.grey.shade700, fontSize: 13))),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${dt.month}/${dt.day}/${dt.year}';
  }
}
