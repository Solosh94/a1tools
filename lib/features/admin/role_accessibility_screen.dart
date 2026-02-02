import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../core/services/role_access_service.dart';

class RoleAccessibilityScreen extends StatefulWidget {
  final String currentUsername;
  final String currentRole;

  const RoleAccessibilityScreen({
    super.key,
    required this.currentUsername,
    required this.currentRole,
  });

  @override
  State<RoleAccessibilityScreen> createState() => _RoleAccessibilityScreenState();
}

class _RoleAccessibilityScreenState extends State<RoleAccessibilityScreen> {
  static const Color _accent = AppColors.accent;

  bool _loading = true;
  bool _saving = false;
  String? _error;
  Map<String, List<FeatureAccess>> _featuresByCategory = {};
  final Map<String, List<String>> _pendingChanges = {};

  // Roles that can be edited (not including developer which always has access)
  static const List<String> _editableRoles = [
    'administrator',
    'management',
    'dispatcher',
    'remote_dispatcher',
    'technician',
    'marketing',
  ];

  @override
  void initState() {
    super.initState();
    _loadFeatures();
  }

  Future<void> _loadFeatures() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final features = await RoleAccessService.instance.getFeaturesByCategory();
      setState(() {
        _featuresByCategory = features;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load feature access settings';
        _loading = false;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_pendingChanges.isEmpty) return;

    setState(() => _saving = true);

    int successCount = 0;
    int failCount = 0;

    for (final entry in _pendingChanges.entries) {
      final success = await RoleAccessService.instance.updateFeatureAccess(
        featureId: entry.key,
        allowedRoles: entry.value,
        updatedBy: widget.currentUsername,
      );

      if (success) {
        successCount++;
      } else {
        failCount++;
      }
    }

    setState(() {
      _saving = false;
      _pendingChanges.clear();
    });

    if (!mounted) return;

    if (failCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved $successCount change${successCount != 1 ? 's' : ''} successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$successCount saved, $failCount failed'),
          backgroundColor: failCount > 0 ? AppColors.warning : AppColors.success,
        ),
      );
    }

    // Reload to get fresh data
    _loadFeatures();
  }

  void _toggleRoleAccess(FeatureAccess feature, String role, bool enabled) {
    // Don't allow changes to system features for developer role
    if (feature.isSystemFeature && role == 'developer') return;

    setState(() {
      // Get current roles (either from pending changes or original)
      final List<String> currentRoles = _pendingChanges[feature.featureId] ??
          List<String>.from(feature.allowedRoles);

      if (enabled && !currentRoles.contains(role)) {
        currentRoles.add(role);
      } else if (!enabled && currentRoles.contains(role)) {
        currentRoles.remove(role);
      }

      // Always ensure developer has access
      if (!currentRoles.contains('developer')) {
        currentRoles.add('developer');
      }

      _pendingChanges[feature.featureId] = currentRoles;
    });
  }

  List<String> _getCurrentRoles(FeatureAccess feature) {
    return _pendingChanges[feature.featureId] ?? feature.allowedRoles;
  }

  bool _hasChanges() => _pendingChanges.isNotEmpty;

  Future<void> _resetToDefaults() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults?'),
        content: const Text(
          'This will reset all feature access settings to their default values. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _saving = true);

    final success = await RoleAccessService.instance.resetToDefaults(
      updatedBy: widget.currentUsername,
    );

    setState(() {
      _saving = false;
      _pendingChanges.clear();
    });

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings reset to defaults'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadFeatures();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to reset settings'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);
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
          onPressed: () {
            if (_hasChanges()) {
              _showUnsavedChangesDialog();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          if (_hasChanges())
            TextButton.icon(
              onPressed: _saving ? null : _saveChanges,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save, size: 18),
              label: Text(_saving ? 'Saving...' : 'Save'),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'reset') {
                _resetToDefaults();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.restore, size: 18),
                    SizedBox(width: 8),
                    Text('Reset to Defaults'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      backgroundColor: bgColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : _buildContent(cardColor, isDark),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text(_error ?? 'An error occurred'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadFeatures,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(Color cardColor, bool isDark) {
    final categories = _featuresByCategory.keys.toList()..sort();

    return Column(
      children: [
        // Header with info
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: _accent.withValues(alpha: 0.1),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: _accent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Configure which roles can access each feature. '
                  'Developers always have full access.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Role legend
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: cardColor,
          child: Row(
            children: [
              const Text(
                'Roles: ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _editableRoles.map((role) {
                    return Chip(
                      label: Text(
                        RoleDefinition.formatRoleName(role),
                        style: const TextStyle(fontSize: 10),
                      ),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Feature list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final features = _featuresByCategory[category] ?? [];
              return _buildCategorySection(category, features, cardColor, isDark);
            },
          ),
        ),
        // Unsaved changes indicator
        if (_hasChanges())
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: AppColors.warning.withValues(alpha: 0.2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.pending, size: 16, color: AppColors.warning),
                const SizedBox(width: 8),
                Text(
                  '${_pendingChanges.length} unsaved change${_pendingChanges.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCategorySection(
    String category,
    List<FeatureAccess> features,
    Color cardColor,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 8),
          child: Row(
            children: [
              Icon(_getCategoryIcon(category), size: 18, color: _accent),
              const SizedBox(width: 8),
              Text(
                category,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        ...features.map((feature) => _buildFeatureCard(feature, cardColor, isDark)),
        const SizedBox(height: 16),
      ],
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Home': return Icons.home;
      case 'Administration': return Icons.admin_panel_settings;
      case 'Sunday': return Icons.view_kanban;
      case 'Training Management': return Icons.school;
      case 'Metrics': return Icons.bar_chart;
      case 'App Management': return Icons.apps;
      case 'General Settings': return Icons.settings_applications;
      default: return Icons.folder;
    }
  }

  Widget _buildFeatureCard(FeatureAccess feature, Color cardColor, bool isDark) {
    final currentRoles = _getCurrentRoles(feature);
    final hasChanges = _pendingChanges.containsKey(feature.featureId);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: hasChanges ? _accent.withValues(alpha: 0.05) : cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: hasChanges
            ? const BorderSide(color: _accent, width: 1.5)
            : BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            feature.isSystemFeature ? Icons.lock : Icons.tune,
            color: _accent,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                feature.featureName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            if (feature.isSystemFeature)
              Tooltip(
                message: 'System feature - limited editing',
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.grey.shade500,
                ),
              ),
          ],
        ),
        subtitle: Text(
          feature.description,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        trailing: Text(
          '${currentRoles.length} roles',
          style: TextStyle(
            fontSize: 11,
            color: hasChanges ? _accent : Colors.grey.shade500,
            fontWeight: hasChanges ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        children: [
          // Role checkboxes
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: _editableRoles.map((role) {
              final isEnabled = currentRoles.contains(role);
              return FilterChip(
                label: Text(
                  RoleDefinition.formatRoleName(role),
                  style: TextStyle(
                    fontSize: 11,
                    color: isEnabled ? Colors.white : null,
                  ),
                ),
                selected: isEnabled,
                onSelected: (selected) {
                  _toggleRoleAccess(feature, role, selected);
                },
                selectedColor: _accent,
                checkmarkColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
          // Quick actions
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  // Enable all roles
                  setState(() {
                    _pendingChanges[feature.featureId] = [
                      'developer',
                      ..._editableRoles,
                    ];
                  });
                },
                icon: const Icon(Icons.select_all, size: 14),
                label: const Text('All', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: feature.isSystemFeature
                    ? null
                    : () {
                        // Admin roles only
                        setState(() {
                          _pendingChanges[feature.featureId] = [
                            'developer',
                            'administrator',
                          ];
                        });
                      },
                icon: const Icon(Icons.admin_panel_settings, size: 14),
                label: const Text('Admin Only', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              if (_pendingChanges.containsKey(feature.featureId))
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _pendingChanges.remove(feature.featureId);
                    });
                  },
                  icon: const Icon(Icons.undo, size: 14),
                  label: const Text('Undo', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: AppColors.error,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showUnsavedChangesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: Text(
          'You have ${_pendingChanges.length} unsaved change${_pendingChanges.length != 1 ? 's' : ''}. '
          'Do you want to save before leaving?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Leave screen
            },
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              navigator.pop(); // Close dialog
              await _saveChanges();
              if (mounted) navigator.pop(); // Leave screen
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
