/// Mobile Item Row Widget
/// Touch-optimized item row with swipe actions and horizontal scrolling columns
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/sunday_models.dart';
import '../cell_widgets/status_cell.dart';
import '../cell_widgets/person_cell.dart';
import '../cell_widgets/date_cell.dart';
import '../cell_widgets/text_cell.dart';
import '../cell_widgets/rating_cell.dart';

class MobileItemRow extends StatefulWidget {
  final SundayItem item;
  final List<SundayColumn> columns;
  final Color groupColor;
  final double nameColumnWidth;
  final double columnWidth;
  final ScrollController horizontalScrollController;
  final String username;
  final bool isAdmin;
  final VoidCallback onTap;
  final Function(String columnKey, dynamic value) onValueChanged;
  final VoidCallback onDelete;
  final Function(String newName) onRename;

  const MobileItemRow({
    super.key,
    required this.item,
    required this.columns,
    required this.groupColor,
    required this.nameColumnWidth,
    required this.columnWidth,
    required this.horizontalScrollController,
    required this.username,
    required this.isAdmin,
    required this.onTap,
    required this.onValueChanged,
    required this.onDelete,
    required this.onRename,
  });

  @override
  State<MobileItemRow> createState() => _MobileItemRowState();
}

class _MobileItemRowState extends State<MobileItemRow> {
  // Track if user can delete (admin or creator)
  bool get _canDelete {
    return widget.isAdmin || widget.item.createdBy == widget.username;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rowBg = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    // Dismissible wrapper for swipe-to-delete (only if can delete)
    final Widget rowContent = _buildRowContent(isDark, rowBg, borderColor);

    if (_canDelete) {
      return Dismissible(
        key: ValueKey('mobile_item_${widget.item.id}'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (direction) => _confirmDelete(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: Colors.red,
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        child: rowContent,
      );
    }

    return rowContent;
  }

  Widget _buildRowContent(bool isDark, Color rowBg, Color borderColor) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: rowBg,
          border: Border(
            bottom: BorderSide(color: borderColor),
            left: BorderSide(color: widget.groupColor, width: 3),
          ),
        ),
        child: Row(
          children: [
            // Sticky name column
            _buildNameColumn(isDark, borderColor),
            // Scrollable columns
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  // Sync scroll position with header
                  if (notification is ScrollUpdateNotification) {
                    widget.horizontalScrollController.jumpTo(notification.metrics.pixels);
                  }
                  return false;
                },
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: widget.columns.map((col) => _buildCell(col, isDark)).toList(),
                  ),
                ),
              ),
            ),
            // Chevron indicator for tap to open detail
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                Icons.chevron_right,
                size: 20,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameColumn(bool isDark, Color borderColor) {
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      width: widget.nameColumnWidth,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          // Subitem indicator
          if (widget.item.hasSubitems) ...[
            Icon(
              Icons.subdirectory_arrow_right,
              size: 14,
              color: Colors.grey.shade500,
            ),
            const SizedBox(width: 4),
          ],
          // Item name
          Expanded(
            child: Text(
              widget.item.name,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: textColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Subitem count badge
          if (widget.item.hasSubitems)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${widget.item.subitems.length}',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCell(SundayColumn column, bool isDark) {
    final value = widget.item.columnValues[column.key];

    return Container(
      width: widget.columnWidth,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.centerLeft,
      child: _buildCellContent(column, value),
    );
  }

  Widget _buildCellContent(SundayColumn column, dynamic value) {
    switch (column.type) {
      case ColumnType.status:
      case ColumnType.label: // Custom label categories use same cell as status
        return StatusCell(
          value: value,
          labels: column.statusLabels,
          onChanged: (newValue) => widget.onValueChanged(column.key, newValue),
          compact: true,
        );

      case ColumnType.person:
      case ColumnType.technician:
        final isCreatedByColumn = column.key == 'created_by';
        final personCell = PersonCell(
          value: value,
          onChanged: (newValue) => widget.onValueChanged(column.key, newValue),
          compact: true,
          readOnly: isCreatedByColumn,
          multiSelect: !isCreatedByColumn,
        );
        // Center the created_by column content
        return isCreatedByColumn ? Center(child: personCell) : personCell;

      case ColumnType.date:
        return DateCell(
          value: value,
          onChanged: (newValue) => widget.onValueChanged(column.key, newValue),
        );

      case ColumnType.checkbox:
        return Checkbox(
          value: value == true || value == 1 || value == '1' || value == 'true',
          onChanged: (newValue) => widget.onValueChanged(column.key, newValue),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        );

      case ColumnType.priority:
        return _buildPriorityCell(value);

      case ColumnType.progress:
        return _buildProgressCell(value);

      case ColumnType.rating:
        return RatingCell(
          value: value,
          onChanged: (newValue) => widget.onValueChanged(column.key, newValue),
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

      case ColumnType.dateRange:
        return _buildDateRangeCell(value);

      case ColumnType.timeTracking:
        return _buildTimeTrackingCell(value);

      case ColumnType.lastUpdated:
      case ColumnType.createdAt:
        return _buildReadOnlyDateCell(value);

      case ColumnType.file:
        return _buildFileCell(value);

      case ColumnType.location:
        return _buildLocationCell(value);

      case ColumnType.text:
      default:
        return TextCell(
          value: value?.toString() ?? '',
          onChanged: (newValue) => widget.onValueChanged(column.key, newValue),
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
      return Center(
        child: Text('-', style: TextStyle(color: Colors.grey.shade400)),
      );
    }

    final hasUnread = unread > 0;
    final color = hasUnread ? Colors.red : Colors.green;

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasUnread ? Icons.mark_chat_unread : Icons.mark_chat_read,
              size: 12,
              color: color,
            ),
            const SizedBox(width: 3),
            Text(
              hasUnread ? '$unread/$count' : '$count',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityCell(dynamic value) {
    final priority = value?.toString().toLowerCase() ?? '';
    Color color;
    const IconData icon = Icons.flag;

    switch (priority) {
      case 'critical':
      case 'high':
        color = Colors.red;
        break;
      case 'medium':
        color = Colors.orange;
        break;
      case 'low':
        color = Colors.blue;
        break;
      default:
        color = Colors.grey;
    }

    return Icon(icon, size: 18, color: color);
  }

  Widget _buildProgressCell(dynamic value) {
    // Value is stored as 0-100 percentage
    final percentage = (value is num ? value : double.tryParse(value?.toString() ?? '0') ?? 0).toDouble();
    final progress = (percentage / 100).clamp(0.0, 1.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 50,
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation(
              percentage >= 100 ? Colors.green : percentage > 50 ? Colors.orange : Colors.blue,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${percentage.toInt()}%',
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Future<bool> _confirmDelete() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Delete "${widget.item.name}"? This cannot be undone.'),
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

    if (result == true) {
      widget.onDelete();
      return true;
    }
    return false;
  }

  Widget _buildNumberCell(dynamic value) {
    final numValue = value is num ? value : double.tryParse(value?.toString() ?? '');
    final displayText = numValue != null
        ? (numValue == numValue.toInt() ? numValue.toInt().toString() : numValue.toStringAsFixed(2))
        : value?.toString() ?? '';

    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Text(
          displayText,
          style: const TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]),
        ),
      ),
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
          fontSize: 12,
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.email_outlined, size: 12, color: Colors.blue.shade600),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              email,
              style: TextStyle(fontSize: 11, color: Colors.blue.shade600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneCell(dynamic value) {
    final phone = value?.toString() ?? '';
    if (phone.isEmpty) return const SizedBox.shrink();

    return InkWell(
      onTap: () => _launchUrl('tel:$phone'),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.phone_outlined, size: 12, color: Colors.green.shade600),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              phone,
              style: TextStyle(fontSize: 11, color: Colors.green.shade600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkCell(dynamic value) {
    final url = value?.toString() ?? '';
    if (url.isEmpty) return const SizedBox.shrink();

    String displayText;
    try {
      final uri = Uri.parse(url);
      displayText = uri.host.isNotEmpty ? uri.host : url;
    } catch (_) {
      displayText = url;
    }

    return InkWell(
      onTap: () => _launchUrl(url.startsWith('http') ? url : 'https://$url'),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.link, size: 12, color: Colors.blue.shade600),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              displayText,
              style: TextStyle(fontSize: 11, color: Colors.blue.shade600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(tag, style: TextStyle(fontSize: 9, color: Colors.blue.shade700)),
        )),
        if (hasMore)
          Text('+${tags.length - 2}', style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildDateRangeCell(dynamic value) {
    String startDate = '';
    String endDate = '';

    if (value is Map) {
      startDate = value['start']?.toString() ?? '';
      endDate = value['end']?.toString() ?? '';
    } else if (value is String && value.contains(' - ')) {
      final parts = value.split(' - ');
      startDate = parts[0];
      endDate = parts.length > 1 ? parts[1] : '';
    }

    if (startDate.isEmpty && endDate.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.date_range, size: 12, color: Colors.grey.shade600),
        const SizedBox(width: 2),
        Text(
          '$startDate → $endDate',
          style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildTimeTrackingCell(dynamic value) {
    final minutes = value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

    if (minutes == 0) {
      return Text('-', style: TextStyle(color: Colors.grey.shade400, fontSize: 11));
    }

    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    final displayText = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.timer_outlined, size: 12, color: Colors.purple.shade400),
        const SizedBox(width: 2),
        Text(displayText, style: TextStyle(fontSize: 11, color: Colors.purple.shade600)),
      ],
    );
  }

  Widget _buildReadOnlyDateCell(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return Text('-', style: TextStyle(color: Colors.grey.shade400, fontSize: 11));
    }

    String displayDate;
    try {
      final date = DateTime.parse(value.toString());
      displayDate = '${date.month}/${date.day}/${date.year}';
    } catch (_) {
      displayDate = value.toString();
    }

    return Text(displayDate, style: TextStyle(fontSize: 11, color: Colors.grey.shade600));
  }

  Widget _buildFileCell(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return Icon(Icons.attach_file, size: 14, color: Colors.grey.shade400);
    }

    final filename = value.toString().split('/').last;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.attach_file, size: 12, color: Colors.blue.shade600),
        const SizedBox(width: 2),
        Flexible(
          child: Text(
            filename,
            style: TextStyle(fontSize: 11, color: Colors.blue.shade600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationCell(dynamic value) {
    final location = value?.toString() ?? '';
    if (location.isEmpty) return const SizedBox.shrink();

    return InkWell(
      onTap: () => _launchUrl('https://maps.google.com/?q=${Uri.encodeComponent(location)}'),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on_outlined, size: 12, color: Colors.red.shade400),
          const SizedBox(width: 2),
          Flexible(
            child: Text(
              location,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
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
