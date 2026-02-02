/// Mobile Board View Widget
/// Optimized layout for mobile devices with sticky name column and swipe gestures
library;

import 'package:flutter/material.dart';
import '../../../../app_theme.dart';
import '../../models/sunday_models.dart';
import 'mobile_item_row.dart';
import 'mobile_group_header.dart';
import 'mobile_add_item_row.dart';
import '../item_detail_panel.dart';

class MobileBoardView extends StatefulWidget {
  final SundayBoard board;
  final String username;
  final String role;
  final bool isSundayAdmin;
  final VoidCallback onRefresh;
  final Function(int itemId, String columnKey, dynamic value) onValueChanged;
  final Function(int groupId, String name, Map<String, dynamic>? values) onAddItem;
  final Function(int itemId) onDeleteItem;
  final Function(int itemId, String newName) onRenameItem;

  const MobileBoardView({
    super.key,
    required this.board,
    required this.username,
    required this.role,
    required this.isSundayAdmin,
    required this.onRefresh,
    required this.onValueChanged,
    required this.onAddItem,
    required this.onDeleteItem,
    required this.onRenameItem,
  });

  @override
  State<MobileBoardView> createState() => _MobileBoardViewState();
}

class _MobileBoardViewState extends State<MobileBoardView> {
  final ScrollController _horizontalScrollController = ScrollController();
  final Set<int> _collapsedGroups = {};

  // Fixed name column width for mobile
  static const double _nameColumnWidth = 180.0;
  // Column width for other columns on mobile
  static const double _columnWidth = 120.0;

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final visibleColumns = widget.board.columns.where((c) => !c.isHidden).toList();

    return Column(
      children: [
        // Sticky header row
        _buildColumnHeaders(visibleColumns, isDark),
        // Groups and items
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => widget.onRefresh(),
            color: AppColors.accent,
            child: ListView.builder(
              itemCount: widget.board.groups.length,
              itemBuilder: (context, index) {
                final group = widget.board.groups[index];
                return _buildGroup(group, visibleColumns, isDark);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColumnHeaders(List<SundayColumn> columns, bool isDark) {
    final headerBg = isDark ? Colors.grey.shade900 : Colors.grey.shade100;
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: headerBg,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          // Sticky name column header
          Container(
            width: _nameColumnWidth,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: headerBg,
              border: Border(right: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                const Icon(Icons.text_fields, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Name',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          // Scrollable column headers
          Expanded(
            child: SingleChildScrollView(
              controller: _horizontalScrollController,
              scrollDirection: Axis.horizontal,
              child: Row(
                children: columns.map((col) => _buildColumnHeader(col, isDark)).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnHeader(SundayColumn column, bool isDark) {
    return Container(
      width: _columnWidth,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Icon(_getColumnIcon(column.type), size: 14, color: Colors.grey),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              column.title,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getColumnIcon(ColumnType type) {
    switch (type) {
      case ColumnType.status:
      case ColumnType.label: // Custom label categories
        return Icons.circle;
      case ColumnType.person:
      case ColumnType.technician:
        return Icons.person;
      case ColumnType.date:
        return Icons.calendar_today;
      case ColumnType.checkbox:
        return Icons.check_box_outlined;
      case ColumnType.priority:
        return Icons.flag;
      case ColumnType.progress:
        return Icons.linear_scale;
      case ColumnType.text:
      default:
        return Icons.text_fields;
    }
  }

  Widget _buildGroup(SundayGroup group, List<SundayColumn> columns, bool isDark) {
    final isCollapsed = _collapsedGroups.contains(group.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group header
        MobileGroupHeader(
          group: group,
          isCollapsed: isCollapsed,
          itemCount: group.items.length,
          onToggleCollapse: () {
            setState(() {
              if (isCollapsed) {
                _collapsedGroups.remove(group.id);
              } else {
                _collapsedGroups.add(group.id);
              }
            });
          },
        ),
        // Items (if not collapsed)
        if (!isCollapsed) ...[
          ...group.items.map((item) => _buildItemRow(item, columns, isDark, group)),
          // Add item row
          MobileAddItemRow(
            groupColor: group.colorValue,
            onAdd: (name) => widget.onAddItem(group.id, name, null),
          ),
        ],
      ],
    );
  }

  Widget _buildItemRow(SundayItem item, List<SundayColumn> columns, bool isDark, SundayGroup group) {
    return MobileItemRow(
      item: item,
      columns: columns,
      groupColor: group.colorValue,
      nameColumnWidth: _nameColumnWidth,
      columnWidth: _columnWidth,
      horizontalScrollController: _horizontalScrollController,
      username: widget.username,
      isAdmin: widget.isSundayAdmin,
      onTap: () => _showItemDetail(item),
      onValueChanged: (columnKey, value) {
        widget.onValueChanged(item.id, columnKey, value);
      },
      onDelete: () => widget.onDeleteItem(item.id),
      onRename: (newName) => widget.onRenameItem(item.id, newName),
    );
  }

  void _showItemDetail(SundayItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            decoration: BoxDecoration(
              color: isDark ? Theme.of(context).cardColor : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Item detail panel
                Expanded(
                  child: ItemDetailPanel(
                    item: item,
                    columns: widget.board.columns,
                    username: widget.username,
                    onClose: () => Navigator.pop(context),
                    onUpdate: (columnKey, value) async {
                      widget.onValueChanged(item.id, columnKey, value);
                    },
                    onRename: (newName) async {
                      widget.onRenameItem(item.id, newName);
                    },
                    onRefresh: widget.onRefresh,
                    isMobile: true,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
