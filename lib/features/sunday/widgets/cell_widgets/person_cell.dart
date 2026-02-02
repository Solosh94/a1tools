/// Person Cell Widget
/// Displays and edits person/assignee column values
library;

import 'package:flutter/material.dart';
import '../../sunday_service.dart';

class PersonCell extends StatelessWidget {
  final dynamic value;
  final Function(dynamic) onChanged; // Can be String or List<String>
  final bool compact;
  final bool readOnly; // For 'created_by' column
  final bool multiSelect; // Allow multiple person selection
  final String? username; // Current user for API authentication

  const PersonCell({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = false,
    this.readOnly = false,
    this.multiSelect = true, // Default to multi-select
    this.username,
  });

  /// Get list of people from value (handles both string and list)
  List<String> get _peopleList {
    if (value == null) return <String>[];

    // Handle List type
    if (value is List) {
      // Filter out null, empty strings, and 'null' string values
      final result = <String>[];
      for (final e in value) {
        if (e != null) {
          final s = e.toString();
          if (s.isNotEmpty && s != 'null') {
            result.add(s);
          }
        }
      }
      return result;
    }

    // Handle Map type (some APIs return {0: "name1", 1: "name2"})
    if (value is Map) {
      final result = <String>[];
      for (final e in value.values) {
        if (e != null) {
          final s = e.toString();
          if (s.isNotEmpty && s != 'null') {
            result.add(s);
          }
        }
      }
      return result;
    }

    // Handle String type (might be JSON string, comma-separated, or single name)
    final str = value.toString();
    if (str.isEmpty || str == 'null') return <String>[];

    // Try to parse as JSON array string like ["name1", "name2"]
    if (str.startsWith('[')) {
      try {
        // Simple parsing: remove brackets, split by comma, clean up quotes
        final inner = str.substring(1, str.length - 1);
        final result = <String>[];
        for (final part in inner.split(',')) {
          final cleaned = part.trim().replaceAll('"', '').replaceAll("'", '');
          if (cleaned.isNotEmpty && cleaned != 'null') {
            result.add(cleaned);
          }
        }
        if (result.isNotEmpty) return result;
      } catch (_) {
        // Fall through to single string handling
      }
    }

    // Check if it's a comma-separated list
    if (str.contains(',')) {
      final result = <String>[];
      for (final part in str.split(',')) {
        final cleaned = part.trim();
        if (cleaned.isNotEmpty && cleaned != 'null') {
          result.add(cleaned);
        }
      }
      return result;
    }

    return <String>[str];
  }

