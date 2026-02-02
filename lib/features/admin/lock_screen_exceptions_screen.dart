import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../app_theme.dart';
import '../../config/api_config.dart';

/// Lock Screen Exceptions Management Screen
/// Allows admins to manage which users are exempt from the lock screen
/// (for remote workers, work-from-home employees, etc.)
class LockScreenExceptionsScreen extends StatefulWidget {
  final String currentUsername;

  const LockScreenExceptionsScreen({
    super.key,
    required this.currentUsername,
  });

  @override
  State<LockScreenExceptionsScreen> createState() => _LockScreenExceptionsScreenState();
}

class _LockScreenExceptionsScreenState extends State<LockScreenExceptionsScreen> {
  static const String _baseUrl = ApiConfig.lockScreenExceptions;

  List<Map<String, dynamic>> _exceptions = [];
  List<Map<String, dynamic>> _eligibleUsers = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl?action=list'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _exceptions = List<Map<String, dynamic>>.from(data['exceptions'] ?? []);
            _eligibleUsers = List<Map<String, dynamic>>.from(data['eligible_users'] ?? []);
            _loading = false;
          });
        } else {
          setState(() {
            _error = data['error'] ?? 'Failed to load data';
            _loading = false;
          });
        }
      } else {
        setState(() {
          _error = 'Server error: ${response.statusCode}';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Connection error: $e';
        _loading = false;
      });
    }
  }

  Future<void> _addException(String username, String reason) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?action=add'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'reason': reason,
          'created_by': widget.currentUsername,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _loadData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Exception added successfully')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(data['error'] ?? 'Failed to add exception'),
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

  Future<void> _removeException(String username) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?action=remove'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _loadData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Exception removed')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(data['error'] ?? 'Failed to remove exception'),
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

  void _showAddExceptionDialog() {
    // Filter out users who already have exceptions
    final exceptionUsernames = _exceptions.map((e) => e['username']).toSet();
    final availableUsers = _eligibleUsers
        .where((u) => !exceptionUsernames.contains(u['username']))
        .toList();

    if (availableUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All eligible users already have exceptions'),
        ),
      );
      return;
    }

    String? selectedUsername;
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.person_add, color: AppColors.accent),
              SizedBox(width: 12),
              Text('Add Lock Screen Exception'),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select a user to exempt from the lock screen requirement:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedUsername,
                  decoration: const InputDecoration(
                    labelText: 'User',
                    border: OutlineInputBorder(),
                  ),
                  items: availableUsers.map((user) {
                    final displayName = user['full_name']?.isNotEmpty == true
                        ? '${user['full_name']} (${user['username']})'
                        : user['username'];
                    return DropdownMenuItem(
                      value: user['username'] as String,
                      child: Text(displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedUsername = value);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason (optional)',
                    hintText: 'e.g., Works from home, Remote employee',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Users with this exception will not see the lock screen even if they are not clocked in.',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selectedUsername == null
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      _addException(selectedUsername!, reasonController.text.trim());
                    },
              child: const Text('Add Exception'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemoveException(Map<String, dynamic> exception) {
    final username = exception['username'];
    final fullName = exception['full_name'] ?? username;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Exception'),
        content: Text('Remove lock screen exception for $fullName?\n\nThey will be required to clock in to access the app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _removeException(username);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lock Screen Exceptions'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      backgroundColor: bgColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExceptionDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Exception'),
        backgroundColor: AppColors.accent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                      const SizedBox(height: 16),
                      Text(_error!, style: TextStyle(color: Colors.red.shade400)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildContent(cardColor),
    );
  }

  Widget _buildContent(Color cardColor) {
    if (_exceptions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.no_accounts, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No Exceptions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All users are required to clock in to access the app',
              style: TextStyle(color: Colors.grey.shade500),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddExceptionDialog,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Exception'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _exceptions.length,
      itemBuilder: (context, index) {
        final exception = _exceptions[index];
        return _buildExceptionCard(exception, cardColor);
      },
    );
  }

  Widget _buildExceptionCard(Map<String, dynamic> exception, Color cardColor) {
    final username = exception['username'] ?? '';
    final fullName = exception['full_name'] ?? username;
    final role = exception['role'] ?? 'Unknown';
    final reason = exception['reason'] ?? '';
    final createdBy = exception['created_by'] ?? '';
    final createdAt = exception['created_at'] ?? '';

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.accent.withValues(alpha: 0.2),
          child: Text(
            (fullName.isNotEmpty ? fullName[0] : username[0]).toUpperCase(),
            style: const TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          fullName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '@$username',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _formatRole(role),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                reason,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              'Added by $createdBy on ${_formatDate(createdAt)}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
          onPressed: () => _confirmRemoveException(exception),
          tooltip: 'Remove Exception',
        ),
      ),
    );
  }

  String _formatRole(String role) {
    switch (role.toLowerCase()) {
      case 'developer':
        return 'Developer';
      case 'administrator':
        return 'Administrator';
      case 'management':
        return 'Management';
      case 'dispatcher':
        return 'Dispatcher';
      case 'remote_dispatcher':
        return 'Remote Dispatcher';
      case 'marketing':
        return 'Marketing';
      default:
        return role;
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.month}/${date.day}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }
}
