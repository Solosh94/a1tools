import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';

/// User VM status model
class UserVmStatus {
  final String username;
  final String displayName;
  final String role;
  final bool isOnVm;
  final String? vmType;
  final bool isBlocked;
  final DateTime? lastSeen;
  final bool isOnline;

  UserVmStatus({
    required this.username,
    required this.displayName,
    required this.role,
    required this.isOnVm,
    this.vmType,
    required this.isBlocked,
    this.lastSeen,
    required this.isOnline,
  });

  factory UserVmStatus.fromJson(Map<String, dynamic> json) {
    return UserVmStatus(
      username: json['username'] ?? '',
      displayName: json['display_name'] ?? json['username'] ?? '',
      role: json['role'] ?? 'user',
      isOnVm: json['is_on_vm'] == true || json['is_on_vm'] == 1,
      vmType: json['vm_type'],
      isBlocked: json['is_blocked'] == true || json['is_blocked'] == 1,
      lastSeen: json['last_seen'] != null
          ? DateTime.tryParse(json['last_seen'])
          : null,
      isOnline: json['is_online'] == true || json['is_online'] == 1,
    );
  }
}

/// VM Detection Settings Screen
/// Allows admins to enable/disable VM detection remotely
/// and manage per-user VM blocking
class VmSettingsScreen extends StatefulWidget {
  final String username;
  final String role;

  const VmSettingsScreen({
    super.key,
    required this.username,
    required this.role,
  });

  @override
  State<VmSettingsScreen> createState() => _VmSettingsScreenState();
}

