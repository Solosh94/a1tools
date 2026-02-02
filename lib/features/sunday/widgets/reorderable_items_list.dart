/// Reorderable Items List Widget
/// Provides drag-and-drop reordering for Sunday items within a group
library;

import 'package:flutter/material.dart';
import '../models/sunday_models.dart';
import 'item_row.dart';
import 'subitem_row.dart';

class ReorderableItemsList extends StatefulWidget {
  final List<SundayItem> items;
  final int groupId;
  final List<SundayColumn> columns;
  final Map<String, double> columnWidths;
  final int? selectedItemId;
  final bool isAdmin;
  final String username;
  final Function(SundayItem) onItemTap;
  final Function(int itemId, String columnKey, dynamic value) onValueChanged;
  final Function(int itemId) onDelete;
  final Function(int itemId) onDuplicate;
  final Function(int itemId)? onMoveToBoard;
  final Function(int oldIndex, int newIndex) onReorder;
  final VoidCallback onSubitemUpdated;

  const ReorderableItemsList({
    super.key,
    required this.items,
    required this.groupId,
    required this.columns,
    required this.columnWidths,
    this.selectedItemId,
    required this.isAdmin,
    required this.username,
    required this.onItemTap,
    required this.onValueChanged,
    required this.onDelete,
    required this.onDuplicate,
    this.onMoveToBoard,
    required this.onReorder,
    required this.onSubitemUpdated,
  });

  @override
  State<ReorderableItemsList> createState() => _ReorderableItemsListState();
}

class _ReorderableItemsListState extends State<ReorderableItemsList> {
  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }

    // Build a list with items and their subitems
    // Only items (not subitems) are reorderable
    final List<Widget> itemWidgets = [];

    for (int i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];

      // Add the main item row
      itemWidgets.add(
        _buildDraggableItem(item, i),
      );

      // Add subitems (not draggable - they follow their parent)
      for (final subitem in item.subitems) {
        itemWidgets.add(
          SubitemRow(
            key: ValueKey('subitem_${subitem.id}'),
            subitem: subitem,
            columns: widget.columns,
            columnWidths: widget.columnWidths,
            username: widget.username,
            onUpdated: widget.onSubitemUpdated,
            onDeleted: widget.onSubitemUpdated,
          ),
        );
      }
    }

    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) {
        // Convert widget indices to item indices
        // We need to map the widget index back to the item index
        final oldItemIndex = _widgetIndexToItemIndex(oldIndex);
        var newItemIndex = _widgetIndexToItemIndex(newIndex);

        if (oldItemIndex == -1) return; // Dragged a subitem, ignore

        // Adjust for removal
        if (newItemIndex > oldItemIndex) {
          newItemIndex--;
        }

        if (oldItemIndex != newItemIndex) {
          widget.onReorder(oldItemIndex, newItemIndex);
        }
      },
      children: _buildReorderableChildren(),
    );
  }

  int _widgetIndexToItemIndex(int widgetIndex) {
    int currentWidgetIndex = 0;
    for (int i = 0; i < widget.items.length; i++) {
      if (currentWidgetIndex == widgetIndex) {
        return i;
      }
      currentWidgetIndex++; // For the item itself
      currentWidgetIndex += widget.items[i].subitems.length; // For subitems
    }
    return -1; // Widget index corresponds to a subitem
  }

  List<Widget> _buildReorderableChildren() {
    final List<Widget> children = [];

    for (int i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];

      // Add the main item row (draggable)
      children.add(
        _buildDraggableItem(item, i),
      );

      // Add subitems (non-draggable placeholders)
      for (final subitem in item.subitems) {
        children.add(
          SubitemRow(
            key: ValueKey('subitem_${subitem.id}'),
            subitem: subitem,
            columns: widget.columns,
            columnWidths: widget.columnWidths,
            username: widget.username,
            onUpdated: widget.onSubitemUpdated,
            onDeleted: widget.onSubitemUpdated,
          ),
        );
      }
    }

    return children;
  }

  Widget _buildDraggableItem(SundayItem item, int index) {
    return ItemRow(
      key: ValueKey('item_${item.id}'),
      item: item,
      columns: widget.columns,
      columnWidths: widget.columnWidths,
      isSelected: widget.selectedItemId == item.id,
      isAdmin: widget.isAdmin,
      isDraggable: widget.isAdmin,
      onTap: () => widget.onItemTap(item),
      onValueChanged: (columnKey, value) {
        widget.onValueChanged(item.id, columnKey, value);
      },
      onDelete: () => widget.onDelete(item.id),
      onDuplicate: () => widget.onDuplicate(item.id),
      onMoveToBoard: widget.onMoveToBoard != null
          ? () => widget.onMoveToBoard!(item.id)
          : null,
    );
  }
}
