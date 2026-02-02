/// Sunday Settings Dialog
/// Allows Sunday admins to manage default labels, templates, and import
library;

import 'package:flutter/material.dart';
import '../sunday_service.dart';
import '../models/sunday_models.dart';
import '../../../app_theme.dart';
import '../sunday_templates_screen.dart';
import '../sunday_monday_import_screen.dart';

class SundaySettingsDialog extends StatefulWidget {
  final String username;

  const SundaySettingsDialog({
    super.key,
    required this.username,
  });

  @override
  State<SundaySettingsDialog> createState() => _SundaySettingsDialogState();
}

class _SundaySettingsDialogState extends State<SundaySettingsDialog> with TickerProviderStateMixin {
  TabController? _tabController;
  List<LabelCategory> _categories = [];
  Map<String, List<SundayDefaultLabel>> _labelsByCategory = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    // Load categories first
    final categories = await SundayService.getLabelCategories(widget.username);

    // Load labels for each category
    final labelsByCategory = <String, List<SundayDefaultLabel>>{};
    for (final category in categories) {
      final labels = await SundayService.getDefaultLabels(
        type: category.key,
        username: widget.username,
      );
      labelsByCategory[category.key] = labels;
    }

    if (mounted) {
      // Dispose old tab controller if exists
      _tabController?.dispose();

      // Create new tab controller with correct length (+3 for "Manage", "Templates", "Import" tabs)
      _tabController = TabController(
        length: categories.length + 3,
        vsync: this,
      );

      setState(() {
        _categories = categories;
        _labelsByCategory = labelsByCategory;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      child: Container(
        width: 700,
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
                  const Icon(Icons.settings, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Sunday Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Tabs - dynamic based on categories
            if (_loading || _tabController == null)
              const SizedBox(height: 48)
            else
              Container(
                color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: AppColors.accent,
                  unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  indicatorColor: AppColors.accent,
                  tabs: [
                    // Dynamic category tabs
                    ..._categories.map((cat) => Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getIconForCategory(cat.icon), size: 16),
                          const SizedBox(width: 6),
                          Text(cat.name),
                          if (cat.labelCount > 0) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${cat.labelCount}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    )),
                    // Manage categories tab
                    const Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_circle_outline, size: 16),
                          SizedBox(width: 6),
                          Text('Manage'),
                        ],
                      ),
                    ),
                    // Templates tab
                    const Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.folder_copy_outlined, size: 16),
                          SizedBox(width: 6),
                          Text('Templates'),
                        ],
                      ),
                    ),
                    // Import tab
                    const Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_upload_outlined, size: 16),
                          SizedBox(width: 6),
                          Text('Import'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Content
            Expanded(
              child: _loading || _tabController == null
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        // Dynamic label lists for each category
                        ..._categories.map((cat) => _buildLabelsList(
                          _labelsByCategory[cat.key] ?? [],
                          cat.key,
                        )),
                        // Manage categories tab
                        _buildManageCategoriesTab(),
                        // Templates tab
                        _buildTemplatesTab(),
                        // Import tab
                        _buildImportTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForCategory(String iconName) {
    switch (iconName) {
      case 'circle':
        return Icons.circle_outlined;
      case 'flag':
        return Icons.flag_outlined;
      case 'label':
        return Icons.label_outline;
      case 'tag':
        return Icons.sell_outlined;
      case 'star':
        return Icons.star_outline;
      case 'bookmark':
        return Icons.bookmark_outline;
      case 'category':
        return Icons.category_outlined;
      case 'folder':
        return Icons.folder_outlined;
      case 'share':
        return Icons.share_outlined;
      case 'link':
        return Icons.link;
      case 'person':
        return Icons.person_outline;
      case 'group':
        return Icons.group_outlined;
      case 'check':
        return Icons.check_circle_outline;
      case 'priority':
        return Icons.priority_high;
      default:
        return Icons.label_outline;
    }
  }

  Widget _buildManageCategoriesTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Header with add button
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.category_outlined,
                size: 20,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                'Label Categories',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _showAddCategoryDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Category'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                ),
              ),
            ],
          ),
        ),

        // Info box
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Create custom label categories to organize your boards. Each category can be used as a column type.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Categories list
        Expanded(
          child: _categories.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.category_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No label categories yet',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    return _buildCategoryTile(category);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTemplatesTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.folder_copy_outlined,
                size: 20,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                'Board Templates',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SundayTemplatesScreen(username: widget.username),
                    ),
                  );
                },
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Open Templates'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                ),
              ),
            ],
          ),
        ),

        // Info box
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Create and manage board templates. Save existing boards as templates to quickly create new boards with the same structure.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Template preview
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.folder_copy_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'Manage your board templates',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Click "Open Templates" to view, create, and edit templates',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImportTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.cloud_upload_outlined,
                size: 20,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                'Import from Monday.com',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SundayMondayImportScreen(username: widget.username),
                    ),
                  );
                },
                icon: const Icon(Icons.cloud_upload, size: 16),
                label: const Text('Start Import'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                ),
              ),
            ],
          ),
        ),

        // Info box
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.purple.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Import your boards, groups, items, and columns from Monday.com. You\'ll need your Monday.com API key to proceed.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.purple.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Import preview
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'Import boards from Monday.com',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Click "Start Import" to begin the import process',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 24),
                // Steps
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How to import:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildImportStep('1', 'Get your Monday.com API key from Settings'),
                      _buildImportStep('2', 'Click "Start Import" and paste your key'),
                      _buildImportStep('3', 'Select which boards to import'),
                      _buildImportStep('4', 'Choose a workspace and confirm'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImportStep(String number, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(LabelCategory category) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _parseColor(category.color);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getIconForCategory(category.icon),
            color: color,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Text(
              category.name,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            if (category.isBuiltin) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'BUILT-IN',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          category.description.isNotEmpty
              ? category.description
              : '${category.labelCount} label${category.labelCount == 1 ? '' : 's'}',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
          ),
        ),
        trailing: category.isBuiltin
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () => _showEditCategoryDialog(category),
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, size: 18, color: Colors.red.shade400),
                    onPressed: () => _confirmDeleteCategory(category),
                    tooltip: 'Delete',
                  ),
                ],
              ),
      ),
    );
  }

  void _showAddCategoryDialog() {
    final keyController = TextEditingController();
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String selectedIcon = 'label';
    String selectedColor = '#0073ea';

    final icons = ['label', 'tag', 'star', 'bookmark', 'category', 'folder', 'share', 'link', 'check'];
    final colors = [
      '#0073ea', '#00c875', '#fdab3d', '#e2445c', '#a25ddc',
      '#579bfc', '#037f4c', '#FF5AC4', '#784BD1', '#808080',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New Label Category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    hintText: 'e.g., Socials, Tags, Custom Labels',
                  ),
                  autofocus: true,
                  onChanged: (value) {
                    // Auto-generate key from name
                    keyController.text = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: keyController,
                  decoration: const InputDecoration(
                    labelText: 'Key (for system use)',
                    hintText: 'e.g., socials, custom_tags',
                    helperText: 'Lowercase letters and underscores only',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'What is this category for?',
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Icon:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: icons.map((icon) {
                    final isSelected = icon == selectedIcon;
                    return InkWell(
                      onTap: () => setDialogState(() => selectedIcon = icon),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected ? _parseColor(selectedColor).withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected ? Border.all(color: _parseColor(selectedColor), width: 2) : null,
                        ),
                        child: Icon(
                          _getIconForCategory(icon),
                          color: isSelected ? _parseColor(selectedColor) : Colors.grey,
                          size: 20,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Color:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: colors.map((color) {
                    final isSelected = color == selectedColor;
                    return InkWell(
                      onTap: () => setDialogState(() => selectedColor = color),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _parseColor(color),
                          borderRadius: BorderRadius.circular(4),
                          border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                          boxShadow: isSelected ? [BoxShadow(color: _parseColor(color), blurRadius: 4)] : null,
                        ),
                        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                      ),
                    );
                  }).toList(),
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
              onPressed: () async {
                if (nameController.text.trim().isEmpty || keyController.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(ctx);

                final key = await SundayService.createLabelCategory(
                  key: keyController.text.trim(),
                  name: nameController.text.trim(),
                  description: descController.text.trim(),
                  icon: selectedIcon,
                  color: selectedColor,
                  username: widget.username,
                );

                if (key != null) {
                  _loadData();
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCategoryDialog(LabelCategory category) {
    final nameController = TextEditingController(text: category.name);
    final descController = TextEditingController(text: category.description);
    String selectedIcon = category.icon;
    String selectedColor = category.color;

    final icons = ['label', 'tag', 'star', 'bookmark', 'category', 'folder', 'share', 'link', 'check'];
    final colors = [
      '#0073ea', '#00c875', '#fdab3d', '#e2445c', '#a25ddc',
      '#579bfc', '#037f4c', '#FF5AC4', '#784BD1', '#808080',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Edit "${category.name}"'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Display Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 16),
                const Text('Icon:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: icons.map((icon) {
                    final isSelected = icon == selectedIcon;
                    return InkWell(
                      onTap: () => setDialogState(() => selectedIcon = icon),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected ? _parseColor(selectedColor).withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected ? Border.all(color: _parseColor(selectedColor), width: 2) : null,
                        ),
                        child: Icon(
                          _getIconForCategory(icon),
                          color: isSelected ? _parseColor(selectedColor) : Colors.grey,
                          size: 20,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Color:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: colors.map((color) {
                    final isSelected = color == selectedColor;
                    return InkWell(
                      onTap: () => setDialogState(() => selectedColor = color),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _parseColor(color),
                          borderRadius: BorderRadius.circular(4),
                          border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                        ),
                        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                      ),
                    );
                  }).toList(),
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
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                Navigator.pop(ctx);

                await SundayService.updateLabelCategory(
                  key: category.key,
                  name: nameController.text.trim(),
                  description: descController.text.trim(),
                  icon: selectedIcon,
                  color: selectedColor,
                  username: widget.username,
                );

                _loadData();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteCategory(LabelCategory category) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Delete "${category.name}"?'),
            const SizedBox(height: 8),
            if (category.labelCount > 0)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, size: 18, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This will also delete ${category.labelCount} label${category.labelCount == 1 ? '' : 's'} in this category.',
                        style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await SundayService.deleteLabelCategory(category.key, widget.username);
              _loadData();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelsList(List<SundayDefaultLabel> labels, String type) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Find category name for this type
    final category = _categories.where((c) => c.key == type).firstOrNull;
    final categoryName = category?.name ?? '${type[0].toUpperCase()}${type.substring(1)} Labels';

    return Column(
      children: [
        // Add button
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (category != null) ...[
                Icon(
                  _getIconForCategory(category.icon),
                  size: 18,
                  color: _parseColor(category.color),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                categoryName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _showAddLabelDialog(type),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Label'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                ),
              ),
            ],
          ),
        ),

        // Labels list
        Expanded(
          child: labels.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        category != null ? _getIconForCategory(category.icon) : Icons.label_outline,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No labels yet',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add labels that will be available when using this category as a column',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: labels.length,
                  onReorder: (oldIndex, newIndex) => _reorderLabels(labels, type, oldIndex, newIndex),
                  itemBuilder: (context, index) {
                    final label = labels[index];
                    return _buildLabelTile(label, type, Key('label_${label.id}'));
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLabelTile(SundayDefaultLabel label, String type, Key key) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _parseColor(label.color);

    // Build subtitle text
    String? subtitleText;
    if (label.isDone && label.isDefault) {
      subtitleText = 'Marks item as done • Default for new items';
    } else if (label.isDone) {
      subtitleText = 'Marks item as done';
    } else if (label.isDefault) {
      subtitleText = 'Default for new items';
    }

    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
          child: label.isDone
              ? const Icon(Icons.check, color: Colors.white, size: 18)
              : null,
        ),
        title: Row(
          children: [
            Text(
              label.name,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            if (label.isDefault) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'DEFAULT',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade600,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: subtitleText != null
            ? Text(
                subtitleText,
                style: TextStyle(
                  fontSize: 11,
                  color: label.isDone ? Colors.green.shade600 : Colors.blue.shade600,
                ),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: () => _showEditLabelDialog(label, type),
              tooltip: 'Edit',
            ),
            IconButton(
              icon: Icon(Icons.delete, size: 18, color: Colors.red.shade400),
              onPressed: () => _confirmDeleteLabel(label, type),
              tooltip: 'Delete',
            ),
            const Icon(Icons.drag_handle, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String colorString) {
    try {
      if (colorString.startsWith('#')) {
        return Color(int.parse(colorString.substring(1), radix: 16) | 0xFF000000);
      }
    } catch (_) {}
    return Colors.grey;
  }

  void _showAddLabelDialog(String type) {
    final nameController = TextEditingController();
    String selectedColor = '#0073ea';
    bool isDone = false;
    bool isDefault = false;

    final colors = [
      // Primary colors
      '#0073ea', '#00c875', '#fdab3d', '#e2445c', '#a25ddc',
      '#579bfc', '#037f4c', '#FF5AC4', '#784BD1', '#808080',
      // Additional colors
      '#BB3354', '#175A63', '#2B76E5', '#66CCFF', '#226A5E',
      '#F04095', '#FFCB00', '#FF642E', '#7F5347', '#C4C4C4',
      '#CAB641', '#9CD326', '#6161FF', '#999999', '#4ECCC6',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Default Label'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Label Name',
                  hintText: 'e.g., Working on it, Done, Stuck',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              const Text('Color:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: colors.map((color) {
                  final isSelected = color == selectedColor;
                  return InkWell(
                    onTap: () => setDialogState(() => selectedColor = color),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _parseColor(color),
                        borderRadius: BorderRadius.circular(4),
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                        boxShadow: isSelected
                            ? [BoxShadow(color: _parseColor(color), blurRadius: 4)]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 16)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: isDone,
                onChanged: (v) => setDialogState(() => isDone = v ?? false),
                title: const Text('Marks item as "Done"'),
                subtitle: const Text('Items with this status will be considered complete'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                value: isDefault,
                onChanged: (v) => setDialogState(() => isDefault = v ?? false),
                title: const Text('Default for new items'),
                subtitle: Text('New items will start with this $type'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                Navigator.pop(ctx);

                await SundayService.createDefaultLabel(
                  name: nameController.text.trim(),
                  color: selectedColor,
                  type: type,
                  isDone: isDone,
                  isDefault: isDefault,
                  username: widget.username,
                );

                _loadData();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditLabelDialog(SundayDefaultLabel label, String type) {
    final nameController = TextEditingController(text: label.name);
    String selectedColor = label.color;
    bool isDone = label.isDone;
    bool isDefault = label.isDefault;

    final colors = [
      // Primary colors
      '#0073ea', '#00c875', '#fdab3d', '#e2445c', '#a25ddc',
      '#579bfc', '#037f4c', '#FF5AC4', '#784BD1', '#808080',
      // Additional colors
      '#BB3354', '#175A63', '#2B76E5', '#66CCFF', '#226A5E',
      '#F04095', '#FFCB00', '#FF642E', '#7F5347', '#C4C4C4',
      '#CAB641', '#9CD326', '#6161FF', '#999999', '#4ECCC6',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Label'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Label Name'),
              ),
              const SizedBox(height: 16),
              const Text('Color:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: colors.map((color) {
                  final isSelected = color == selectedColor;
                  return InkWell(
                    onTap: () => setDialogState(() => selectedColor = color),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _parseColor(color),
                        borderRadius: BorderRadius.circular(4),
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 16)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: isDone,
                onChanged: (v) => setDialogState(() => isDone = v ?? false),
                title: const Text('Marks item as "Done"'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                value: isDefault,
                onChanged: (v) => setDialogState(() => isDefault = v ?? false),
                title: const Text('Default for new items'),
                subtitle: Text('New items will start with this $type'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                Navigator.pop(ctx);

                await SundayService.updateDefaultLabel(
                  id: label.id,
                  name: nameController.text.trim(),
                  color: selectedColor,
                  isDone: isDone,
                  isDefault: isDefault,
                  username: widget.username,
                );

                _loadData();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteLabel(SundayDefaultLabel label, String type) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Label'),
        content: Text('Delete "${label.name}"? This won\'t affect existing boards.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await SundayService.deleteDefaultLabel(label.id, widget.username);
              _loadData();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _reorderLabels(List<SundayDefaultLabel> labels, String type, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;

    final item = labels.removeAt(oldIndex);
    labels.insert(newIndex, item);

    setState(() {});

    final order = labels.map((l) => l.id).toList();
    await SundayService.reorderDefaultLabels(order, widget.username);
  }
}
