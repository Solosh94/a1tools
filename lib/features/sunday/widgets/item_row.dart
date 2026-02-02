/// Item Row Widget
/// Displays a single item row in the table view
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/sunday_models.dart';
import 'cell_widgets/status_cell.dart';
import 'cell_widgets/person_cell.dart';
import 'cell_widgets/date_cell.dart';
import 'cell_widgets/text_cell.dart';
import 'cell_widgets/rating_cell.dart';

class ItemRow extends StatefulWidget {
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
  final VoidCallback? onDragStarted;
  final VoidCallback? onDragEnded;
  final double? nameColumnWidth;
  final String? username; // Current user's username to check ownership
  final Future<void> Function(int columnId, String label, String color)? onAddLabel; // Callback to add label to column

  const ItemRow({
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
    this.onDragStarted,
    this.onDragEnded,
    this.nameColumnWidth,
    this.username,
    this.onAddLabel,
  });

  @override
  State<ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends State<ItemRow> {
  bool _hovering = false;
  bool _isEditingName = false;
  bool _isMenuOpen = false;
  late TextEditingController _nameController;
  final FocusNode _nameFocusNode = FocusNode();

  /// Check if current user can see the action menu
  /// Admin can always see, non-admin can see if they created the item
  bool get _canShowMenu {
    if (widget.isAdmin) return true;
    // Non-admin can see menu if they created the item
    if (widget.username != null && widget.item.createdBy == widget.username) {
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _nameFocusNode.addListener(() {
      if (!_nameFocusNode.hasFocus && _isEditingName) {
        _submitNameChange();
      }
    });
  }

  @override
  void didUpdateWidget(ItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.name != widget.item.name && !_isEditingName) {
      _nameController.text = widget.item.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      _isEditingName = true;
      _nameController.text = widget.item.name;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocusNode.requestFocus();
      _nameController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _nameController.text.length,
      );
    });
  }

  void _submitNameChange() {
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty && newName != widget.item.name) {
      widget.onRename?.call(newName);
    }
    setState(() => _isEditingName = false);
  }

  /// Calculate the name column width based on custom width
  /// The actions column is now separate, so we don't subtract from name width
  double _getNameColumnWidth() {
    // Base width from nameColumnWidth or default
    // The actions column width is added separately by the caller
    return widget.nameColumnWidth ?? 300.0;
  }

  /// Get the width of the actions column (drag handle + more actions menu)
  /// Always returns 52.0 for consistent alignment with header
  static double getActionsColumnWidth(bool isAdmin, bool canShowMenu, {bool isDraggable = true}) {
    // Always use consistent width for alignment: 20 (drag) + 32 (menu space) = 52
    return 52.0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rowBgColor = isDark ? Theme.of(context).cardColor : Colors.white;
    final hoverColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50;
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    // Build accessibility label with item details
    final accessibilityLabel = 'Item: ${widget.item.name}${widget.isSelected ? ', selected' : ''}';

    return Semantics(
      label: accessibilityLabel,
      button: true,
      selected: widget.isSelected,
      hint: 'Double tap to open item details',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: InkWell(
          onTap: widget.onTap,
          child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                : _hovering
                    ? hoverColor
                    : rowBgColor,
            border: Border(
              bottom: BorderSide(color: borderColor),
              left: widget.isSelected
                  ? BorderSide(color: Theme.of(context).primaryColor, width: 3)
                  : BorderSide.none,
            ),
          ),
          child: Row(
            children: [
              // ==== ACTIONS COLUMN (Fixed width, separate from name) ====
              // This column contains drag handle + more actions menu
              // Having it as a separate fixed-width column fixes alignment issues
              SizedBox(
                width: getActionsColumnWidth(widget.isAdmin, _canShowMenu, isDraggable: widget.isDraggable),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle indicator (shown on hover when draggable - available to ALL users)
                    if (widget.isDraggable && _hovering)
                      MouseRegion(
                        cursor: SystemMouseCursors.grab,
                        child: Container(
                          width: 20,
                          height: 40,
                          alignment: Alignment.center,
                          child: Icon(Icons.drag_indicator, size: 16, color: Colors.grey.shade400),
                        ),
                      )
                    else if (widget.isDraggable)
                      const SizedBox(width: 20),

                    // Row actions menu area - always 32px wide for alignment
                    // Show menu button when user can interact, otherwise empty space
                    SizedBox(
                      width: 32,
                      child: (_canShowMenu && (_hovering || widget.isSelected || _isMenuOpen))
                          ? Listener(
                              // Block all pointer events from bubbling up to LongPressDraggable
                              onPointerDown: (event) {},
                              behavior: HitTestBehavior.opaque,
                              child: PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 18),
                                tooltip: 'More actions',
                                onOpened: () {
                                  setState(() => _isMenuOpen = true);
                                },
                                onCanceled: () {
                                  setState(() => _isMenuOpen = false);
                                },
                                onSelected: (action) {
                                  setState(() => _isMenuOpen = false);
                                  switch (action) {
                                    case 'rename':
                                      _startEditing();
                                      break;
                                    case 'delete':
                                      widget.onDelete();
                                      break;
                                    case 'duplicate':
                                      widget.onDuplicate();
                                      break;
                                    case 'move_to_board':
                                      widget.onMoveToBoard?.call();
                                      break;
                                    case 'move_to_group':
                                      widget.onMoveToGroup?.call();
                                      break;
                                    case 'manage_access':
                                      widget.onManageAccess?.call();
                                      break;
                                  }
                                },
                                itemBuilder: (context) => [
                                  // Rename - admin only
                                  if (widget.isAdmin)
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
                                  // Duplicate - admin only
                                  if (widget.isAdmin)
                                    const PopupMenuItem(
                                      value: 'duplicate',
                                      child: Row(
                                        children: [
                                          Icon(Icons.copy, size: 18),
                                          SizedBox(width: 8),
                                          Text('Duplicate'),
                                        ],
                                      ),
                                    ),
                                  // Move to Group - admin only
                                  if (widget.isAdmin && widget.onMoveToGroup != null)
                                    const PopupMenuItem(
                                      value: 'move_to_group',
                                      child: Row(
                                        children: [
                                          Icon(Icons.move_down, size: 18),
                                          SizedBox(width: 8),
                                          Text('Move to Group'),
                                        ],
                                      ),
                                    ),
                                  // Move to Board - admin only
                                  if (widget.isAdmin && widget.onMoveToBoard != null)
                                    const PopupMenuItem(
                                      value: 'move_to_board',
                                      child: Row(
                                        children: [
                                          Icon(Icons.drive_file_move_outline, size: 18),
                                          SizedBox(width: 8),
                                          Text('Move to Board'),
                                        ],
                                      ),
                                    ),
                                  // Manage Access - admin only
                                  if (widget.isAdmin && widget.onManageAccess != null)
                                    const PopupMenuItem(
                                      value: 'manage_access',
                                      child: Row(
                                        children: [
                                          Icon(Icons.person_add, size: 18, color: Colors.blue),
                                          SizedBox(width: 8),
                                          Text('Manage Access', style: TextStyle(color: Colors.blue)),
                                        ],
                                      ),
                                    ),
                                  if (widget.isAdmin) const PopupMenuDivider(),
                                  // Delete - admin or item creator
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
                            )
                          : null, // Empty space when menu not shown
                    ),
                  ],
                ),
              ),

              // ==== NAME COLUMN (Separate from actions) ====
              // Item name
              GestureDetector(
                onDoubleTap: widget.onRename != null ? _startEditing : null,
                child: Container(
                  width: _getNameColumnWidth(),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      // Subitem expand/collapse indicator
                      if (widget.item.hasSubitems)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            widget.isSelected ? Icons.expand_more : Icons.chevron_right,
                            size: 16,
                            color: widget.isSelected ? Theme.of(context).primaryColor : Colors.grey.shade400,
                          ),
                        ),
                      Expanded(
                        child: _isEditingName
                            ? TextField(
                                controller: _nameController,
                                focusNode: _nameFocusNode,
                                style: const TextStyle(fontSize: 13),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                                ),
                                onSubmitted: (_) => _submitNameChange(),
                              )
                            : Text(
                                widget.item.name,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                      // Subitem count badge
                      if (widget.item.hasSubitems && !widget.isSelected)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${widget.item.subitems.length}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Dynamic columns
              ...widget.columns.map((column) {
                final width = widget.columnWidths[column.key] ?? column.width.toDouble();
                final value = widget.item.columnValues[column.key];

                return Container(
                  width: width,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(color: Colors.grey.shade100),
                    ),
                  ),
                  child: _buildCell(column, value),
                );
              }),
            ],
          ),
        ),
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
          columnId: column.id,
          onChanged: (newValue) {
            widget.onValueChanged(column.key, newValue);
          },
          onAddLabel: widget.onAddLabel != null
              ? (label, color) => widget.onAddLabel!(column.id, label, color)
              : null,
        );

      case ColumnType.person:
      case ColumnType.technician:
        // 'created_by' column is read-only and shows who created the item
        final isCreatedByColumn = column.key == 'created_by';
        final personCell = PersonCell(
          value: value,
          onChanged: (newValue) {
            widget.onValueChanged(column.key, newValue);
          },
          readOnly: isCreatedByColumn,
          multiSelect: !isCreatedByColumn, // created_by is single, person allows multiple
        );
        // Center the created_by column content
        return isCreatedByColumn ? Center(child: personCell) : personCell;

      case ColumnType.date:
        return DateCell(
          value: value,
          onChanged: (newValue) {
            widget.onValueChanged(column.key, newValue);
          },
        );

      case ColumnType.checkbox:
        return Center(
          child: Checkbox(
            value: value == true || value == 1 || value == '1',
            onChanged: (newValue) {
              widget.onValueChanged(column.key, newValue);
            },
          ),
        );

      case ColumnType.priority:
        return _buildPriorityCell(value);

      case ColumnType.progress:
        return _buildProgressCell(value);

      case ColumnType.rating:
        return RatingCell(
          value: value,
          onChanged: (newValue) {
            widget.onValueChanged(column.key, newValue);
          },
        );

      case ColumnType.updateCounter:
        return _buildUpdateCounterCell(value);

      case ColumnType.number:
        return _buildNumberCell(column, value);

      case ColumnType.currency:
        return _buildCurrencyCell(column, value);

      case ColumnType.email:
        return _buildEmailCell(column, value);

      case ColumnType.phone:
        return _buildPhoneCell(column, value);

      case ColumnType.link:
        return _buildLinkCell(column, value);

      case ColumnType.tags:
        return _buildTagsCell(column, value);

      case ColumnType.dateRange:
        return _buildDateRangeCell(column, value);

      case ColumnType.timeTracking:
        return _buildTimeTrackingCell(column, value);

      case ColumnType.lastUpdated:
      case ColumnType.createdAt:
        return _buildReadOnlyDateCell(value);

      case ColumnType.file:
        return _buildFileCell(column, value);

      case ColumnType.location:
        return _buildLocationCell(column, value);

      default:
        return TextCell(
          value: value?.toString() ?? '',
          onChanged: (newValue) {
            widget.onValueChanged(column.key, newValue);
          },
        );
    }
  }

  Widget _buildUpdateCounterCell(dynamic value) {
    // Value should be a map like {'count': 5, 'unread': 2} or just an int
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
        child: Text(
          '-',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade400,
          ),
        ),
      );
    }

    // Green if all read (unread == 0), red if has unread
    final hasUnread = unread > 0;
    final color = hasUnread ? Colors.red : Colors.green;

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasUnread ? Icons.mark_chat_unread : Icons.mark_chat_read,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              hasUnread ? '$unread/$count' : '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityCell(dynamic value) {
    final priorities = {
      'critical': {'color': Colors.red, 'icon': Icons.flag},
      'high': {'color': Colors.orange, 'icon': Icons.flag},
      'medium': {'color': Colors.yellow.shade700, 'icon': Icons.flag_outlined},
      'low': {'color': Colors.green, 'icon': Icons.flag_outlined},
    };

    final priority = priorities[value?.toString().toLowerCase()];
    if (priority == null) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          priority['icon'] as IconData,
          size: 14,
          color: priority['color'] as Color,
        ),
        const SizedBox(width: 4),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 12,
            color: priority['color'] as Color,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCell(dynamic value) {
    final progress = (value is num ? value : double.tryParse(value?.toString() ?? '0') ?? 0).toDouble();
    final percentage = progress.clamp(0.0, 100.0);

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: percentage == 100
                      ? Colors.green
                      : percentage > 50
                          ? Colors.orange
                          : Colors.blue,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${percentage.toInt()}%',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildNumberCell(SundayColumn column, dynamic value) {
    final numValue = value is num ? value : double.tryParse(value?.toString() ?? '');
    final displayText = numValue != null
        ? (numValue == numValue.toInt() ? numValue.toInt().toString() : numValue.toStringAsFixed(2))
        : value?.toString() ?? '';

    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Text(
          displayText,
          style: const TextStyle(fontSize: 13, fontFeatures: [FontFeature.tabularFigures()]),
        ),
      ),
    );
  }

  Widget _buildCurrencyCell(SundayColumn column, dynamic value) {
    final numValue = value is num ? value : double.tryParse(value?.toString() ?? '');
    final displayText = numValue != null ? '\$${numValue.toStringAsFixed(2)}' : value?.toString() ?? '';

    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Text(
          displayText,
          style: TextStyle(
            fontSize: 13,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: numValue != null && numValue < 0 ? Colors.red : null,
          ),
        ),
      ),
    );
  }

  Widget _buildEmailCell(SundayColumn column, dynamic value) {
    final email = value?.toString() ?? '';
    if (email.isEmpty) return const SizedBox.shrink();

    return InkWell(
      onTap: () => _launchUrl('mailto:$email'),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.email_outlined, size: 14, color: Colors.blue.shade600),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              email,
              style: TextStyle(fontSize: 12, color: Colors.blue.shade600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneCell(SundayColumn column, dynamic value) {
    final phone = value?.toString() ?? '';
    if (phone.isEmpty) return const SizedBox.shrink();

    return InkWell(
      onTap: () => _launchUrl('tel:$phone'),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.phone_outlined, size: 14, color: Colors.green.shade600),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              phone,
              style: TextStyle(fontSize: 12, color: Colors.green.shade600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkCell(SundayColumn column, dynamic value) {
    final url = value?.toString() ?? '';
    if (url.isEmpty) return const SizedBox.shrink();

    // Extract display text (domain or short url)
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
          Icon(Icons.link, size: 14, color: Colors.blue.shade600),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              displayText,
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade600,
                decoration: TextDecoration.underline,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsCell(SundayColumn column, dynamic value) {
    List<String> tags = [];
    if (value is List) {
      tags = value.map((e) => e.toString()).toList();
    } else if (value is String && value.isNotEmpty) {
      tags = value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    if (tags.isEmpty) return const SizedBox.shrink();

    final displayTags = tags.take(3).toList();
    final hasMore = tags.length > 3;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...displayTags.map((tag) => Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              tag,
              style: TextStyle(fontSize: 10, color: Colors.blue.shade700),
            ),
          )),
          if (hasMore)
            Text(
              '+${tags.length - 3}',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
        ],
      ),
    );
  }

  Widget _buildDateRangeCell(SundayColumn column, dynamic value) {
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
        Icon(Icons.date_range, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          '$startDate → $endDate',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildTimeTrackingCell(SundayColumn column, dynamic value) {
    // Value could be minutes, hours, or a formatted string
    final minutes = value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

    if (minutes == 0) {
      return Text('-', style: TextStyle(color: Colors.grey.shade400));
    }

    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    final displayText = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.timer_outlined, size: 14, color: Colors.purple.shade400),
        const SizedBox(width: 4),
        Text(
          displayText,
          style: TextStyle(fontSize: 12, color: Colors.purple.shade600),
        ),
      ],
    );
  }

  Widget _buildReadOnlyDateCell(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return Text('-', style: TextStyle(color: Colors.grey.shade400));
    }

    String displayDate;
    try {
      final date = DateTime.parse(value.toString());
      displayDate = '${date.month}/${date.day}/${date.year}';
    } catch (_) {
      displayDate = value.toString();
    }

    return Text(
      displayDate,
      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
    );
  }

  Widget _buildFileCell(SundayColumn column, dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return Icon(Icons.attach_file, size: 16, color: Colors.grey.shade400);
    }

    // Value could be a filename or URL
    final filename = value.toString().split('/').last;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.attach_file, size: 14, color: Colors.blue.shade600),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            filename,
            style: TextStyle(fontSize: 12, color: Colors.blue.shade600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationCell(SundayColumn column, dynamic value) {
    final location = value?.toString() ?? '';
    if (location.isEmpty) return const SizedBox.shrink();

    return InkWell(
      onTap: () => _launchUrl('https://maps.google.com/?q=${Uri.encodeComponent(location)}'),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on_outlined, size: 14, color: Colors.red.shade400),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              location,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
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
