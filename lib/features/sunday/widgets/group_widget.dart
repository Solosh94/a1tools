/// Group Widget
/// Displays a collapsible group with its items
/// Supports drag-and-drop for reordering and moving items between groups
library;

import 'package:flutter/material.dart';
import '../models/sunday_models.dart';

class GroupWidget extends StatefulWidget {
  final SundayGroup group;
  final bool isCollapsed;
  final int itemCount;
  final int? totalItemCount; // Total items when filters are active (shows "X of Y")
  final VoidCallback onToggleCollapse;
  final Function(String) onRename;
  final Function(String) onChangeColor;
  final VoidCallback onDelete;
  final VoidCallback? onManageAccess; // New: Callback for managing group access
  final List<Widget> children;
  final bool isAdmin;
  final bool isDragTarget;
  final Function(int itemId)? onItemDropped;

  const GroupWidget({
    super.key,
    required this.group,
    required this.isCollapsed,
    required this.itemCount,
    this.totalItemCount,
    required this.onToggleCollapse,
    required this.onRename,
    required this.onChangeColor,
    required this.onDelete,
    this.onManageAccess,
    required this.children,
    this.isAdmin = false,
    this.isDragTarget = false,
    this.onItemDropped,
  });

  @override
  State<GroupWidget> createState() => _GroupWidgetState();
}

class _GroupWidgetState extends State<GroupWidget> {
  bool _isDragOver = false;

  @override
  Widget build(BuildContext context) {
    final columnContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group header
        _buildHeader(context),

        // Children (items)
        ...widget.children,
      ],
    );

    // Wrap with DragTarget if enabled
    if (widget.isDragTarget && widget.onItemDropped != null) {
      return DragTarget<int>(
        onWillAcceptWithDetails: (details) {
          setState(() => _isDragOver = true);
          return true;
        },
        onLeave: (_) {
          setState(() => _isDragOver = false);
        },
        onAcceptWithDetails: (details) {
          setState(() => _isDragOver = false);
          widget.onItemDropped!(details.data);
        },
        builder: (context, candidateData, rejectedData) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              border: _isDragOver
                  ? Border.all(color: widget.group.colorValue, width: 2)
                  : null,
              borderRadius: BorderRadius.circular(4),
            ),
            child: columnContent,
          );
        },
      );
    }

    return columnContent;
  }

  Widget _buildHeader(BuildContext context) {
    return InkWell(
      onTap: widget.onToggleCollapse,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _isDragOver
              ? widget.group.colorValue.withValues(alpha: 0.3)
              : widget.group.colorValue.withValues(alpha: 0.1),
          border: Border(
            left: BorderSide(color: widget.group.colorValue, width: 3),
          ),
        ),
        child: Row(
          children: [
            // Drag handle indicator for group reordering (visual only, parent handles dragging)
            if (widget.isAdmin)
              MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Icon(
                  Icons.drag_indicator,
                  color: Colors.grey.shade400,
                  size: 18,
                ),
              ),
            if (widget.isAdmin) const SizedBox(width: 4),
            Icon(
              widget.isCollapsed ? Icons.chevron_right : Icons.expand_more,
              color: widget.group.colorValue,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              widget.group.title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: widget.group.colorValue,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: widget.group.colorValue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                widget.totalItemCount != null
                    ? '${widget.itemCount} of ${widget.totalItemCount}'
                    : '${widget.itemCount}',
                style: TextStyle(
                  color: widget.group.colorValue,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Spacer(),
            if (widget.isAdmin)
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz, color: Colors.grey.shade400, size: 20),
                onSelected: (action) {
                  switch (action) {
                    case 'rename':
                      _showRenameDialog(context);
                      break;
                    case 'color':
                      _showColorDialog(context);
                      break;
                    case 'manage_access':
                      widget.onManageAccess?.call();
                      break;
                    case 'delete':
                      widget.onDelete();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18),
                        SizedBox(width: 8),
                        Text('Rename'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'color',
                    child: Row(
                      children: [
                        Icon(Icons.palette, size: 18),
                        SizedBox(width: 8),
                        Text('Change color'),
                      ],
                    ),
                  ),
                  if (widget.onManageAccess != null) ...[
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'manage_access',
                      child: Row(
                        children: [
                          Icon(Icons.group_add, size: 18, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Manage Access', style: TextStyle(color: Colors.blue)),
                        ],
                      ),
                    ),
                  ],
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: widget.group.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Group'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Group name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (controller.text.trim().isNotEmpty) {
                widget.onRename(controller.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showColorDialog(BuildContext context) {
    final colors = [
      '#0073ea', '#00c875', '#fdab3d', '#e2445c', '#a25ddc',
      '#579bfc', '#037f4c', '#9AADBD', '#FF5AC4', '#784BD1',
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose Color'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: colors.map((color) {
            return InkWell(
              onTap: () {
                Navigator.pop(ctx);
                widget.onChangeColor(color);
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(int.parse(color.replaceFirst('#', '0xFF'))),
                  shape: BoxShape.circle,
                  border: widget.group.color == color
                      ? Border.all(color: Colors.white, width: 3)
                      : null,
                  boxShadow: [
                    if (widget.group.color == color)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
