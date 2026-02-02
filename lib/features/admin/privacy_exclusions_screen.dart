import 'package:flutter/material.dart';
import '../../app_theme.dart';
import 'privacy_exclusions_service.dart';

/// Privacy Exclusions Management Screen
/// Allows developers to manage which programs are hidden from
/// screenshots and the admin dashboard program lists.
class PrivacyExclusionsScreen extends StatefulWidget {
  final String currentUsername;
  final String currentRole;

  const PrivacyExclusionsScreen({
    super.key,
    required this.currentUsername,
    required this.currentRole,
  });

  @override
  State<PrivacyExclusionsScreen> createState() => _PrivacyExclusionsScreenState();
}

class _PrivacyExclusionsScreenState extends State<PrivacyExclusionsScreen>
    with SingleTickerProviderStateMixin {
  List<PrivacyExclusion> _exclusions = [];
  List<ProgramSuggestion> _suggestions = [];
  bool _loading = true;
  bool _loadingSuggestions = false;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Only developer role can access this screen
    if (widget.currentRole.toLowerCase() != 'developer') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access denied. Developer role required.'),
            backgroundColor: Colors.red,
          ),
        );
      });
    } else {
      _loadData();
      _loadSuggestions();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final exclusions = await PrivacyExclusionsService.list();
      if (mounted) {
        setState(() {
          _exclusions = exclusions;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load exclusions: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadSuggestions() async {
    setState(() {
      _loadingSuggestions = true;
    });

    try {
      final suggestions = await PrivacyExclusionsService.getSuggestions(limit: 30);
      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _loadingSuggestions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingSuggestions = false;
        });
      }
    }
  }

  Future<void> _addExclusion(String programName, String displayName, String matchType, String? notes) async {
    final success = await PrivacyExclusionsService.add(
      programName: programName,
      displayName: displayName,
      matchType: matchType,
      notes: notes,
      createdBy: widget.currentUsername,
    );

    if (success) {
      _loadData();
      _loadSuggestions(); // Refresh suggestions to remove the added program
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exclusion added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add exclusion'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeExclusion(int id) async {
    final success = await PrivacyExclusionsService.remove(id);

    if (success) {
      _loadData();
      _loadSuggestions(); // Refresh suggestions as removed program may now appear
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exclusion removed')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to remove exclusion'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddExclusionDialog() {
    final programNameController = TextEditingController();
    final displayNameController = TextEditingController();
    final notesController = TextEditingController();
    String selectedMatchType = 'contains';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.visibility_off, color: AppColors.accent),
              SizedBox(width: 12),
              Text('Add Privacy Exclusion'),
            ],
          ),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Programs matching this exclusion will be hidden from screenshots and program lists.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: programNameController,
                    decoration: const InputDecoration(
                      labelText: 'Program Name *',
                      hintText: 'e.g., chrome, notepad, 1password',
                      helperText: 'The process name (without .exe)',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: displayNameController,
                    decoration: const InputDecoration(
                      labelText: 'Display Name *',
                      hintText: 'e.g., Google Chrome, 1Password',
                      helperText: 'Human-readable name for the list',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedMatchType,
                    decoration: const InputDecoration(
                      labelText: 'Match Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'contains',
                        child: Text('Contains (recommended)'),
                      ),
                      DropdownMenuItem(
                        value: 'exact',
                        child: Text('Exact match'),
                      ),
                    ],
                    onChanged: (value) {
                      setDialogState(() => selectedMatchType = value ?? 'contains');
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      hintText: 'e.g., Personal banking app',
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
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'How it works:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          '1. Windows from excluded programs are made invisible to screen capture\n'
                          '2. The windows remain visible to the user but appear black in screenshots\n'
                          '3. Excluded programs will not appear in the analytics dashboard',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final programName = programNameController.text.trim();
                final displayName = displayNameController.text.trim();

                if (programName.isEmpty || displayName.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Program name and display name are required'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.pop(ctx);
                _addExclusion(
                  programName,
                  displayName,
                  selectedMatchType,
                  notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                );
              },
              child: const Text('Add Exclusion'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemoveExclusion(PrivacyExclusion exclusion) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Exclusion'),
        content: Text(
          'Remove "${exclusion.displayName}" from privacy exclusions?\n\n'
          'This program will be visible in screenshots and program lists.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _removeExclusion(exclusion.id);
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
        title: const Text('Privacy Exclusions'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadData();
              _loadSuggestions();
            },
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.visibility_off),
              text: 'Exclusions (${_exclusions.length})',
            ),
            Tab(
              icon: const Icon(Icons.lightbulb_outline),
              text: 'Suggestions (${_suggestions.length})',
            ),
          ],
        ),
      ),
      backgroundColor: bgColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExclusionDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Exclusion'),
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
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildExclusionsTab(cardColor),
                    _buildSuggestionsTab(cardColor),
                  ],
                ),
    );
  }

  Widget _buildExclusionsTab(Color cardColor) {
    if (_exclusions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No Privacy Exclusions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All programs will be visible in screenshots and program lists',
              style: TextStyle(color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Check the Suggestions tab for commonly used programs',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddExclusionDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Exclusion'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _exclusions.length,
      itemBuilder: (context, index) {
        final exclusion = _exclusions[index];
        return _buildExclusionCard(exclusion, cardColor);
      },
    );
  }

  Widget _buildSuggestionsTab(Color cardColor) {
    if (_loadingSuggestions) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_suggestions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lightbulb_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No Suggestions Available',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Suggestions are based on programs commonly used by monitored users.\nOnce users start being monitored, suggestions will appear here.',
              style: TextStyle(color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Group suggestions by category
    final privacySensitive = _suggestions.where((s) => s.isPrivacySensitive).toList();
    final others = _suggestions.where((s) => !s.isPrivacySensitive).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (privacySensitive.isNotEmpty) ...[
          _buildSectionHeader(
            'Privacy-Sensitive Programs',
            'These programs are commonly used and may contain sensitive information',
            Colors.orange,
            Icons.security,
          ),
          const SizedBox(height: 8),
          ...privacySensitive.map((s) => _buildSuggestionCard(s, cardColor)),
          const SizedBox(height: 24),
        ],
        if (others.isNotEmpty) ...[
          _buildSectionHeader(
            'Other Common Programs',
            'Programs frequently used across monitored computers',
            Colors.blue,
            Icons.apps,
          ),
          const SizedBox(height: 8),
          ...others.map((s) => _buildSuggestionCard(s, cardColor)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(ProgramSuggestion suggestion, Color cardColor) {
    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: suggestion.isPrivacySensitive
                ? Colors.orange.withValues(alpha: 0.1)
                : Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getCategoryIcon(suggestion.category),
            color: suggestion.isPrivacySensitive ? Colors.orange : Colors.blue,
            size: 22,
          ),
        ),
        title: Text(
          suggestion.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    suggestion.programName,
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(suggestion.category).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    suggestion.categoryLabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: _getCategoryColor(suggestion.category),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Used by ${suggestion.userCount} user${suggestion.userCount != 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        trailing: FilledButton.tonal(
          onPressed: () => _addFromSuggestion(suggestion),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: const Text('Add'),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'browser':
        return Icons.language;
      case 'communication':
        return Icons.chat;
      case 'email':
        return Icons.email;
      case 'password_manager':
        return Icons.key;
      case 'vpn':
        return Icons.vpn_key;
      case 'development':
        return Icons.code;
      case 'office':
        return Icons.description;
      case 'media':
        return Icons.music_note;
      case 'graphics':
        return Icons.brush;
      case 'finance':
        return Icons.attach_money;
      case 'gaming':
        return Icons.sports_esports;
      case 'cloud_storage':
        return Icons.cloud;
      default:
        return Icons.apps;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'browser':
        return Colors.blue;
      case 'communication':
        return Colors.green;
      case 'email':
        return Colors.orange;
      case 'password_manager':
        return Colors.red;
      case 'vpn':
        return Colors.purple;
      case 'development':
        return Colors.teal;
      case 'office':
        return Colors.indigo;
      case 'media':
        return Colors.pink;
      case 'graphics':
        return Colors.amber;
      case 'finance':
        return Colors.green;
      case 'gaming':
        return Colors.deepPurple;
      case 'cloud_storage':
        return Colors.cyan;
      default:
        return Colors.grey;
    }
  }

  void _addFromSuggestion(ProgramSuggestion suggestion) {
    _addExclusion(
      suggestion.programName,
      suggestion.displayName,
      'contains',
      'Added from suggestions - used by ${suggestion.userCount} user${suggestion.userCount != 1 ? 's' : ''}',
    );
  }

  Widget _buildExclusionCard(PrivacyExclusion exclusion, Color cardColor) {
    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.visibility_off,
            color: AppColors.accent,
            size: 24,
          ),
        ),
        title: Text(
          exclusion.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    exclusion.programName,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: exclusion.matchType == 'contains'
                        ? Colors.blue.withValues(alpha: 0.1)
                        : Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    exclusion.matchType,
                    style: TextStyle(
                      fontSize: 10,
                      color: exclusion.matchType == 'contains' ? Colors.blue : Colors.purple,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (exclusion.notes != null && exclusion.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                exclusion.notes!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              'Added by ${exclusion.createdBy} on ${_formatDate(exclusion.createdAt)}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
          onPressed: () => _confirmRemoveExclusion(exclusion),
          tooltip: 'Remove Exclusion',
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
