import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../app_theme.dart';
import '../../config/api_config.dart';
import 'user_metrics_detail_screen.dart';

/// Data Analysis Screen - User Activity Dashboard
/// Shows all users with their online status, app version, and activity metrics
class DataAnalysisScreen extends StatefulWidget {
  final String? currentUsername;

  const DataAnalysisScreen({super.key, this.currentUsername});

  @override
  State<DataAnalysisScreen> createState() => _DataAnalysisScreenState();
}

class _DataAnalysisScreenState extends State<DataAnalysisScreen> {
  static const String _baseUrl = ApiConfig.apiBase;

  List<_UserData> _users = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;
  
  // Filters
  String? _selectedRoleFilter;
  String _statusFilter = 'all'; // all, online, offline
  String _searchQuery = '';
  
  // Profile picture cache
  final Map<String, Uint8List> _profilePictureCache = {};
  final Set<String> _loadingPictures = {};
  
  // Stats
  int _onlineCount = 0;
  int _awayCount = 0;
  int _offlineCount = 0;
  int _mobileCount = 0;

  static const Color _accent = AppColors.accent;
  
  // Status colors
  static const Color _onlineColor = Color(0xFF4CAF50);   // Green
  static const Color _awayColor = Color(0xFFF49320);     // Orange
  static const Color _offlineColor = Color(0xFFF44336); // Red
  static const Color _mobileColor = Color(0xFF2196F3);  // Blue

