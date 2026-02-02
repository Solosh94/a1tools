/// Add Item Row Widget
/// Quick add row at the bottom of each group
library;

import 'package:flutter/material.dart';
import '../../../app_theme.dart';
import '../models/sunday_models.dart';

class AddItemRow extends StatefulWidget {
  final List<SundayColumn> columns;
  final Map<String, double> columnWidths;
  final Function(String name, Map<String, dynamic> values) onAdd;
  final double? nameColumnWidth;
  final bool isAdmin; // For calculating actions column width
  final bool canShowMenu; // For calculating actions column width

  const AddItemRow({
    super.key,
    required this.columns,
    required this.columnWidths,
    required this.onAdd,
    this.nameColumnWidth,
    this.isAdmin = false,
    this.canShowMenu = false,
  });

  @override
  State<AddItemRow> createState() => _AddItemRowState();
}

class _AddItemRowState extends State<AddItemRow> {
  bool _editing = false;
  final _nameController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _nameController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.grey.shade50;
    final editBgColor = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final textColor = isDark ? Colors.grey.shade400 : Colors.grey.shade500;

    if (!_editing) {
      return InkWell(
        onTap: () {
          setState(() => _editing = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _focusNode.requestFocus();
          });
        },
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              bottom: BorderSide(color: borderColor),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.add, size: 18, color: textColor),
              const SizedBox(width: 8),
              Text(
                'Add item',
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Calculate actions column width to match item rows
    // Drag handle (20) is available to everyone, plus menu space (32)
    const actionsWidth = 52.0; // 20 (drag) + 32 (menu) - consistent for all users

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: editBgColor,
        border: Border(
          bottom: BorderSide(color: borderColor),
          left: const BorderSide(color: AppColors.accent, width: 3),
        ),
      ),
      child: Row(
        children: [
          // Actions column placeholder (for alignment)
          const SizedBox(width: actionsWidth),
          // Name input
          Container(
            width: widget.nameColumnWidth ?? 300.0,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextField(
              controller: _nameController,
              focusNode: _focusNode,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Item name',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              onSubmitted: (value) => _submit(),
            ),
          ),

          // Placeholder cells
          ...widget.columns.map((column) {
            final width = widget.columnWidths[column.key] ?? column.width.toDouble();
            return Container(
              width: width,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: Colors.grey.shade100),
                ),
              ),
              child: Center(
                child: Text(
                  '-',
                  style: TextStyle(color: Colors.grey.shade300),
                ),
              ),
            );
          }),

          // Submit button
          IconButton(
            onPressed: _submit,
            icon: const Icon(Icons.check, color: AppColors.accent, size: 20),
          ),

          // Cancel button
          IconButton(
            onPressed: () {
              setState(() {
                _editing = false;
                _nameController.clear();
              });
            },
            icon: Icon(Icons.close, color: Colors.grey.shade400, size: 20),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      widget.onAdd(name, {});
      _nameController.clear();
      setState(() => _editing = false);
    }
  }
}
