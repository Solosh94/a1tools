import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import 'time_clock_service.dart';
import 'work_schedule_editor.dart';

/// User Schedule Management Screen
/// Allows managers to view and edit work schedules for all users
class UserScheduleManagementScreen extends StatefulWidget {
  const UserScheduleManagementScreen({super.key});

  @override
  State<UserScheduleManagementScreen> createState() => _UserScheduleManagementScreenState();
}

class _UserScheduleManagementScreenState extends State<UserScheduleManagementScreen> {
  List<_UserWithSchedule> _users = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  String _filterRole = 'all';
  
  @override
  void initState() {
    super.initState();
    _loadUsers();
  }
  
  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      // Load users from the existing API
      final response = await http.get(
        Uri.parse('${ApiConfig.users}?action=list'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['users'] != null) {
          final users = (data['users'] as List).map((u) {
            WorkSchedule? schedule;
            if (u['work_schedule'] != null) {
              try {
                final scheduleData = u['work_schedule'] is String 
                    ? jsonDecode(u['work_schedule']) 
                    : u['work_schedule'];
                schedule = WorkSchedule.fromJson(scheduleData);
              } catch (e) {
  debugPrint('[UserScheduleManagementScreen] Error: $e');
}
            }
            
            return _UserWithSchedule(
              username: u['username'] ?? '',
              firstName: u['first_name'],
              lastName: u['last_name'],
              role: u['role'] ?? '',
              schedule: schedule,
            );
          }).toList();
          
          // Sort by name
          users.sort((a, b) => a.displayName.compareTo(b.displayName));
          
          setState(() {
            _users = users;
            _isLoading = false;
          });
          return;
        }
      }
      
      setState(() {
        _error = 'Failed to load users';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }
  
  List<_UserWithSchedule> get _filteredUsers {
    return _users.where((user) {
      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!user.displayName.toLowerCase().contains(query) &&
            !user.username.toLowerCase().contains(query)) {
          return false;
        }
      }
      
      // Filter by role
      if (_filterRole != 'all') {
        if (user.role.toLowerCase() != _filterRole.toLowerCase()) {
          return false;
        }
      }
      
      return true;
    }).toList();
  }
  
  Future<void> _editSchedule(_UserWithSchedule user) async {
    final result = await WorkScheduleEditor.show(
      context,
      username: user.username,
      displayName: user.displayName,
      initialSchedule: user.schedule,
    );
    
    if (result == true) {
      // Reload to get updated schedule
      _loadUsers();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Work Schedules'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filter bar
          Container(
            padding: const EdgeInsets.all(16),
            color: isDark ? const Color(0xFF252525) : Colors.grey.shade100,
            child: Row(
              children: [
                // Search field
                Expanded(
                  flex: 2,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search users...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                
                // Role filter
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<String>(
                    initialValue: _filterRole,
                    decoration: InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Roles')),
                      DropdownMenuItem(value: 'dispatcher', child: Text('Dispatcher')),
                      DropdownMenuItem(value: 'marketing', child: Text('Marketing')),
                      DropdownMenuItem(value: 'management', child: Text('Management')),
                      DropdownMenuItem(value: 'technician', child: Text('Technician')),
                      DropdownMenuItem(value: 'administrator', child: Text('Administrator')),
                      DropdownMenuItem(value: 'developer', child: Text('Developer')),
                    ],
                    onChanged: (value) {
                      setState(() => _filterRole = value ?? 'all');
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // User list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                            const SizedBox(height: 16),
                            Text(_error!),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadUsers,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _filteredUsers.isEmpty
                        ? const Center(child: Text('No users found'))
                        : ListView.builder(
                            itemCount: _filteredUsers.length,
                            itemBuilder: (context, index) {
                              final user = _filteredUsers[index];
                              return _buildUserTile(user);
                            },
                          ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildUserTile(_UserWithSchedule user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final requiresClockIn = TimeClockService.requiresClockIn(user.role);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(user.role),
          child: Text(
            user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.displayName,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getRoleColor(user.role).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                user.role,
                style: TextStyle(
                  fontSize: 11,
                  color: _getRoleColor(user.role),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.username,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 4),
            if (requiresClockIn)
              WorkScheduleDisplay(schedule: user.schedule)
            else
              Text(
                'Clock in not required',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
        trailing: requiresClockIn
            ? IconButton(
                icon: const Icon(Icons.edit_calendar),
                onPressed: () => _editSchedule(user),
                tooltip: 'Edit Schedule',
                color: const Color(0xFFF49320),
              )
            : null,
        isThreeLine: true,
        onTap: requiresClockIn ? () => _editSchedule(user) : null,
      ),
    );
  }
  
  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'developer':
        return Colors.purple;
      case 'administrator':
        return Colors.red;
      case 'management':
        return Colors.blue;
      case 'dispatcher':
        return Colors.green;
      case 'marketing':
        return Colors.orange;
      case 'technician':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
}

class _UserWithSchedule {
  final String username;
  final String? firstName;
  final String? lastName;
  final String role;
  final WorkSchedule? schedule;
  
  _UserWithSchedule({
    required this.username,
    this.firstName,
    this.lastName,
    required this.role,
    this.schedule,
  });
  
  String get displayName {
    if (firstName != null || lastName != null) {
      return '${firstName ?? ''} ${lastName ?? ''}'.trim();
    }
    return username;
  }
}
