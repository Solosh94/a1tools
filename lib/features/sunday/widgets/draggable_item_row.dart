/// Draggable Item Row Widget
/// A wrapper that makes an item row draggable for moving between groups
library;

import 'package:flutter/material.dart';
import '../models/sunday_models.dart';
import 'item_row.dart';

class DraggableItemRow extends StatefulWidget {
  final SundayItem item;
  final List<SundayColumn> columns;
  final Map<String, double> columnWidths;
  final bool isSelected;
  final VoidCallback onTap;
  final Function(String, dynamic) onValueChanged;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final VoidCallback? onMoveToBoard;
  final VoidCallback? onMoveToGroup; // Callback for moving item to different group
  final VoidCallback? onManageAccess; // Callback for managing item access
  final Function(String)? onRename;
  final bool isAdmin;
  final bool isDraggable;
  final double? nameColumnWidth;
  final String? username;
  final Future<void> Function(int columnId, String label, String color)? onAddLabel;

  const DraggableItemRow({
    super.key,
    required this.item,
    required this.columns,
    required this.columnWidths,
    required this.isSelected,
    required this.onTap,
    required this.onValueChanged,
    required this.onDelete,
    required this.onDuplicate,
    this.onMoveToBoard,
    this.onMoveToGroup,
    this.onManageAccess,
    this.onRename,
    this.isAdmin = false,
    this.isDraggable = true,
    this.nameColumnWidth,
    this.username,
    this.onAddLabel,
  });

  @override
  State<DraggableItemRow> createState() => _DraggableItemRowState();
}

class _DraggableItemRowState extends State<DraggableItemRow> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final itemRow = ItemRow(
      item: widget.item,
      columns: widget.columns,
      columnWidths: widget.columnWidths,
      isSelected: widget.isSelected,
      isAdmin: widget.isAdmin,
      isDraggable: false, // We handle dragging at this level
      onTap: widget.onTap,
      onValueChanged: widget.onValueChanged,
      onDelete: widget.onDelete,
      onDuplicate: widget.onDuplicate,
      onMoveToBoard: widget.onMoveToBoard,
      onMoveToGroup: widget.onMoveToGroup,
      onManageAccess: widget.onManageAccess,
      onRename: widget.onRename,
      nameColumnWidth: widget.nameColumnWidth,
      username: widget.username,
      onAddLabel: widget.onAddLabel,
    );

    // Allow all users to drag items (not just admins)
    if (!widget.isDraggable) {
      return itemRow;
    }

    // Use Draggable instead of LongPressDraggable to avoid conflicts with popup menus
    // The drag handle area will initiate dragging
    return LongPressDraggable<int>(
      data: widget.item.id,
      delay: const Duration(milliseconds: 200),
      // Only trigger drag from the drag handle area (left side of the row)
      hitTestBehavior: HitTestBehavior.deferToChild,
      onDragStarted: () {
        setState(() => _isDragging = true);
      },
      onDragEnd: (_) {
        setState(() => _isDragging = false);
      },
      onDraggableCanceled: (_, __) {
        setState(() => _isDragging = false);
      },
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 300,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Theme.of(context).primaryColor),
          ),
          child: Row(
            children: [
              const Icon(Icons.drag_indicator, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.item.name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: itemRow,
      ),
      child: AnimatedOpacity(
        opacity: _isDragging ? 0.4 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: itemRow,
      ),
    );
  }
}
