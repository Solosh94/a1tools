/// Kanban View Widget
/// Displays board items in a Kanban-style layout
library;

import 'package:flutter/material.dart';
import '../../../app_theme.dart';
import '../models/sunday_models.dart';

class KanbanView extends StatelessWidget {
  final SundayBoard board;
  final String username;
  final Function(SundayItem) onItemTap;
  final Function(int itemId, int groupId) onItemMoved;
  final Function(int groupId, String name) onAddItem;
  final VoidCallback onRefresh;

  const KanbanView({
    super.key,
    required this.board,
    required this.username,
    required this.onItemTap,
    required this.onItemMoved,
    required this.onAddItem,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: AppColors.accent,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: board.groups.map((group) {
            return _buildColumn(context, group);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildColumn(BuildContext context, SundayGroup group) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final columnBg = isDark ? Colors.grey.shade900 : Colors.grey.shade100;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: columnBg,
        borderRadius: BorderRadius.circular(12),
        border: isDark ? Border.all(color: Colors.grey.shade800) : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Column header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: group.colorValue.withValues(alpha: isDark ? 0.3 : 0.2),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: group.colorValue,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    group.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: textColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: group.colorValue.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${group.items.length}',
                    style: TextStyle(
                      color: group.colorValue,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Items
          Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height - 200,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(8),
              itemCount: group.items.length,
              itemBuilder: (context, index) {
                final item = group.items[index];
                return _buildCard(context, item, group);
              },
            ),
          ),

          // Add item button
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextButton.icon(
              onPressed: () => _showAddItemDialog(context, group),
              icon: Icon(Icons.add, size: 18, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              label: Text(
                'Add item',
                style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, SundayItem item, SundayGroup group) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Get status from column values (with null safety for empty columns)
    SundayColumn? statusColumn;
    if (board.columns.isNotEmpty) {
      statusColumn = board.columns.cast<SundayColumn?>().firstWhere(
        (c) => c?.type == ColumnType.status,
        orElse: () => null,
      );
    }
    final statusValue = statusColumn != null ? item.columnValues[statusColumn.key] : null;
    StatusLabel? statusLabel;
    if (statusValue != null && statusColumn != null) {
      statusLabel = statusColumn.statusLabels.cast<StatusLabel?>().firstWhere(
        (l) => l?.id == statusValue || l?.label == statusValue,
        orElse: () => StatusLabel(id: '', label: statusValue.toString(), color: '#808080'),
      );
    }

    // Get assignee (with null safety for empty columns)
    SundayColumn? personColumn;
    if (board.columns.isNotEmpty) {
      personColumn = board.columns.cast<SundayColumn?>().firstWhere(
        (c) => c?.type == ColumnType.person || c?.type == ColumnType.technician,
        orElse: () => null,
      );
    }
    final assignee = personColumn != null ? item.columnValues[personColumn.key] : null;

    // Get due date (with null safety for empty columns)
    SundayColumn? dateColumn;
    if (board.columns.isNotEmpty) {
      dateColumn = board.columns.cast<SundayColumn?>().firstWhere(
        (c) => c?.type == ColumnType.date,
        orElse: () => null,
      );
    }
    final dueDate = dateColumn != null ? item.columnValues[dateColumn.key] : null;

    final cardBg = isDark ? Colors.grey.shade800 : Colors.white;

    return Draggable<Map<String, dynamic>>(
      data: {'item_id': item.id, 'group_id': group.id},
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            item.name,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: _buildCardContent(context, item, statusLabel, assignee, dueDate),
      ),
      child: DragTarget<Map<String, dynamic>>(
        onWillAcceptWithDetails: (details) {
          return details.data['item_id'] != item.id;
        },
        onAcceptWithDetails: (details) {
          onItemMoved(details.data['item_id'], group.id);
        },
        builder: (context, candidateData, rejectedData) {
          return _buildCardContent(
            context,
            item,
            statusLabel,
            assignee,
            dueDate,
            isHighlighted: candidateData.isNotEmpty,
          );
        },
      ),
    );
  }

  Widget _buildCardContent(
    BuildContext context,
    SundayItem item,
    StatusLabel? statusLabel,
    dynamic assignee,
    dynamic dueDate, {
    bool isHighlighted = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Colors.grey.shade800 : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    // Build accessibility description
    final accessibilityParts = <String>[item.name];
    if (statusLabel != null) accessibilityParts.add('Status: ${statusLabel.label}');
    if (assignee != null && assignee.toString().isNotEmpty) {
      accessibilityParts.add('Assigned to: $assignee');
    }
    if (dueDate != null && dueDate.toString().isNotEmpty) {
      accessibilityParts.add('Due: ${_formatDate(dueDate.toString())}');
    }
    if (item.hasSubitems) {
      accessibilityParts.add('${item.subitems.length} subitems');
    }

    return Semantics(
      label: accessibilityParts.join(', '),
      button: true,
      hint: 'Double tap to open item details',
      child: GestureDetector(
        onTap: () => onItemTap(item),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(8),
          border: isHighlighted
              ? Border.all(color: AppColors.accent, width: 2)
              : isDark
                  ? Border.all(color: Colors.grey.shade700)
                  : null,
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item name
            Text(
              item.name,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: textColor,
              ),
            ),

            const SizedBox(height: 8),

            // Status badge
            if (statusLabel != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusLabel.colorValue.withValues(alpha: isDark ? 0.3 : 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusLabel.label,
                  style: TextStyle(
                    color: isDark ? statusLabel.colorValue.withValues(alpha: 0.9) : statusLabel.colorValue,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            const SizedBox(height: 8),

            // Bottom row: assignee and due date
            Row(
              children: [
                // Assignee avatar
                if (assignee != null && assignee.toString().isNotEmpty) ...[
                  _buildAvatar(assignee.toString()),
                  const SizedBox(width: 8),
                ],

                const Spacer(),

                // Due date
                if (dueDate != null && dueDate.toString().isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: subtextColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(dueDate.toString()),
                        style: TextStyle(
                          fontSize: 11,
                          color: subtextColor,
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            // Subitem indicator
            if (item.hasSubitems) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.subdirectory_arrow_right,
                    size: 14,
                    color: subtextColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${item.subitems.length} subitems',
                    style: TextStyle(
                      fontSize: 11,
                      color: subtextColor,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
    );
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

    return Tooltip(
      message: name,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            initials.isEmpty ? '?' : initials,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) return 'Today';
    if (dateOnly == today.add(const Duration(days: 1))) return 'Tomorrow';

    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }

  void _showAddItemDialog(BuildContext context, SundayGroup group) {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add item to "${group.title}"'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Item name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              onAddItem(group.id, value.trim());
              Navigator.pop(ctx);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                onAddItem(group.id, name);
                Navigator.pop(ctx);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
