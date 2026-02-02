import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../app_theme.dart';
import '../timeclock/time_clock_service.dart';
import '../../config/api_config.dart';

class UserManagementScreen extends StatefulWidget {
  final String currentUsername;
  final String currentRole;

  const UserManagementScreen({
    super.key,
    required this.currentUsername,
    required this.currentRole,
  });

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  static const String _baseUrl = ApiConfig.userManagement;
  static const String _pictureUrl = ApiConfig.profilePicture;
  static const Color _accent = AppColors.accent;

  List<_User> _users = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  String _filterRole = 'all';
  Timer? _refreshTimer;
  
  // Cache for profile pictures (username -> bytes)
  final Map<String, Uint8List> _profilePictureCache = {};
  
  // Inventory locations for franchise manager assignment
  List<Map<String, dynamic>> _franchiseLocations = [];

  // Workiz locations for Workiz integration
  List<Map<String, dynamic>> _workizLocations = [];

  // Role hierarchy (higher index = higher privilege)
  // Developer > Admin > Manager > Franchise Manager > everything else
  static const List<String> _allRoles = [
    'dispatcher',
    'remote_dispatcher',
    'technician',
    'marketing',
    'franchise_manager',
    'management',
    'administrator',
    'developer',
  ];

  static const Map<String, int> _roleHierarchy = {
    'dispatcher': 0,
    'remote_dispatcher': 0,
    'technician': 0,
    'marketing': 0,
    'franchise_manager': 1,
    'management': 2,
    'administrator': 3,
    'developer': 4,
  };

  /// Get the hierarchy level of a role
  int _getRoleLevel(String role) {
    return _roleHierarchy[role.toLowerCase()] ?? 0;
  }

