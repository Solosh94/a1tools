/// Status Cell Widget
/// Displays and edits status column values - Monday.com style
library;

import 'package:flutter/material.dart';
import '../../models/sunday_models.dart';

class StatusCell extends StatelessWidget {
  final dynamic value;
  final List<StatusLabel> labels;
  final Function(String) onChanged;
  final bool compact;
  final int? columnId; // Column ID for adding custom labels
  final Function(String label, String color)? onAddLabel; // Callback to add a new label

  const StatusCell({
    super.key,
    required this.value,
    required this.labels,
    required this.onChanged,
    this.compact = false,
    this.columnId,
    this.onAddLabel,
  });

  @override
  Widget build(BuildContext context) {
    // Find matching label
    StatusLabel? currentLabel;
    if (value != null && labels.isNotEmpty) {
      currentLabel = labels.firstWhere(
        (l) => l.id == value || l.label == value,
        orElse: () => StatusLabel(
          id: value.toString(),
          label: value.toString(),
          color: '#808080',
        ),
      );
    }

    return Semantics(
      label: 'Status: ${currentLabel?.label ?? 'Not set'}',
      button: true,
      hint: 'Tap to change status',
      child: PopupMenuButton<String>(
        onSelected: (selectedValue) {
          if (selectedValue == '__add_new__') {
            _showAddLabelDialog(context);
          } else {
            onChanged(selectedValue);
          }
        },
        offset: const Offset(0, 36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        tooltip: 'Change status',
        // Full-width colored pill like Monday.com
        child: Container(
          width: double.infinity,
          height: compact ? 26 : 32,
          decoration: BoxDecoration(
            color: currentLabel?.colorValue ?? Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
          alignment: Alignment.center,
          child: Text(
            currentLabel?.label ?? '',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      itemBuilder: (context) => [
        // Status options
        ...labels.map((label) {
          return PopupMenuItem<String>(
            value: label.id,
            height: 40,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: label.colorValue,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (label.isDone) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.check, size: 16, color: Colors.white),
                  ],
                ],
              ),
            ),
          );
        }),
        // Add new label option (only if callback is provided)
        if (onAddLabel != null) ...[
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: '__add_new__',
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 18, color: Colors.grey),
                SizedBox(width: 4),
                Text(
                  'Add new label',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
      ),
    );
  }

  void _showAddLabelDialog(BuildContext context) {
    final nameController = TextEditingController();
    String selectedColor = '#808080';

    final colors = [
      '#0073ea', '#00c875', '#fdab3d', '#e2445c', '#a25ddc',
      '#579bfc', '#037f4c', '#FF5AC4', '#784BD1', '#808080',
      '#333333', '#ff642e', '#9cd326', '#00d4d4', '#ffd700',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          return AlertDialog(
            title: const Text('Add New Label'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Label name',
                    hintText: 'e.g., In Progress, Pending',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Color:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: colors.map((color) {
                    final isSelected = color == selectedColor;
                    final colorValue = _parseColor(color);
                    return InkWell(
                      onTap: () => setDialogState(() => selectedColor = color),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: colorValue,
                          borderRadius: BorderRadius.circular(4),
                          border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                          boxShadow: isSelected ? [BoxShadow(color: colorValue, blurRadius: 4)] : null,
                        ),
                        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // Preview
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _parseColor(selectedColor),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    nameController.text.isEmpty ? 'Preview' : nameController.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
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
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  Navigator.pop(ctx);
                  onAddLabel?.call(name, selectedColor);
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _parseColor(String color) {
    try {
      return Color(int.parse(color.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }
}
