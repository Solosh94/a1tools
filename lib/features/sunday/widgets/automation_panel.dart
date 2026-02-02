/// Automation Panel Widget
/// Shows and manages board automations
library;

import 'package:flutter/material.dart';
import '../../../app_theme.dart';
import '../models/sunday_models.dart';
import '../models/automation_models.dart';
import '../sunday_service.dart';
import 'automation_builder_dialog.dart';

class AutomationPanel extends StatefulWidget {
  final int boardId;
  final String username;
  final VoidCallback onClose;
  final SundayBoard? board;

  const AutomationPanel({
    super.key,
    required this.boardId,
    required this.username,
    required this.onClose,
    this.board,
  });

  @override
  State<AutomationPanel> createState() => _AutomationPanelState();
}

class _AutomationPanelState extends State<AutomationPanel> {
  List<SundayAutomation> _automations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAutomations();
  }

  Future<void> _loadAutomations() async {
    setState(() => _loading = true);
    final automations = await SundayService.getAutomations(widget.boardId);
    if (mounted) {
      setState(() {
        _automations = automations;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          left: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt, color: AppColors.accent),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Automations',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),

          // Add automation button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showAddAutomationDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Automation'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: const BorderSide(color: AppColors.accent),
                ),
              ),
            ),
          ),

          // Automations list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _automations.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _automations.length,
                        itemBuilder: (context, index) {
                          return _buildAutomationCard(_automations[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bolt, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No automations yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Automate repetitive tasks to save time',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _showAddAutomationDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create Automation'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutomationCard(SundayAutomation automation) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    automation.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Switch(
                  value: automation.isActive,
                  onChanged: (value) async {
                    await SundayService.toggleAutomation(automation.id, widget.username);
                    _loadAutomations();
                  },
                  activeTrackColor: AppColors.accent,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              automation.readableDescription,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.play_arrow,
                  size: 14,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 4),
                Text(
                  'Triggered ${automation.triggerCount} times',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.edit, size: 18, color: Colors.grey.shade400),
                  onPressed: () => _editAutomation(automation),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  onPressed: () => _confirmDeleteAutomation(automation),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAutomationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Automation'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose a template to get started:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              ...AutomationTemplate.standardTemplates.take(5).map((template) {
                return ListTile(
                  leading: const Icon(Icons.bolt, color: AppColors.accent),
                  title: Text(template.name),
                  subtitle: Text(
                    template.description,
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await SundayService.createAutomationFromTemplate(
                      boardId: widget.boardId,
                      templateId: template.id,
                      username: widget.username,
                    );
                    _loadAutomations();
                  },
                );
              }),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Create custom automation'),
                subtitle: const Text(
                  'Build from scratch',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCustomAutomationBuilder();
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showCustomAutomationBuilder() async {
    if (widget.board == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Board data not available')),
      );
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AutomationBuilderDialog(
        boardId: widget.boardId,
        username: widget.username,
        board: widget.board!,
      ),
    );

    if (result == true) {
      _loadAutomations();
    }
  }

  void _editAutomation(SundayAutomation automation) async {
    if (widget.board == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Board data not available')),
      );
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AutomationBuilderDialog(
        boardId: widget.boardId,
        username: widget.username,
        board: widget.board!,
        existingAutomation: automation,
      ),
    );

    if (result == true) {
      _loadAutomations();
    }
  }

  void _confirmDeleteAutomation(SundayAutomation automation) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Automation'),
        content: Text('Are you sure you want to delete "${automation.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SundayService.deleteAutomation(automation.id, widget.username);
      _loadAutomations();
    }
  }
}