  /// Get roles that the current user can assign (same level or lower)
  List<String> get _assignableRoles {
    final currentLevel = _getRoleLevel(widget.currentRole);
    return _allRoles.where((role) {
      final roleLevel = _getRoleLevel(role);
      return roleLevel <= currentLevel;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadFranchiseLocations();
    _loadWorkizLocations();
    // Refresh every 15 seconds to get updated statuses
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _loadUsersSilent();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Silent refresh - doesn't show loading spinner
  Future<void> _loadUsersSilent() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl?action=list&requesting_username=${widget.currentUsername}'),
        headers: {'X-Username': widget.currentUsername},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && mounted) {
          setState(() {
            _users = (data['users'] as List)
                .map((u) => _User.fromJson(u))
                .toList();
          });
        }
      }
    } catch (e) {
      // Silent fail
    }
  }

  /// Load franchise locations for assignment (deprecated - use Workiz locations)
  Future<void> _loadFranchiseLocations() async {
    // Franchise location management has been removed
    // Use Workiz locations for job data access control
  }

  /// Load franchise locations assigned to a specific user (deprecated - use Workiz locations)
  Future<List<int>> _loadUserLocations(String username) async {
    // Franchise location management has been removed
    // Use Workiz locations for job data access control
    return [];
  }

  /// Save franchise locations for a user (deprecated - use Workiz locations)
  Future<bool> _saveUserLocations(String username, List<int> locationIds) async {
    // Franchise location management has been removed
    // Use Workiz locations for job data access control
    return false;
  }

  /// Load Workiz locations for assignment
  Future<void> _loadWorkizLocations() async {
    try {
      final response = await http.get(Uri.parse(
        '${ApiConfig.workizLocations}?action=list_locations&requesting_role=${widget.currentRole}'
      ));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && mounted) {
          setState(() {
            _workizLocations = List<Map<String, dynamic>>.from(data['locations'] ?? []);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading Workiz locations: $e');
    }
  }

  /// Load Workiz locations assigned to a specific user
  Future<List<int>> _loadUserWorkizLocations(String username) async {
    try {
      final response = await http.get(Uri.parse(
        '${ApiConfig.workizLocations}?action=user_locations&username=$username'
      ));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final locations = data['locations'] as List? ?? [];
          return locations.map<int>((l) => l['id'] as int).toList();
        }
      }
    } catch (e) {
      debugPrint('Error loading user Workiz locations: $e');
    }
    return [];
  }

  /// Save Workiz locations for a user
  Future<bool> _saveUserWorkizLocations(String username, List<int> locationIds) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.workizLocations}?action=set_user_locations&requesting_role=${widget.currentRole}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'location_ids': locationIds,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
    } catch (e) {
      debugPrint('Error saving user Workiz locations: $e');
    }
    return false;
  }

  Future<void> _loadProfilePicture(String username) async {
    if (_profilePictureCache.containsKey(username)) return;
    
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
              _profilePictureCache[username] = bytes;
            });
          }
        }
      }
    } catch (e) {
      // Silently fail - just show initials
    }
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl?action=list&requesting_username=${widget.currentUsername}'),
        headers: {'X-Username': widget.currentUsername},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final users = (data['users'] as List)
              .map((u) => _User.fromJson(u))
              .toList();
          setState(() {
            _users = users;
            _loading = false;
          });
          
          // Load profile pictures in background
          for (final user in users) {
            _loadProfilePicture(user.username);
          }
        } else {
          throw Exception(data['error'] ?? 'Failed to load users');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<_User> get _filteredUsers {
    return _users.where((user) {
      final matchesSearch = _searchQuery.isEmpty ||
          user.username.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          user.firstName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          user.lastName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          user.email.toLowerCase().contains(_searchQuery.toLowerCase());
      
      final matchesRole = _filterRole == 'all' || user.role == _filterRole;
      
      return matchesSearch && matchesRole;
    }).toList();
  }

  String _displayRole(String role) {
    switch (role.toLowerCase()) {
      case 'developer': return 'Developer';
      case 'administrator': return 'Administrator';
      case 'management': return 'Management';
      case 'franchise_manager': return 'Franchise Manager';
      case 'dispatcher': return 'Dispatcher';
      case 'remote_dispatcher': return 'Remote Dispatcher';
      case 'technician': return 'Technician';
      case 'marketing': return 'Marketing';
      default: return role;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'online':
        return Colors.green;
      case 'away':
        return Colors.amber;
      default:
        return Colors.red;
    }
  }

  Future<void> _createUser() async {
    String? createdUsername;
    List<int>? selectedLocations;
    List<int>? selectedWorkizLocations;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _UserDialog(
        title: 'Create User',
        roles: _assignableRoles,
        franchiseLocations: _franchiseLocations,
        workizLocations: _workizLocations,
        onSave: (data) async {
          final response = await http.post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'X-Username': widget.currentUsername,
            },
            body: jsonEncode({
              'action': 'create',
              'requesting_username': widget.currentUsername,
              ...data,
            }),
          );

          final result = jsonDecode(response.body);
          if (result['success'] != true) {
            throw Exception(result['error'] ?? 'Failed to create user');
          }
          createdUsername = data['username'];
          return true;
        },
        onSaveLocations: (locationIds) async {
          // Store locations to save after user is created
          selectedLocations = locationIds;
          return true;
        },
        onSaveWorkizLocations: (locationIds) async {
          // Store Workiz locations to save after user is created
          selectedWorkizLocations = locationIds;
          return true;
        },
      ),
    );

    if (result == true) {
      // Save locations for newly created franchise manager
      if (createdUsername != null && selectedLocations != null && selectedLocations!.isNotEmpty) {
        await _saveUserLocations(createdUsername!, selectedLocations!);
      }

      // Save Workiz locations for the new user
      if (createdUsername != null && selectedWorkizLocations != null && selectedWorkizLocations!.isNotEmpty) {
        await _saveUserWorkizLocations(createdUsername!, selectedWorkizLocations!);
      }

      _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _editUser(_User user) async {
    final profilePicture = _profilePictureCache[user.username];

    // Check if current user can edit this user (can only edit users at same level or below)
    final userLevel = _getRoleLevel(user.role);
    final currentUserLevel = _getRoleLevel(widget.currentRole);

    // Cannot edit users with higher privileges
    if (userLevel > currentUserLevel) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You cannot edit a ${_displayRole(user.role)} (higher privilege level)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Load user's assigned locations if they're a franchise manager
    List<int> assignedLocations = [];
    if (user.role == 'franchise_manager') {
      assignedLocations = await _loadUserLocations(user.username);
    }

    // Load user's Workiz locations
    final List<int> assignedWorkizLocations = await _loadUserWorkizLocations(user.username);

    // Determine which roles can be assigned - if editing self, cannot promote to higher level
    final isEditingSelf = user.username == widget.currentUsername;
    final availableRoles = isEditingSelf
        ? _assignableRoles.where((r) => _getRoleLevel(r) <= userLevel).toList()
        : _assignableRoles;

    if (!mounted) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _UserDialog(
        title: 'Edit User',
        user: user,
        roles: availableRoles,
        profilePicture: profilePicture,
        franchiseLocations: _franchiseLocations,
        assignedLocationIds: assignedLocations,
        workizLocations: _workizLocations,
        assignedWorkizLocationIds: assignedWorkizLocations,
        onSave: (data) async {
          final response = await http.post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'X-Username': widget.currentUsername,
            },
            body: jsonEncode({
              'action': 'update',
              'id': user.id,
              'requesting_username': widget.currentUsername,
              ...data,
            }),
          );

          final result = jsonDecode(response.body);
          if (result['success'] != true) {
            throw Exception(result['error'] ?? 'Failed to update user');
          }
          return true;
        },
        onSaveLocations: (locationIds) async {
          return await _saveUserLocations(user.username, locationIds);
        },
        onSaveWorkizLocations: (locationIds) async {
          return await _saveUserWorkizLocations(user.username, locationIds);
        },
        onUploadPicture: (bytes) async {
          final base64Image = base64Encode(bytes);
          final response = await http.post(
            Uri.parse(_pictureUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': user.username,
              'picture': base64Image,
            }),
          );

          final result = jsonDecode(response.body);
          if (result['success'] == true) {
            // Update cache
            setState(() {
              _profilePictureCache[user.username] = bytes;
            });
            return true;
          }
          throw Exception(result['error'] ?? 'Failed to upload picture');
        },
        onDeletePicture: () async {
          final response = await http.delete(
            Uri.parse('$_pictureUrl?username=${Uri.encodeComponent(user.username)}'),
          );

          final result = jsonDecode(response.body);
          if (result['success'] == true) {
            setState(() {
              _profilePictureCache.remove(user.username);
            });
            return true;
          }
          throw Exception(result['error'] ?? 'Failed to delete picture');
        },
      ),
    );

    if (result == true) {
      _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _deleteUser(_User user) async {
    final profilePicture = _profilePictureCache[user.username];
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            ),
            const SizedBox(width: 12),
            const Text('Delete User'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this user?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _accent.withValues(alpha: 0.2),
                    backgroundImage: profilePicture != null
                        ? MemoryImage(profilePicture)
                        : null,
                    child: profilePicture == null
                        ? Text(
                            user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                            style: const TextStyle(color: _accent, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName.isNotEmpty ? user.fullName : user.username,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '@${user.username} - ${_displayRole(user.role)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone.',
                      style: TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_forever),
            label: const Text('Delete User'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final response = await http.post(
          Uri.parse(_baseUrl),
          headers: {
            'Content-Type': 'application/json',
            'X-Username': widget.currentUsername,
          },
          body: jsonEncode({
            'action': 'delete',
            'id': user.id,
            'requesting_username': widget.currentUsername,
          }),
        );

        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          _loadUsers();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${user.username} deleted'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          throw Exception(result['error'] ?? 'Failed to delete user');
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
  }

  Future<void> _resetPassword(_User user) async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset Password for ${user.username}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (passwordController.text.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Password is required')),
                );
                return;
              }
              if (passwordController.text != confirmController.text) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match')),
                );
                return;
              }
              if (passwordController.text.length < 6) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Password must be at least 6 characters')),
                );
                return;
              }
              
              try {
                final response = await http.post(
                  Uri.parse(_baseUrl),
                  headers: {
                    'Content-Type': 'application/json',
                    'X-Username': widget.currentUsername,
                  },
                  body: jsonEncode({
                    'action': 'reset_password',
                    'id': user.id,
                    'password': passwordController.text,
                    'requesting_username': widget.currentUsername,
                  }),
                );

                final result = jsonDecode(response.body);
                if (result['success'] == true) {
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx, true);
                } else {
                  throw Exception(result['error'] ?? 'Failed to reset password');
                }
              } catch (e) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadUsers,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createUser,
        icon: const Icon(Icons.person_add),
        label: const Text('Add User'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search and filter bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search users...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _filterRole,
                    decoration: InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: [
                      const DropdownMenuItem(value: 'all', child: Text('All Roles')),
                      ..._allRoles.map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(_displayRole(r)),
                      )),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _filterRole = v);
                    },
                  ),
                ),
              ],
            ),
          ),
          // User list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                            const SizedBox(height: 16),
                            Text('Error: $_error'),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _loadUsers,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _filteredUsers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isNotEmpty || _filterRole != 'all'
                                      ? 'No users match your search'
                                      : 'No users found',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredUsers.length,
                            itemBuilder: (ctx, i) => _buildUserCard(_filteredUsers[i], isDark),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(_User user, bool isDark) {
    final profilePicture = _profilePictureCache[user.username];
    final requiresClockIn = TimeClockService.requiresClockIn(user.role);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar with status indicator
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: _accent.withValues(alpha: 0.2),
                    backgroundImage: profilePicture != null
                        ? MemoryImage(profilePicture)
                        : null,
                    child: profilePicture == null
                        ? Text(
                            user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: _accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: _getStatusColor(user.appStatus),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? Colors.grey.shade900 : Colors.white,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          user.fullName.isNotEmpty ? user.fullName : user.username,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _displayRole(user.role),
                            style: const TextStyle(
                              fontSize: 11,
                              color: _accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (user.crmAdmin) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.dashboard_customize, size: 12, color: Colors.blue),
                                SizedBox(width: 4),
                                Text(
                                  'Sunday',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${user.username}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    if (user.email.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                        ),
                      ),
                    ],
                    // Show schedule indicator for roles that require clock in
                    if (requiresClockIn) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 14,
                            color: user.workSchedule != null 
                                ? Colors.green 
                                : Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            user.workSchedule != null 
                                ? 'Schedule set' 
                                : 'No schedule',
                            style: TextStyle(
                              fontSize: 11,
                              color: user.workSchedule != null 
                                  ? Colors.green 
                                  : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Actions
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (action) {
                  switch (action) {
                    case 'edit':
                      _editUser(user);
                      break;
                    case 'password':
                      _resetPassword(user);
                      break;
                    case 'delete':
                      _deleteUser(user);
                      break;
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 12),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'password',
                    child: Row(
                      children: [
                        Icon(Icons.lock_reset, size: 20),
                        SizedBox(width: 12),
                        Text('Reset Password'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 12),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        onTap: () => _editUser(user),
      ),
    );
  }
}

class _User {
  final int id;
  final String username;
  final String role;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String? birthday;
  final String? profilePicture;
  final DateTime? createdAt;
  final String appStatus;
  final Map<String, dynamic>? workSchedule;
  final bool crmAdmin;

  _User({
    required this.id,
    required this.username,
    required this.role,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    this.birthday,
    this.profilePicture,
    this.createdAt,
    this.appStatus = 'offline',
    this.workSchedule,
    this.crmAdmin = false,
  });

  String get fullName => '$firstName $lastName'.trim();
  
  bool get isOnline => appStatus == 'online';
  bool get isAway => appStatus == 'away';
  bool get isOffline => appStatus == 'offline' || appStatus.isEmpty;

  factory _User.fromJson(Map<String, dynamic> json) {
    return _User(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      username: json['username'] ?? '',
      role: json['role'] ?? 'dispatcher',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      birthday: json['birthday'],
      profilePicture: json['profile_picture'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      appStatus: json['app_status']?.toString() ?? 'offline',
      workSchedule: json['work_schedule'] is Map
          ? Map<String, dynamic>.from(json['work_schedule'])
          : null,
      crmAdmin: json['crm_admin'] == true || json['crm_admin'] == 1,
    );
  }
}

class _UserDialog extends StatefulWidget {
  final String title;
  final _User? user;
  final List<String> roles;
  final List<Map<String, dynamic>>? workizLocations;
  final List<int>? assignedWorkizLocationIds;
  final Uint8List? profilePicture;
  final List<Map<String, dynamic>>? franchiseLocations;
  final List<int>? assignedLocationIds;
  final Future<bool> Function(Map<String, dynamic> data) onSave;
  final Future<bool> Function(Uint8List bytes)? onUploadPicture;
  final Future<bool> Function()? onDeletePicture;
  final Future<bool> Function(List<int> locationIds)? onSaveLocations;
  final Future<bool> Function(List<int> locationIds)? onSaveWorkizLocations;

  const _UserDialog({
    required this.title,
    this.user,
    required this.roles,
    this.profilePicture,
    this.franchiseLocations,
    this.assignedLocationIds,
    this.workizLocations,
    this.assignedWorkizLocationIds,
    required this.onSave,
    this.onUploadPicture,
    this.onDeletePicture,
    this.onSaveLocations,
    this.onSaveWorkizLocations,
  });

  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  static const Color _accent = AppColors.accent;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _passwordController;
  late String _selectedRole;
  DateTime? _selectedBirthday;
  bool _saving = false;
  bool _uploadingPicture = false;
  Uint8List? _currentPicture;
  
  // Franchise location assignments
  Set<int> _selectedLocationIds = {};

  // Workiz location assignments
  Set<int> _selectedWorkizLocationIds = {};

  // CRM Admin permission
  bool _crmAdmin = false;

  // Work schedule
  late Map<String, _DaySchedule> _workSchedule;

  bool get _isEditing => widget.user != null;
  bool get _requiresClockIn => TimeClockService.requiresClockIn(_selectedRole);
  bool get _isFranchiseManager => _selectedRole == 'franchise_manager';
  bool get _hasWorkizLocations => widget.workizLocations != null && widget.workizLocations!.isNotEmpty;

  static const _days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.user?.username ?? '');
    _firstNameController = TextEditingController(text: widget.user?.firstName ?? '');
    _lastNameController = TextEditingController(text: widget.user?.lastName ?? '');
    _emailController = TextEditingController(text: widget.user?.email ?? '');
    _phoneController = TextEditingController(text: widget.user?.phone ?? '');
    _passwordController = TextEditingController();
    _selectedRole = widget.user?.role ?? 'dispatcher';
    _currentPicture = widget.profilePicture;
    
    // Initialize assigned locations
    if (widget.assignedLocationIds != null) {
      _selectedLocationIds = Set<int>.from(widget.assignedLocationIds!);
    }

    // Initialize assigned Workiz locations
    if (widget.assignedWorkizLocationIds != null) {
      _selectedWorkizLocationIds = Set<int>.from(widget.assignedWorkizLocationIds!);
    }

    // Initialize CRM admin
    _crmAdmin = widget.user?.crmAdmin ?? false;

    // Parse birthday if exists
    if (widget.user?.birthday != null && widget.user!.birthday!.isNotEmpty) {
      _selectedBirthday = DateTime.tryParse(widget.user!.birthday!);
    }
    
    // Initialize work schedule
    _workSchedule = {};
    if (widget.user?.workSchedule != null) {
      for (final day in _days) {
        final dayData = widget.user!.workSchedule![day];
        if (dayData != null) {
          _workSchedule[day] = _DaySchedule(
            start: dayData['start'],
            end: dayData['end'],
            off: dayData['off'] == true,
          );
        } else {
          _workSchedule[day] = _DaySchedule(start: null, end: null, off: true);
        }
      }
    } else {
      // Default schedule: Mon-Fri 9-5, weekends off
      for (final day in _days) {
        final isWeekend = day == 'saturday' || day == 'sunday';
        _workSchedule[day] = _DaySchedule(
          start: isWeekend ? null : '09:00',
          end: isWeekend ? null : '17:00',
          off: isWeekend,
        );
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _displayRole(String role) {
    switch (role.toLowerCase()) {
      case 'developer': return 'Developer';
      case 'administrator': return 'Administrator';
      case 'management': return 'Management';
      case 'franchise_manager': return 'Franchise Manager';
      case 'dispatcher': return 'Dispatcher';
      case 'remote_dispatcher': return 'Remote Dispatcher';
      case 'technician': return 'Technician';
      case 'marketing': return 'Marketing';
      default: return role;
    }
  }

  String _formatBirthday(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatBirthdayForApi(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthday ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      helpText: 'Select birthday',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: _accent,
              brightness: Theme.of(context).brightness,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedBirthday = picked);
    }
  }

  Future<void> _pickTime(String day, bool isStart) async {
    final schedule = _workSchedule[day]!;
    final currentTime = isStart ? schedule.start : schedule.end;
    
    TimeOfDay initial = const TimeOfDay(hour: 9, minute: 0);
    if (currentTime != null) {
      final parts = currentTime.split(':');
      if (parts.length == 2) {
        initial = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 9,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }
    
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: _accent,
              brightness: Theme.of(context).brightness,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      final timeStr = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (isStart) {
          _workSchedule[day] = _DaySchedule(
            start: timeStr,
            end: schedule.end,
            off: false,
          );
        } else {
          _workSchedule[day] = _DaySchedule(
            start: schedule.start,
            end: timeStr,
            off: false,
          );
        }
      });
    }
  }

  Map<String, dynamic> _buildScheduleJson() {
    final json = <String, dynamic>{};
    for (final day in _days) {
      final schedule = _workSchedule[day]!;
      json[day] = {
        'start': schedule.off ? null : schedule.start,
        'end': schedule.off ? null : schedule.end,
        'off': schedule.off,
      };
    }
    return json;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final data = <String, dynamic>{
        'username': _usernameController.text.trim(),
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': _selectedRole,
      };

      // Add birthday if selected
      if (_selectedBirthday != null) {
        data['birthday'] = _formatBirthdayForApi(_selectedBirthday!);
      }

      // Only include password for new users or if provided
      if (!_isEditing && _passwordController.text.isNotEmpty) {
        data['password'] = _passwordController.text;
      }
      
      // Add work schedule if role requires clock in
      if (_requiresClockIn) {
        data['work_schedule'] = _buildScheduleJson();
      }

      // Add CRM admin permission
      data['crm_admin'] = _crmAdmin;

      await widget.onSave(data);

      // Save franchise location assignments if applicable
      if (_isFranchiseManager && widget.onSaveLocations != null) {
        await widget.onSaveLocations!(_selectedLocationIds.toList());
      }

      // Save Workiz location assignments
      if (widget.onSaveWorkizLocations != null) {
        await widget.onSaveWorkizLocations!(_selectedWorkizLocationIds.toList());
      }

      if (mounted) {
        Navigator.pop(context, true);
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
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _pickImage() async {
    if (widget.onUploadPicture == null) return;
    
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      
      if (picked == null) return;
      
      setState(() => _uploadingPicture = true);
      
      final bytes = await picked.readAsBytes();
      await widget.onUploadPicture!(bytes);
      
      setState(() {
        _currentPicture = bytes;
        _uploadingPicture = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _uploadingPicture = false);
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

  Future<void> _deletePicture() async {
    if (widget.onDeletePicture == null || _currentPicture == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Picture'),
        content: const Text('Are you sure you want to remove the profile picture?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    try {
      setState(() => _uploadingPicture = true);
      await widget.onDeletePicture!();
      
      setState(() {
        _currentPicture = null;
        _uploadingPicture = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture removed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _uploadingPicture = false);
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

  void _applyPreset(String preset) {
    setState(() {
      switch (preset) {
        case 'mon_fri_9_5':
          for (final day in _days) {
            final isWeekend = day == 'saturday' || day == 'sunday';
            _workSchedule[day] = _DaySchedule(
              start: isWeekend ? null : '09:00',
              end: isWeekend ? null : '17:00',
              off: isWeekend,
            );
          }
          break;
        case 'mon_fri_8_4':
          for (final day in _days) {
            final isWeekend = day == 'saturday' || day == 'sunday';
            _workSchedule[day] = _DaySchedule(
              start: isWeekend ? null : '08:00',
              end: isWeekend ? null : '16:00',
              off: isWeekend,
            );
          }
          break;
        case 'all_off':
          for (final day in _days) {
            _workSchedule[day] = _DaySchedule(start: null, end: null, off: true);
          }
          break;
      }
    });
  }

  Widget _buildProfilePictureSection() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: _accent.withValues(alpha: 0.2),
              backgroundImage: _currentPicture != null
                  ? MemoryImage(_currentPicture!)
                  : null,
              child: _currentPicture == null
                  ? Text(
                      widget.user?.username.isNotEmpty == true 
                          ? widget.user!.username[0].toUpperCase() 
                          : '?',
                      style: const TextStyle(
                        color: _accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 36,
                      ),
                    )
                  : null,
            ),
            if (_uploadingPicture)
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _uploadingPicture ? null : _pickImage,
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: Text(_currentPicture == null ? 'Add Photo' : 'Change'),
            ),
            if (_currentPicture != null) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _uploadingPicture ? null : _deletePicture,
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                label: const Text('Remove', style: TextStyle(color: Colors.red)),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildScheduleEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with presets
        Row(
          children: [
            const Icon(Icons.schedule, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Work Schedule',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Spacer(),
            PopupMenuButton<String>(
              tooltip: 'Apply preset',
              icon: const Icon(Icons.auto_fix_high, size: 20),
              onSelected: _applyPreset,
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'mon_fri_9_5',
                  child: Text('Mon-Fri 9:00-17:00'),
                ),
                const PopupMenuItem(
                  value: 'mon_fri_8_4',
                  child: Text('Mon-Fri 8:00-16:00'),
                ),
                const PopupMenuItem(
                  value: 'all_off',
                  child: Text('All Days Off'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Days
        ...List.generate(_days.length, (i) {
          final day = _days[i];
          final label = _dayLabels[i];
          final schedule = _workSchedule[day]!;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 45,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: schedule.off ? Colors.grey : null,
                    ),
                  ),
                ),
                // Day off checkbox
                SizedBox(
                  width: 80,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: schedule.off,
                          onChanged: (v) {
                            setState(() {
                              _workSchedule[day] = _DaySchedule(
                                start: v == true ? null : '09:00',
                                end: v == true ? null : '17:00',
                                off: v == true,
                              );
                            });
                          },
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Off',
                        style: TextStyle(
                          fontSize: 12,
                          color: schedule.off ? Colors.grey : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Time pickers
                if (!schedule.off) ...[
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickTime(day, true),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.login, size: 14, color: Colors.green),
                            const SizedBox(width: 4),
                            Text(
                              schedule.start ?? '--:--',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('to'),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickTime(day, false),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.logout, size: 14, color: Colors.red),
                            const SizedBox(width: 4),
                            Text(
                              schedule.end ?? '--:--',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Day off',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 450,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Profile picture section (only for editing)
                if (_isEditing) ...[
                  _buildProfilePictureSection(),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  enabled: !_isEditing,
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                if (!_isEditing) ...[
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    validator: (v) {
                      if (!_isEditing && (v?.isEmpty == true)) {
                        return 'Required for new users';
                      }
                      if (v?.isNotEmpty == true && v!.length < 6) {
                        return 'Minimum 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(
                          labelText: 'First Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Last Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 16),
                // Birthday picker
                InkWell(
                  onTap: _pickBirthday,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Birthday',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.cake),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedBirthday != null
                              ? _formatBirthday(_selectedBirthday!)
                              : 'Select birthday',
                          style: TextStyle(
                            color: _selectedBirthday != null
                                ? null
                                : Theme.of(context).hintColor,
                          ),
                        ),
                        if (_selectedBirthday != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              setState(() => _selectedBirthday = null);
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                  ),
                  items: widget.roles.map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Text(_displayRole(role)),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedRole = v);
                  },
                ),
                // CRM Admin permission toggle
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _crmAdmin
                              ? Colors.blue.withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.dashboard_customize,
                          color: _crmAdmin ? Colors.blue : Colors.grey,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sunday Administrator',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Can create/delete workspaces, boards, and manage Sunday settings',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _crmAdmin,
                        onChanged: (v) => setState(() => _crmAdmin = v),
                        activeThumbColor: Colors.blue,
                      ),
                    ],
                  ),
                ),
                // Franchise location assignment (only for franchise_manager role)
                if (_isFranchiseManager && widget.franchiseLocations != null && widget.franchiseLocations!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: _accent),
                      const SizedBox(width: 8),
                      const Text(
                        'Assigned Locations',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_selectedLocationIds.length} selected',
                        style: TextStyle(
                          color: _selectedLocationIds.isEmpty ? Colors.red : Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: widget.franchiseLocations!.length,
                      itemBuilder: (context, index) {
                        final location = widget.franchiseLocations![index];
                        final locationId = location['id'] as int;
                        final isSelected = _selectedLocationIds.contains(locationId);
                        
                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selectedLocationIds.add(locationId);
                              } else {
                                _selectedLocationIds.remove(locationId);
                              }
                            });
                          },
                          title: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _accent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  location['label'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _accent,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  location['name'] ?? '',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            [location['city'], location['state']]
                                .where((e) => e != null && e.toString().isNotEmpty)
                                .join(', '),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: _accent,
                          dense: true,
                        );
                      },
                    ),
                  ),
                  if (_selectedLocationIds.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'At least one location should be assigned',
                            style: TextStyle(color: Colors.orange, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                ],
                // Workiz location assignment section (available for all users)
                if (_hasWorkizLocations) ...[
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.work_outline, color: Colors.blue, size: 20),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Workiz Locations',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Assign access to Workiz job data',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${_selectedWorkizLocationIds.length} selected',
                        style: TextStyle(
                          color: _selectedWorkizLocationIds.isEmpty ? Colors.grey : Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: widget.workizLocations!.length,
                      itemBuilder: (context, index) {
                        final location = widget.workizLocations![index];
                        final locationId = location['id'] as int;
                        final isSelected = _selectedWorkizLocationIds.contains(locationId);
                        final status = location['status'] ?? 'not_configured';
                        final statusColor = status == 'working'
                            ? Colors.green
                            : status == 'auth_error'
                                ? Colors.red
                                : Colors.grey;

                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selectedWorkizLocationIds.add(locationId);
                              } else {
                                _selectedWorkizLocationIds.remove(locationId);
                              }
                            });
                          },
                          title: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  location['location_code'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  location['location_name'] ?? '',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            status == 'working'
                                ? 'Connected'
                                : status == 'auth_error'
                                    ? 'Authentication error'
                                    : 'Not configured',
                            style: TextStyle(fontSize: 11, color: statusColor),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: Colors.blue,
                          dense: true,
                        );
                      },
                    ),
                  ),
                ],
                // Work schedule section (only for roles that require clock in)
                if (_requiresClockIn) ...[
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),
                  _buildScheduleEditor(),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}

class _DaySchedule {
  final String? start;
  final String? end;
  final bool off;

  _DaySchedule({this.start, this.end, this.off = false});
}
