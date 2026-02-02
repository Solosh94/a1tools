/// Item Members Dialog
/// Allows managing user access to specific items within a board
library;

import 'package:flutter/material.dart';
import '../../../app_theme.dart';
import '../models/sunday_models.dart';
import '../sunday_service.dart';

class ItemMembersDialog extends StatefulWidget {
  final int itemId;
  final String itemName;
  final int boardId;
  final String boardName;
  final String username;

  const ItemMembersDialog({
    super.key,
    required this.itemId,
    required this.itemName,
    required this.boardId,
    required this.boardName,
    required this.username,
  });

  @override
  State<ItemMembersDialog> createState() => _ItemMembersDialogState();
}

class _ItemMembersDialogState extends State<ItemMembersDialog> {
  List<ItemMember> _members = [];
  List<Map<String, dynamic>> _availableUsers = [];
  bool _loading = true;
  bool _loadingUsers = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _loadAvailableUsers();
  }

  Future<void> _loadMembers() async {
    setState(() => _loading = true);
    final members = await SundayService.getItemMembers(widget.itemId);
    if (mounted) {
      setState(() {
        _members = members;
        _loading = false;
      });
    }
  }

  Future<void> _loadAvailableUsers() async {
    setState(() => _loadingUsers = true);
    final users = await SundayService.getAppUsers(requestingUsername: widget.username);
    if (mounted) {
      setState(() {
        _availableUsers = users;
        _loadingUsers = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      child: Container(
        width: 500,
        height: 550,
        padding: const EdgeInsets.all(0),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.assignment_ind, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Item Access',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          widget.itemName,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Info banner
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.purple.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Users assigned here can only see this specific item within the board.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.purple.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Add member button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'Assigned Users',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _showAddMemberDialog,
                    icon: const Icon(Icons.person_add, size: 16),
                    label: const Text('Add User'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Members list
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _members.isEmpty
                      ? _buildEmptyState(isDark)
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _members.length,
                          itemBuilder: (context, index) {
                            final member = _members[index];
                            return _buildMemberTile(member, isDark);
                          },
                        ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off,
            size: 48,
            color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No users assigned to this item',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add users to give them access to only this item',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberTile(ItemMember member, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.accent.withValues(alpha: 0.2),
          child: Text(
            member.displayName.substring(0, 1).toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
        ),
        title: Text(
          member.displayName,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          member.username,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Access level dropdown
            PopupMenuButton<String>(
              initialValue: member.accessLevel == GranularAccessLevel.edit ? 'edit' : 'view',
              onSelected: (value) => _updateMemberAccess(member, value),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('Can Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'view',
                  child: Row(
                    children: [
                      Icon(Icons.visibility, size: 18),
                      SizedBox(width: 8),
                      Text('View Only'),
                    ],
                  ),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: member.accessLevel == GranularAccessLevel.edit
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      member.accessLevel == GranularAccessLevel.edit
                          ? Icons.edit
                          : Icons.visibility,
                      size: 14,
                      color: member.accessLevel == GranularAccessLevel.edit
                          ? Colors.green
                          : Colors.blue,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      member.accessLevel == GranularAccessLevel.edit ? 'Edit' : 'View',
                      style: TextStyle(
                        fontSize: 12,
                        color: member.accessLevel == GranularAccessLevel.edit
                            ? Colors.green
                            : Colors.blue,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Remove button
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              onPressed: () => _removeMember(member),
              tooltip: 'Remove access',
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMemberDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddItemMemberDialog(
        availableUsers: _availableUsers,
        existingMembers: _members.map((m) => m.username).toList(),
        onAdd: _addMember,
        loading: _loadingUsers,
      ),
    );
  }

  Future<void> _addMember(String username, String accessLevel) async {
    final success = await SundayService.addItemMember(
      itemId: widget.itemId,
      memberUsername: username,
      accessLevel: accessLevel,
      addedBy: widget.username,
    );

    if (success) {
      _loadMembers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User added to item'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add user'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateMemberAccess(ItemMember member, String accessLevel) async {
    final success = await SundayService.updateItemMemberAccess(
      memberId: member.id,
      accessLevel: accessLevel,
      username: widget.username,
    );

    if (success) {
      _loadMembers();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update access level'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeMember(ItemMember member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Access'),
        content: Text(
          'Remove ${member.displayName}\'s access to this item?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await SundayService.removeItemMember(
        member.id,
        widget.username,
      );

      if (success) {
        _loadMembers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User removed from item'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to remove user'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

/// Dialog for adding a new member to the item
class _AddItemMemberDialog extends StatefulWidget {
  final List<Map<String, dynamic>> availableUsers;
  final List<String> existingMembers;
  final Function(String username, String accessLevel) onAdd;
  final bool loading;

  const _AddItemMemberDialog({
    required this.availableUsers,
    required this.existingMembers,
    required this.onAdd,
    required this.loading,
  });

  @override
  State<_AddItemMemberDialog> createState() => _AddItemMemberDialogState();
}

class _AddItemMemberDialogState extends State<_AddItemMemberDialog> {
  String _searchQuery = '';
  String _selectedAccessLevel = 'edit';

  List<Map<String, dynamic>> get _filteredUsers {
    return widget.availableUsers.where((user) {
      final username = user['username'] as String? ?? '';
      final firstName = user['first_name'] as String? ?? '';
      final lastName = user['last_name'] as String? ?? '';
      final fullName = '$firstName $lastName'.toLowerCase();

      // Exclude already added members
      if (widget.existingMembers.contains(username)) {
        return false;
      }

      // Filter by search query
      if (_searchQuery.isEmpty) return true;
      return username.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          fullName.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      child: Container(
        width: 400,
        height: 500,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.person_add, color: AppColors.accent),
                const SizedBox(width: 8),
                const Text(
                  'Add User to Item',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search field
            TextField(
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
            const SizedBox(height: 12),

            // Access level selector
            Row(
              children: [
                const Text('Access Level: '),
                const SizedBox(width: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'edit',
                      label: Text('Can Edit'),
                      icon: Icon(Icons.edit, size: 16),
                    ),
                    ButtonSegment(
                      value: 'view',
                      label: Text('View Only'),
                      icon: Icon(Icons.visibility, size: 16),
                    ),
                  ],
                  selected: {_selectedAccessLevel},
                  onSelectionChanged: (value) {
                    setState(() => _selectedAccessLevel = value.first);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // User list
            Expanded(
              child: widget.loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredUsers.isEmpty
                      ? Center(
                          child: Text(
                            _searchQuery.isEmpty
                                ? 'No users available'
                                : 'No users match your search',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = _filteredUsers[index];
                            final username = user['username'] as String? ?? '';
                            final firstName = user['first_name'] as String? ?? '';
                            final lastName = user['last_name'] as String? ?? '';
                            final fullName = '$firstName $lastName'.trim();
                            final displayName = fullName.isNotEmpty ? fullName : username;

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                                child: Text(
                                  displayName.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
                              title: Text(displayName),
                              subtitle: Text(username),
                              trailing: IconButton(
                                icon: const Icon(Icons.add_circle, color: AppColors.accent),
                                onPressed: () {
                                  widget.onAdd(username, _selectedAccessLevel);
                                  Navigator.pop(context);
                                },
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
