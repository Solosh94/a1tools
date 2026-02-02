/// Board Members Dialog
/// Allows managing user access to boards
library;

import 'package:flutter/material.dart';
import '../../../app_theme.dart';
import '../models/sunday_models.dart';
import '../sunday_service.dart';

class BoardMembersDialog extends StatefulWidget {
  final int boardId;
  final String boardName;
  final String username;

  const BoardMembersDialog({
    super.key,
    required this.boardId,
    required this.boardName,
    required this.username,
  });

  @override
  State<BoardMembersDialog> createState() => _BoardMembersDialogState();
}

class _BoardMembersDialogState extends State<BoardMembersDialog> {
  List<SundayBoardMember> _members = [];
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
    final members = await SundayService.getBoardMembers(widget.boardId);
    if (mounted) {
      setState(() {
        _members = members;
        _loading = false;
      });
    }
  }

  Future<void> _loadAvailableUsers() async {
    setState(() => _loadingUsers = true);
    debugPrint('[BoardMembers] Loading available users...');
    final users = await SundayService.getAppUsers(requestingUsername: widget.username);
    debugPrint('[BoardMembers] Loaded ${users.length} users: $users');
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
                  const Icon(Icons.people, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Board Members',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          widget.boardName,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
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

            // Add member button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Members',
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
                    label: const Text('Add Member'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),

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
                            return _buildMemberTile(_members[index], isDark);
                          },
                        ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Only members can view and edit this board',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                      ),
                    ),
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.group_off_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No members yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add members to control who can access this board',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberTile(SundayBoardMember member, bool isDark) {
    final accessColor = switch (member.accessLevel) {
      BoardAccessLevel.owner => Colors.orange,
      BoardAccessLevel.editor => AppColors.accent,
      BoardAccessLevel.viewer => Colors.grey,
    };

    final accessLabel = switch (member.accessLevel) {
      BoardAccessLevel.owner => 'Owner',
      BoardAccessLevel.editor => 'Editor',
      BoardAccessLevel.viewer => 'Viewer',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.accent.withValues(alpha: 0.2),
          child: Text(
            member.username.isNotEmpty ? member.username[0].toUpperCase() : '?',
            style: const TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        title: Text(
          member.username,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          'Added by ${member.addedBy}',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: accessColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                accessLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: accessColor,
                ),
              ),
            ),
            if (member.accessLevel != BoardAccessLevel.owner) ...[
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  size: 18,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'change_access',
                    child: ListTile(
                      leading: Icon(Icons.edit),
                      title: Text('Change Access'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'remove',
                    child: ListTile(
                      leading: Icon(Icons.person_remove, color: Colors.red),
                      title: Text('Remove', style: TextStyle(color: Colors.red)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'change_access') {
                    _showChangeAccessDialog(member);
                  } else if (value == 'remove') {
                    _confirmRemoveMember(member);
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAddMemberDialog() {
    if (_loadingUsers) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading users...')),
      );
      return;
    }

    // Filter out users who are already members
    final existingUsernames = _members.map((m) => m.username).toSet();
    final availableToAdd = _availableUsers
        .where((u) => !existingUsernames.contains(u['username']))
        .toList();

    if (availableToAdd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All users are already members')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => _AddMemberSearchDialog(
        availableUsers: availableToAdd,
        onUserSelected: (username, accessLevel) async {
          Navigator.pop(ctx);

          // Show loading
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Adding member...')),
            );
          }

          debugPrint('[BoardMembers] Adding member: $username with access: ${accessLevel.name}');
          debugPrint('[BoardMembers] Board ID: ${widget.boardId}, Added by: ${widget.username}');

          final success = await SundayService.addBoardMember(
            boardId: widget.boardId,
            memberUsername: username,
            accessLevel: accessLevel,
            addedBy: widget.username,
          );

          debugPrint('[BoardMembers] Add member result: $success');

          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$username added successfully'),
                  backgroundColor: Colors.green,
                ),
              );
              _loadMembers();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to add member. Check console for details.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _showChangeAccessDialog(SundayBoardMember member) {
    BoardAccessLevel selectedAccess = member.accessLevel;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Change Access for ${member.username}'),
          content: DropdownButtonFormField<BoardAccessLevel>(
            initialValue: selectedAccess,
            decoration: const InputDecoration(
              labelText: 'Access Level',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: BoardAccessLevel.editor,
                child: Text('Editor - Can edit items'),
              ),
              DropdownMenuItem(
                value: BoardAccessLevel.viewer,
                child: Text('Viewer - Read only'),
              ),
            ],
            onChanged: (value) {
              setDialogState(() => selectedAccess = value!);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await SundayService.updateBoardMemberAccess(
                  memberId: member.id,
                  accessLevel: selectedAccess,
                  username: widget.username,
                );
                _loadMembers();
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemoveMember(SundayBoardMember member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text(
          'Remove ${member.username} from this board? They will no longer be able to access it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await SundayService.removeBoardMember(member.id, widget.username);
              _loadMembers();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

/// Searchable dialog for adding board members
class _AddMemberSearchDialog extends StatefulWidget {
  final List<Map<String, dynamic>> availableUsers;
  final Function(String username, BoardAccessLevel accessLevel) onUserSelected;

  const _AddMemberSearchDialog({
    required this.availableUsers,
    required this.onUserSelected,
  });

  @override
  State<_AddMemberSearchDialog> createState() => _AddMemberSearchDialogState();
}

class _AddMemberSearchDialogState extends State<_AddMemberSearchDialog> {
  String _searchQuery = '';
  String? _selectedUsername;
  BoardAccessLevel _selectedAccess = BoardAccessLevel.editor;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) return widget.availableUsers;
    final query = _searchQuery.toLowerCase();
    return widget.availableUsers.where((u) {
      final name = (u['name'] ?? '').toString().toLowerCase();
      final username = (u['username'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final firstName = (u['firstName'] ?? '').toString().toLowerCase();
      final lastName = (u['lastName'] ?? '').toString().toLowerCase();
      return name.contains(query) ||
          username.contains(query) ||
          email.contains(query) ||
          firstName.contains(query) ||
          lastName.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: const Text('Add Member'),
      content: SizedBox(
        width: 400,
        height: 450,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search field
            TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search by name, username, or email...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
            const SizedBox(height: 12),

            // User list
            Expanded(
              child: _filteredUsers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isEmpty ? 'No users available' : 'No matching users',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = _filteredUsers[index];
                        final username = user['username'] as String;
                        final name = user['name'] as String? ?? username;
                        final email = user['email'] as String? ?? '';
                        final isSelected = _selectedUsername == username;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 4),
                          color: isSelected
                              ? AppColors.accent.withValues(alpha: 0.15)
                              : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: isSelected
                                ? const BorderSide(color: AppColors.accent, width: 2)
                                : BorderSide.none,
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              setState(() => _selectedUsername = username);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  // Avatar
                                  _buildUserAvatar(name),
                                  const SizedBox(width: 12),
                                  // User info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Name
                                        Text(
                                          name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        // Username and email
                                        Text(
                                          '@$username${email.isNotEmpty ? ' \u2022 $email' : ''}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? Colors.grey.shade400
                                                : Colors.grey.shade600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Check icon
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle,
                                      color: AppColors.accent,
                                      size: 22,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 12),

            // Access level selector
            Text(
              'Access Level',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildAccessOption(
                    BoardAccessLevel.editor,
                    'Editor',
                    'Can edit items',
                    Icons.edit,
                    isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildAccessOption(
                    BoardAccessLevel.viewer,
                    'Viewer',
                    'Read only',
                    Icons.visibility,
                    isDark,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedUsername == null
              ? null
              : () => widget.onUserSelected(_selectedUsername!, _selectedAccess),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
          ),
          child: const Text('Add Member'),
        ),
      ],
    );
  }

  Widget _buildAccessOption(
    BoardAccessLevel level,
    String title,
    String subtitle,
    IconData icon,
    bool isDark,
  ) {
    final isSelected = _selectedAccess == level;

    return InkWell(
      onTap: () => setState(() => _selectedAccess = level),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.accent : Colors.grey.shade400,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? AppColors.accent.withValues(alpha: 0.1) : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppColors.accent : Colors.grey.shade500,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.accent
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, size: 16, color: AppColors.accent),
          ],
        ),
      ),
    );
  }

  Widget _buildUserAvatar(String name) {
    final initials = name
        .split(' ')
        .take(2)
        .map((s) => s.isNotEmpty ? s[0] : '')
        .join()
        .toUpperCase();
    final colors = [
      const Color(0xFF0073ea),
      const Color(0xFF00c875),
      const Color(0xFFfdab3d),
      const Color(0xFFe2445c),
      const Color(0xFFa25ddc),
    ];
    final color = colors[name.hashCode.abs() % colors.length];

    return CircleAvatar(
      radius: 18,
      backgroundColor: color,
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
