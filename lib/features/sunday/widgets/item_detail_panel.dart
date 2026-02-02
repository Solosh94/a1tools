/// Item Detail Panel
/// Shows full item details with updates/comments
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pasteboard/pasteboard.dart';
import '../../../app_theme.dart';
import '../models/sunday_models.dart';
import '../sunday_service.dart';

class ItemDetailPanel extends StatefulWidget {
  final SundayItem item;
  final List<SundayColumn> columns;
  final VoidCallback onClose;
  final Function(String columnKey, dynamic value) onUpdate;
  final Future<void> Function(String body)? onPostUpdate;
  final Function(String newName)? onRename;
  final ScrollController? scrollController;
  final String username;
  final VoidCallback? onRefresh;
  final bool isMobile;

  const ItemDetailPanel({
    super.key,
    required this.item,
    required this.columns,
    required this.onClose,
    required this.onUpdate,
    required this.username,
    this.onPostUpdate,
    this.onRename,
    this.scrollController,
    this.onRefresh,
    this.isMobile = false,
  });

  @override
  State<ItemDetailPanel> createState() => _ItemDetailPanelState();
}

class _ItemDetailPanelState extends State<ItemDetailPanel> {
  List<SundayItemUpdate> _updates = [];
  List<SundaySubitem> _subitems = [];
  bool _loadingUpdates = true;
  bool _loadingSubitems = true;
  final _updateController = TextEditingController();
  final _subitemController = TextEditingController();
  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();
  bool _showSubitemInput = false;
  bool _isEditingName = false;
  final ImagePicker _imagePicker = ImagePicker();