  @override
  Widget build(BuildContext context) {
    final people = _peopleList;

    if (people.isEmpty) {
      // Always show assign button when empty (unless readOnly)
      // This fixes the blank space bug when all persons are removed
      return Semantics(
        label: readOnly ? 'No person assigned' : 'Unassigned. Tap to assign',
        button: !readOnly,
        child: InkWell(
          onTap: readOnly ? null : () => _showPersonPicker(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  readOnly ? Icons.person_off : Icons.person_add_alt,
                  size: 14,
                  color: Colors.grey.shade400,
                ),
                if (!readOnly) ...[
                  const SizedBox(width: 4),
                  Text(
                    'Assign',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    // Build accessibility description for assigned people
    final peopleDescription = people.length == 1
        ? 'Assigned to: ${people.first}'
        : 'Assigned to: ${people.length} people: ${people.join(', ')}';

    return Semantics(
      label: peopleDescription,
      button: !readOnly,
      hint: readOnly ? null : 'Tap to change assignment',
      child: InkWell(
        onTap: readOnly ? null : () => _showPersonPicker(context),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...people.take(3).map((person) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _buildAvatar(person),
            )),
            if (people.length > 3)
              Text(
                '+${people.length - 3}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String name) {
    final initials = name.split(' ').take(2).map((s) => s.isNotEmpty ? s[0] : '').join().toUpperCase();
    final color = _getColorForName(name);
    final size = compact ? 20.0 : 24.0;
    final fontSize = compact ? 8.0 : 10.0;

    return Tooltip(
      message: name,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            initials.isEmpty ? '?' : initials,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Color _getColorForName(String name) {
    final colors = [
      const Color(0xFF0073ea),
      const Color(0xFF00c875),
      const Color(0xFFfdab3d),
      const Color(0xFFe2445c),
      const Color(0xFFa25ddc),
      const Color(0xFF579bfc),
      const Color(0xFF037f4c),
      const Color(0xFFFF5AC4),
      const Color(0xFF784BD1),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  void _showPersonPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _PersonPickerDialog(
        currentValues: _peopleList,
        multiSelect: multiSelect,
        username: username,
        onChanged: (selectedPeople) {
          Navigator.pop(ctx);
          // Return as list for multi-select, single string for single-select
          if (multiSelect) {
            onChanged(selectedPeople);
          } else {
            onChanged(selectedPeople.isNotEmpty ? selectedPeople.first : '');
          }
        },
      ),
    );
  }
}

class _PersonPickerDialog extends StatefulWidget {
  final List<String> currentValues;
  final bool multiSelect;
  final Function(List<String>) onChanged;
  final String? username; // Current user for API authentication

  const _PersonPickerDialog({
    required this.currentValues,
    required this.multiSelect,
    required this.onChanged,
    this.username,
  });

  @override
  State<_PersonPickerDialog> createState() => _PersonPickerDialogState();
}

class _PersonPickerDialogState extends State<_PersonPickerDialog> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String _searchQuery = '';
  late Set<String> _selectedPeople;

  @override
  void initState() {
    super.initState();
    _selectedPeople = Set.from(widget.currentValues);
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final users = await SundayService.getAppUsers(requestingUsername: widget.username);
    if (mounted) {
      setState(() {
        _users = users;
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) return _users;
    final query = _searchQuery.toLowerCase();
    return _users.where((u) =>
      (u['name']?.toString() ?? '').toLowerCase().contains(query) ||
      (u['username']?.toString() ?? '').toLowerCase().contains(query) ||
      (u['email']?.toString() ?? '').toLowerCase().contains(query) ||
      (u['firstName']?.toString() ?? '').toLowerCase().contains(query) ||
      (u['lastName']?.toString() ?? '').toLowerCase().contains(query)
    ).toList();
  }

  bool _isSelected(String name, String username) {
    return _selectedPeople.contains(name) || _selectedPeople.contains(username);
  }

  void _togglePerson(String name) {
    setState(() {
      if (widget.multiSelect) {
        // Multi-select: toggle the person
        if (_selectedPeople.contains(name)) {
          _selectedPeople.remove(name);
        } else {
          _selectedPeople.add(name);
        }
      } else {
        // Single-select: replace with the person
        _selectedPeople.clear();
        _selectedPeople.add(name);
        // Immediately apply for single-select
        widget.onChanged(_selectedPeople.toList());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: Text(widget.multiSelect ? 'Assign People' : 'Assign Person'),
      content: SizedBox(
        width: 300,
        height: 400,
        child: Column(
          children: [
            // Selected people chips (only for multi-select)
            if (widget.multiSelect && _selectedPeople.isNotEmpty) ...[
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: _selectedPeople.map((name) => Chip(
                  label: Text(name, style: const TextStyle(fontSize: 12)),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () => _togglePerson(name),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),
              ),
              const SizedBox(height: 8),
            ],

            // Search field (searches name, username, and email but email is not displayed for privacy)
            TextField(
              decoration: InputDecoration(
                hintText: 'Search by name or username...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
            const SizedBox(height: 12),

            // User list
            Expanded(
              child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                  ? Center(
                      child: Text(
                        _searchQuery.isEmpty ? 'No users found' : 'No matching users',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = _filteredUsers[index];
                        final name = (user['name']?.toString() ?? user['username']?.toString() ?? '');
                        final username = user['username']?.toString() ?? '';
                        final isSelected = _isSelected(name, username);

                        return ListTile(
                          leading: _buildUserAvatar(name),
                          title: Text(
                            name,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Theme.of(context).primaryColor : null,
                            ),
                          ),
                          // Only show username, not email (privacy concern)
                          // Email is still searchable via _filteredUsers
                          subtitle: Text(
                            '@$username',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: widget.multiSelect
                            ? Checkbox(
                                value: isSelected,
                                onChanged: (_) => _togglePerson(name),
                              )
                            : (isSelected
                                ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor)
                                : null),
                          selected: isSelected,
                          onTap: () => _togglePerson(name),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() => _selectedPeople.clear());
            if (!widget.multiSelect) {
              widget.onChanged([]);
            }
          },
          child: const Text('Clear All'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (widget.multiSelect)
          FilledButton(
            onPressed: () => widget.onChanged(_selectedPeople.toList()),
            child: Text('Apply (${_selectedPeople.length})'),
          ),
      ],
    );
  }

  Widget _buildUserAvatar(String name) {
    final initials = name.split(' ').take(2).map((s) => s.isNotEmpty ? s[0] : '').join().toUpperCase();
    final colors = [
      const Color(0xFF0073ea),
      const Color(0xFF00c875),
      const Color(0xFFfdab3d),
      const Color(0xFFe2445c),
      const Color(0xFFa25ddc),
    ];
    final color = colors[name.hashCode.abs() % colors.length];

    return CircleAvatar(
      radius: 16,
      backgroundColor: color,
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
