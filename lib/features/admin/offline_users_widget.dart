import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';

/// Widget that displays users whose apps are currently offline
/// Part of Layer 3 of the multi-layered restart system
class OfflineUsersWidget extends StatefulWidget {
  /// Whether to show in compact mode (for dashboard tiles)
  final bool compact;

  /// Refresh interval in seconds (default: 30)
  final int refreshInterval;

  const OfflineUsersWidget({
    super.key,
    this.compact = false,
    this.refreshInterval = 30,
  });

  @override
  State<OfflineUsersWidget> createState() => _OfflineUsersWidgetState();
}

class _OfflineUsersWidgetState extends State<OfflineUsersWidget> {
  List<OfflineUser> _offlineUsers = [];
  OfflineSummary? _summary;
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;
  DateTime? _lastUpdate;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(
      Duration(seconds: widget.refreshInterval),
      (_) => _fetchData(),
    );
  }

  Future<void> _fetchData() async {
    try {
      // Fetch both offline users and summary in parallel
      final results = await Future.wait([
        _fetchOfflineUsers(),
        _fetchSummary(),
      ]);

      if (mounted) {
        setState(() {
          _offlineUsers = results[0] as List<OfflineUser>;
          _summary = results[1] as OfflineSummary?;
          _loading = false;
          _error = null;
          _lastUpdate = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<List<OfflineUser>> _fetchOfflineUsers() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.apiBase}/heartbeat_monitor.php?action=get_offline_users'),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return (data['users'] as List)
            .map((u) => OfflineUser.fromJson(u))
            .toList();
      }
    }
    return [];
  }

  Future<OfflineSummary?> _fetchSummary() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.apiBase}/heartbeat_monitor.php?action=get_summary'),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['summary'] != null) {
        return OfflineSummary.fromJson(data['summary']);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _buildCompactView();
    }
    return _buildFullView();
  }

  Widget _buildCompactView() {
    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final criticalCount = _offlineUsers.where((u) => u.statusLevel == 'critical').length;
    final warningCount = _offlineUsers.where((u) => u.statusLevel == 'warning').length;

    return Card(
      child: InkWell(
        onTap: () => _showDetailDialog(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _offlineUsers.isEmpty ? Icons.check_circle : Icons.warning,
                    color: criticalCount > 0
                        ? Colors.red
                        : warningCount > 0
                            ? Colors.orange
                            : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'App Status',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_summary != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatusChip('Online', _summary!.online, Colors.green),
                    _buildStatusChip('Offline', _offlineUsers.length, Colors.orange),
                    _buildStatusChip('Critical', criticalCount, Colors.red),
                  ],
                ),
              ] else if (_offlineUsers.isEmpty)
                const Text(
                  'All users online',
                  style: TextStyle(color: Colors.green),
                )
              else
                Text(
                  '${_offlineUsers.length} user(s) offline',
                  style: TextStyle(
                    color: criticalCount > 0 ? Colors.red : Colors.orange,
                  ),
                ),
              if (_lastUpdate != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Updated ${_formatTimeAgo(_lastUpdate!)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: count > 0 ? color : Colors.grey,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildFullView() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Offline Users',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Row(
                  children: [
                    if (_lastUpdate != null)
                      Text(
                        'Updated ${_formatTimeAgo(_lastUpdate!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _fetchData,
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
              ],
            ),
            const Divider(),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[300], size: 48),
                    const SizedBox(height: 8),
                    Text('Error: $_error'),
                    TextButton(
                      onPressed: _fetchData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else if (_offlineUsers.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 48),
                      SizedBox(height: 8),
                      Text(
                        'All users are online',
                        style: TextStyle(color: Colors.green),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _offlineUsers.length,
                itemBuilder: (context, index) {
                  return _buildUserTile(_offlineUsers[index]);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserTile(OfflineUser user) {
    final statusColor = switch (user.statusLevel) {
      'critical' => Colors.red,
      'warning' => Colors.orange,
      _ => Colors.grey,
    };

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: statusColor.withValues(alpha: 0.2),
        child: Icon(
          user.statusLevel == 'critical' ? Icons.error : Icons.warning,
          color: statusColor,
        ),
      ),
      title: Text(user.displayName),
      subtitle: Text(
        'Offline for ${user.offlineMinutes} min • ${user.role ?? "Unknown role"}',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withValues(alpha: 0.5)),
            ),
            child: Text(
              user.statusLevel.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'v${user.appVersion ?? "?"}',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.monitor_heart),
            SizedBox(width: 8),
            Text('App Status Monitor'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: _buildFullView(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${diff.inHours}h ago';
    }
  }
}

/// Model for offline user data
class OfflineUser {
  final String username;
  final String displayName;
  final String? role;
  final String? lastHeartbeat;
  final String? appVersion;
  final int offlineSeconds;
  final int offlineMinutes;
  final String statusLevel;

  OfflineUser({
    required this.username,
    required this.displayName,
    this.role,
    this.lastHeartbeat,
    this.appVersion,
    required this.offlineSeconds,
    required this.offlineMinutes,
    required this.statusLevel,
  });

  factory OfflineUser.fromJson(Map<String, dynamic> json) {
    return OfflineUser(
      username: json['username'] ?? '',
      displayName: json['display_name'] ?? json['username'] ?? '',
      role: json['role'],
      lastHeartbeat: json['last_heartbeat'],
      appVersion: json['app_version'],
      offlineSeconds: json['offline_seconds'] ?? 0,
      offlineMinutes: json['offline_minutes'] ?? 0,
      statusLevel: json['status_level'] ?? 'offline',
    );
  }
}

/// Model for summary data
class OfflineSummary {
  final int totalUsers;
  final int online;
  final int offline;
  final int warning;
  final int critical;
  final int neverConnected;
  final int alertsToday;
  final int unresolvedAlerts;

  OfflineSummary({
    required this.totalUsers,
    required this.online,
    required this.offline,
    required this.warning,
    required this.critical,
    required this.neverConnected,
    required this.alertsToday,
    required this.unresolvedAlerts,
  });

  factory OfflineSummary.fromJson(Map<String, dynamic> json) {
    return OfflineSummary(
      totalUsers: json['total_users'] ?? 0,
      online: json['online'] ?? 0,
      offline: json['offline'] ?? 0,
      warning: json['warning'] ?? 0,
      critical: json['critical'] ?? 0,
      neverConnected: json['never_connected'] ?? 0,
      alertsToday: json['alerts_today'] ?? 0,
      unresolvedAlerts: json['unresolved_alerts'] ?? 0,
    );
  }
}