  // Selected files for upload (images and documents)
  List<({Uint8List bytes, String filename})> _selectedFiles = [];

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.item.name;
    _loadUpdates();
    _loadSubitems();
  }

  @override
  void didUpdateWidget(ItemDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _nameController.text = widget.item.name;
      _isEditingName = false;
      _loadUpdates();
      _loadSubitems();
    } else if (oldWidget.item.name != widget.item.name && !_isEditingName) {
      _nameController.text = widget.item.name;
    }
  }

  @override
  void dispose() {
    _updateController.dispose();
    _subitemController.dispose();
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _startEditingName() {
    setState(() {
      _isEditingName = true;
      _nameController.text = widget.item.name;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocusNode.requestFocus();
      _nameController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _nameController.text.length,
      );
    });
  }

  void _submitNameChange() {
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty && newName != widget.item.name) {
      widget.onRename?.call(newName);
    }
    setState(() => _isEditingName = false);
  }

  Future<void> _loadUpdates() async {
    setState(() => _loadingUpdates = true);
    final updates = await SundayService.getItemUpdates(widget.item.id);
    if (mounted) {
      setState(() {
        _updates = updates;
        _loadingUpdates = false;
      });
      // Mark updates as read when viewing the item (don't await to avoid blocking UI)
      SundayService.markUpdatesRead(
        itemId: widget.item.id,
        username: widget.username,
      );
    }
  }

  Future<void> _loadSubitems() async {
    setState(() => _loadingSubitems = true);
    final subitems = await SundayService.getSubitems(widget.item.id);
    if (mounted) {
      setState(() {
        _subitems = subitems;
        _loadingSubitems = false;
      });
    }
  }

  Future<void> _addSubitem(String name) async {
    if (name.trim().isEmpty) return;

    // Inherit status, priority, and date from parent item
    final inheritedValues = <String, dynamic>{};
    final parentValues = widget.item.columnValues;

    // Copy status if exists
    if (parentValues.containsKey('status')) {
      inheritedValues['status'] = parentValues['status'];
    }
    // Copy priority if exists
    if (parentValues.containsKey('priority')) {
      inheritedValues['priority'] = parentValues['priority'];
    }
    // Copy date if exists
    if (parentValues.containsKey('date')) {
      inheritedValues['date'] = parentValues['date'];
    }

    final id = await SundayService.createSubitem(
      parentItemId: widget.item.id,
      name: name.trim(),
      username: widget.username,
      columnValues: inheritedValues.isNotEmpty ? inheritedValues : null,
    );
    if (id != null) {
      _subitemController.clear();
      setState(() => _showSubitemInput = false);
      _loadSubitems();
    }
  }

  Future<void> _deleteSubitem(int subitemId) async {
    final success = await SundayService.deleteSubitem(subitemId, widget.username);
    if (success) {
      _loadSubitems();
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
                Expanded(
                  child: _isEditingName
                      ? TextField(
                          controller: _nameController,
                          focusNode: _nameFocusNode,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 4),
                          ),
                          onSubmitted: (_) => _submitNameChange(),
                          onTapOutside: (_) => _submitNameChange(),
                        )
                      : GestureDetector(
                          onDoubleTap: widget.onRename != null ? _startEditingName : null,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.item.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (widget.onRename != null)
                                IconButton(
                                  icon: Icon(Icons.edit, size: 18, color: Colors.grey.shade400),
                                  onPressed: _startEditingName,
                                  tooltip: 'Rename item',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                // Updates section (moved to top)
                _buildUpdatesSection(),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                // Subitems section
                _buildSubitemsSection(),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                // Column values/settings (moved to bottom)
                _buildColumnValues(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnValues() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.columns.map((column) {
        final value = widget.item.columnValues[column.key];
        return _buildColumnField(column, value);
      }).toList(),
    );
  }

  Widget _buildColumnField(SundayColumn column, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            column.title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          _buildFieldEditor(column, value),
        ],
      ),
    );
  }

  Widget _buildFieldEditor(SundayColumn column, dynamic value) {
    switch (column.type) {
      case ColumnType.status:
      case ColumnType.label: // Custom label categories use same editor as status
        return _buildStatusEditor(column, value);
      case ColumnType.person:
      case ColumnType.technician:
        return _buildPersonEditor(column, value);
      case ColumnType.date:
        return _buildDateEditor(column, value);
      case ColumnType.checkbox:
        return _buildCheckboxEditor(column, value);
      case ColumnType.longText:
        return _buildLongTextEditor(column, value);
      default:
        return _buildTextEditor(column, value);
    }
  }

  Widget _buildStatusEditor(SundayColumn column, dynamic value) {
    final labels = column.statusLabels;
    final currentLabel = labels.firstWhere(
      (l) => l.id == value || l.label == value,
      orElse: () => const StatusLabel(id: '', label: 'Select status', color: '#808080'),
    );

    return PopupMenuButton<String>(
      onSelected: (newValue) => widget.onUpdate(column.key, newValue),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: currentLabel.colorValue.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: currentLabel.colorValue,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              currentLabel.label,
              style: TextStyle(
                color: currentLabel.colorValue,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, color: currentLabel.colorValue),
          ],
        ),
      ),
      itemBuilder: (context) => labels.map((label) {
        return PopupMenuItem<String>(
          value: label.id,
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: label.colorValue,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(label.label),
              if (label.isDone) ...[
                const Spacer(),
                Icon(Icons.check, size: 16, color: Colors.green.shade700),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPersonEditor(SundayColumn column, dynamic value) {
    return InkWell(
      onTap: () => _showPersonPicker(column),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            if (value != null && value.toString().isNotEmpty) ...[
              _buildAvatar(value.toString()),
              const SizedBox(width: 8),
              Expanded(child: Text(value.toString())),
            ] else ...[
              Icon(Icons.person_add_alt, color: Colors.grey.shade400, size: 18),
              const SizedBox(width: 8),
              Text('Assign person', style: TextStyle(color: Colors.grey.shade400)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDateEditor(SundayColumn column, dynamic value) {
    DateTime? date;
    if (value != null) {
      if (value is DateTime) {
        date = value;
      } else if (value is String && value.isNotEmpty) {
        date = DateTime.tryParse(value);
      }
    }

    return InkWell(
      onTap: () async {
        final selected = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (selected != null) {
          widget.onUpdate(column.key, selected.toIso8601String().split('T').first);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: Colors.grey.shade500, size: 18),
            const SizedBox(width: 8),
            Builder(
              builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Text(
                  date != null
                      ? '${date.month}/${date.day}/${date.year}'
                      : 'Select date',
                  style: TextStyle(
                    color: date != null
                        ? (isDark ? Colors.white : Colors.black87)
                        : (isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckboxEditor(SundayColumn column, dynamic value) {
    return Row(
      children: [
        Checkbox(
          value: value == true || value == 1 || value == '1',
          onChanged: (newValue) {
            widget.onUpdate(column.key, newValue);
          },
          activeColor: AppColors.accent,
        ),
        Text(value == true ? 'Yes' : 'No'),
      ],
    );
  }

  Widget _buildLongTextEditor(SundayColumn column, dynamic value) {
    return TextField(
      controller: TextEditingController(text: value?.toString() ?? ''),
      maxLines: 4,
      decoration: InputDecoration(
        hintText: 'Enter text...',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      ),
      onChanged: (newValue) {
        // Debounce this in production
        widget.onUpdate(column.key, newValue);
      },
    );
  }

  Widget _buildTextEditor(SundayColumn column, dynamic value) {
    return TextField(
      controller: TextEditingController(text: value?.toString() ?? ''),
      decoration: InputDecoration(
        hintText: 'Enter ${column.title.toLowerCase()}...',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      ),
      onChanged: (newValue) {
        widget.onUpdate(column.key, newValue);
      },
    );
  }

  Widget _buildSubitemsSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final badgeBgColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final badgeTextColor = isDark ? Colors.grey.shade300 : Colors.grey.shade700;
    final inputBgColor = isDark ? Colors.grey.shade800 : Colors.grey.shade50;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.subdirectory_arrow_right, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Subitems',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_subitems.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: badgeTextColor,
                    ),
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () => setState(() => _showSubitemInput = true),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Add subitem input
        if (_showSubitemInput)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: inputBgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subitemController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Enter subitem name...',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onSubmitted: _addSubitem,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.check, color: AppColors.accent),
                  onPressed: () => _addSubitem(_subitemController.text),
                  iconSize: 20,
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.grey.shade500),
                  onPressed: () {
                    _subitemController.clear();
                    setState(() => _showSubitemInput = false);
                  },
                  iconSize: 20,
                ),
              ],
            ),
          ),

        // Subitems list
        if (_loadingSubitems)
          const Center(child: CircularProgressIndicator(strokeWidth: 2))
        else if (_subitems.isEmpty && !_showSubitemInput)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.playlist_add, size: 40, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text(
                    'No subitems yet',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() => _showSubitemInput = true),
                    child: const Text('Add first subitem'),
                  ),
                ],
              ),
            ),
          )
        else
          ..._subitems.map((subitem) => _buildSubitemRow(subitem)),
      ],
    );
  }

  Widget _buildSubitemRow(SundaySubitem subitem) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.grey.shade800 : Colors.grey.shade50;
    final borderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade200;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          // Checkbox for completion
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: subitem.status == 'done',
              onChanged: (value) async {
                // Update subitem status
                await SundayService.updateSubitem(
                  subitemId: subitem.id,
                  username: widget.username,
                  columnValues: {'status': value == true ? 'done' : 'pending'},
                );
                _loadSubitems();
              },
              activeColor: AppColors.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(width: 8),
          // Name
          Expanded(
            child: Text(
              subitem.name,
              style: TextStyle(
                decoration: subitem.status == 'done' ? TextDecoration.lineThrough : null,
                color: subitem.status == 'done' ? Colors.grey : textColor,
              ),
            ),
          ),
          // Due date indicator (if set)
          if (subitem.dueDate != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _isOverdue(subitem.dueDate!) ? Colors.red.shade50 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 12,
                    color: _isOverdue(subitem.dueDate!) ? Colors.red : Colors.blue,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${subitem.dueDate!.month}/${subitem.dueDate!.day}',
                    style: TextStyle(
                      fontSize: 11,
                      color: _isOverdue(subitem.dueDate!) ? Colors.red : Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
          // Delete button
          IconButton(
            icon: Icon(Icons.delete_outline, size: 18, color: Colors.grey.shade400),
            onPressed: () => _deleteSubitem(subitem.id),
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  bool _isOverdue(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDate = DateTime(date.year, date.month, date.day);
    return dueDate.isBefore(today);
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedFiles = await _imagePicker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (pickedFiles.isNotEmpty) {
        final newFiles = <({Uint8List bytes, String filename})>[];
        for (final file in pickedFiles) {
          final bytes = await file.readAsBytes();
          newFiles.add((bytes: bytes, filename: file.name));
        }
        setState(() {
          _selectedFiles.addAll(newFiles);
        });
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to pick images'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: [
          // Images
          'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp',
          // Documents
          'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
          // Text
          'txt', 'csv',
          // Archives
          'zip', 'rar', '7z',
        ],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final newFiles = <({Uint8List bytes, String filename})>[];
        for (final file in result.files) {
          if (file.bytes != null) {
            // Check file size (max 10MB)
            if (file.bytes!.length > 10 * 1024 * 1024) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${file.name} is too large (max 10MB)'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
              continue;
            }
            newFiles.add((bytes: file.bytes!, filename: file.name));
          }
        }
        if (newFiles.isNotEmpty) {
          setState(() {
            _selectedFiles.addAll(newFiles);
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking files: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to pick files'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  bool _isImageFile(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
  }

  IconData _getFileIcon(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
        return Icons.text_snippet;
      case 'csv':
        return Icons.grid_on;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }

  Future<void> _postUpdateWithFiles() async {
    final content = _updateController.text.trim();

    // Need either text or files
    if (content.isEmpty && _selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter text or attach files'),
        ),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(_selectedFiles.isNotEmpty
                    ? 'Uploading ${_selectedFiles.length} file(s)...'
                    : 'Posting update...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final result = await SundayService.postUpdateWithFiles(
        itemId: widget.item.id,
        body: content,
        username: widget.username,
        files: _selectedFiles.isNotEmpty ? _selectedFiles : null,
      );

      if (mounted) Navigator.pop(context); // Close loading

      if (result != null) {
        _updateController.clear();
        setState(() {
          _selectedFiles = [];
        });
        await _loadUpdates();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Update posted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_selectedFiles.isNotEmpty
                ? 'Failed to upload files. Please check file sizes (max 10MB each) and try again.'
                : 'Failed to post update'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading
      debugPrint('Error posting update: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildUpdatesSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Updates',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),

        // New update input
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _updateController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Write an update...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 8),

            // Selected files preview
            if (_selectedFiles.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.attach_file, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '${_selectedFiles.length} file(s) attached',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setState(() => _selectedFiles = []),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Clear all', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(_selectedFiles.length, (index) {
                        final file = _selectedFiles[index];
                        final isImage = _isImageFile(file.filename);
                        return Container(
                          width: 80,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey.shade700 : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(4),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isImage)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: Image.memory(
                                          file.bytes,
                                          width: 70,
                                          height: 50,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    else
                                      Container(
                                        width: 70,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.grey.shade600 : Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Icon(
                                          _getFileIcon(file.filename),
                                          size: 28,
                                          color: AppColors.accent,
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    Text(
                                      file.filename,
                                      style: const TextStyle(fontSize: 9),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () => _removeFile(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade400,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, size: 12, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Action buttons
            Row(
              children: [
                // Image picker button
                IconButton(
                  onPressed: _pickImages,
                  icon: Icon(Icons.image, color: Colors.grey.shade500),
                  tooltip: 'Attach images',
                ),
                // File picker button
                IconButton(
                  onPressed: _pickFiles,
                  icon: Icon(Icons.attach_file, color: Colors.grey.shade500),
                  tooltip: 'Attach files',
                ),
                const Spacer(),
                // Send button
                FilledButton.icon(
                  onPressed: () => _postUpdateWithFiles(),
                  icon: const Icon(Icons.send, size: 16),
                  label: const Text('Post'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Updates list
        if (_loadingUpdates)
          const Center(child: CircularProgressIndicator(strokeWidth: 2))
        else if (_updates.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text(
                    'No updates yet',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          )
        else
          ...(_updates.map((update) => _buildUpdateCard(update))),
      ],
    );
  }

  Widget _buildUpdateCard(SundayItemUpdate update) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.grey.shade800 : Colors.grey.shade50;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildAvatar(update.createdBy),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      update.createdBy,
                      style: TextStyle(fontWeight: FontWeight.w500, color: textColor),
                    ),
                    Text(
                      _formatTime(update.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              // Edit/Delete menu - only show for own updates
              if (update.createdBy == widget.username)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade500),
                  padding: EdgeInsets.zero,
                  onSelected: (action) {
                    if (action == 'edit') {
                      _showEditUpdateDialog(update);
                    } else if (action == 'delete') {
                      _confirmDeleteUpdate(update);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Selectable text with copy context menu
          GestureDetector(
            onSecondaryTapDown: (details) => _showTextContextMenu(details.globalPosition, update.body),
            onLongPress: () => _copyTextToClipboard(update.body),
            child: SelectableText(
              update.body,
              style: TextStyle(color: textColor),
              contextMenuBuilder: (context, editableTextState) {
                return AdaptiveTextSelectionToolbar.buttonItems(
                  anchors: editableTextState.contextMenuAnchors,
                  buttonItems: [
                    ContextMenuButtonItem(
                      label: 'Copy',
                      onPressed: () {
                        editableTextState.copySelection(SelectionChangedCause.toolbar);
                      },
                    ),
                    ContextMenuButtonItem(
                      label: 'Copy All',
                      onPressed: () {
                        _copyTextToClipboard(update.body);
                        editableTextState.hideToolbar();
                      },
                    ),
                    ContextMenuButtonItem(
                      label: 'Select All',
                      onPressed: () {
                        editableTextState.selectAll(SelectionChangedCause.toolbar);
                      },
                    ),
                  ],
                );
              },
            ),
          ),
          // Display images if any
          if (update.images.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: update.images.map((imageUrl) => _buildUpdateImage(imageUrl)).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUpdateImage(String imageUrl) {
    return GestureDetector(
      onTap: () => _showFullImage(imageUrl),
      onSecondaryTapDown: (details) => _showImageContextMenu(details.globalPosition, imageUrl),
      onLongPress: () => _showImageOptionsDialog(imageUrl),
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.grey.shade200,
              child: const Icon(Icons.broken_image, color: Colors.grey),
            ),
          ),
        ),
      ),
    );
  }

  void _showFullImage(String imageUrl) {
    showDialog(
      context: context,
      barrierDismissible: true, // Allow closing by clicking outside
      barrierColor: Colors.black87, // Dark background
      builder: (ctx) => GestureDetector(
        // Close when tapping anywhere outside the image
        onTap: () => Navigator.pop(ctx),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // Image in center - absorb taps so they don't close the dialog
              Center(
                child: GestureDetector(
                  onTap: () {}, // Absorb taps on the image so it doesn't close
                  onSecondaryTapDown: (details) {
                    // Show context menu WITHOUT closing the dialog
                    _showImageContextMenuInDialog(ctx, details.globalPosition, imageUrl);
                  },
                  child: Image.network(imageUrl),
                ),
              ),
              // Action buttons at top right
              Positioned(
                top: 16,
                right: 16,
                child: GestureDetector(
                  onTap: () {}, // Absorb taps so buttons don't close dialog
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.copy, color: Colors.white, size: 24),
                          tooltip: 'Copy Image',
                          onPressed: () {
                            Navigator.pop(ctx);
                            _copyImageToClipboard(imageUrl);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.share, color: Colors.white, size: 24),
                          tooltip: 'Share',
                          onPressed: () {
                            Navigator.pop(ctx);
                            _shareImage(imageUrl);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.chat, color: Color(0xFF25D366), size: 24),
                          tooltip: 'Send to WhatsApp',
                          onPressed: () {
                            Navigator.pop(ctx);
                            _shareImageToWhatsApp(imageUrl);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.download, color: Colors.white, size: 24),
                          tooltip: 'Save Image',
                          onPressed: () {
                            Navigator.pop(ctx);
                            _saveImageToFile(imageUrl);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 30),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== COPY/PASTE FUNCTIONALITY ====================

  /// Copy text to clipboard with feedback
  void _copyTextToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Text copied to clipboard'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show context menu for text (right-click)
  void _showTextContextMenu(Offset position, String text) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: [
        const PopupMenuItem(
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.copy, size: 18),
              SizedBox(width: 8),
              Text('Copy Text'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'copy') {
        _copyTextToClipboard(text);
      }
    });
  }

  /// Show context menu for image (right-click)
  void _showImageContextMenu(Offset position, String imageUrl) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: [
        const PopupMenuItem(
          value: 'copy_image',
          child: Row(
            children: [
              Icon(Icons.copy, size: 18),
              SizedBox(width: 8),
              Text('Copy Image'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'copy_url',
          child: Row(
            children: [
              Icon(Icons.link, size: 18),
              SizedBox(width: 8),
              Text('Copy Image URL'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'share',
          child: Row(
            children: [
              Icon(Icons.share, size: 18),
              SizedBox(width: 8),
              Text('Share'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'whatsapp',
          child: Row(
            children: [
              Icon(Icons.chat, size: 18, color: Color(0xFF25D366)),
              SizedBox(width: 8),
              Text('Send to WhatsApp'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'save',
          child: Row(
            children: [
              Icon(Icons.download, size: 18),
              SizedBox(width: 8),
              Text('Save Image'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'view',
          child: Row(
            children: [
              Icon(Icons.fullscreen, size: 18),
              SizedBox(width: 8),
              Text('View Full Size'),
            ],
          ),
        ),
      ],
    ).then((value) {
      switch (value) {
        case 'copy_image':
          _copyImageToClipboard(imageUrl);
          break;
        case 'copy_url':
          _copyImageUrlToClipboard(imageUrl);
          break;
        case 'share':
          _shareImage(imageUrl);
          break;
        case 'whatsapp':
          _shareImageToWhatsApp(imageUrl);
          break;
        case 'save':
          _saveImageToFile(imageUrl);
          break;
        case 'view':
          _showFullImage(imageUrl);
          break;
      }
    });
  }

  /// Show context menu for image inside a dialog (doesn't close parent dialog)
  void _showImageContextMenuInDialog(BuildContext dialogContext, Offset position, String imageUrl) {
    showMenu<String>(
      context: dialogContext,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: [
        const PopupMenuItem(
          value: 'copy_image',
          child: Row(
            children: [
              Icon(Icons.copy, size: 18),
              SizedBox(width: 8),
              Text('Copy Image'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'copy_url',
          child: Row(
            children: [
              Icon(Icons.link, size: 18),
              SizedBox(width: 8),
              Text('Copy Image URL'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'share',
          child: Row(
            children: [
              Icon(Icons.share, size: 18),
              SizedBox(width: 8),
              Text('Share'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'whatsapp',
          child: Row(
            children: [
              Icon(Icons.chat, size: 18, color: Color(0xFF25D366)),
              SizedBox(width: 8),
              Text('Send to WhatsApp'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'save',
          child: Row(
            children: [
              Icon(Icons.download, size: 18),
              SizedBox(width: 8),
              Text('Save Image'),
            ],
          ),
        ),
      ],
    ).then((value) {
      // Close the dialog first, then perform action
      if (value != null && dialogContext.mounted) {
        Navigator.pop(dialogContext);
      }
      switch (value) {
        case 'copy_image':
          _copyImageToClipboard(imageUrl);
          break;
        case 'copy_url':
          _copyImageUrlToClipboard(imageUrl);
          break;
        case 'share':
          _shareImage(imageUrl);
          break;
        case 'whatsapp':
          _shareImageToWhatsApp(imageUrl);
          break;
        case 'save':
          _saveImageToFile(imageUrl);
          break;
      }
    });
  }

  /// Show image options dialog (long press on mobile)
  void _showImageOptionsDialog(String imageUrl) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy Image'),
              onTap: () {
                Navigator.pop(ctx);
                _copyImageToClipboard(imageUrl);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Copy Image URL'),
              onTap: () {
                Navigator.pop(ctx);
                _copyImageUrlToClipboard(imageUrl);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(ctx);
                _shareImage(imageUrl);
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat, color: Color(0xFF25D366)),
              title: const Text('Send to WhatsApp'),
              onTap: () {
                Navigator.pop(ctx);
                _shareImageToWhatsApp(imageUrl);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Save Image'),
              onTap: () {
                Navigator.pop(ctx);
                _saveImageToFile(imageUrl);
              },
            ),
            ListTile(
              leading: const Icon(Icons.fullscreen),
              title: const Text('View Full Size'),
              onTap: () {
                Navigator.pop(ctx);
                _showFullImage(imageUrl);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Copy image URL to clipboard
  void _copyImageUrlToClipboard(String imageUrl) {
    Clipboard.setData(ClipboardData(text: imageUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Image URL copied to clipboard'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Copy actual image to clipboard (for pasting into other apps like WhatsApp, Paint, etc.)
  Future<void> _copyImageToClipboard(String imageUrl) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Copying image...'),
            ],
          ),
          duration: Duration(seconds: 10),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Download image
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;

        // Use pasteboard to copy actual image bytes to clipboard
        // This works on Windows, macOS, and Linux
        await Pasteboard.writeImage(bytes);

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Image copied! You can now paste it anywhere (Ctrl+V)'),
                ],
              ),
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        throw Exception('Failed to download image (${response.statusCode})');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy image: $e'),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Save image to file with file picker
  Future<void> _saveImageToFile(String imageUrl) async {
    try {
      // Get file name from URL
      final uri = Uri.parse(imageUrl);
      final originalFileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'image.png';

      // Let user choose save location
      final String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Image',
        fileName: originalFileName,
        type: FileType.image,
      );

      if (outputPath == null) return; // User cancelled

      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 12),
                Text('Saving image...'),
              ],
            ),
            duration: Duration(seconds: 30),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Download and save
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final file = File(outputPath);
        await file.writeAsBytes(response.bodyBytes);

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Image saved to: $outputPath'),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Open',
                onPressed: () {
                  if (Platform.isWindows) {
                    Process.run('explorer.exe', ['/select,', outputPath]);
                  } else if (Platform.isMacOS) {
                    Process.run('open', ['-R', outputPath]);
                  }
                },
              ),
            ),
          );
        }
      } else {
        throw Exception('Failed to download image (${response.statusCode})');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save image: $e'),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Share image using system share sheet
  Future<void> _shareImage(String imageUrl) async {
    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Preparing to share...'),
            ],
          ),
          duration: Duration(seconds: 10),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Download image to temp
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final uri = Uri.parse(imageUrl);
        final fileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'image.png';
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }

        // Share using share_plus
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Shared from A1 Tools',
        );
      } else {
        throw Exception('Failed to download image');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: $e'),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Share image directly to WhatsApp
  Future<void> _shareImageToWhatsApp(String imageUrl) async {
    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Preparing for WhatsApp...'),
            ],
          ),
          duration: Duration(seconds: 10),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Download image to temp
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final tempDir = await getTemporaryDirectory();
        final uri = Uri.parse(imageUrl);
        final fileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'image.png';
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(bytes);

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }

        // On mobile, use share_plus which opens the share sheet with WhatsApp as an option
        if (Platform.isAndroid || Platform.isIOS) {
          await Share.shareXFiles(
            [XFile(file.path)],
            text: 'Shared from A1 Tools',
          );
        } else {
          // On desktop (Windows/Mac):
          // 1. Copy the actual image to clipboard using pasteboard
          // 2. Open WhatsApp Desktop
          // 3. User selects contact and pastes with Ctrl+V

          // Copy actual image to clipboard
          await Pasteboard.writeImage(bytes);

          // Try to open WhatsApp Desktop app
          const whatsappDesktopUrl = 'whatsapp://';

          if (await canLaunchUrl(Uri.parse(whatsappDesktopUrl))) {
            await launchUrl(Uri.parse(whatsappDesktopUrl));

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF25D366), size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Image copied! Select a chat in WhatsApp and press Ctrl+V to paste',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  duration: Duration(seconds: 5),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } else {
            // WhatsApp Desktop not installed, try WhatsApp Web
            const whatsappWebUrl = 'https://web.whatsapp.com/';
            await launchUrl(Uri.parse(whatsappWebUrl), mode: LaunchMode.externalApplication);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF25D366), size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Image copied! Select a chat in WhatsApp Web and press Ctrl+V to paste',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  duration: Duration(seconds: 5),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        }
      } else {
        throw Exception('Failed to download image');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share to WhatsApp: $e'),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ==================== END COPY/PASTE FUNCTIONALITY ====================

  Future<void> _showEditUpdateDialog(SundayItemUpdate update) async {
    final editController = TextEditingController(text: update.body);

    final newBody = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Update'),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: editController,
            maxLines: 5,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Update text...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, editController.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    editController.dispose();

    if (newBody != null && newBody.isNotEmpty && newBody != update.body) {
      final success = await SundayService.editUpdate(
        updateId: update.id,
        body: newBody,
        username: widget.username,
      );
      if (success) {
        _loadUpdates();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to edit update'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteUpdate(SundayItemUpdate update) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Update'),
        content: const Text('Are you sure you want to delete this update?'),
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
      final success = await SundayService.deleteUpdate(update.id, widget.username);
      if (success) {
        _loadUpdates();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete update'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildAvatar(String name) {
    final initials = name.split(' ').take(2).map((s) => s.isNotEmpty ? s[0] : '').join().toUpperCase();
    final colors = [
      const Color(0xFF0073ea),
      const Color(0xFF00c875),
      const Color(0xFFfdab3d),
      const Color(0xFFe2445c),
      const Color(0xFFa25ddc),
    ];
    final color = colors[name.hashCode.abs() % colors.length];

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials.isEmpty ? '?' : initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${time.month}/${time.day}/${time.year}';
  }

  void _showPersonPicker(SundayColumn column) {
    showDialog(
      context: context,
      builder: (ctx) => _PersonPickerDialog(
        title: 'Assign ${column.title}',
        currentValue: widget.item.columnValues[column.key]?.toString() ?? '',
        username: widget.username,
        onChanged: (name) {
          Navigator.pop(ctx);
          widget.onUpdate(column.key, name);
        },
      ),
    );
  }
}

/// Dialog for selecting a person from the users list
class _PersonPickerDialog extends StatefulWidget {
  final String title;
  final String currentValue;
  final Function(String) onChanged;
  final String? username; // Current user for API authentication

  const _PersonPickerDialog({
    required this.title,
    required this.currentValue,
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

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await SundayService.getAppUsers(requestingUsername: widget.username);
      if (mounted) {
        setState(() {
          _users = users;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _searchQuery.isEmpty
        ? _users
        : _users.where((u) {
            final name = (u['name']?.toString() ?? '').toLowerCase();
            final username = (u['username']?.toString() ?? '').toLowerCase();
            final query = _searchQuery.toLowerCase();
            return name.contains(query) || username.contains(query);
          }).toList();

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 350,
        height: 400,
        child: Column(
          children: [
            TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredUsers.isEmpty
                      ? Center(
                          child: Text(
                            'No users found',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = filteredUsers[index];
                            final displayName = (user['name']?.toString() ?? user['username']?.toString() ?? '');
                            final username = user['username']?.toString() ?? '';
                            final initials = displayName.isNotEmpty
                                ? displayName.split(' ').take(2).map((s) => s.isNotEmpty ? s[0] : '').join().toUpperCase()
                                : '?';

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getColorForName(displayName),
                                child: Text(
                                  initials,
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                              title: Text(displayName),
                              subtitle: Text(username, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                              onTap: () => widget.onChanged(displayName),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => widget.onChanged(''),
          child: const Text('Clear'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
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
}
