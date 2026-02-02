import 'package:flutter/material.dart';
import '../../../app_theme.dart';
import 'web_management_service.dart';
import 'site_info_tab.dart';
import 'social_media_tab.dart';
import 'web_management_guide.dart';
import 'group_social_defaults_editor.dart';

/// Main screen for managing website variables across WordPress sites
class WebManagementScreen extends StatefulWidget {
  const WebManagementScreen({super.key});

  @override
  State<WebManagementScreen> createState() => _WebManagementScreenState();
}

class _WebManagementScreenState extends State<WebManagementScreen>
    with SingleTickerProviderStateMixin {
  static const Color _accent = AppColors.accent;

  late TabController _tabController;

  bool _isLoading = true;
  List<Map<String, dynamic>> _groupedSites = [];
  List<Map<String, dynamic>> _ungroupedSites = [];

  Map<String, dynamic>? _selectedSite;
  WebsiteVariables? _variables;
  bool _isLoadingVariables = false;
  bool _hasUnsavedChanges = false;

  // Group defaults editing state
  bool _isEditingGroupDefaults = false;
  Map<String, dynamic>? _selectedGroup;
  GroupSocialDefaults? _groupDefaults;

  // Site's group defaults (for showing hints in social media tab)
  GroupSocialDefaults? _siteGroupDefaults;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSites();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSites() async {
    setState(() => _isLoading = true);

    final result = await WebManagementService.listSites();

    if (result['success'] == true) {
      _groupedSites = List<Map<String, dynamic>>.from(result['grouped'] ?? []);
      _ungroupedSites = List<Map<String, dynamic>>.from(result['ungrouped'] ?? []);

      // Auto-select first site if available
      if (_selectedSite == null) {
        if (_groupedSites.isNotEmpty && (_groupedSites.first['sites'] as List).isNotEmpty) {
          _selectSite((_groupedSites.first['sites'] as List).first);
        } else if (_ungroupedSites.isNotEmpty) {
          _selectSite(_ungroupedSites.first);
        }
      }
    } else {
      _showError(result['error'] ?? 'Failed to load sites');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _selectSite(Map<String, dynamic> site) async {
    if (_hasUnsavedChanges) {
      final discard = await _showDiscardDialog();
      if (discard != true) return;
    }

    setState(() {
      _isEditingGroupDefaults = false;
      _selectedGroup = null;
      _groupDefaults = null;
      _siteGroupDefaults = null;
      _selectedSite = site;
      _isLoadingVariables = true;
      _hasUnsavedChanges = false;
    });

    final siteId = site['site_id'] as int;
    final groupId = site['group_id'];

    // Fetch site variables
    final result = await WebManagementService.getVariables(siteId);

    if (result['success'] == true && result['variables'] != null) {
      _variables = WebsiteVariables.fromJson(result['variables'], siteId);
    } else {
      _variables = WebsiteVariables.empty(siteId);
    }

    // Fetch group defaults if site belongs to a group
    if (groupId != null) {
      final groupResult = await WebManagementService.getGroupSocialDefaults(groupId as int);
      if (groupResult['success'] == true && groupResult['social_defaults'] != null) {
        _siteGroupDefaults = GroupSocialDefaults.fromJson(groupResult['social_defaults'], groupId);
      }
    }

    setState(() => _isLoadingVariables = false);
  }

  Future<void> _saveVariables() async {
    if (_variables == null || _selectedSite == null) return;

    setState(() => _isLoadingVariables = true);

    final result = await WebManagementService.saveVariables(
      _selectedSite!['site_id'] as int,
      _variables!.toJson(),
    );

    setState(() => _isLoadingVariables = false);

    if (result['success'] == true) {
      _showSuccess('Variables saved successfully');
      setState(() => _hasUnsavedChanges = false);
      _loadSites(); // Refresh the list to update badges
    } else {
      _showError(result['error'] ?? 'Failed to save');
    }
  }

  void _onVariablesChanged(WebsiteVariables updated) {
    setState(() {
      _variables = updated;
      _hasUnsavedChanges = true;
    });
  }

  Future<void> _selectGroupDefaults(Map<String, dynamic> group) async {
    if (_hasUnsavedChanges) {
      final discard = await _showDiscardDialog();
      if (discard != true) return;
    }

    setState(() {
      _isEditingGroupDefaults = true;
      _selectedGroup = group;
      _selectedSite = null;
      _variables = null;
      _isLoadingVariables = true;
      _hasUnsavedChanges = false;
    });

    final groupId = group['group_id'] as int;
    final result = await WebManagementService.getGroupSocialDefaults(groupId);

    if (result['success'] == true && result['social_defaults'] != null) {
      _groupDefaults = GroupSocialDefaults.fromJson(result['social_defaults'], groupId);
    } else {
      _groupDefaults = GroupSocialDefaults.empty(groupId);
    }

    setState(() => _isLoadingVariables = false);
  }

  Future<void> _saveGroupDefaults() async {
    if (_groupDefaults == null || _selectedGroup == null) return;

    setState(() => _isLoadingVariables = true);

    final result = await WebManagementService.saveGroupSocialDefaults(
      _selectedGroup!['group_id'] as int,
      _groupDefaults!,
    );

    setState(() => _isLoadingVariables = false);

    if (result['success'] == true) {
      _showSuccess('Group defaults saved successfully');
      setState(() => _hasUnsavedChanges = false);
    } else {
      _showError(result['error'] ?? 'Failed to save');
    }
  }

  void _onGroupDefaultsChanged(GroupSocialDefaults updated) {
    setState(() {
      _groupDefaults = updated;
      _hasUnsavedChanges = true;
    });
  }

  Future<bool?> _showDiscardDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('You have unsaved changes. Discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green.shade700),
    );
  }

  void _showGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const WebManagementGuideDialog(),
    );
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
          onPressed: () async {
            if (_hasUnsavedChanges) {
              final discard = await _showDiscardDialog();
              if (discard != true) return;
            }
            if (mounted) Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showGuide(context),
            tooltip: 'How to Use',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSites,
            tooltip: 'Refresh',
          ),
        ],
      ),
      backgroundColor: bgColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : Row(
              children: [
                // Left panel - Site selector
                Container(
                  width: 280,
                  decoration: BoxDecoration(
                    color: cardColor,
                    border: Border(
                      right: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                    ),
                  ),
                  child: _buildSiteSelector(isDark, cardColor),
                ),
                // Right panel - Variable editor or Group defaults editor
                Expanded(
                  child: _isEditingGroupDefaults
                      ? _buildGroupDefaultsEditor(isDark, cardColor)
                      : _selectedSite == null
                          ? _buildNoSiteSelected()
                          : _buildVariableEditor(isDark, cardColor),
                ),
              ],
            ),
    );
  }

  Widget _buildSiteSelector(bool isDark, Color cardColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.language, color: _accent, size: 20),
              const SizedBox(width: 8),
              const Text(
                'WordPress Sites',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(8),
            children: [
              // Grouped sites
              for (final group in _groupedSites) ...[
                _buildGroupHeader(group),
                for (final site in (group['sites'] as List))
                  _buildSiteItem(site, cardColor),
                const SizedBox(height: 8),
              ],
              // Ungrouped sites
              if (_ungroupedSites.isNotEmpty) ...[
                _buildGroupHeader(null, label: 'Ungrouped Sites'),
                for (final site in _ungroupedSites)
                  _buildSiteItem(site, cardColor),
              ],
              // Empty state
              if (_groupedSites.isEmpty && _ungroupedSites.isEmpty)
                _buildEmptyState(
                  icon: Icons.web_asset_off,
                  title: 'No Sites Found',
                  subtitle: 'Add WordPress sites in Integrations first',
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGroupHeader(Map<String, dynamic>? group, {String? label}) {
    final name = label ?? group?['group_name'] ?? 'Unknown Group';
    final isSelected = _isEditingGroupDefaults &&
        _selectedGroup?['group_id'] == group?['group_id'];

    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 8, bottom: 4, right: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? _accent : Colors.grey.shade600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          if (group != null)
            InkWell(
              onTap: () => _selectGroupDefaults(group),
              borderRadius: BorderRadius.circular(4),
              child: Tooltip(
                message: 'Edit group social media defaults',
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _accent.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    Icons.settings,
                    size: 16,
                    color: isSelected ? _accent : Colors.grey.shade500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSiteItem(Map<String, dynamic> site, Color cardColor) {
    final isSelected = _selectedSite?['site_id'] == site['site_id'];
    final hasVariables = site['has_variables'] == true;
    final isActive = site['is_active'] == true;

    return Card(
      color: isSelected ? _accent.withValues(alpha: 0.1) : cardColor,
      elevation: isSelected ? 2 : 0,
      margin: const EdgeInsets.symmetric(vertical: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? _accent : Colors.transparent,
          width: isSelected ? 2 : 0,
        ),
      ),
      child: InkWell(
        onTap: () => _selectSite(site),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                Icons.wordpress,
                size: 20,
                color: isActive ? _accent : Colors.grey,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      site['site_name'] ?? 'Unknown',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isActive ? null : Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (site['location_name'] != null && site['location_name'].toString().isNotEmpty)
                      Text(
                        site['location_name'],
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                  ],
                ),
              ),
              if (hasVariables)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.check, size: 14, color: Colors.green),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoSiteSelected() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Select a Site',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a WordPress site from the left panel',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildVariableEditor(bool isDark, Color cardColor) {
    return Column(
      children: [
        // Site header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            border: Border(
              bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.language, color: _accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedSite?['site_name'] ?? 'Unknown Site',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Text(
                      _selectedSite?['site_url'] ?? '',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              if (_hasUnsavedChanges)
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit, size: 14, color: Colors.orange),
                      SizedBox(width: 4),
                      Text('Unsaved', style: TextStyle(fontSize: 12, color: Colors.orange)),
                    ],
                  ),
                ),
              ElevatedButton.icon(
                onPressed: _isLoadingVariables ? null : _saveVariables,
                icon: _isLoadingVariables
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save, size: 18),
                label: const Text('Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        // Tabs
        Container(
          color: cardColor,
          child: TabBar(
            controller: _tabController,
            indicatorColor: _accent,
            labelColor: _accent,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(icon: Icon(Icons.info_outline), text: 'Information'),
              Tab(icon: Icon(Icons.share), text: 'Social Media'),
            ],
          ),
        ),
        // Tab content
        Expanded(
          child: _isLoadingVariables
              ? const Center(child: CircularProgressIndicator(color: _accent))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    SiteInfoTab(
                      variables: _variables!,
                      onChanged: _onVariablesChanged,
                    ),
                    SocialMediaTab(
                      variables: _variables!,
                      onChanged: _onVariablesChanged,
                      groupDefaults: _siteGroupDefaults,
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildGroupDefaultsEditor(bool isDark, Color cardColor) {
    return Column(
      children: [
        // Group header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            border: Border(
              bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.folder_shared, color: Colors.purple, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedGroup?['group_name'] ?? 'Unknown Group',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Text(
                      'Group Social Media Defaults',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              if (_hasUnsavedChanges)
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit, size: 14, color: Colors.orange),
                      SizedBox(width: 4),
                      Text('Unsaved', style: TextStyle(fontSize: 12, color: Colors.orange)),
                    ],
                  ),
                ),
              ElevatedButton.icon(
                onPressed: _isLoadingVariables ? null : _saveGroupDefaults,
                icon: _isLoadingVariables
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save, size: 18),
                label: const Text('Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: _isLoadingVariables
              ? const Center(child: CircularProgressIndicator(color: _accent))
              : GroupSocialDefaultsEditor(
                  defaults: _groupDefaults!,
                  onChanged: _onGroupDefaultsChanged,
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
