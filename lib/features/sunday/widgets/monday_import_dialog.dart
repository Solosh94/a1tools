/// Monday.com Import Dialog
/// Allows users to import boards from Monday.com Excel exports
library;

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../sunday_service.dart';
import '../../../app_theme.dart';

class MondayImportDialog extends StatefulWidget {
  final int workspaceId;
  final String username;
  final Function(int boardId) onImportComplete;

  const MondayImportDialog({
    super.key,
    required this.workspaceId,
    required this.username,
    required this.onImportComplete,
  });

  @override
  State<MondayImportDialog> createState() => _MondayImportDialogState();
}

class _MondayImportDialogState extends State<MondayImportDialog> {
  String? _selectedFilePath;
  String? _fileName;
  MondayImportPreview? _preview;
  bool _loading = false;
  bool _importing = false;
  String? _error;
  final _boardNameController = TextEditingController();

  @override
  void dispose() {
    _boardNameController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        dialogTitle: 'Select Monday.com Export File',
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFilePath = result.files.single.path;
          _fileName = result.files.single.name;
          _preview = null;
          _error = null;
        });

        // Preview the file
        await _previewFile();
      }
    } catch (e) {
      setState(() {
        _error = 'Error selecting file: $e';
      });
    }
  }

  Future<void> _previewFile() async {
    if (_selectedFilePath == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final preview = await SundayService.previewMondayImport(_selectedFilePath!);

      if (preview != null) {
        setState(() {
          _preview = preview;
          _boardNameController.text = preview.boardName;
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to parse the Excel file. Make sure it\'s a valid Monday.com export.';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error previewing file: $e';
        _loading = false;
      });
    }
  }

  Future<void> _importBoard() async {
    if (_selectedFilePath == null) return;

    setState(() {
      _importing = true;
      _error = null;
    });

    try {
      final result = await SundayService.importMondayBoard(
        filePath: _selectedFilePath!,
        workspaceId: widget.workspaceId,
        username: widget.username,
        boardName: _boardNameController.text.isNotEmpty
            ? _boardNameController.text
            : null,
      );

      if (result != null && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.green,
          ),
        );
        widget.onImportComplete(result.boardId);
      }
    } catch (e) {
      if (mounted) {
        // Clean up the exception message - remove "Exception: " prefix if present
        String errorMsg = e.toString();
        if (errorMsg.startsWith('Exception: ')) {
          errorMsg = errorMsg.substring(11);
        }
        setState(() {
          _error = errorMsg;
          _importing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final footerBgColor = isDark ? Theme.of(context).cardColor : Colors.grey.shade50;
    final errorBgColor = isDark ? Colors.red.shade900.withValues(alpha: 0.3) : Colors.red.shade50;
    final errorBorderColor = isDark ? Colors.red.shade700 : Colors.red.shade200;
    final errorTextColor = isDark ? Colors.red.shade300 : Colors.red.shade700;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      // ignore: deprecated_member_use - use dialogBackgroundColor until migration to DialogThemeData
      backgroundColor: Theme.of(context).dialogBackgroundColor,
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.upload_file, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Import from Monday.com',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Import your existing boards from Monday.com Excel exports',
                          style: TextStyle(
                            fontSize: 13,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // File selection
                    _buildFileSelection(),

                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: errorBgColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: errorBorderColor),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: errorTextColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(color: errorTextColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_loading) ...[
                      const SizedBox(height: 24),
                      const Center(child: CircularProgressIndicator()),
                      const SizedBox(height: 16),
                      const Center(child: Text('Analyzing file...')),
                    ],

                    if (_preview != null) ...[
                      const SizedBox(height: 24),
                      _buildPreview(),
                    ],
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: footerBgColor,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _importing ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _preview != null && !_importing ? _importBoard : null,
                    icon: _importing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download),
                    label: Text(_importing ? 'Importing...' : 'Import Board'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
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

  Widget _buildFileSelection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedBgColor = isDark ? Theme.of(context).cardColor : Colors.grey.shade50;
    final unselectedBorderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border.all(
          color: _selectedFilePath != null ? AppColors.accent : unselectedBorderColor,
          width: _selectedFilePath != null ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
        color: _selectedFilePath != null
            ? AppColors.accent.withValues(alpha: isDark ? 0.15 : 0.05)
            : unselectedBgColor,
      ),
      child: Column(
        children: [
          Icon(
            _selectedFilePath != null ? Icons.check_circle : Icons.cloud_upload,
            size: 48,
            color: _selectedFilePath != null ? AppColors.accent : (isDark ? Colors.grey.shade500 : Colors.grey),
          ),
          const SizedBox(height: 12),
          if (_selectedFilePath != null) ...[
            Text(
              _fileName ?? 'File selected',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loading || _importing ? null : _pickFile,
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Choose Different File'),
            ),
          ] else ...[
            const Text(
              'Select Monday.com Export File',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Supported formats: .xlsx, .xls',
              style: TextStyle(
                fontSize: 13,
                color: subtitleColor,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('Browse Files'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.accent),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (_preview == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? Colors.grey.shade400 : Colors.grey.shade700;
    final borderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade200;
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final summaryBgColor = isDark ? Colors.blue.shade900.withValues(alpha: 0.3) : Colors.blue.shade50;
    final chipBgColor = isDark ? Colors.grey.shade800 : Colors.grey.shade100;
    final chipIconColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Board name
        Text(
          'Board Name',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _boardNameController,
          decoration: InputDecoration(
            hintText: 'Enter board name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),

        const SizedBox(height: 24),

        // Summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: summaryBgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              _buildSummaryItem(
                Icons.folder,
                '${_preview!.groups.length}',
                'Groups',
              ),
              _buildSummaryDivider(),
              _buildSummaryItem(
                Icons.list_alt,
                '${_preview!.totalItems}',
                'Items',
              ),
              _buildSummaryDivider(),
              _buildSummaryItem(
                Icons.view_column,
                '${_preview!.columns.length}',
                'Columns',
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Groups preview
        Text(
          'Groups',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: _preview!.groups.map((group) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: borderColor),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        group.title,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      '${group.itemCount} items',
                      style: TextStyle(
                        fontSize: 13,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 24),

        // Columns preview
        Text(
          'Columns',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _preview!.columns.map((column) {
            return Chip(
              label: Text(column.name),
              avatar: Icon(
                _getColumnIcon(column.type),
                size: 16,
                color: chipIconColor,
              ),
              backgroundColor: chipBgColor,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(IconData icon, String value, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.blue.shade300 : Colors.blue.shade700;
    final valueColor = isDark ? Colors.blue.shade300 : Colors.blue.shade700;
    final labelColor = isDark ? Colors.blue.shade400 : Colors.blue.shade600;

    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryDivider() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 1,
      height: 50,
      color: isDark ? Colors.blue.shade700 : Colors.blue.shade200,
    );
  }

  IconData _getColumnIcon(String type) {
    switch (type) {
      case 'status':
        return Icons.circle;
      case 'person':
        return Icons.person;
      case 'date':
        return Icons.calendar_today;
      case 'priority':
        return Icons.flag;
      case 'email':
        return Icons.email;
      case 'phone':
        return Icons.phone;
      case 'number':
        return Icons.tag;
      case 'link':
        return Icons.link;
      case 'tags':
        return Icons.label;
      case 'progress':
        return Icons.linear_scale;
      default:
        return Icons.text_fields;
    }
  }
}
