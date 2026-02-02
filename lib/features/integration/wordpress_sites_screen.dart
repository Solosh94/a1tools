import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../app_theme.dart';
import '../../config/api_config.dart';

class WordPressSitesScreen extends StatefulWidget {
  const WordPressSitesScreen({super.key});

  @override
  State<WordPressSitesScreen> createState() => _WordPressSitesScreenState();
}

class _WordPressSitesScreenState extends State<WordPressSitesScreen>
    with SingleTickerProviderStateMixin {
  static const Color _accent = AppColors.accent;
  static const String _baseUrl = ApiConfig.apiBase;

  late TabController _tabController;
  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _sites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([_loadGroups(), _loadSites()]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadGroups() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/wordpress_sites.php?action=list_groups'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _groups = List<Map<String, dynamic>>.from(data['groups'] ?? []);
        }
      }
    } catch (e) {
      _showError('Failed to load groups: $e');
    }
  }

  Future<void> _loadSites() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/wordpress_sites.php?action=list'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _sites = List<Map<String, dynamic>>.from(data['sites'] ?? []);
        }
      }
    } catch (e) {
      _showError('Failed to load sites: $e');
    }
  }

  Future<void> _deleteGroup(int id, String name) async {
    final confirm = await _showConfirmDialog(
      'Delete Group',
      'Are you sure you want to delete "$name"?\n\nSites in this group will not be deleted, only unassigned.',
    );
    if (confirm != true) return;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/wordpress_sites.php?action=delete_group&id=$id'),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _showSuccess('Group deleted');
        _loadData();
      } else {
        _showError(data['error'] ?? 'Failed to delete');
      }
    } catch (e) {
      _showError('Error: $e');
    }
  }

  Future<void> _deleteSite(int id, String name) async {
    final confirm = await _showConfirmDialog('Delete Site', 'Are you sure you want to delete "$name"?');
    if (confirm != true) return;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/wordpress_sites.php?action=delete&id=$id'),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _showSuccess('Site deleted');
        _loadData();
      } else {
        _showError(data['error'] ?? 'Failed to delete');
      }
    } catch (e) {
      _showError('Error: $e');
    }
  }

  Future<void> _testConnection(int id) async {
    _showLoadingDialog('Testing connection...');
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/wordpress_sites.php?action=test&id=$id'),
      );
      if (!mounted) return;
      Navigator.pop(context);
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final user = data['user'];
        _showSuccess('Connected as ${user['name']}\nRoles: ${(user['roles'] as List).join(', ')}');
      } else {
        _showError(data['error'] ?? 'Connection failed');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showError('Error: $e');
    }
  }

  Future<bool?> _showConfirmDialog(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(color: _accent),
            const SizedBox(width: 20),
            Text(message),
          ],
        ),
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

  void _openGroupEditor([Map<String, dynamic>? group]) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _GroupEditorScreen(group: group)),
    );
    if (result == true) _loadData();
  }

  void _openSiteEditor([Map<String, dynamic>? site]) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _SiteEditorScreen(site: site, groups: _groups)),
    );
    if (result == true) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Image.asset(
          isDark ? 'assets/images/logo-white.png' : 'assets/images/logo.png',
          height: 40,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData, tooltip: 'Refresh'),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _accent,
          labelColor: _accent,
          tabs: const [
            Tab(icon: Icon(Icons.folder), text: 'Groups'),
            Tab(icon: Icon(Icons.language), text: 'Sites'),
          ],
        ),
      ),
      backgroundColor: bgColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 0) {
            _openGroupEditor();
          } else {
            _openSiteEditor();
          }
        },
        backgroundColor: _accent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          _tabController.index == 0 ? 'Add Group' : 'Add Site',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildGroupsTab(isDark),
                _buildSitesTab(isDark),
              ],
            ),
    );
  }

  Widget _buildGroupsTab(bool isDark) {
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;

    if (_groups.isEmpty) {
      return _buildEmptyState(
        icon: Icons.folder_outlined,
        title: 'No Groups Created',
        subtitle: 'Create groups to organize your WordPress sites by company',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _groups.length,
      itemBuilder: (context, index) {
        final group = _groups[index];
        final siteCount = group['site_count'] ?? 0;
        final activeSiteCount = group['active_site_count'] ?? 0;

        return Card(
          color: cardColor,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: _accent.withValues(alpha: 0.3)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.folder, color: _accent, size: 28),
            ),
            title: Text(
              group['name'] ?? 'Unnamed Group',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (group['company']?.isNotEmpty == true)
                  Text(group['company'], style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                Text(
                  '$activeSiteCount/$siteCount sites active',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _openGroupEditor(group),
                  tooltip: 'Edit',
                  color: _accent,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20),
                  onPressed: () => _deleteGroup(group['id'], group['name'] ?? ''),
                  tooltip: 'Delete',
                  color: Colors.red,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSitesTab(bool isDark) {
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;

    if (_sites.isEmpty) {
      return _buildEmptyState(
        icon: Icons.language_outlined,
        title: 'No WordPress Sites',
        subtitle: 'Add your WordPress sites to start publishing blog posts',
      );
    }

    // Group sites by their group
    final Map<String, List<Map<String, dynamic>>> groupedSites = {};
    final List<Map<String, dynamic>> ungroupedSites = [];

    for (final site in _sites) {
      final groupName = site['group_name'] as String?;
      if (groupName != null && groupName.isNotEmpty) {
        groupedSites.putIfAbsent(groupName, () => []).add(site);
      } else {
        ungroupedSites.add(site);
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Grouped sites
        for (final entry in groupedSites.entries) ...[
          _buildGroupHeader(entry.key, entry.value.length),
          ...entry.value.map((site) => _buildSiteCard(site, cardColor)),
          const SizedBox(height: 16),
        ],
        // Ungrouped sites
        if (ungroupedSites.isNotEmpty) ...[
          _buildGroupHeader('Ungrouped Sites', ungroupedSites.length),
          ...ungroupedSites.map((site) => _buildSiteCard(site, cardColor)),
        ],
        const SizedBox(height: 80), // Space for FAB
      ],
    );
  }

  Widget _buildGroupHeader(String name, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Row(
        children: [
          const Icon(Icons.folder, size: 16, color: _accent),
          const SizedBox(width: 8),
          Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(fontSize: 12, color: _accent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteCard(Map<String, dynamic> site, Color cardColor) {
    final isActive = site['is_active'] == 1 || site['is_active'] == '1';
    final isPrimary = site['is_primary'] == 1 || site['is_primary'] == '1';
    final geoLocation = site['geo_location'] as String?;
    final geoEnabled = site['geo_enabled'] == 1 || site['geo_enabled'] == '1';

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isActive ? _accent.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isActive ? _accent.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.wordpress, color: isActive ? _accent : Colors.grey, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          site['name'] ?? 'Unnamed Site',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isPrimary)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('Primary', style: TextStyle(fontSize: 10, color: Colors.blue.shade700)),
                        ),
                      if (!isActive)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Inactive', style: TextStyle(fontSize: 10, color: Colors.black54)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    site['url'] ?? '',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (geoLocation != null && geoLocation.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 12,
                            color: geoEnabled ? _accent : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            geoLocation,
                            style: TextStyle(
                              fontSize: 11,
                              color: geoEnabled ? _accent : Colors.grey,
                            ),
                          ),
                          if (!geoEnabled)
                            Text(
                              ' (disabled)',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.wifi_tethering, size: 18),
                  onPressed: () => _testConnection(site['id']),
                  tooltip: 'Test Connection',
                  color: Colors.blue,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () => _openSiteEditor(site),
                  tooltip: 'Edit',
                  color: _accent,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 18),
                  onPressed: () => _deleteSite(site['id'], site['name'] ?? ''),
                  tooltip: 'Delete',
                  color: Colors.red,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: Colors.grey.shade500), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ============== GROUP EDITOR ==============

class _GroupEditorScreen extends StatefulWidget {
  final Map<String, dynamic>? group;
  const _GroupEditorScreen({this.group});

  @override
  State<_GroupEditorScreen> createState() => _GroupEditorScreenState();
}

class _GroupEditorScreenState extends State<_GroupEditorScreen> {
  static const Color _accent = AppColors.accent;
  static const String _baseUrl = ApiConfig.apiBase;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _companyController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isActive = true;
  bool _isSaving = false;

  bool get _isEditing => widget.group != null;

  @override
  void initState() {
    super.initState();
    if (widget.group != null) {
      _nameController.text = widget.group!['name'] ?? '';
      _companyController.text = widget.group!['company'] ?? '';
      _descriptionController.text = widget.group!['description'] ?? '';
      _isActive = widget.group!['is_active'] == 1 || widget.group!['is_active'] == '1';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/wordpress_sites.php?action=save_group'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': widget.group?['id'] ?? 0,
          'name': _nameController.text.trim(),
          'company': _companyController.text.trim(),
          'description': _descriptionController.text.trim(),
          'is_active': _isActive ? 1 : 0,
        }),
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_isEditing ? 'Group updated' : 'Group created'), backgroundColor: Colors.green.shade700),
          );
          Navigator.pop(context, true);
        }
      } else {
        _showError(data['error'] ?? 'Failed to save');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Group' : 'New Group'),
      ),
      backgroundColor: bgColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _accent.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Group Name *',
                            hintText: 'e.g., A1 Chimney Sites',
                            prefixIcon: Icon(Icons.folder),
                          ),
                          validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _companyController,
                          decoration: const InputDecoration(
                            labelText: 'Company Name',
                            hintText: 'e.g., A-1 Chimney Specialist',
                            prefixIcon: Icon(Icons.business),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            hintText: 'Optional notes about this group',
                            prefixIcon: Icon(Icons.notes),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text('Active'),
                          value: _isActive,
                          onChanged: (v) => setState(() => _isActive = v),
                          activeTrackColor: _accent.withValues(alpha: 0.5),
                          activeThumbColor: _accent,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save),
                      label: Text(_isSaving ? 'Saving...' : 'Save Group'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============== SITE EDITOR ==============

class _SiteEditorScreen extends StatefulWidget {
  final Map<String, dynamic>? site;
  final List<Map<String, dynamic>> groups;
  const _SiteEditorScreen({this.site, required this.groups});

  @override
  State<_SiteEditorScreen> createState() => _SiteEditorScreenState();
}

class _SiteEditorScreenState extends State<_SiteEditorScreen> {
  static const Color _accent = AppColors.accent;
  static const String _baseUrl = ApiConfig.apiBase;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _geoLocationController = TextEditingController();

  int? _groupId;
  bool _isPrimary = false;
  bool _geoEnabled = true;
  bool _isActive = true;
  bool _isSaving = false;
  bool _obscurePassword = true;

  bool get _isEditing => widget.site != null;

  @override
  void initState() {
    super.initState();
    if (widget.site != null) {
      _nameController.text = widget.site!['name'] ?? '';
      _urlController.text = widget.site!['url'] ?? '';
      _usernameController.text = widget.site!['username'] ?? '';
      _geoLocationController.text = widget.site!['geo_location'] ?? '';
      _groupId = widget.site!['group_id'];
      _isPrimary = widget.site!['is_primary'] == 1 || widget.site!['is_primary'] == '1';
      _geoEnabled = widget.site!['geo_enabled'] == 1 || widget.site!['geo_enabled'] == '1';
      _isActive = widget.site!['is_active'] == 1 || widget.site!['is_active'] == '1';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _geoLocationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/wordpress_sites.php?action=save'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': widget.site?['id'] ?? 0,
          'group_id': _groupId,
          'name': _nameController.text.trim(),
          'url': _urlController.text.trim(),
          'username': _usernameController.text.trim(),
          'app_password': _passwordController.text,
          'is_primary': _isPrimary ? 1 : 0,
          'geo_location': _geoLocationController.text.trim(),
          'geo_enabled': _geoEnabled ? 1 : 0,
          'is_active': _isActive ? 1 : 0,
        }),
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_isEditing ? 'Site updated' : 'Site created'), backgroundColor: Colors.green.shade700),
          );
          Navigator.pop(context, true);
        }
      } else {
        _showError(data['error'] ?? 'Failed to save');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Site' : 'Add Site')),
      backgroundColor: bgColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Basic Info Card
                  _buildCard(
                    cardColor: cardColor,
                    title: 'Site Details',
                    icon: Icons.wordpress,
                    children: [
                      DropdownButtonFormField<int?>(
                        initialValue: _groupId,
                        decoration: const InputDecoration(
                          labelText: 'Group',
                          prefixIcon: Icon(Icons.folder),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('No Group')),
                          ...widget.groups.map((g) => DropdownMenuItem(
                            value: g['id'] as int,
                            child: Text(g['name'] ?? 'Unknown'),
                          )),
                        ],
                        onChanged: (v) => setState(() => _groupId = v),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Site Name *',
                          hintText: 'e.g., A1 Chimney - California',
                          prefixIcon: Icon(Icons.label),
                        ),
                        validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _urlController,
                        decoration: const InputDecoration(
                          labelText: 'WordPress URL *',
                          hintText: 'https://ca.a-1chimney.com',
                          prefixIcon: Icon(Icons.link),
                        ),
                        keyboardType: TextInputType.url,
                        validator: (v) {
                          if (v?.trim().isEmpty == true) return 'Required';
                          if (!v!.startsWith('http')) return 'Must start with http:// or https://';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Primary Site'),
                        subtitle: const Text('Main website (geo replacement optional)'),
                        value: _isPrimary,
                        onChanged: (v) => setState(() => _isPrimary = v),
                        activeTrackColor: _accent.withValues(alpha: 0.5),
                        activeThumbColor: _accent,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Authentication Card
                  _buildCard(
                    cardColor: cardColor,
                    title: 'Authentication',
                    icon: Icons.lock,
                    children: [
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'WordPress Username *',
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: _isEditing ? 'App Password (leave blank to keep)' : 'Application Password *',
                          prefixIcon: const Icon(Icons.key),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (v) {
                          if (!_isEditing && (v?.isEmpty ?? true)) return 'Required for new sites';
                          return null;
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Geo Replacement Card
                  _buildCard(
                    cardColor: cardColor,
                    title: 'Geo Location Replacement',
                    icon: Icons.location_on,
                    children: [
                      TextFormField(
                        controller: _geoLocationController,
                        decoration: const InputDecoration(
                          labelText: 'Location Name',
                          hintText: 'e.g., California, Texas, Florida',
                          prefixIcon: Icon(Icons.place),
                          helperText: 'This will replace #GeoLocation in blog content',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('Enable Geo Replacement'),
                        subtitle: const Text('Replace #GeoLocation tags in content'),
                        value: _geoEnabled,
                        onChanged: (v) => setState(() => _geoEnabled = v),
                        activeTrackColor: _accent.withValues(alpha: 0.5),
                        activeThumbColor: _accent,
                        contentPadding: EdgeInsets.zero,
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'For primary sites, you may want to disable geo replacement to keep content generic.',
                                style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Status Card
                  _buildCard(
                    cardColor: cardColor,
                    title: 'Status',
                    icon: Icons.toggle_on,
                    children: [
                      SwitchListTile(
                        title: const Text('Active'),
                        subtitle: const Text('Include in group publishing'),
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                        activeTrackColor: _accent.withValues(alpha: 0.5),
                        activeThumbColor: _accent,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save),
                      label: Text(_isSaving ? 'Saving...' : 'Save Site'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({
    required Color cardColor,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _accent, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
