/// Sunday Templates Screen
/// Standalone screen for managing board templates
library;

import 'package:flutter/material.dart';
import '../../app_theme.dart';
import 'sunday_service.dart';
import 'models/sunday_models.dart';

class SundayTemplatesScreen extends StatefulWidget {
  final String username;

  const SundayTemplatesScreen({
    super.key,
    required this.username,
  });

  @override
  State<SundayTemplatesScreen> createState() => _SundayTemplatesScreenState();
}

class _SundayTemplatesScreenState extends State<SundayTemplatesScreen> {
  SundayBoardTemplateList? _templateList;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() => _loading = true);
    final list = await SundayService.getBoardTemplates(username: widget.username);
    if (mounted) {
      setState(() {
        _templateList = list;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Board Templates'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(isDark),
    );
  }

  Widget _buildContent(bool isDark) {
    if (_templateList == null) {
      return const Center(child: Text('Failed to load templates'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Built-in templates section
          Text(
            'Built-in Templates',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pre-configured templates for common use cases',
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _templateList!.builtinTemplates.map((template) {
              return _buildTemplateCard(template, isDark, isBuiltin: true);
            }).toList(),
          ),

          const SizedBox(height: 32),

          // Saved templates section
          Row(
            children: [
              Text(
                'Saved Templates',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_templateList!.savedTemplates.length}',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Templates saved from existing boards',
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),

          if (_templateList!.savedTemplates.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bookmark_border,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No saved templates',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Save a board as template from the board menu',
                      style: TextStyle(
                        color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _templateList!.savedTemplates.map((template) {
                return _buildTemplateCard(template, isDark, isBuiltin: false);
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(SundayBoardTemplateInfo template, bool isDark, {required bool isBuiltin}) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getTemplateIcon(template.icon),
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (!isBuiltin)
                      Text(
                        'By ${template.createdBy ?? 'Unknown'}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
              if (!isBuiltin)
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Colors.red.shade400,
                    size: 20,
                  ),
                  onPressed: () => _confirmDeleteTemplate(template),
                  tooltip: 'Delete template',
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            template.description ?? '',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.category_outlined,
                size: 14,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
              Text(
                template.category,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getTemplateIcon(String icon) {
    switch (icon) {
      case 'work':
        return Icons.work_outline;
      case 'pipeline':
        return Icons.filter_list;
      case 'task':
        return Icons.task_alt;
      case 'project':
        return Icons.folder_outlined;
      case 'calendar':
        return Icons.calendar_today;
      case 'bug':
        return Icons.bug_report_outlined;
      case 'people':
        return Icons.people_outline;
      case 'checklist':
        return Icons.checklist;
      default:
        return Icons.dashboard_outlined;
    }
  }

  void _confirmDeleteTemplate(SundayBoardTemplateInfo template) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text('Delete "${template.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final templateId = int.tryParse(template.id) ?? 0;
              if (templateId > 0) {
                await SundayService.deleteBoardTemplate(templateId, widget.username);
                _loadTemplates();
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
