/// Column Header Widget
/// Resizable column header with settings
library;

import 'package:flutter/material.dart';
import '../models/sunday_models.dart';

class ColumnHeader extends StatefulWidget {
  final SundayColumn column;
  final double width;
  final Function(double) onWidthChanged;
  final VoidCallback onSettings;
  final bool isDraggable;

  const ColumnHeader({
    super.key,
    required this.column,
    required this.width,
    required this.onWidthChanged,
    required this.onSettings,
    this.isDraggable = false,
  });

  @override
  State<ColumnHeader> createState() => _ColumnHeaderState();
}

class _ColumnHeaderState extends State<ColumnHeader> {
  bool _hovering = false;
  double _dragStartX = 0;
  double _dragStartWidth = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final iconColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Container(
        width: widget.width,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: borderColor),
          ),
        ),
        child: Row(
          children: [
            // Drag indicator (when draggable and hovering)
            if (widget.isDraggable && _hovering)
              MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Icon(
                  Icons.drag_indicator,
                  size: 14,
                  color: iconColor,
                ),
              )
            else if (widget.isDraggable)
              const SizedBox(width: 14),

            // Column icon
            Icon(
              _getColumnIcon(widget.column.type),
              size: 14,
              color: iconColor,
            ),
            const SizedBox(width: 6),

            // Column title
            Expanded(
              child: Text(
                widget.column.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Settings button (on hover)
            if (_hovering)
              GestureDetector(
                onTap: widget.onSettings,
                child: Icon(
                  Icons.more_vert,
                  size: 16,
                  color: iconColor,
                ),
              ),

            // Resize handle
            GestureDetector(
              onHorizontalDragStart: (details) {
                _dragStartX = details.globalPosition.dx;
                _dragStartWidth = widget.width;
              },
              onHorizontalDragUpdate: (details) {
                final delta = details.globalPosition.dx - _dragStartX;
                final newWidth = (_dragStartWidth + delta).clamp(80.0, 400.0);
                widget.onWidthChanged(newWidth);
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: Container(
                  width: 6,
                  height: 40,
                  color: _hovering
                      ? Colors.grey.shade300
                      : Colors.transparent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getColumnIcon(ColumnType type) {
    switch (type) {
      case ColumnType.text:
        return Icons.text_fields;
      case ColumnType.longText:
        return Icons.notes;
      case ColumnType.number:
        return Icons.numbers;
      case ColumnType.status:
        return Icons.circle;
      case ColumnType.person:
        return Icons.person;
      case ColumnType.date:
        return Icons.calendar_today;
      case ColumnType.dateRange:
        return Icons.date_range;
      case ColumnType.timeline:
        return Icons.timeline;
      case ColumnType.checkbox:
        return Icons.check_box;
      case ColumnType.dropdown:
        return Icons.arrow_drop_down_circle;
      case ColumnType.email:
        return Icons.email;
      case ColumnType.phone:
        return Icons.phone;
      case ColumnType.link:
        return Icons.link;
      case ColumnType.file:
        return Icons.attach_file;
      case ColumnType.rating:
        return Icons.star;
      case ColumnType.currency:
        return Icons.attach_money;
      case ColumnType.location:
        return Icons.location_on;
      case ColumnType.tags:
        return Icons.label;
      case ColumnType.priority:
        return Icons.flag;
      case ColumnType.progress:
        return Icons.trending_up;
      case ColumnType.formula:
        return Icons.functions;
      case ColumnType.mirror:
        return Icons.sync_alt;
      case ColumnType.dependency:
        return Icons.call_split;
      case ColumnType.timeTracking:
        return Icons.timer;
      case ColumnType.lastUpdated:
        return Icons.update;
      case ColumnType.createdAt:
        return Icons.add_circle;
      case ColumnType.workizJob:
        return Icons.work;
      case ColumnType.technician:
        return Icons.engineering;
      case ColumnType.label:
        return Icons.label_outline;
      case ColumnType.updateCounter:
        return Icons.mark_chat_unread;
    }
  }
}
