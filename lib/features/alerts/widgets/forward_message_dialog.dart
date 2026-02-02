import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../config/api_config.dart';

/// Dialog for forwarding messages to other users
class ForwardMessageDialog extends StatefulWidget {
  final String message;
  final String currentUsername;
  final Function(String toUsername) onForward;

  const ForwardMessageDialog({
    super.key,
    required this.message,
    required this.currentUsername,
    required this.onForward,
  });

  @override
  State<ForwardMessageDialog> createState() => _ForwardMessageDialogState();
}

class _ForwardMessageDialogState extends State<ForwardMessageDialog> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _loading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.userManagement}?action=list&requesting_username=${widget.currentUsername}'),
        headers: {'X-Username': widget.currentUsername},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _users = List<Map<String, dynamic>>.from(data['users'] ?? [])
              ..removeWhere((u) => u['username'] == widget.currentUsername);
            _filteredUsers = _users;
            _loading = false;
          });
        }
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _filterUsers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = _users;
      } else {
        _filteredUsers = _users.where((u) {
          final name =
              '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.toLowerCase();
          final username = (u['username'] ?? '').toString().toLowerCase();
          return name.contains(query.toLowerCase()) ||
              username.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: const Text('Forward to...'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            // Preview of message being forwarded
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.format_quote, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.message.length > 100
                          ? '${widget.message.substring(0, 100)}...'
                          : widget.message,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Search field
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: _filterUsers,
            ),
            const SizedBox(height: 12),
            // User list
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredUsers.isEmpty
                      ? const Center(child: Text('No users found'))
                      : ListView.builder(
                          itemCount: _filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = _filteredUsers[index];
                            final displayName =
                                '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'
                                    .trim();
                            final username = user['username'] ?? '';

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    const Color(0xFFF49320).withValues(alpha: 0.2),
                                child: Text(
                                  displayName.isNotEmpty
                                      ? displayName[0].toUpperCase()
                                      : username[0].toUpperCase(),
                                  style: const TextStyle(
                                      color: Color(0xFFF49320),
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(displayName.isNotEmpty
                                  ? displayName
                                  : username),
                              subtitle: displayName.isNotEmpty
                                  ? Text('@$username',
                                      style: const TextStyle(fontSize: 12))
                                  : null,
                              onTap: () {
                                Navigator.pop(context);
                                widget.onForward(username);
                              },
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
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
