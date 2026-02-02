import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../app_theme.dart';
import '../../config/api_config.dart';

/// Detailed user metrics screen showing comprehensive system information
class UserMetricsDetailScreen extends StatefulWidget {
  final String username;
  final String displayName;
  final String role;
  final String appVersion;
  final String appStatus;
  final Uint8List? profilePicture;

  const UserMetricsDetailScreen({
    super.key,
    required this.username,
    required this.displayName,
    required this.role,
    required this.appVersion,
    required this.appStatus,
    this.profilePicture,
  });

  @override
  State<UserMetricsDetailScreen> createState() => _UserMetricsDetailScreenState();
}

class _UserMetricsDetailScreenState extends State<UserMetricsDetailScreen> {
  static const Color _accent = AppColors.accent;

  // Programs to exclude from display (privacy - personal browser)
  static const List<String> _excludedPrograms = ['brave'];

  /// Check if a program name should be excluded from display
  bool _isExcludedProgram(String programName) {
    final lowerName = programName.toLowerCase();
    return _excludedPrograms.any((excluded) => lowerName.contains(excluded));
  }

  _SystemMetrics? _metrics;
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadMetrics());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMetrics() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.systemMetrics}?action=get&username=${Uri.encodeComponent(widget.username)}'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['metrics'] != null) {
          if (mounted) {
            setState(() {
              _metrics = _SystemMetrics.fromJson(data['metrics']);
              _loading = false;
              _error = null;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _loading = false;
              _error = data['error'] ?? 'No metrics available for this user';
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load metrics: $e';
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'online': return Colors.green;
      case 'away': return Colors.orange;
      default: return Colors.grey;
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'developer': return Colors.purple;
      case 'administrator': return Colors.red;
      case 'management': return Colors.blue;
      case 'dispatcher': return Colors.teal;
      case 'remote_dispatcher': return Colors.cyan;
      case 'technician': return Colors.green;
      case 'marketing': return Colors.orange;
      default: return Colors.grey;
    }
  }

  String _formatRole(String role) {
    if (role.isEmpty) return 'No Role';
    return role[0].toUpperCase() + role.substring(1).replaceAll('_', ' ');
  }

  Color _getUsageColor(double percentage) {
    if (percentage < 50) return Colors.green;
    if (percentage < 75) return Colors.orange;
    return Colors.red;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _formatUptime(int seconds) {
    final days = seconds ~/ 86400;
    final hours = (seconds % 86400) ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    
    if (days > 0) return '${days}d ${hours}h ${mins}m';
    if (hours > 0) return '${hours}h ${mins}m';
    return '${mins}m';
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);
      
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (e) {
      return timestamp;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _getStatusColor(widget.appStatus);
    final roleColor = _getRoleColor(widget.role);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[100],
      appBar: AppBar(
        title: const Text('System Metrics'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _loading = true);
              _loadMetrics();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User header card
            _buildCard(
              isDark: isDark,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: _accent.withValues(alpha: 0.2),
                    backgroundImage: widget.profilePicture != null 
                        ? MemoryImage(widget.profilePicture!) 
                        : null,
                    child: widget.profilePicture == null
                        ? Text(
                            widget.displayName.isNotEmpty 
                                ? widget.displayName[0].toUpperCase() 
                                : '?',
                            style: const TextStyle(
                              color: _accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.displayName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '@${widget.username}',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _buildBadge(_formatRole(widget.role), roleColor),
                            _buildBadge('v${widget.appVersion}', Colors.blue),
                            _buildBadge(
                              widget.appStatus[0].toUpperCase() + widget.appStatus.substring(1),
                              statusColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (_loading)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator(color: _accent)),
              )
            else if (_error != null)
              _buildCard(
                isDark: isDark,
                child: Column(
                  children: [
                    Icon(Icons.info_outline, size: 48, color: Colors.orange[300]),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Metrics will appear once the user\'s app sends system data.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              )
            else if (_metrics != null) ...[
              const SizedBox(height: 16),
              
              // ============ SYSTEM INFO ============
              _buildSectionTitle('System Information', Icons.computer),
              _buildCard(
                isDark: isDark,
                child: Table(
                  columnWidths: const {
                    0: FixedColumnWidth(32),
                    1: FixedColumnWidth(140),
                    2: FlexColumnWidth(),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    _buildTableRow(Icons.desktop_windows, 'Computer', _metrics!.computerName, isDark),
                    _buildTableRow(Icons.window, 'Operating System', _metrics!.osName, isDark),
                    _buildTableRow(Icons.info_outline, 'OS Version', _metrics!.osVersion, isDark),
                    _buildTableRow(Icons.memory, 'Processor', _metrics!.processor, isDark),
                    _buildTableRow(Icons.developer_board, 'CPU Cores', '${_metrics!.cpuCores} cores', isDark),
                    _buildTableRow(Icons.storage, 'Total RAM', _formatBytes(_metrics!.totalRam), isDark),
                    if (_metrics!.gpuName.isNotEmpty)
                      _buildTableRow(Icons.videocam, 'GPU', _metrics!.gpuName, isDark),
                    _buildTableRow(Icons.timer, 'System Uptime', _formatUptime(_metrics!.uptimeSeconds), isDark),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ============ PERFORMANCE ============
              _buildSectionTitle('Performance', Icons.speed),
              _buildCard(
                isDark: isDark,
                child: Column(
                  children: [
                    _buildUsageBar('CPU Usage', _metrics!.cpuUsage, isDark),
                    const SizedBox(height: 16),
                    _buildUsageBar('Memory Usage', _metrics!.memoryUsage, isDark),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Available: ${_formatBytes(_metrics!.availableRam)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                        Text(
                          'Used: ${_formatBytes(_metrics!.totalRam - _metrics!.availableRam)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    if (_metrics!.gpuName.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildUsageBar('GPU Usage', _metrics!.gpuUsage, isDark),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ============ STORAGE ============
              _buildSectionTitle('Storage', Icons.storage),
              _buildCard(
                isDark: isDark,
                child: Column(
                  children: _metrics!.drives.map((drive) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.folder,
                                size: 18,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${drive.name} ${drive.label.isNotEmpty ? "(${drive.label})" : "(Local Disk)"}',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              const Spacer(),
                              Text(
                                '${_formatBytes(drive.usedSpace)} / ${_formatBytes(drive.totalSpace)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white54 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildUsageBar('', drive.usagePercent, isDark, showLabel: false),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 16),

              // ============ NETWORK ============
              _buildSectionTitle('Network', Icons.wifi),
              _buildCard(
                isDark: isDark,
                child: Table(
                  columnWidths: const {
                    0: FixedColumnWidth(32),
                    1: FixedColumnWidth(140),
                    2: FlexColumnWidth(),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    if (_metrics!.connectionType == 'WiFi' && _metrics!.wifiSsid.isNotEmpty)
                      _buildTableRow(Icons.wifi, 'WiFi Network', _metrics!.wifiSsid, isDark),
                    if (_metrics!.connectionType == 'WiFi' && _metrics!.signalStrength > 0)
                      _buildTableRow(Icons.signal_wifi_4_bar, 'Signal Strength', '${_metrics!.signalStrength}%', isDark),
                    if (_metrics!.connectionType.isNotEmpty)
                      _buildTableRow(Icons.cable, 'Connection Type', _metrics!.connectionType, isDark),
                    _buildTableRow(Icons.public, 'Public IP', _metrics!.publicIp.isNotEmpty ? _metrics!.publicIp : 'N/A', isDark),
                    _buildTableRow(Icons.lan, 'Local IP', _metrics!.localIp.isNotEmpty ? _metrics!.localIp : 'N/A', isDark),
                    if (_metrics!.networkAdapter.isNotEmpty)
                      _buildTableRow(Icons.settings_ethernet, 'Adapter', _metrics!.networkAdapter, isDark),
                    _buildTableRow(Icons.upload, 'Data Sent', _formatBytes(_metrics!.bytesSent), isDark),
                    _buildTableRow(Icons.download, 'Data Received', _formatBytes(_metrics!.bytesReceived), isDark),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ============ RUNNING APPS ============
              if (_metrics!.runningApps.where((app) => !_isExcludedProgram(app.name)).isNotEmpty) ...[
                _buildSectionTitle('Running Apps (${_metrics!.runningApps.where((app) => !_isExcludedProgram(app.name)).length})', Icons.apps),
                _buildCard(
                  isDark: isDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _metrics!.runningApps.where((app) => !_isExcludedProgram(app.name)).map((app) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.window,
                              size: 16,
                              color: _accent,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    app.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    app.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.white38 : Colors.black38,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _formatBytes(app.memoryBytes),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ============ BROWSER WINDOWS ============
              if (_metrics!.browserWindows.where((w) => !_isExcludedProgram(w.browser)).isNotEmpty) ...[
                _buildSectionTitle('Browser Tabs (${_metrics!.browserWindows.where((w) => !_isExcludedProgram(w.browser)).length})', Icons.web),
                _buildCard(
                  isDark: isDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _metrics!.browserWindows.where((w) => !_isExcludedProgram(w.browser)).map((window) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              _getBrowserIcon(window.browser),
                              size: 16,
                              color: _getBrowserColor(window.browser),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                window.title,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ============ USER ACTIVITY ============
              _buildSectionTitle('User Activity', Icons.person),
              _buildCard(
                isDark: isDark,
                child: Table(
                  columnWidths: const {
                    0: FixedColumnWidth(32),
                    1: FixedColumnWidth(140),
                    2: FlexColumnWidth(),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    _buildTableRow(
                      Icons.timer_outlined, 
                      'Idle Time', 
                      _formatIdleTime(_metrics!.idleSeconds), 
                      isDark,
                    ),
                    _buildTableRow(
                      _metrics!.screenLocked ? Icons.lock : Icons.lock_open, 
                      'Screen', 
                      _metrics!.screenLocked ? 'Locked' : 'Unlocked', 
                      isDark,
                    ),
                    if (_metrics!.activeWindow.isNotEmpty)
                      _buildTableRow(
                        Icons.web_asset,
                        'Active Window',
                        // Show "A1 Tools" if Brave is the active window (privacy)
                        _isExcludedProgram(_metrics!.activeWindow) ? 'A1 Tools' : _metrics!.activeWindow,
                        isDark,
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ============ SECURITY STATUS ============
              _buildSectionTitle('Security', Icons.security),
              _buildCard(
                isDark: isDark,
                child: Column(
                  children: [
                    // Defender status row
                    Row(
                      children: [
                        Icon(
                          _metrics!.defenderEnabled ? Icons.shield : Icons.shield_outlined,
                          color: _metrics!.defenderEnabled ? Colors.green : Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Windows Defender', style: TextStyle(fontWeight: FontWeight.w500)),
                              Text(
                                _metrics!.defenderEnabled 
                                    ? (_metrics!.defenderRealtime ? 'Active & Real-time protection on' : 'Active but real-time off')
                                    : 'Disabled',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _metrics!.defenderEnabled ? Colors.green : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_metrics!.defenderDefinitionsAge > 0)
                          _buildBadge(
                            'Definitions: ${_metrics!.defenderDefinitionsAge}d old',
                            _metrics!.defenderDefinitionsAge > 7 ? Colors.orange : Colors.green,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Firewall row
                    Row(
                      children: [
                        Icon(
                          _metrics!.firewallEnabled ? Icons.local_fire_department : Icons.local_fire_department_outlined,
                          color: _metrics!.firewallEnabled ? Colors.green : Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Windows Firewall', style: TextStyle(fontWeight: FontWeight.w500)),
                              Text(
                                _metrics!.firewallEnabled ? 'Enabled' : 'Disabled',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _metrics!.firewallEnabled ? Colors.green : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Windows Updates row
                    Row(
                      children: [
                        Icon(
                          Icons.system_update,
                          color: _metrics!.pendingUpdatesCount > 0 ? Colors.orange : Colors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Windows Updates', style: TextStyle(fontWeight: FontWeight.w500)),
                              Text(
                                _metrics!.pendingUpdatesCount > 0 
                                    ? '${_metrics!.pendingUpdatesCount} pending update(s)'
                                    : 'Up to date',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _metrics!.pendingUpdatesCount > 0 ? Colors.orange : Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Show pending updates list
                    if (_metrics!.pendingUpdates.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Divider(),
                      ...(_metrics!.pendingUpdates.take(5).map((update) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const SizedBox(width: 32),
                              Expanded(
                                child: Text(
                                  update.title,
                                  style: const TextStyle(fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (update.kb.isNotEmpty)
                                Text(
                                  update.kb,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white38 : Colors.black38,
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList()),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ============ BATTERY (if present) ============
              if (_metrics!.hasBattery) ...[
                _buildSectionTitle('Battery', Icons.battery_full),
                _buildCard(
                  isDark: isDark,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            _getBatteryIcon(_metrics!.batteryPercent, _metrics!.isCharging),
                            color: _getBatteryColor(_metrics!.batteryPercent),
                            size: 32,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '${_metrics!.batteryPercent}%',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildBadge(
                                      _metrics!.batteryStatus,
                                      _metrics!.isCharging ? Colors.green : Colors.blue,
                                    ),
                                  ],
                                ),
                                if (_metrics!.batteryTimeRemaining > 0 && !_metrics!.isCharging)
                                  Text(
                                    '${_metrics!.batteryTimeRemaining} minutes remaining',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white54 : Colors.black54,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildUsageBar('', _metrics!.batteryPercent.toDouble(), isDark, showLabel: false),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ============ ACTIVE CONNECTIONS ============
              if (_metrics!.activeConnections.where((c) => !_isExcludedProgram(c.process)).isNotEmpty) ...[
                _buildSectionTitle('Active Connections (${_metrics!.activeConnections.where((c) => !_isExcludedProgram(c.process)).length})', Icons.cable),
                _buildCard(
                  isDark: isDark,
                  child: Column(
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Process',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'Remote Address',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 50,
                              child: Text(
                                'Port',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      ...(_metrics!.activeConnections.where((c) => !_isExcludedProgram(c.process)).take(15).map((conn) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  conn.process.isNotEmpty ? conn.process : 'Unknown',
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  conn.remoteAddress,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(
                                width: 50,
                                child: Text(
                                  '${conn.remotePort}',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white54 : Colors.black54,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList()),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ============ INSTALLED PROGRAMS ============
              if (_metrics!.installedPrograms.where((p) => !_isExcludedProgram(p.name)).isNotEmpty) ...[
                _buildSectionTitle('Installed Programs (${_metrics!.installedPrograms.where((p) => !_isExcludedProgram(p.name)).length})', Icons.apps),
                _buildCard(
                  isDark: isDark,
                  child: Column(
                    children: _metrics!.installedPrograms.where((p) => !_isExcludedProgram(p.name)).take(20).map((program) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 16,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    program.name,
                                    style: const TextStyle(fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (program.publisher.isNotEmpty)
                                    Text(
                                      program.publisher,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.white38 : Colors.black38,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (program.version.isNotEmpty)
                              Text(
                                'v${program.version}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white54 : Colors.black54,
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ============ PROCESSES (moved to bottom) ============
              _buildSectionTitle('Running Processes (${_metrics!.processes.where((p) => !_isExcludedProgram(p.name)).length})', Icons.list),
              _buildCard(
                isDark: isDark,
                child: _metrics!.processes.where((p) => !_isExcludedProgram(p.name)).isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No process data available'),
                      )
                    : Column(
                        children: [
                          // Header row
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'Process',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white38 : Colors.black38,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'Memory',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white38 : Colors.black38,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          ...(_metrics!.processes.where((p) => !_isExcludedProgram(p.name)).map((proc) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      proc.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      _formatBytes(proc.memoryBytes),
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.white54 : Colors.black54,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList()),
                        ],
                      ),
              ),

              // Last Updated
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Last updated: ${_formatTimestamp(_metrics!.timestamp)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required bool isDark, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: child,
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _accent),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  TableRow _buildTableRow(IconData icon, String label, String value, bool isDark) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Icon(icon, size: 16, color: isDark ? Colors.white38 : Colors.black38),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildUsageBar(String label, double percentage, bool isDark, {bool showLabel = true}) {
    final color = _getUsageColor(percentage);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        if (showLabel) const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (percentage / 100).clamp(0.0, 1.0),
            backgroundColor: isDark ? Colors.white12 : Colors.black12,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  IconData _getBrowserIcon(String browser) {
    switch (browser.toLowerCase()) {
      case 'chrome':
        return Icons.public;
      case 'msedge':
        return Icons.language;
      case 'firefox':
        return Icons.local_fire_department;
      case 'brave':
        return Icons.shield;
      case 'librewolf':
        return Icons.pets; // Wolf icon
      default:
        return Icons.web;
    }
  }

  Color _getBrowserColor(String browser) {
    switch (browser.toLowerCase()) {
      case 'chrome':
        return Colors.blue;
      case 'msedge':
        return Colors.cyan;
      case 'firefox':
        return Colors.orange;
      case 'brave':
        return Colors.deepOrange;
      case 'librewolf':
        return Colors.indigo; // Purple/indigo for LibreWolf
      default:
        return Colors.grey;
    }
  }

  String _formatIdleTime(int seconds) {
    if (seconds < 60) return 'Active now';
    if (seconds < 3600) return '${seconds ~/ 60} min idle';
    if (seconds < 86400) return '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m idle';
    return '${seconds ~/ 86400}d idle';
  }

  IconData _getBatteryIcon(int percent, bool isCharging) {
    if (isCharging) return Icons.battery_charging_full;
    if (percent > 90) return Icons.battery_full;
    if (percent > 70) return Icons.battery_6_bar;
    if (percent > 50) return Icons.battery_5_bar;
    if (percent > 30) return Icons.battery_3_bar;
    if (percent > 15) return Icons.battery_2_bar;
    return Icons.battery_alert;
  }

  Color _getBatteryColor(int percent) {
    if (percent > 50) return Colors.green;
    if (percent > 20) return Colors.orange;
    return Colors.red;
  }
}

// ============ DATA MODELS ============

class _SystemMetrics {
  final String computerName;
  final String osName;
  final String osVersion;
  final String processor;
  final int cpuCores;
  final String gpuName;
  final double gpuUsage;
  final int totalRam;
  final int availableRam;
  final double cpuUsage;
  final double memoryUsage;
  final List<_DriveInfo> drives;
  final String publicIp;
  final String localIp;
  final String networkAdapter;
  final String wifiSsid;
  final String connectionType;
  final int signalStrength;
  final int bytesSent;
  final int bytesReceived;
  final int uptimeSeconds;
  final List<_ProcessInfo> processes;
  final List<_BrowserWindow> browserWindows;
  final List<_RunningApp> runningApps;
  // New fields
  final int idleSeconds;
  final bool screenLocked;
  final String activeWindow;
  final bool defenderEnabled;
  final bool defenderRealtime;
  final String defenderLastScan;
  final int defenderDefinitionsAge;
  final bool firewallEnabled;
  final int pendingUpdatesCount;
  final List<_PendingUpdate> pendingUpdates;
  final bool hasBattery;
  final int batteryPercent;
  final String batteryStatus;
  final int batteryTimeRemaining;
  final bool isCharging;
  final List<_InstalledProgram> installedPrograms;
  final List<_StartupProgram> startupPrograms;
  final List<_ActiveConnection> activeConnections;
  final String timestamp;

  _SystemMetrics({
    required this.computerName,
    required this.osName,
    required this.osVersion,
    required this.processor,
    required this.cpuCores,
    required this.gpuName,
    required this.gpuUsage,
    required this.totalRam,
    required this.availableRam,
    required this.cpuUsage,
    required this.memoryUsage,
    required this.drives,
    required this.publicIp,
    required this.localIp,
    required this.networkAdapter,
    required this.wifiSsid,
    required this.connectionType,
    required this.signalStrength,
    required this.bytesSent,
    required this.bytesReceived,
    required this.uptimeSeconds,
    required this.processes,
    required this.browserWindows,
    required this.runningApps,
    required this.idleSeconds,
    required this.screenLocked,
    required this.activeWindow,
    required this.defenderEnabled,
    required this.defenderRealtime,
    required this.defenderLastScan,
    required this.defenderDefinitionsAge,
    required this.firewallEnabled,
    required this.pendingUpdatesCount,
    required this.pendingUpdates,
    required this.hasBattery,
    required this.batteryPercent,
    required this.batteryStatus,
    required this.batteryTimeRemaining,
    required this.isCharging,
    required this.installedPrograms,
    required this.startupPrograms,
    required this.activeConnections,
    required this.timestamp,
  });

  factory _SystemMetrics.fromJson(Map<String, dynamic> json) {
    return _SystemMetrics(
      computerName: json['computer_name'] ?? '',
      osName: json['os_name'] ?? '',
      osVersion: json['os_version'] ?? '',
      processor: json['processor'] ?? '',
      cpuCores: json['cpu_cores'] ?? 0,
      gpuName: json['gpu_name'] ?? '',
      gpuUsage: (json['gpu_usage'] ?? 0).toDouble(),
      totalRam: json['total_ram'] ?? 0,
      availableRam: json['available_ram'] ?? 0,
      cpuUsage: (json['cpu_usage'] ?? 0).toDouble(),
      memoryUsage: (json['memory_usage'] ?? 0).toDouble(),
      drives: (json['drives'] as List<dynamic>?)
          ?.map((d) => _DriveInfo.fromJson(d))
          .toList() ?? [],
      publicIp: json['public_ip'] ?? '',
      localIp: json['local_ip'] ?? '',
      networkAdapter: json['network_adapter'] ?? '',
      wifiSsid: json['wifi_ssid'] ?? '',
      connectionType: json['connection_type'] ?? '',
      signalStrength: json['signal_strength'] ?? 0,
      bytesSent: json['bytes_sent'] ?? 0,
      bytesReceived: json['bytes_received'] ?? 0,
      uptimeSeconds: json['uptime_seconds'] ?? 0,
      processes: (json['processes'] as List<dynamic>?)
          ?.map((p) => _ProcessInfo.fromJson(p))
          .toList() ?? [],
      browserWindows: (json['browser_windows'] as List<dynamic>?)
          ?.map((b) => _BrowserWindow.fromJson(b))
          .toList() ?? [],
      runningApps: (json['running_apps'] as List<dynamic>?)
          ?.map((a) => _RunningApp.fromJson(a))
          .toList() ?? [],
      // New fields
      idleSeconds: json['idle_seconds'] ?? 0,
      screenLocked: json['screen_locked'] ?? false,
      activeWindow: json['active_window'] ?? '',
      defenderEnabled: json['defender_enabled'] ?? false,
      defenderRealtime: json['defender_realtime'] ?? false,
      defenderLastScan: json['defender_last_scan'] ?? '',
      defenderDefinitionsAge: json['defender_definitions_age'] ?? 0,
      firewallEnabled: json['firewall_enabled'] ?? false,
      pendingUpdatesCount: json['pending_updates_count'] ?? 0,
      pendingUpdates: (json['pending_updates'] as List<dynamic>?)
          ?.map((u) => _PendingUpdate.fromJson(u))
          .toList() ?? [],
      hasBattery: json['has_battery'] ?? false,
      batteryPercent: json['battery_percent'] ?? 0,
      batteryStatus: json['battery_status'] ?? '',
      batteryTimeRemaining: json['battery_time_remaining'] ?? 0,
      isCharging: json['is_charging'] ?? false,
      installedPrograms: (json['installed_programs'] as List<dynamic>?)
          ?.map((p) => _InstalledProgram.fromJson(p))
          .toList() ?? [],
      startupPrograms: (json['startup_programs'] as List<dynamic>?)
          ?.map((p) => _StartupProgram.fromJson(p))
          .toList() ?? [],
      activeConnections: (json['active_connections'] as List<dynamic>?)
          ?.map((c) => _ActiveConnection.fromJson(c))
          .toList() ?? [],
      timestamp: json['timestamp'] ?? '',
    );
  }
}

class _DriveInfo {
  final String name;
  final String label;
  final int totalSpace;
  final int freeSpace;
  final int usedSpace;
  final double usagePercent;

  _DriveInfo({
    required this.name,
    required this.label,
    required this.totalSpace,
    required this.freeSpace,
    required this.usedSpace,
    required this.usagePercent,
  });

  factory _DriveInfo.fromJson(Map<String, dynamic> json) {
    final total = json['total_space'] ?? 0;
    final free = json['free_space'] ?? 0;
    final used = total - free;
    return _DriveInfo(
      name: json['name'] ?? '',
      label: json['label'] ?? '',
      totalSpace: total,
      freeSpace: free,
      usedSpace: used,
      usagePercent: total > 0 ? (used / total * 100) : 0,
    );
  }
}

class _ProcessInfo {
  final String name;
  final double cpuPercent;
  final int memoryBytes;

  _ProcessInfo({
    required this.name,
    required this.cpuPercent,
    required this.memoryBytes,
  });

  factory _ProcessInfo.fromJson(Map<String, dynamic> json) {
    return _ProcessInfo(
      name: json['name'] ?? '',
      cpuPercent: (json['cpu_percent'] ?? 0).toDouble(),
      memoryBytes: json['memory_bytes'] ?? 0,
    );
  }
}

class _BrowserWindow {
  final String browser;
  final String title;

  _BrowserWindow({
    required this.browser,
    required this.title,
  });

  factory _BrowserWindow.fromJson(Map<String, dynamic> json) {
    return _BrowserWindow(
      browser: json['browser'] ?? '',
      title: json['title'] ?? '',
    );
  }
}

class _RunningApp {
  final String name;
  final String title;
  final int memoryBytes;

  _RunningApp({
    required this.name,
    required this.title,
    required this.memoryBytes,
  });

  factory _RunningApp.fromJson(Map<String, dynamic> json) {
    return _RunningApp(
      name: json['name'] ?? '',
      title: json['title'] ?? '',
      memoryBytes: json['memory_bytes'] ?? 0,
    );
  }
}

class _PendingUpdate {
  final String title;
  final String kb;

  _PendingUpdate({
    required this.title,
    required this.kb,
  });

  factory _PendingUpdate.fromJson(Map<String, dynamic> json) {
    return _PendingUpdate(
      title: json['title'] ?? '',
      kb: json['kb'] ?? '',
    );
  }
}

class _InstalledProgram {
  final String name;
  final String version;
  final String publisher;
  final String installDate;
  final double sizeMb;

  _InstalledProgram({
    required this.name,
    required this.version,
    required this.publisher,
    required this.installDate,
    required this.sizeMb,
  });

  factory _InstalledProgram.fromJson(Map<String, dynamic> json) {
    return _InstalledProgram(
      name: json['name'] ?? '',
      version: json['version'] ?? '',
      publisher: json['publisher'] ?? '',
      installDate: json['install_date'] ?? '',
      sizeMb: (json['size_mb'] ?? 0).toDouble(),
    );
  }
}

class _StartupProgram {
  final String name;
  final String command;
  final String location;

  _StartupProgram({
    required this.name,
    required this.command,
    required this.location,
  });

  factory _StartupProgram.fromJson(Map<String, dynamic> json) {
    return _StartupProgram(
      name: json['name'] ?? '',
      command: json['command'] ?? '',
      location: json['location'] ?? '',
    );
  }
}

class _ActiveConnection {
  final String process;
  final int localPort;
  final String remoteAddress;
  final int remotePort;

  _ActiveConnection({
    required this.process,
    required this.localPort,
    required this.remoteAddress,
    required this.remotePort,
  });

  factory _ActiveConnection.fromJson(Map<String, dynamic> json) {
    return _ActiveConnection(
      process: json['process'] ?? '',
      localPort: json['local_port'] ?? 0,
      remoteAddress: json['remote_address'] ?? '',
      remotePort: json['remote_port'] ?? 0,
    );
  }
}
