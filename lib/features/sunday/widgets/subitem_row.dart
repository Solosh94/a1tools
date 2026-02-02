/// Subitem Row Widget
/// Displays a subitem row with columns like parent items
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app_theme.dart';
import '../models/sunday_models.dart';
import '../sunday_service.dart';
import 'cell_widgets/status_cell.dart';
import 'cell_widgets/person_cell.dart';
import 'cell_widgets/date_cell.dart';
import 'cell_widgets/text_cell.dart';
import 'cell_widgets/rating_cell.dart';

class SubitemRow extends StatefulWidget {
  final SundaySubitem subitem;
  final List<SundayColumn> columns;
  final Map<String, double> columnWidths;
  final String username;
  final VoidCallback onUpdated;
  final VoidCallback onDeleted;
  final double? nameColumnWidth;
  final bool isAdmin; // For calculating actions column width
  final bool canShowMenu; // For calculating actions column width

  const SubitemRow({
    super.key,
    required this.subitem,
    required this.columns,
    required this.columnWidths,
    required this.username,
    required this.onUpdated,
    required this.onDeleted,
    this.nameColumnWidth,
    this.isAdmin = false,
    this.canShowMenu = true, // Subitems typically show menu for deletion
  });

  @override
  State<SubitemRow> createState() => _SubitemRowState();
}