  @override
  void initState() {
    super.initState();
    _loadData();
    // Refresh every 15 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadData());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // Fetch users from user_management
      final requestingUsername = widget.currentUsername ?? '';
      final usersResponse = await http.get(
        Uri.parse('$_baseUrl/user_management.php?action=list&requesting_username=$requestingUsername'),
        headers: requestingUsername.isNotEmpty ? {'X-Username': requestingUsername} : null,
      ).timeout(const Duration(seconds: 15));

      // Fetch latest metrics for all users
      final metricsResponse = await http.get(
        Uri.parse('$_baseUrl/system_metrics.php?action=list_all'),
      ).timeout(const Duration(seconds: 15));

      final Map<String, Map<String, dynamic>> metricsMap = {};
      
      if (metricsResponse.statusCode == 200) {
        final metricsData = jsonDecode(metricsResponse.body);
        if (metricsData['success'] == true && metricsData['users'] != null) {
          for (final m in metricsData['users']) {
            final username = m['username'] as String? ?? '';
            if (username.isNotEmpty) {
              metricsMap[username] = m;
            }
          }
        }
      }

      if (usersResponse.statusCode == 200) {
        final data = jsonDecode(usersResponse.body);
        if (data['success'] == true && data['users'] != null) {
          final List<_UserData> users = [];
          
          for (final u in data['users']) {
            final username = u['username'] ?? '';
            final metrics = metricsMap[username];
            
            users.add(_UserData(
              username: username,
              firstName: u['first_name'] ?? '',
              lastName: u['last_name'] ?? '',
              role: u['role'] ?? '',
              appStatus: u['app_status'] ?? 'offline',
              appVersion: u['app_version'] ?? '',
              isOnline: u['is_online'] == 1 || u['is_online'] == true,
              cpuUsage: _parseDouble(metrics?['cpu_usage']),
              gpuUsage: _parseDouble(metrics?['gpu_usage']),
            ));
          }
          
          // Calculate stats
          int online = 0, away = 0, offline = 0, mobile = 0;
          for (final u in users) {
            if (u.appStatus == 'online') {
              online++;
            } else if (u.appStatus == 'away') {
              away++;
            } else if (u.appStatus == 'online_mobile') {
              mobile++;
            } else {
              offline++;
            }
          }

          if (mounted) {
            setState(() {
              _users = users;
              _loading = false;
              _error = null;
              _onlineCount = online;
              _awayCount = away;
              _offlineCount = offline;
              _mobileCount = mobile;
            });
            
            // Load profile pictures
            for (final user in users) {
              _loadProfilePicture(user.username);
            }
          }
        }
      }
    } catch (e) {
      if (mounted && _users.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'Failed to load data: $e';
        });
      }
    }
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Future<void> _loadProfilePicture(String username) async {
    if (_profilePictureCache.containsKey(username) || _loadingPictures.contains(username)) {
      return;
    }
    
    _loadingPictures.add(username);
    
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.profilePicture}?username=${Uri.encodeComponent(username)}'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['picture'] != null) {
          final bytes = base64Decode(data['picture']);
          if (mounted) {
            setState(() {
              _profilePictureCache[username] = bytes;
            });
          }
        }
      }
    } catch (e) {
      // Silent fail
    } finally {
      _loadingPictures.remove(username);
    }
  }

  List<String> get _availableRoles {
    final roles = _users.map((u) => u.role).where((r) => r.isNotEmpty).toSet().toList();
    roles.sort();
    return roles;
  }

  List<_UserData> get _filteredUsers {
    return _users.where((user) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!user.displayName.toLowerCase().contains(query) &&
            !user.username.toLowerCase().contains(query)) {
          return false;
        }
      }
      
      // Role filter
      if (_selectedRoleFilter != null && user.role != _selectedRoleFilter) {
        return false;
      }
      
      // Status filter
      if (_statusFilter == 'online' && 
          user.appStatus != 'online' && 
          user.appStatus != 'away' && 
          user.appStatus != 'online_mobile') {
        return false;
      }
      if (_statusFilter == 'offline' && user.appStatus != 'offline') {
        return false;
      }
      
      return true;
    }).toList()
      ..sort((a, b) {
        // Sort by status first (online/mobile/away first)
        int statusOrder(String s) {
          if (s == 'online') return 0;
          if (s == 'online_mobile') return 1;
          if (s == 'away') return 2;
          return 3;
        }
        final statusCompare = statusOrder(a.appStatus).compareTo(statusOrder(b.appStatus));
        if (statusCompare != 0) return statusCompare;
        return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
      });
  }

  String _formatRole(String role) {
    if (role.isEmpty) return 'No Role';
    return role[0].toUpperCase() + role.substring(1).replaceAll('_', ' ');
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'online': return _onlineColor;
      case 'online_mobile': return _mobileColor;
      case 'away': return _awayColor;
      default: return _offlineColor;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'online': return Icons.circle;
      case 'online_mobile': return Icons.phone_android;
      case 'away': return Icons.access_time;
      default: return Icons.circle_outlined;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'online': return 'Online';
      case 'online_mobile': return 'Mobile';
      case 'away': return 'Away';
      default: return 'Offline';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredUsers = _filteredUsers;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[100],
      appBar: AppBar(
        title: const Text('User Metrics'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
            ),
            child: Row(
              children: [
                _buildStatChip(
                  icon: Icons.circle,
                  label: 'Online',
                  count: _onlineCount,
                  color: _onlineColor,
                  isSelected: _statusFilter == 'online',
                  onTap: () => setState(() => _statusFilter = _statusFilter == 'online' ? 'all' : 'online'),
                ),
                const SizedBox(width: 8),
                _buildStatChip(
                  icon: Icons.phone_android,
                  label: 'Mobile',
                  count: _mobileCount,
                  color: _mobileColor,
                  isSelected: false,
                  onTap: null,
                ),
                const SizedBox(width: 8),
                _buildStatChip(
                  icon: Icons.access_time,
                  label: 'Away',
                  count: _awayCount,
                  color: _awayColor,
                  isSelected: false,
                  onTap: null,
                ),
                const SizedBox(width: 8),
                _buildStatChip(
                  icon: Icons.circle_outlined,
                  label: 'Offline',
                  count: _offlineCount,
                  color: _offlineColor,
                  isSelected: _statusFilter == 'offline',
                  onTap: () => setState(() => _statusFilter = _statusFilter == 'offline' ? 'all' : 'offline'),
                ),
                const Spacer(),
                Text(
                  '${_users.length} users',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          
          // Search and filter bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
            ),
            child: Row(
              children: [
                // Search field
                Expanded(
                  flex: 2,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search users...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                      ),
                      filled: true,
                      fillColor: isDark ? Colors.white10 : Colors.grey[100],
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                const SizedBox(width: 12),
                // Role filter
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _selectedRoleFilter,
                        isExpanded: true,
                        hint: const Text('All Roles'),
                        icon: const Icon(Icons.arrow_drop_down, size: 20),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All Roles'),
                          ),
                          ..._availableRoles.map((role) => DropdownMenuItem(
                            value: role,
                            child: Text(_formatRole(role)),
                          )),
                        ],
                        onChanged: (value) => setState(() => _selectedRoleFilter = value),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // User list
          Expanded(
            child: _loading && _users.isEmpty
                ? const Center(child: CircularProgressIndicator(color: _accent))
                : _error != null && _users.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                            const SizedBox(height: 16),
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadData,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(backgroundColor: _accent),
                            ),
                          ],
                        ),
                      )
                    : filteredUsers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person_search,
                                  size: 48,
                                  color: isDark ? Colors.white24 : Colors.black26,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No users match your filters',
                                  style: TextStyle(
                                    color: isDark ? Colors.white54 : Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () => setState(() {
                                    _searchQuery = '';
                                    _selectedRoleFilter = null;
                                    _statusFilter = 'all';
                                  }),
                                  child: const Text('Clear filters'),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadData,
                            color: _accent,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: filteredUsers.length,
                              itemBuilder: (context, index) => _buildUserCard(filteredUsers[index], isDark),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
    required bool isSelected,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(_UserData user, bool isDark) {
    final profilePicture = _profilePictureCache[user.username];
    final statusColor = _getStatusColor(user.appStatus);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: InkWell(
        onTap: () => _openUserMetrics(user),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar with status indicator
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: _accent.withValues(alpha: 0.2),
                    backgroundImage: profilePicture != null ? MemoryImage(profilePicture) : null,
                    child: profilePicture == null
                        ? Text(
                            user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: _accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              
              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name and username
                    Text(
                      user.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${user.username}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Badges row
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        // Role badge - always orange
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _formatRole(user.role),
                            style: const TextStyle(
                              fontSize: 11,
                              color: _accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        // Version badge
                        if (user.appVersion.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'v${user.appVersion}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.blue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getStatusIcon(user.appStatus),
                                size: 10,
                                color: statusColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _getStatusLabel(user.appStatus),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // CPU/GPU usage on the right + chevron arrow
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // CPU/GPU metrics (always show)
                  Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // CPU Usage
                          _buildMetricRow(
                            icon: Icons.memory,
                            label: 'CPU',
                            value: user.cpuUsage,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 6),
                          // GPU Usage
                          _buildMetricRow(
                            icon: Icons.videocam,
                            label: 'GPU',
                            value: user.gpuUsage,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                  // Chevron arrow (always visible)
                  Icon(
                    Icons.chevron_right,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricRow({
    required IconData icon,
    required String label,
    required double value,
    required bool isDark,
  }) {
    // Determine color based on usage level
    Color valueColor;
    if (value >= 80) {
      valueColor = _offlineColor; // Red for high usage
    } else if (value >= 50) {
      valueColor = _awayColor; // Orange for medium usage
    } else {
      valueColor = _onlineColor; // Green for low usage
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 12,
          color: isDark ? Colors.white38 : Colors.black38,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.white38 : Colors.black38,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          constraints: const BoxConstraints(minWidth: 38),
          child: Text(
            '${value.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 12,
              color: valueColor,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  void _openUserMetrics(_UserData user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserMetricsDetailScreen(
          username: user.username,
          displayName: user.displayName,
          role: user.role,
          appVersion: user.appVersion,
          appStatus: user.appStatus,
          profilePicture: _profilePictureCache[user.username],
        ),
      ),
    );
  }
}

class _UserData {
  final String username;
  final String firstName;
  final String lastName;
  final String role;
  final String appStatus;
  final String appVersion;
  final bool isOnline;
  final double cpuUsage;
  final double gpuUsage;

  _UserData({
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.appStatus,
    required this.appVersion,
    required this.isOnline,
    this.cpuUsage = 0.0,
    this.gpuUsage = 0.0,
  });

  String get displayName {
    if (firstName.isNotEmpty || lastName.isNotEmpty) {
      return '$firstName $lastName'.trim();
    }
    return username;
  }
}
