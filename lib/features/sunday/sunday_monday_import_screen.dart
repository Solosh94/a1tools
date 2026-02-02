/// Sunday Monday Import Screen
/// Standalone screen for importing boards from Monday.com
library;

import 'package:flutter/material.dart';
import '../../app_theme.dart';
import 'sunday_service.dart';
import 'models/sunday_models.dart';
import 'widgets/monday_import_dialog.dart';

class SundayMondayImportScreen extends StatefulWidget {
  final String username;

  const SundayMondayImportScreen({
    super.key,
    required this.username,
  });

  @override
  State<SundayMondayImportScreen> createState() => _SundayMondayImportScreenState();
}

class _SundayMondayImportScreenState extends State<SundayMondayImportScreen> {
  List<SundayWorkspace> _workspaces = [];
  bool _loading = true;
  SundayWorkspace? _selectedWorkspace;

  @override
  void initState() {
    super.initState();
    _loadWorkspaces();
  }

  Future<void> _loadWorkspaces() async {
    setState(() => _loading = true);
    final workspaces = await SundayService.getWorkspaces(widget.username);
    if (mounted) {
      setState(() {
        _workspaces = workspaces;
        _loading = false;
        if (workspaces.isNotEmpty) {
          _selectedWorkspace = workspaces.first;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import from Monday.com'),
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
    if (_workspaces.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_off,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No workspaces found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a workspace in Sunday first',
              style: TextStyle(
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Import Monday.com Board',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Export a board from Monday.com as Excel and import it here.',
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),

          // Workspace selector
          Text(
            'Select Workspace',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<SundayWorkspace>(
                value: _selectedWorkspace,
                isExpanded: true,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                items: _workspaces.map((workspace) {
                  return DropdownMenuItem(
                    value: workspace,
                    child: Text(workspace.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedWorkspace = value);
                },
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Import button
          Center(
            child: FilledButton.icon(
              onPressed: _selectedWorkspace != null ? _showImportDialog : null,
              icon: const Icon(Icons.upload_file),
              label: const Text('Select Excel File'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 20,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'How to export from Monday.com',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildStep('1', 'Open your board in Monday.com'),
                _buildStep('2', 'Click the three dots menu (...)'),
                _buildStep('3', 'Select "Export board to Excel"'),
                _buildStep('4', 'Download the .xlsx file'),
                _buildStep('5', 'Import it here'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showImportDialog() {
    if (_selectedWorkspace == null) return;

    showDialog(
      context: context,
      builder: (ctx) => MondayImportDialog(
        workspaceId: _selectedWorkspace!.id,
        username: widget.username,
        onImportComplete: (boardId) {
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Board imported successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }
}