class _SubitemRowState extends State<SubitemRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rowBgColor = isDark
        ? Colors.grey.shade900.withValues(alpha: 0.5)
        : Colors.grey.shade50;
    final hoverColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.grey.shade100;
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final textColor = isDark ? Colors.white : Colors.black87;
    final isDone = widget.subitem.status == 'done';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: _hovering ? hoverColor : rowBgColor,
          border: Border(
            bottom: BorderSide(color: borderColor, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Actions column (fixed width for alignment)
            // Matches parent item rows: 20 (drag area) + 32 (menu) = 52
            SizedBox(
              width: 52.0, // Consistent with item rows for alignment
              child: _hovering
                  ? PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, size: 16, color: Colors.grey.shade500),
                      padding: EdgeInsets.zero,
                      onSelected: (action) {
                        if (action == 'delete') {
                          _confirmDelete(context);
                        }
                      },
                      itemBuilder: (context) => [
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
                    )
                  : null,
            ),

            // Subitem name with indent
            Container(
              width: widget.nameColumnWidth ?? 300.0,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  // Indent indicator
                  const SizedBox(width: 16),
                  Icon(
                    Icons.subdirectory_arrow_right,
                    size: 14,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(width: 4),
                  // Checkbox for completion
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: isDone,
                      onChanged: (value) => _updateColumnValue(
                        'status',
                        value == true ? 'done' : 'pending',
                      ),
                      activeColor: AppColors.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(3),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Subitem name
                  Expanded(
                    child: Text(
                      widget.subitem.name,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDone ? Colors.grey : textColor,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Dynamic columns (same as parent items)
            ...widget.columns.map((column) {
              final width = widget.columnWidths[column.key] ?? column.width.toDouble();
              final value = widget.subitem.columnValues[column.key];

              return Container(
                width: width,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: borderColor.withValues(alpha: 0.5)),
                  ),
                ),
                child: _buildCell(column, value),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(SundayColumn column, dynamic value) {
    switch (column.type) {
      case ColumnType.status:
      case ColumnType.label: // Custom label categories use same cell as status
        return StatusCell(
          value: value,
          labels: column.statusLabels,
          onChanged: (newValue) => _updateColumnValue(column.key, newValue),
          compact: true,
        );

      case ColumnType.person:
      case ColumnType.technician:
        final isCreatedByColumn = column.key == 'created_by';
        final personCell = PersonCell(
          value: value,
          onChanged: (newValue) => _updateColumnValue(column.key, newValue),
          compact: true,
          readOnly: isCreatedByColumn,
          multiSelect: !isCreatedByColumn,
        );
        // Center the created_by column content
        return isCreatedByColumn ? Center(child: personCell) : personCell;

      case ColumnType.date:
        return DateCell(
          value: value,
          onChanged: (newValue) => _updateColumnValue(column.key, newValue),
        );

      case ColumnType.checkbox:
        return Center(
          child: Transform.scale(
            scale: 0.8,
            child: Checkbox(
              value: value == true || value == 1 || value == '1',
              onChanged: (newValue) => _updateColumnValue(column.key, newValue),
            ),
          ),
        );

      case ColumnType.priority:
        return _buildPriorityCell(column, value);

      case ColumnType.rating:
        return RatingCell(
          value: value,
          onChanged: (newValue) => _updateColumnValue(column.key, newValue),
          compact: true,
        );

      case ColumnType.updateCounter:
        return _buildUpdateCounterCell(value);

      case ColumnType.number:
        return _buildNumberCell(value);

      case ColumnType.currency:
        return _buildCurrencyCell(value);

      case ColumnType.email:
        return _buildEmailCell(value);

      case ColumnType.phone:
        return _buildPhoneCell(value);

      case ColumnType.link:
        return _buildLinkCell(value);

      case ColumnType.tags:
        return _buildTagsCell(value);

      case ColumnType.progress:
        return _buildProgressCell(value);

      case ColumnType.lastUpdated:
      case ColumnType.createdAt:
        return _buildReadOnlyDateCell(value);

      default:
        return TextCell(
          value: value?.toString() ?? '',
          onChanged: (newValue) => _updateColumnValue(column.key, newValue),
        );
    }
  }

  Widget _buildUpdateCounterCell(dynamic value) {
    int count = 0;
    int unread = 0;

    if (value is Map) {
      count = (value['count'] ?? value['total'] ?? 0) is int
          ? (value['count'] ?? value['total'] ?? 0) as int
          : int.tryParse((value['count'] ?? value['total'] ?? '0').toString()) ?? 0;
      unread = (value['unread'] ?? 0) is int
          ? (value['unread'] ?? 0) as int
          : int.tryParse((value['unread'] ?? '0').toString()) ?? 0;
    } else if (value is int) {
      count = value;
    } else if (value is String) {
      count = int.tryParse(value) ?? 0;
    }

    if (count == 0) {
      return Center(child: Text('-', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)));
    }

    final hasUnread = unread > 0;
    final color = hasUnread ? Colors.red : Colors.green;

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          hasUnread ? '$unread/$count' : '$count',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
        ),
      ),
    );
  }

  Widget _buildPriorityCell(SundayColumn column, dynamic value) {
    // Use status labels if available for priority column
    if (column.statusLabels.isNotEmpty) {
      return StatusCell(
        value: value,
        labels: column.statusLabels,
        onChanged: (newValue) => _updateColumnValue(column.key, newValue),
        compact: true,
      );
    }

    // Fallback to default priorities
    final priorities = {
      'critical': {'color': Colors.red, 'label': 'Critical'},
      'high': {'color': Colors.orange, 'label': 'High'},
      'medium': {'color': Colors.yellow.shade700, 'label': 'Medium'},
      'low': {'color': Colors.green, 'label': 'Low'},
    };

    final currentPriority = priorities[value?.toString().toLowerCase()];

    return PopupMenuButton<String>(
      onSelected: (newValue) => _updateColumnValue(column.key, newValue),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: (currentPriority?['color'] as Color?)?.withValues(alpha: 0.2) ??
              Colors.grey.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          currentPriority?['label'] as String? ?? value?.toString() ?? '-',
          style: TextStyle(
            fontSize: 11,
            color: currentPriority?['color'] as Color? ?? Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      itemBuilder: (context) => priorities.entries.map((entry) {
        return PopupMenuItem(
          value: entry.key,
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: entry.value['color'] as Color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(entry.value['label'] as String),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _updateColumnValue(String key, dynamic value) async {
    await SundayService.updateSubitem(
      subitemId: widget.subitem.id,
      username: widget.username,
      columnValues: {key: value},
    );
    widget.onUpdated();
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Subitem'),
        content: Text('Delete "${widget.subitem.name}"?'),
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
      await SundayService.deleteSubitem(widget.subitem.id, widget.username);
      widget.onDeleted();
    }
  }

  Widget _buildNumberCell(dynamic value) {
    final numValue = value is num ? value : double.tryParse(value?.toString() ?? '');
    final displayText = numValue != null
        ? (numValue == numValue.toInt() ? numValue.toInt().toString() : numValue.toStringAsFixed(2))
        : value?.toString() ?? '';

    return Align(
      alignment: Alignment.centerRight,
      child: Text(displayText, style: const TextStyle(fontSize: 11, fontFeatures: [FontFeature.tabularFigures()])),
    );
  }

  Widget _buildCurrencyCell(dynamic value) {
    final numValue = value is num ? value : double.tryParse(value?.toString() ?? '');
    final displayText = numValue != null ? '\$${numValue.toStringAsFixed(2)}' : value?.toString() ?? '';

    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: 11,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: numValue != null && numValue < 0 ? Colors.red : null,
        ),
      ),
    );
  }

  Widget _buildEmailCell(dynamic value) {
    final email = value?.toString() ?? '';
    if (email.isEmpty) return const SizedBox.shrink();

    return InkWell(
      onTap: () => _launchUrl('mailto:$email'),
      child: Text(email, style: TextStyle(fontSize: 10, color: Colors.blue.shade600), overflow: TextOverflow.ellipsis),
    );
  }

  Widget _buildPhoneCell(dynamic value) {
    final phone = value?.toString() ?? '';
    if (phone.isEmpty) return const SizedBox.shrink();

    return InkWell(
      onTap: () => _launchUrl('tel:$phone'),
      child: Text(phone, style: TextStyle(fontSize: 10, color: Colors.green.shade600), overflow: TextOverflow.ellipsis),
    );
  }

  Widget _buildLinkCell(dynamic value) {
    final url = value?.toString() ?? '';
    if (url.isEmpty) return const SizedBox.shrink();

    return InkWell(
      onTap: () => _launchUrl(url.startsWith('http') ? url : 'https://$url'),
      child: Text(
        url,
        style: TextStyle(fontSize: 10, color: Colors.blue.shade600, decoration: TextDecoration.underline),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildTagsCell(dynamic value) {
    List<String> tags = [];
    if (value is List) {
      tags = value.map((e) => e.toString()).toList();
    } else if (value is String && value.isNotEmpty) {
      tags = value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    if (tags.isEmpty) return const SizedBox.shrink();

    final displayTags = tags.take(2).toList();
    final hasMore = tags.length > 2;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...displayTags.map((tag) => Container(
          margin: const EdgeInsets.only(right: 2),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text(tag, style: TextStyle(fontSize: 9, color: Colors.blue.shade700)),
        )),
        if (hasMore)
          Text('+${tags.length - 2}', style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildProgressCell(dynamic value) {
    final percentage = (value is num ? value : double.tryParse(value?.toString() ?? '0') ?? 0).toDouble().clamp(0.0, 100.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 40,
          height: 4,
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation(percentage >= 100 ? Colors.green : Colors.blue),
          ),
        ),
        const SizedBox(width: 3),
        Text('${percentage.toInt()}%', style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildReadOnlyDateCell(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return Text('-', style: TextStyle(color: Colors.grey.shade400, fontSize: 10));
    }

    String displayDate;
    try {
      final date = DateTime.parse(value.toString());
      displayDate = '${date.month}/${date.day}/${date.year}';
    } catch (_) {
      displayDate = value.toString();
    }

    return Text(displayDate, style: TextStyle(fontSize: 10, color: Colors.grey.shade600));
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('Could not launch $url: $e');
    }
  }
}
