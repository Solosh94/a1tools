/// Mobile Kanban View Widget
/// Optimized kanban layout for mobile with full-width columns and page view
library;

import 'package:flutter/material.dart';
import '../../../../app_theme.dart';
import '../../models/sunday_models.dart';
import '../item_detail_panel.dart';

class MobileKanbanView extends StatefulWidget {
  final SundayBoard board;
  final String username;
  final Function(SundayItem) onItemTap;
  final Function(int itemId, int groupId) onItemMoved;
  final Function(int groupId, String name) onAddItem;
  final VoidCallback onRefresh;

  const MobileKanbanView({
    super.key,
    required this.board,
    required this.username,
    required this.onItemTap,
    required this.onItemMoved,
    required this.onAddItem,
    required this.onRefresh,
  });

  @override
  State<MobileKanbanView> createState() => _MobileKanbanViewState();
}

class _MobileKanbanViewState extends State<MobileKanbanView> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Group indicator dots
        _buildPageIndicator(),
        // Kanban columns as pages
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemCount: widget.board.groups.length,
            itemBuilder: (context, index) {
              final group = widget.board.groups[index];
              return _buildColumn(context, group);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPageIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          widget.board.groups.length,
          (index) {
            final group = widget.board.groups[index];
            final isSelected = index == _currentPage;
            return GestureDetector(
              onTap: () {
                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isSelected ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isSelected ? group.colorValue : group.colorValue.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildColumn(BuildContext context, SundayGroup group) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final columnBg = isDark ? Colors.grey.shade900 : Colors.grey.shade100;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: columnBg,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: Colors.grey.shade800) : null,
      ),
      child: Column(
        children: [
          // Column header
          _buildColumnHeader(context, group, isDark),
          // Items list
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => widget.onRefresh(),
              color: group.colorValue,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: group.items.length + 1, // +1 for add button
                itemBuilder: (context, index) {
                  if (index == group.items.length) {
                    return _buildAddItemButton(context, group, isDark);
                  }
                  return _buildCard(context, group.items[index], group);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnHeader(BuildContext context, SundayGroup group, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: group.colorValue.withValues(alpha: isDark ? 0.3 : 0.2),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: group.colorValue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              group.title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: textColor,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: group.colorValue.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${group.items.length}',
              style: TextStyle(
                color: group.colorValue,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, SundayItem item, SundayGroup group) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Colors.grey.shade800 : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    // Get status and assignee from column values
    final statusColumn = widget.board.columns.cast<SundayColumn?>().firstWhere(
          (c) => c?.type == ColumnType.status,
          orElse: () => null,
        );
    final statusValue = statusColumn != null ? item.columnValues[statusColumn.key] : null;
    StatusLabel? statusLabel;
    if (statusValue != null && statusColumn != null) {
      statusLabel = statusColumn.statusLabels.cast<StatusLabel?>().firstWhere(
            (l) => l?.id == statusValue || l?.label == statusValue,
            orElse: () => StatusLabel(id: '', label: statusValue.toString(), color: '#808080'),
          );
    }

    final personColumn = widget.board.columns.cast<SundayColumn?>().firstWhere(
          (c) => c?.type == ColumnType.person || c?.type == ColumnType.technician,
          orElse: () => null,
        );
    final assignee = personColumn != null ? item.columnValues[personColumn.key] : null;

    final dateColumn = widget.board.columns.cast<SundayColumn?>().firstWhere(
          (c) => c?.type == ColumnType.date,
          orElse: () => null,
        );
    final dueDate = dateColumn != null ? item.columnValues[dateColumn.key] : null;

    return GestureDetector(
      onTap: () => _showItemDetail(context, item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: isDark ? Border.all(color: Colors.grey.shade700) : null,
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
                fontSize: 15,
                color: textColor,
              ),
            ),
            const SizedBox(height: 10),
            // Status badge
            if (statusLabel != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusLabel.colorValue.withValues(alpha: isDark ? 0.3 : 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel.label,
                  style: TextStyle(
                    color: isDark ? statusLabel.colorValue.withValues(alpha: 0.9) : statusLabel.colorValue,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            // Bottom row: assignee and due date
            Row(
              children: [
                if (assignee != null && assignee.toString().isNotEmpty) ...[
                  _buildAvatar(assignee.toString()),
                  const SizedBox(width: 8),
                ],
                const Spacer(),
                if (dueDate != null && dueDate.toString().isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: subtextColor),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(dueDate.toString()),
                        style: TextStyle(fontSize: 12, color: subtextColor),
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
                  Icon(Icons.subdirectory_arrow_right, size: 14, color: subtextColor),
                  const SizedBox(width: 4),
                  Text(
                    '${item.subitems.length} subitems',
                    style: TextStyle(fontSize: 12, color: subtextColor),
                  ),
                ],
              ),
            ],
          ],
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

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials.isEmpty ? '?' : initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
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

  Widget _buildAddItemButton(BuildContext context, SundayGroup group, bool isDark) {
    return GestureDetector(
      onTap: () => _showAddItemDialog(context, group),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 20, color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
            const SizedBox(width: 8),
            Text(
              'Add item',
              style: TextStyle(
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddItemDialog(BuildContext context, SundayGroup group) {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add item to "${group.title}"',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Item name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
              ),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  widget.onAddItem(group.id, value.trim());
                  Navigator.pop(ctx);
                }
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      final name = controller.text.trim();
                      if (name.isNotEmpty) {
                        widget.onAddItem(group.id, name);
                        Navigator.pop(ctx);
                      }
                    },
                    style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                    child: const Text('Add'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showItemDetail(BuildContext context, SundayItem item) {
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
                      // This would need to be wired up properly
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