class _VmSettingsScreenState extends State<VmSettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _vmDetectionEnabled = false;
  String? _error;

  // User list
  List<UserVmStatus> _users = [];
  bool _isLoadingUsers = false;
  String? _usersError;
  String _searchQuery = '';
  bool _showOnlyVmUsers = false;

  // Auto-refresh
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadSetting();
    _loadUsers();
    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadUsers();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSetting() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.vmSettings}?action=get_setting'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _vmDetectionEnabled = data['vm_detection_enabled'] == true;
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = data['error'] ?? 'Failed to load setting';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = 'Server error: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Network error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoadingUsers = true;
      _usersError = null;
    });

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.vmSettings}?action=get_users_vm_status'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final usersJson = data['users'] as List? ?? [];
          setState(() {
            _users = usersJson.map((u) => UserVmStatus.fromJson(u)).toList();
            _isLoadingUsers = false;
          });
        } else {
          setState(() {
            _usersError = data['error'] ?? 'Failed to load users';
            _isLoadingUsers = false;
          });
        }
      } else {
        setState(() {
          _usersError = 'Server error: ${response.statusCode}';
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      setState(() {
        _usersError = 'Network error: $e';
        _isLoadingUsers = false;
      });
    }
  }

  Future<void> _saveSetting(bool enabled) async {
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.vmSettings}?action=set_setting'),
        body: {
          'username': widget.username,
          'enabled': enabled ? '1' : '0',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _vmDetectionEnabled = data['vm_detection_enabled'] == true;
            _isSaving = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(enabled
                    ? 'VM detection enabled - takes effect immediately'
                    : 'VM detection disabled - takes effect immediately'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          setState(() {
            _error = data['error'] ?? 'Failed to save setting';
            _isSaving = false;
          });
        }
      } else {
        setState(() {
          _error = 'Server error: ${response.statusCode}';
          _isSaving = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Network error: $e';
        _isSaving = false;
      });
    }
  }

  Future<void> _clearAllVmStatus() async {
    // Confirm action
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Text('Clear All VM Status?'),
          ],
        ),
        content: const Text(
          'This will reset all VM detection data for all users. '
          'Users will need to restart their app to re-report their status.\n\n'
          'Use this after fixing false positive detection issues.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.vmSettings}?action=clear_all_vm_status'),
        body: {
          'admin_username': widget.username,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('VM status cleared for ${data['affected_users'] ?? 'all'} users'),
                backgroundColor: Colors.green,
              ),
            );
          }
          _loadUsers(); // Refresh the list
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(data['error'] ?? 'Failed to clear VM status'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleUserBlock(UserVmStatus user, bool block) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.vmSettings}?action=set_user_block'),
        body: {
          'admin_username': widget.username,
          'target_username': user.username,
          'blocked': block ? '1' : '0',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          // Update local state
          setState(() {
            final index = _users.indexWhere((u) => u.username == user.username);
            if (index != -1) {
              _users[index] = UserVmStatus(
                username: user.username,
                displayName: user.displayName,
                role: user.role,
                isOnVm: user.isOnVm,
                vmType: user.vmType,
                isBlocked: block,
                lastSeen: user.lastSeen,
                isOnline: user.isOnline,
              );
            }
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(block
                    ? '${user.displayName} is now blocked from using VMs'
                    : '${user.displayName} can now use VMs'),
                backgroundColor: block ? Colors.red : Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(data['error'] ?? 'Failed to update user'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<UserVmStatus> get _filteredUsers {
    var filtered = _users;

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((u) =>
          u.username.toLowerCase().contains(query) ||
          u.displayName.toLowerCase().contains(query) ||
          u.role.toLowerCase().contains(query)).toList();
    }

    // Filter by VM status
    if (_showOnlyVmUsers) {
      filtered = filtered.where((u) => u.isOnVm).toList();
    }

    // Sort: VM users first, then online, then by name
    filtered.sort((a, b) {
      // VM users first
      if (a.isOnVm && !b.isOnVm) return -1;
      if (!a.isOnVm && b.isOnVm) return 1;
      // Then online users
      if (a.isOnline && !b.isOnline) return -1;
      if (!a.isOnline && b.isOnline) return 1;
      // Then alphabetically
      return a.displayName.compareTo(b.displayName);
    });

    return filtered;
  }

  int get _vmUserCount => _users.where((u) => u.isOnVm).length;
  int get _blockedUserCount => _users.where((u) => u.isBlocked).length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Image.asset(
          isDark ? 'assets/images/logo-white.png' : 'assets/images/logo.png',
          height: 40,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadSetting();
              _loadUsers();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF49320).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.computer,
                          color: Color(0xFFF49320),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Virtual Machine Detection',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Control whether the app blocks VMs',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Error message
                  if (_error != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh, color: Colors.red),
                            onPressed: _loadSetting,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Main setting card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Global VM Detection',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _vmDetectionEnabled
                                        ? 'App will block virtual machines'
                                        : 'App will allow virtual machines',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_isSaving)
                              const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              Switch(
                                value: _vmDetectionEnabled,
                                onChanged: (value) => _saveSetting(value),
                                activeThumbColor: const Color(0xFFF49320),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _vmDetectionEnabled
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _vmDetectionEnabled
                                    ? Icons.shield
                                    : Icons.shield_outlined,
                                color: _vmDetectionEnabled
                                    ? Colors.green
                                    : Colors.orange,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _vmDetectionEnabled
                                      ? 'Protection is active. Users running the app in a VM will be blocked unless they have developer/admin bypass.'
                                      : 'Protection is disabled. All users can run the app in virtual machines.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _vmDetectionEnabled
                                        ? Colors.green.shade700
                                        : Colors.orange.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Info section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'How it works',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildInfoItem(
                          'Changes take effect immediately (no restart needed)',
                        ),
                        _buildInfoItem(
                          'App checks status every 15-30 seconds',
                        ),
                        _buildInfoItem(
                          'Developers and admins can always bypass',
                        ),
                        _buildInfoItem(
                          'Users can still download updates when blocked',
                        ),
                        _buildInfoItem(
                          'Block individual users below for targeted control',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // User List Section
                  _buildUserListSection(isDark, cardColor),
                ],
              ),
            ),
    );
  }

  Widget _buildUserListSection(bool isDark, Color cardColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.people,
                color: Colors.purple,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'User VM Status',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Monitor and block individual users',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            if (_isLoadingUsers)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Stats row
        Row(
          children: [
            _buildStatChip(
              icon: Icons.computer,
              label: 'VM Users',
              count: _vmUserCount,
              color: Colors.orange,
            ),
            const SizedBox(width: 12),
            _buildStatChip(
              icon: Icons.block,
              label: 'Blocked',
              count: _blockedUserCount,
              color: Colors.red,
            ),
            const SizedBox(width: 12),
            _buildStatChip(
              icon: Icons.people,
              label: 'Total',
              count: _users.length,
              color: Colors.blue,
            ),
            const Spacer(),
            // Clear all VM status button
            if (_vmUserCount > 0)
              TextButton.icon(
                onPressed: _clearAllVmStatus,
                icon: const Icon(Icons.cleaning_services, size: 18),
                label: const Text('Clear All'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.orange,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Search and filter
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search users...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilterChip(
              label: const Text('VM Only'),
              selected: _showOnlyVmUsers,
              onSelected: (value) => setState(() => _showOnlyVmUsers = value),
              avatar: Icon(
                Icons.computer,
                size: 18,
                color: _showOnlyVmUsers ? Colors.white : Colors.orange,
              ),
              selectedColor: Colors.orange,
              checkmarkColor: Colors.white,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Users list
        if (_usersError != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 12),
                Expanded(child: Text(_usersError!, style: const TextStyle(color: Colors.red))),
                TextButton(
                  onPressed: _loadUsers,
                  child: const Text('Retry'),
                ),
              ],
            ),
          )
        else if (_filteredUsers.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    _showOnlyVmUsers ? Icons.computer_outlined : Icons.people_outline,
                    size: 48,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _showOnlyVmUsers
                        ? 'No users currently on VMs'
                        : 'No users found',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              ),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredUsers.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              ),
              itemBuilder: (context, index) {
                final user = _filteredUsers[index];
                return _buildUserTile(user, isDark);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$count $label',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(UserVmStatus user, bool isDark) {
    final bypassRoles = ['developer', 'administrator'];
    final hasBypass = bypassRoles.contains(user.role.toLowerCase());

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: user.isOnVm
                ? Colors.orange.withValues(alpha: 0.2)
                : Colors.grey.withValues(alpha: 0.2),
            child: Icon(
              user.isOnVm ? Icons.computer : Icons.person,
              color: user.isOnVm ? Colors.orange : Colors.grey,
            ),
          ),
          // Online indicator
          if (user.isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? const Color(0xFF252525) : Colors.white,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              user.displayName,
              style: const TextStyle(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: hasBypass
                  ? Colors.purple.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              user.role,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: hasBypass ? Colors.purple : Colors.grey,
              ),
            ),
          ),
          if (hasBypass) ...[
            const SizedBox(width: 4),
            Tooltip(
              message: 'Can bypass VM detection',
              child: Icon(
                Icons.verified_user,
                size: 16,
                color: Colors.purple.shade300,
              ),
            ),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '@${user.username}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              // VM status
              if (user.isOnVm) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.computer, size: 12, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        user.vmType ?? 'VM',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
              // Blocked status
              if (user.isBlocked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.block, size: 12, color: Colors.red),
                      SizedBox(width: 4),
                      Text(
                        'BLOCKED',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              // Last seen
              if (user.lastSeen != null && !user.isOnline) ...[
                const Spacer(),
                Text(
                  _formatLastSeen(user.lastSeen!),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      trailing: hasBypass
          ? Tooltip(
              message: 'Admins/developers cannot be blocked',
              child: Icon(
                Icons.lock,
                color: Colors.grey.shade400,
                size: 20,
              ),
            )
          : PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'block') {
                  _toggleUserBlock(user, true);
                } else if (value == 'unblock') {
                  _toggleUserBlock(user, false);
                }
              },
              itemBuilder: (context) => [
                if (!user.isBlocked)
                  const PopupMenuItem(
                    value: 'block',
                    child: Row(
                      children: [
                        Icon(Icons.block, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('Block from VMs'),
                      ],
                    ),
                  )
                else
                  const PopupMenuItem(
                    value: 'unblock',
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                        SizedBox(width: 8),
                        Text('Unblock'),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final diff = now.difference(lastSeen);

    if (diff.inMinutes < 1) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '\u2022 ',
            style: TextStyle(
              fontSize: 13,
              color: Colors.blue.shade700,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.blue.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
