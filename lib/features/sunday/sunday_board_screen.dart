/// Sunday Board Screen
/// Main board view with table, kanban, calendar, and timeline views
/// Responsive design for desktop and mobile
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../app_theme.dart';
import 'models/sunday_models.dart';
import 'sunday_service.dart';
import 'widgets/group_widget.dart';
import 'widgets/draggable_item_row.dart';
import 'widgets/calendar_view.dart';
import 'widgets/kanban_view.dart';
import 'widgets/timeline_view.dart';
import 'widgets/item_detail_panel.dart';
import 'widgets/add_item_row.dart';
import 'widgets/column_header.dart';
import 'widgets/automation_panel.dart';
import 'widgets/activity_panel.dart';
import 'widgets/board_members_dialog.dart';
import 'widgets/group_members_dialog.dart';
import 'widgets/item_members_dialog.dart';
import 'widgets/subitem_row.dart';
import 'widgets/mobile/mobile_board_view.dart';
import 'widgets/mobile/mobile_kanban_view.dart';

enum BoardViewType { table, kanban, calendar, timeline }

/// Represents an undoable action for the Sunday board
class _UndoAction {
  final String description;
  final Future<void> Function() undo;

  _UndoAction({
    required this.description,
    required this.undo,
  });
}

class SundayBoardScreen extends StatefulWidget {
  final int boardId;
  final String username;
  final String role;
  final bool embedded;
  final VoidCallback? onBack;
  final VoidCallback? onBoardUpdated;

  const SundayBoardScreen({
    super.key,
    required this.boardId,
    required this.username,
    required this.role,
    this.embedded = false,
    this.onBack,
    this.onBoardUpdated,
  });

  @override
  State<SundayBoardScreen> createState() => _SundayBoardScreenState();
}

class _SundayBoardScreenState extends State<SundayBoardScreen> {
  SundayBoard? _board;
  bool _loading = true;
  String? _error;
  BoardViewType _viewType = BoardViewType.table;
  SundayItem? _selectedItem;
  bool _showAutomations = false;
  bool _showActivity = false;
  bool _isSundayAdmin = false;

  // Column widths for table view
  final Map<String, double> _columnWidths = {};

  // Resizable sidebar width (item detail panel)
  double _sidebarWidth = 400.0;
  static const double _minSidebarWidth = 300.0;
  static const double _maxSidebarWidth = 700.0;

  // Collapsed groups
  final Set<int> _collapsedGroups = {};

  // Live refresh timer (5 seconds for near real-time updates)
  Timer? _refreshTimer;
  static const _refreshInterval = Duration(seconds: 5);
  String? _lastBoardHash; // Track changes to avoid unnecessary re-renders

  // Editing state - pause auto-refresh when user is actively editing
  bool _isEditing = false;
  Timer? _editingDebounceTimer;
  static const _editingDebounceDelay = Duration(milliseconds: 500);

  // Debounce timers for column value updates
  final Map<String, Timer> _valueUpdateDebounceTimers = {};
  final Map<String, dynamic> _pendingValueUpdates = {};
  static const _valueUpdateDebounceDelay = Duration(milliseconds: 300);

  // Undo stack for item operations
  final List<_UndoAction> _undoStack = [];
  static const _maxUndoStackSize = 20;

  // Bulk selection
  final Set<int> _selectedItemIds = {};
  bool _isBulkSelecting = false;

  // Filter state
  String _searchQuery = '';
  final Set<String> _personFilter = {}; // Filter by assigned person names
  final List<ColumnFilter> _columnFilters = []; // Column-based filters
  String? _sortColumn; // Column key to sort by
  bool _sortAscending = true;
  final Set<String> _hiddenColumns = {}; // Hidden column keys
  String? _groupByColumn; // Column key to group by (null = default groups)

  @override
  void initState() {
    super.initState();
    _checkSundayAdmin();
    _loadBoard();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _editingDebounceTimer?.cancel();
    // Cancel all pending value update timers
    for (final timer in _valueUpdateDebounceTimers.values) {
      timer.cancel();
    }
    _valueUpdateDebounceTimers.clear();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      _silentRefresh();
    });
  }

  /// Pause auto-refresh while user is editing
  void _setEditing(bool editing) {
    _isEditing = editing;
    _editingDebounceTimer?.cancel();
    if (!editing) {
      // Resume refresh after a delay when editing stops
      _editingDebounceTimer = Timer(_editingDebounceDelay, () {
        if (mounted) {
          _silentRefresh();
        }
      });
    }
  }

  /// Generate a hash of board state to detect changes using proper deep comparison
  String _generateBoardHash(SundayBoard board) {
    final buffer = StringBuffer();

    // Hash columns
    for (final col in board.columns) {
      buffer.write('c${col.id}:${col.title}:${col.width}|');
    }

    // Hash groups and their items
    for (final group in board.groups) {
      buffer.write('g${group.id}:${group.title}:${group.color}[');
      for (final item in group.items) {
        buffer.write('i${item.id}:${item.name}:{');
        // Deep hash column values using JSON serialization for reliability
        final sortedKeys = item.columnValues.keys.toList()..sort();
        for (final key in sortedKeys) {
          final value = item.columnValues[key];
          buffer.write('$key=${jsonEncode(value)},');
        }
        buffer.write('}|');
      }
      buffer.write(']');
    }

    return buffer.toString().hashCode.toRadixString(36);
  }

  /// Refresh board data without showing loading indicator - only updates if data changed
  Future<void> _silentRefresh() async {
    // Skip refresh if user is actively editing or widget not mounted
    if (!mounted || _isEditing) return;

    try {
      final board = await SundayService.getBoard(widget.boardId, widget.username);
      if (board != null && mounted && !_isEditing) {
        final newHash = _generateBoardHash(board);
        // Only update state if board data actually changed
        if (newHash != _lastBoardHash) {
          _lastBoardHash = newHash;
          setState(() {
            _board = board;
            // Update column widths if new columns added
            for (final col in board.columns) {
              _columnWidths.putIfAbsent(col.key, () => col.width.toDouble());
            }
          });
        }
      }
    } catch (e) {
      // Silently ignore refresh errors
    }
  }

  /// Add a new label to a status/label column (board-specific)
  Future<void> _handleAddColumnLabel(int columnId, String label, String color) async {
    final newLabel = await SundayService.addColumnLabel(
      columnId: columnId,
      label: label,
      color: color,
      username: widget.username,
    );

    if (newLabel != null && mounted) {
      // Optimistic update - add the label to the column locally
      if (_board != null) {
        setState(() {
          final columnIndex = _board!.columns.indexWhere((c) => c.id == columnId);
          if (columnIndex != -1) {
            final column = _board!.columns[columnIndex];
            final updatedLabels = [...column.statusLabels, newLabel];
            final updatedColumn = column.copyWith(statusLabels: updatedLabels);
            _board = _board!.copyWith(
              columns: [
                ..._board!.columns.sublist(0, columnIndex),
                updatedColumn,
                ..._board!.columns.sublist(columnIndex + 1),
              ],
            );
          }
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Label "$label" added')),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to add label'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================
  // UNDO/REDO SUPPORT
  // ============================================

  /// Push an action to the undo stack
  void _pushUndo(_UndoAction action) {
    _undoStack.add(action);
    if (_undoStack.length > _maxUndoStackSize) {
      _undoStack.removeAt(0);
    }
  }

  /// Undo the last action
  // ignore: unused_element
  Future<void> _undo() async {
    if (_undoStack.isEmpty) return;

    final action = _undoStack.removeLast();
    await action.undo();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Undone: ${action.description}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Check if undo is available
  // ignore: unused_element
  bool get _canUndo => _undoStack.isNotEmpty;

  // ============================================
  // BULK SELECTION
  // ============================================

  /// Toggle bulk selection mode
  // ignore: unused_element
  void _toggleBulkSelection() {
    setState(() {
      _isBulkSelecting = !_isBulkSelecting;
      if (!_isBulkSelecting) {
        _selectedItemIds.clear();
      }
    });
  }

  /// Toggle item selection
  // ignore: unused_element
  void _toggleItemSelection(int itemId) {
    setState(() {
      if (_selectedItemIds.contains(itemId)) {
        _selectedItemIds.remove(itemId);
      } else {
        _selectedItemIds.add(itemId);
      }
    });
  }

  /// Select all items in a group
  // ignore: unused_element
  void _selectAllInGroup(int groupId) {
    final group = _board?.groups.firstWhere((g) => g.id == groupId);
    if (group != null) {
      setState(() {
        for (final item in group.items) {
          _selectedItemIds.add(item.id);
        }
      });
    }
  }

  /// Clear all selections
  // ignore: unused_element
  void _clearSelection() {
    setState(() {
      _selectedItemIds.clear();
    });
  }

  /// Bulk delete selected items
  // ignore: unused_element
  Future<void> _bulkDeleteItems() async {
    if (_selectedItemIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Items'),
        content: Text('Delete ${_selectedItemIds.length} selected items? This cannot be undone.'),
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

    if (confirm != true) return;

    // Store for undo
    final itemsToDelete = <SundayItem>[];
    final itemGroupMap = <int, int>{};
    for (final itemId in _selectedItemIds) {
      for (final group in _board!.groups) {
        final item = group.items.cast<SundayItem?>().firstWhere((i) => i?.id == itemId, orElse: () => null);
        if (item != null) {
          itemsToDelete.add(item);
          itemGroupMap[itemId] = group.id;
          break;
        }
      }
    }

    // Delete locally first
    final deletedIds = List<int>.from(_selectedItemIds);
    for (final itemId in deletedIds) {
      _deleteItemLocally(itemId);
    }
    _selectedItemIds.clear();

    // Sync with server
    int successCount = 0;
    for (final itemId in deletedIds) {
      final success = await SundayService.deleteItem(itemId, widget.username);
      if (success) successCount++;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted $successCount of ${deletedIds.length} items'),
          backgroundColor: successCount == deletedIds.length ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  /// Bulk move selected items to a different group
  // ignore: unused_element
  Future<void> _bulkMoveItems(int targetGroupId) async {
    if (_selectedItemIds.isEmpty) return;

    final itemIds = List<int>.from(_selectedItemIds);
    for (final itemId in itemIds) {
      await _moveItemToGroup(itemId, targetGroupId);
    }

    _selectedItemIds.clear();
    setState(() {});
  }

  // ============================================
  // DEBOUNCED VALUE UPDATES
  // ============================================

  /// Update a column value with debouncing to batch rapid edits
  // ignore: unused_element
  void _debouncedUpdateColumnValue(int itemId, String columnKey, dynamic value) {
    final key = '$itemId:$columnKey';

    // Cancel any existing timer for this cell
    _valueUpdateDebounceTimers[key]?.cancel();

    // Store the pending value
    _pendingValueUpdates[key] = value;

    // Update locally immediately for responsive UI
    _updateItemValueLocally(itemId, columnKey, value);

    // Set editing flag
    _setEditing(true);

    // Create debounce timer
    _valueUpdateDebounceTimers[key] = Timer(_valueUpdateDebounceDelay, () async {
      if (!mounted) return;

      final pendingValue = _pendingValueUpdates.remove(key);
      _valueUpdateDebounceTimers.remove(key);

      // Sync with server
      final result = await SundayService.updateColumnValueWithResult(
        itemId: itemId,
        columnKey: columnKey,
        value: pendingValue,
        username: widget.username,
      );

      if (!result.success && mounted) {
        // Show error with details from API
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Failed to update value'),
            backgroundColor: Colors.red,
          ),
        );
        // Revert the local change
        _silentRefresh();
      }

      _setEditing(false);
    });
  }

  Future<void> _checkSundayAdmin() async {
    if (SundayService.hasRoleBasedSundayAccess(widget.role)) {
      setState(() => _isSundayAdmin = true);
    }
    final hasDbAdmin = await SundayService.hasSundayAdminAccess(widget.username);
    if (hasDbAdmin && mounted) {
      setState(() => _isSundayAdmin = true);
    }
  }

  Future<void> _loadBoard() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Load saved preferences for this board
      final savedWidths = await SundayService.loadColumnWidths(widget.boardId);
      final savedViewType = await SundayService.loadViewType(widget.boardId);
      final savedCollapsedGroups = await SundayService.loadCollapsedGroups(widget.boardId);

      final board = await SundayService.getBoard(widget.boardId, widget.username);
      if (board != null) {
        _lastBoardHash = _generateBoardHash(board); // Set initial hash
        setState(() {
          _board = board;
          _loading = false;

          // Initialize column widths from saved preferences or defaults
          for (final col in board.columns) {
            _columnWidths[col.key] = savedWidths[col.key] ?? col.width.toDouble();
          }

          // Restore view type if saved
          if (savedViewType != null) {
            _viewType = BoardViewType.values.firstWhere(
              (v) => v.name == savedViewType,
              orElse: () => BoardViewType.table,
            );
          }

          // Restore collapsed groups
          _collapsedGroups.addAll(savedCollapsedGroups);
        });
      } else {
        setState(() {
          _error = 'Board not found';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading board: $e';
        _loading = false;
      });
    }
  }

  /// Save column widths when changed
  // ignore: unused_element
  void _onColumnWidthChanged(String columnKey, double newWidth) {
    _columnWidths[columnKey] = newWidth;
    // Debounce the save to avoid excessive writes
    SundayService.saveColumnWidths(widget.boardId, _columnWidths);
  }

  /// Save view type when changed
  void _onViewTypeChanged(BoardViewType newViewType) {
    setState(() => _viewType = newViewType);
    SundayService.saveViewType(widget.boardId, newViewType.name);
  }

  /// Save collapsed groups when changed
  // ignore: unused_element
  void _onGroupCollapsedChanged(int groupId, bool collapsed) {
    setState(() {
      if (collapsed) {
        _collapsedGroups.add(groupId);
      } else {
        _collapsedGroups.remove(groupId);
      }
    });
    SundayService.saveCollapsedGroups(widget.boardId, _collapsedGroups);
  }

  // ============================================
  // OPTIMISTIC UPDATE METHODS
  // These update the local state immediately without reloading
  // ============================================

  /// Update an item's column value locally (optimistic update)
  void _updateItemValueLocally(int itemId, String columnKey, dynamic value) {
    if (_board == null) return;

    setState(() {
      for (final group in _board!.groups) {
        final itemIndex = group.items.indexWhere((i) => i.id == itemId);
        if (itemIndex != -1) {
          // Create updated column values map
          final newColumnValues = Map<String, dynamic>.from(group.items[itemIndex].columnValues);
          newColumnValues[columnKey] = value;

          // Create updated item with new column values
          final updatedItem = group.items[itemIndex].copyWith(columnValues: newColumnValues);

          // Replace item in list
          group.items[itemIndex] = updatedItem;

          // Update selected item if it's the same one
          if (_selectedItem?.id == itemId) {
            _selectedItem = updatedItem;
          }
          break;
        }
      }
    });
  }

  /// Move an item to a different group locally (optimistic update)
  void _moveItemLocally(int itemId, int toGroupId) {
    if (_board == null) return;

    setState(() {
      SundayItem? itemToMove;
      // ignore: unused_local_variable
      int? fromGroupIndex;

      // Find and remove item from current group
      for (int gi = 0; gi < _board!.groups.length; gi++) {
        final itemIndex = _board!.groups[gi].items.indexWhere((i) => i.id == itemId);
        if (itemIndex != -1) {
          itemToMove = _board!.groups[gi].items.removeAt(itemIndex);
          fromGroupIndex = gi;  // Kept for potential undo functionality
          break;
        }
      }

      // Add item to target group
      if (itemToMove != null) {
        final toGroupIndex = _board!.groups.indexWhere((g) => g.id == toGroupId);
        if (toGroupIndex != -1) {
          // Update item's group_id
          final movedItem = itemToMove.copyWith(groupId: toGroupId);
          _board!.groups[toGroupIndex].items.add(movedItem);

          // Update selected item if needed
          if (_selectedItem?.id == itemId) {
            _selectedItem = movedItem;
          }
        }
      }
    });
  }

  /// Add a new item locally (optimistic update)
  void _addItemLocally(int groupId, SundayItem newItem) {
    if (_board == null) return;

    setState(() {
      final groupIndex = _board!.groups.indexWhere((g) => g.id == groupId);
      if (groupIndex != -1) {
        _board!.groups[groupIndex].items.add(newItem);
      }
    });
    // Notify parent to refresh sidebar (item count changed)
    widget.onBoardUpdated?.call();
  }

  /// Delete an item locally (optimistic update)
  void _deleteItemLocally(int itemId) {
    if (_board == null) return;

    setState(() {
      for (final group in _board!.groups) {
        final itemIndex = group.items.indexWhere((i) => i.id == itemId);
        if (itemIndex != -1) {
          group.items.removeAt(itemIndex);
          // Clear selection if deleted item was selected
          if (_selectedItem?.id == itemId) {
            _selectedItem = null;
          }
          break;
        }
      }
    });
    // Notify parent to refresh sidebar (item count changed)
    widget.onBoardUpdated?.call();
  }

  /// Update item name locally (optimistic update)
  void _updateItemNameLocally(int itemId, String newName) {
    if (_board == null) return;

    setState(() {
      for (final group in _board!.groups) {
        final itemIndex = group.items.indexWhere((i) => i.id == itemId);
        if (itemIndex != -1) {
          final updatedItem = group.items[itemIndex].copyWith(name: newName);
          group.items[itemIndex] = updatedItem;
          if (_selectedItem?.id == itemId) {
            _selectedItem = updatedItem;
          }
          break;
        }
      }
    });
  }

  /// Update group title locally (optimistic update)
  void _updateGroupLocally(int groupId, {String? title, String? color}) {
    if (_board == null) return;

    setState(() {
      final groupIndex = _board!.groups.indexWhere((g) => g.id == groupId);
      if (groupIndex != -1) {
        final group = _board!.groups[groupIndex];
        _board!.groups[groupIndex] = group.copyWith(
          title: title ?? group.title,
          color: color ?? group.color,
        );
      }
    });
  }

  /// Move item to a different group (drag & drop) with proper rollback support
  Future<void> _moveItemToGroup(int itemId, int targetGroupId) async {
    if (_board == null) return;

    // Find the item and its current group
    SundayItem? item;
    int? sourceGroupIndex;
    int? sourceGroupId;
    int? itemIndex;

    for (int gi = 0; gi < _board!.groups.length; gi++) {
      final idx = _board!.groups[gi].items.indexWhere((i) => i.id == itemId);
      if (idx != -1) {
        item = _board!.groups[gi].items[idx];
        sourceGroupIndex = gi;
        sourceGroupId = _board!.groups[gi].id;
        itemIndex = idx;
        break;
      }
    }

    if (item == null || sourceGroupIndex == null || itemIndex == null || sourceGroupId == null) return;

    // Don't move if already in target group
    if (sourceGroupId == targetGroupId) return;

    // Store original item for rollback
    final originalItem = item;
    final originalSourceGroupId = sourceGroupId;
    final originalPosition = itemIndex;

    // Optimistic update - move item locally
    setState(() {
      // Remove from source group
      _board!.groups[sourceGroupIndex!].items.removeAt(itemIndex!);

      // Add to target group
      final targetGroupIndex = _board!.groups.indexWhere((g) => g.id == targetGroupId);
      if (targetGroupIndex != -1) {
        final movedItem = item!.copyWith(groupId: targetGroupId);
        _board!.groups[targetGroupIndex].items.add(movedItem);

        // Update selected item if it was moved
        if (_selectedItem?.id == itemId) {
          _selectedItem = movedItem;
        }
      }
    });

    // Sync with server
    final result = await SundayService.moveItemWithResult(itemId, targetGroupId, widget.username);
    if (!result.success && mounted) {
      // Revert the specific move instead of full refresh
      setState(() {
        // Remove from target group
        final targetGroupIndex = _board!.groups.indexWhere((g) => g.id == targetGroupId);
        if (targetGroupIndex != -1) {
          _board!.groups[targetGroupIndex].items.removeWhere((i) => i.id == itemId);
        }

        // Add back to source group at original position
        final sourceIdx = _board!.groups.indexWhere((g) => g.id == originalSourceGroupId);
        if (sourceIdx != -1) {
          final insertPos = originalPosition.clamp(0, _board!.groups[sourceIdx].items.length);
          _board!.groups[sourceIdx].items.insert(insertPos, originalItem);

          // Update selected item if needed
          if (_selectedItem?.id == itemId) {
            _selectedItem = originalItem;
          }
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Failed to move item'),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      // Success - add to undo stack
      _pushUndo(_UndoAction(
        description: 'Move item "${originalItem.name}"',
        undo: () async {
          await _moveItemToGroup(itemId, originalSourceGroupId);
        },
      ));
    }
  }

  /// Reorder items within a group
  Future<void> _reorderItemsInGroup(int groupId, int oldIndex, int newIndex) async {
    if (_board == null) return;

    final groupIndex = _board!.groups.indexWhere((g) => g.id == groupId);
    if (groupIndex == -1) return;

    final items = _board!.groups[groupIndex].items;
    if (oldIndex < 0 || oldIndex >= items.length || newIndex < 0 || newIndex >= items.length) return;

    // Optimistic update
    setState(() {
      final item = items.removeAt(oldIndex);
      items.insert(newIndex, item);
    });

    // Get the new order of item IDs
    final itemIds = _board!.groups[groupIndex].items.map((i) => i.id).toList();

    // Sync with server
    final success = await SundayService.reorderItems(groupId, itemIds, widget.username);
    if (!success && mounted) {
      _silentRefresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to reorder items'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Reorder columns
  Future<void> _reorderColumns(int oldIndex, int newIndex) async {
    if (_board == null) return;

    if (oldIndex < 0 || oldIndex >= _board!.columns.length ||
        newIndex < 0 || newIndex >= _board!.columns.length) {
      return;
    }

    // Optimistic update
    setState(() {
      final column = _board!.columns.removeAt(oldIndex);
      _board!.columns.insert(newIndex, column);
    });

    // Get the new order of column IDs
    final columnIds = _board!.columns.map((c) => c.id).toList();

    // Sync with server
    final success = await SundayService.reorderColumns(widget.boardId, columnIds, widget.username);
    if (!success && mounted) {
      _silentRefresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to reorder columns'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Reorder groups
  Future<void> _reorderGroups(int oldIndex, int newIndex) async {
    if (_board == null) return;

    if (oldIndex < 0 || oldIndex >= _board!.groups.length ||
        newIndex < 0 || newIndex >= _board!.groups.length) {
      return;
    }

    // Optimistic update
    setState(() {
      final group = _board!.groups.removeAt(oldIndex);
      _board!.groups.insert(newIndex, group);
    });

    // Get the new order of group IDs
    final groupIds = _board!.groups.map((g) => g.id).toList();

    // Sync with server
    final success = await SundayService.reorderGroups(widget.boardId, groupIds, widget.username);
    if (!success && mounted) {
      _silentRefresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to reorder groups'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Add a new group locally (optimistic update)
  void _addGroupLocally(SundayGroup newGroup) {
    if (_board == null) return;

    setState(() {
      _board!.groups.add(newGroup);
    });
    // Notify parent to refresh sidebar (group count changed)
    widget.onBoardUpdated?.call();
  }

  /// Delete a group locally (optimistic update)
  void _deleteGroupLocally(int groupId) {
    if (_board == null) return;

    setState(() {
      _board!.groups.removeWhere((g) => g.id == groupId);
    });
    // Notify parent to refresh sidebar (group count changed)
    widget.onBoardUpdated?.call();
  }

  /// Add a new column locally (optimistic update)
  void _addColumnLocally(SundayColumn newColumn) {
    if (_board == null) return;

    setState(() {
      final newColumns = List<SundayColumn>.from(_board!.columns)..add(newColumn);
      _board = _board!.copyWith(columns: newColumns);
    });
  }

  /// Update a column locally (optimistic update)
  void _updateColumnLocally(int columnId, {String? title, int? width}) {
    if (_board == null) return;

    setState(() {
      final columnIndex = _board!.columns.indexWhere((c) => c.id == columnId);
      if (columnIndex != -1) {
        final column = _board!.columns[columnIndex];
        final newColumns = List<SundayColumn>.from(_board!.columns);
        newColumns[columnIndex] = column.copyWith(
          title: title ?? column.title,
          width: width ?? column.width,
        );
        _board = _board!.copyWith(columns: newColumns);
      }
    });
  }

  /// Delete a column locally (optimistic update)
  void _deleteColumnLocally(int columnId) {
    if (_board == null) return;

    setState(() {
      final newColumns = _board!.columns.where((c) => c.id != columnId).toList();
      _board = _board!.copyWith(columns: newColumns);
    });
  }

  /// Update board metadata locally (optimistic update)
  void _updateBoardLocally({String? name, String? description}) {
    if (_board == null) return;

    setState(() {
      _board = _board!.copyWith(
        name: name ?? _board!.name,
        description: description ?? _board!.description,
      );
    });
    // Notify parent to refresh sidebar (board name/description changed)
    widget.onBoardUpdated?.call();
  }

  void _handleBack() {
    if (widget.embedded && widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.pop(context);
    }
  }

  /// Check if we're on a mobile device based on screen width
  bool _isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  /// Filter items based on all active filters (search, person, column filters)
  List<SundayItem> _getFilteredItems(List<SundayItem> items) {
    return items.where((item) {
      // Search filter (matches name or any column value)
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final nameMatch = item.name.toLowerCase().contains(query);
        final columnMatch = item.columnValues.values.any(
          (v) => v?.toString().toLowerCase().contains(query) ?? false,
        );
        if (!nameMatch && !columnMatch) return false;
      }

      // Person filter
      if (_personFilter.isNotEmpty) {
        final assignedPeople = <String>[];
        // Check common person columns
        for (final key in ['person', 'assignee', 'assigned_to', 'technician']) {
          final val = item.columnValues[key];
          if (val != null) {
            if (val is List) {
              assignedPeople.addAll(val.map((e) => e.toString()));
            } else if (val is String && val.isNotEmpty) {
              assignedPeople.add(val);
            }
          }
        }
        // Also check any column that might be a person type
        if (_board != null) {
          for (final col in _board!.columns) {
            if (col.type == ColumnType.person || col.type == ColumnType.technician) {
              final val = item.columnValues[col.key];
              if (val != null) {
                if (val is List) {
                  assignedPeople.addAll(val.map((e) => e.toString()));
                } else if (val is String && val.isNotEmpty) {
                  assignedPeople.add(val);
                }
              }
            }
          }
        }
        if (!_personFilter.any((p) => assignedPeople.contains(p))) {
          return false;
        }
      }

      // Column-based filters
      for (final filter in _columnFilters) {
        if (!filter.matches(item)) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.grey.shade100;
    final isMobile = _isMobile(context);

    final content = Column(
      children: [
        // Board header (different for mobile vs desktop)
        isMobile ? _buildMobileHeader() : _buildHeader(),

        // Main content
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildErrorView()
                  : isMobile
                      ? _buildMobileContent()
                      : _buildContent(),
        ),
      ],
    );

    // When embedded, don't wrap in Scaffold
    if (widget.embedded) {
      return Container(
        color: backgroundColor,
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: content,
    );
  }

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerBgColor = isDark ? Theme.of(context).cardColor : Colors.white;
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: headerBgColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
            tooltip: 'Back to boards',
          ),
          const SizedBox(width: 8),

          // Board name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _board?.name ?? 'Loading...',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_board?.description != null && _board!.description!.isNotEmpty)
                  Text(
                    _board!.description!,
                    style: TextStyle(
                      fontSize: 12,
                      color: subtitleColor,
                    ),
                  ),
              ],
            ),
          ),

          // View switcher
          _buildViewSwitcher(),

          const SizedBox(width: 16),

          // Actions
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => setState(() {
              _showActivity = !_showActivity;
              if (_showActivity) _showAutomations = false;
            }),
            tooltip: 'Activity',
            color: _showActivity ? AppColors.accent : null,
          ),
          if (_isSundayAdmin) ...[
            IconButton(
              icon: const Icon(Icons.bolt),
              onPressed: () => setState(() {
                _showAutomations = !_showAutomations;
                if (_showAutomations) _showActivity = false;
              }),
              tooltip: 'Automations',
              color: _showAutomations ? AppColors.accent : null,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: _handleMenuAction,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'settings',
                  child: ListTile(
                    leading: Icon(Icons.settings),
                    title: Text('Board Settings'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'members',
                  child: ListTile(
                    leading: Icon(Icons.people),
                    title: Text('Manage Members'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'export',
                  child: ListTile(
                    leading: Icon(Icons.download),
                    title: Text('Export'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'import',
                  child: ListTile(
                    leading: Icon(Icons.upload),
                    title: Text('Import'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'save_template',
                  child: ListTile(
                    leading: Icon(Icons.save_alt),
                    title: Text('Save as Template'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title: Text('Delete Board', style: TextStyle(color: Colors.red)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Mobile-optimized header with compact layout
  Widget _buildMobileHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerBgColor = isDark ? Theme.of(context).cardColor : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: headerBgColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top row: back button, board name, menu
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _handleBack,
                iconSize: 22,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              Expanded(
                child: Text(
                  _board?.name ?? 'Loading...',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Refresh button
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadBoard,
                iconSize: 20,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ],
          ),
          // View switcher (compact for mobile - only Table and Kanban)
          _buildMobileViewSwitcher(),
        ],
      ),
    );
  }

  /// Mobile-optimized view switcher with only Table and Kanban options
  Widget _buildMobileViewSwitcher() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SegmentedButton<BoardViewType>(
        segments: const [
          ButtonSegment(
            value: BoardViewType.table,
            icon: Icon(Icons.table_chart, size: 16),
            label: Text('Table'),
          ),
          ButtonSegment(
            value: BoardViewType.kanban,
            icon: Icon(Icons.view_kanban, size: 16),
            label: Text('Kanban'),
          ),
          ButtonSegment(
            value: BoardViewType.calendar,
            icon: Icon(Icons.calendar_month, size: 16),
            label: Text('Calendar'),
          ),
        ],
        selected: {_viewType == BoardViewType.timeline ? BoardViewType.table : _viewType},
        onSelectionChanged: (selected) {
          _onViewTypeChanged(selected.first);
        },
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12)),
        ),
      ),
    );
  }

  /// Mobile-optimized content view
  Widget _buildMobileContent() {
    if (_board == null) return const SizedBox.shrink();

    switch (_viewType) {
      case BoardViewType.table:
        return MobileBoardView(
          board: _board!,
          username: widget.username,
          role: widget.role,
          isSundayAdmin: _isSundayAdmin,
          onRefresh: _loadBoard,
          onValueChanged: (itemId, columnKey, value) async {
            _updateItemValueLocally(itemId, columnKey, value);
            await SundayService.updateColumnValue(
              itemId: itemId,
              columnKey: columnKey,
              value: value,
              username: widget.username,
            );
          },
          onAddItem: (groupId, name, values) async {
            final newItemId = await SundayService.createItem(
              boardId: widget.boardId,
              groupId: groupId,
              name: name,
              username: widget.username,
              columnValues: values,
            );
            if (newItemId != null) {
              final tempItem = SundayItem(
                id: newItemId,
                boardId: widget.boardId,
                groupId: groupId,
                name: name,
                createdBy: widget.username,
                createdAt: DateTime.now(),
                columnValues: values ?? {},
              );
              _addItemLocally(groupId, tempItem);
            }
          },
          onDeleteItem: (itemId) => _confirmDeleteItemById(itemId),
          onRenameItem: (itemId, newName) async {
            _updateItemNameLocally(itemId, newName);
            await SundayService.renameItem(
              itemId: itemId,
              name: newName,
              username: widget.username,
            );
          },
        );
      case BoardViewType.kanban:
        return MobileKanbanView(
          board: _board!,
          username: widget.username,
          onItemTap: (item) => setState(() => _selectedItem = item),
          onItemMoved: _moveItemToGroup,
          onAddItem: (groupId, name) async {
            final newItemId = await SundayService.createItem(
              boardId: widget.boardId,
              groupId: groupId,
              name: name,
              username: widget.username,
            );
            if (newItemId != null) {
              final tempItem = SundayItem(
                id: newItemId,
                boardId: widget.boardId,
                groupId: groupId,
                name: name,
                createdBy: widget.username,
                createdAt: DateTime.now(),
              );
              _addItemLocally(groupId, tempItem);
            }
          },
          onRefresh: _loadBoard,
        );
      case BoardViewType.calendar:
        return _buildCalendarView();
      case BoardViewType.timeline:
        // Timeline not optimized for mobile, fallback to table
        return MobileBoardView(
          board: _board!,
          username: widget.username,
          role: widget.role,
          isSundayAdmin: _isSundayAdmin,
          onRefresh: _loadBoard,
          onValueChanged: (itemId, columnKey, value) async {
            _updateItemValueLocally(itemId, columnKey, value);
            await SundayService.updateColumnValue(
              itemId: itemId,
              columnKey: columnKey,
              value: value,
              username: widget.username,
            );
          },
          onAddItem: (groupId, name, values) async {
            final newItemId = await SundayService.createItem(
              boardId: widget.boardId,
              groupId: groupId,
              name: name,
              username: widget.username,
              columnValues: values,
            );
            if (newItemId != null) {
              final tempItem = SundayItem(
                id: newItemId,
                boardId: widget.boardId,
                groupId: groupId,
                name: name,
                createdBy: widget.username,
                createdAt: DateTime.now(),
                columnValues: values ?? {},
              );
              _addItemLocally(groupId, tempItem);
            }
          },
          onDeleteItem: (itemId) => _confirmDeleteItemById(itemId),
          onRenameItem: (itemId, newName) async {
            _updateItemNameLocally(itemId, newName);
            await SundayService.renameItem(
              itemId: itemId,
              name: newName,
              username: widget.username,
            );
          },
        );
    }
  }

  /// Helper to delete item by ID (for mobile view callbacks)
  Future<void> _confirmDeleteItemById(int itemId) async {
    // Find the item
    SundayItem? item;
    for (final group in _board!.groups) {
      item = group.items.cast<SundayItem?>().firstWhere((i) => i?.id == itemId, orElse: () => null);
      if (item != null) break;
    }
    if (item != null) {
      _confirmDeleteItem(item);
    }
  }

  Widget _buildViewSwitcher() {
    return SegmentedButton<BoardViewType>(
      segments: const [
        ButtonSegment(
          value: BoardViewType.table,
          icon: Icon(Icons.table_chart, size: 18),
          label: Text('Table'),
        ),
        ButtonSegment(
          value: BoardViewType.kanban,
          icon: Icon(Icons.view_kanban, size: 18),
          label: Text('Kanban'),
        ),
        ButtonSegment(
          value: BoardViewType.calendar,
          icon: Icon(Icons.calendar_month, size: 18),
          label: Text('Calendar'),
        ),
        ButtonSegment(
          value: BoardViewType.timeline,
          icon: Icon(Icons.timeline, size: 18),
          label: Text('Timeline'),
        ),
      ],
      selected: {_viewType},
      onSelectionChanged: (selected) {
        _onViewTypeChanged(selected.first);
      },
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            _error ?? 'Unknown error',
            style: TextStyle(color: Colors.red.shade700, fontSize: 16),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loadBoard,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Row(
      children: [
        // Main view
        Expanded(
          child: _buildMainView(),
        ),

        // Item detail panel with resize handle
        if (_selectedItem != null) ...[
          // Resize handle
          _buildResizeHandle(),
          // Panel
          SizedBox(
            width: _sidebarWidth,
            child: ItemDetailPanel(
              item: _selectedItem!,
              columns: _board?.columns ?? [],
              username: widget.username,
              onClose: () => setState(() => _selectedItem = null),
              onUpdate: (columnKey, value) async {
                // Optimistic update - update UI immediately
                _updateItemValueLocally(_selectedItem!.id, columnKey, value);
                // Sync with server in background
                await SundayService.updateColumnValue(
                  itemId: _selectedItem!.id,
                  columnKey: columnKey,
                  value: value,
                  username: widget.username,
                );
              },
              onRename: (newName) async {
                // Optimistic update - update UI immediately
                _updateItemNameLocally(_selectedItem!.id, newName);
                // Sync with server in background
                await SundayService.renameItem(
                  itemId: _selectedItem!.id,
                  name: newName,
                  username: widget.username,
                );
              },
              onPostUpdate: (body) async {
                await SundayService.postUpdate(
                  itemId: _selectedItem!.id,
                  body: body,
                  username: widget.username,
                );
              },
            ),
          ),
        ],

        // Automations panel
        if (_showAutomations)
          SizedBox(
            width: 350,
            child: AutomationPanel(
              boardId: widget.boardId,
              username: widget.username,
              board: _board,
              onClose: () => setState(() => _showAutomations = false),
            ),
          ),

        // Activity panel
        if (_showActivity)
          SizedBox(
            width: 350,
            child: ActivityPanel(
              boardId: widget.boardId,
              username: widget.username,
              onClose: () => setState(() => _showActivity = false),
            ),
          ),
      ],
    );
  }

  /// Build a drag handle for resizing the sidebar
  Widget _buildResizeHandle() {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          setState(() {
            // Dragging left (negative delta) should make sidebar wider
            // Dragging right (positive delta) should make sidebar narrower
            _sidebarWidth = (_sidebarWidth - details.delta.dx)
                .clamp(_minSidebarWidth, _maxSidebarWidth);
          });
        },
        child: Container(
          width: 6,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build the filter toolbar with Search only
  Widget _buildFilterToolbar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final toolbarBg = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final activeColor = Theme.of(context).primaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: toolbarBg,
        border: Border(
          bottom: BorderSide(color: borderColor),
        ),
      ),
      child: Row(
        children: [
          // Search field
          SizedBox(
            width: 200,
            height: 32,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () => setState(() => _searchQuery = ''),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: activeColor),
                ),
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  /// Clear all active filters
  void _clearAllFilters() {
    setState(() {
      _searchQuery = '';
      _personFilter.clear();
      _columnFilters.clear();
      _sortColumn = null;
      _sortAscending = true;
      _hiddenColumns.clear();
      _groupByColumn = null;
    });
  }

  /// Show person filter dialog
  void _showPersonFilterDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _PersonFilterDialog(
        currentSelection: _personFilter,
        username: widget.username,
        onApply: (selected) {
          setState(() {
            _personFilter.clear();
            _personFilter.addAll(selected);
          });
          Navigator.pop(ctx);
        },
      ),
    );
  }

  /// Show advanced filter dialog
  void _showFilterDialog() {
    if (_board == null) return;

    showDialog(
      context: context,
      builder: (ctx) => _ColumnFilterDialog(
        board: _board!,
        currentFilters: _columnFilters,
        onApply: (filters) {
          setState(() {
            _columnFilters.clear();
            _columnFilters.addAll(filters);
          });
          Navigator.pop(ctx);
        },
      ),
    );
  }

  /// Show sort dialog
  void _showSortDialog() {
    if (_board == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sort by'),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Name column option
              ListTile(
                leading: const Icon(Icons.text_fields),
                title: const Text('Name'),
                trailing: _sortColumn == '__name__'
                    ? Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                    : null,
                selected: _sortColumn == '__name__',
                onTap: () {
                  setState(() {
                    if (_sortColumn == '__name__') {
                      _sortAscending = !_sortAscending;
                    } else {
                      _sortColumn = '__name__';
                      _sortAscending = true;
                    }
                  });
                  Navigator.pop(ctx);
                },
              ),
              const Divider(),
              // Other columns
              ..._board!.columns.where((c) => !c.isHidden).map((col) => ListTile(
                leading: Icon(_getColumnIcon(col.type)),
                title: Text(col.title),
                trailing: _sortColumn == col.key
                    ? Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                    : null,
                selected: _sortColumn == col.key,
                onTap: () {
                  setState(() {
                    if (_sortColumn == col.key) {
                      _sortAscending = !_sortAscending;
                    } else {
                      _sortColumn = col.key;
                      _sortAscending = true;
                    }
                  });
                  Navigator.pop(ctx);
                },
              )),
            ],
          ),
        ),
        actions: [
          if (_sortColumn != null)
            TextButton(
              onPressed: () {
                setState(() {
                  _sortColumn = null;
                  _sortAscending = true;
                });
                Navigator.pop(ctx);
              },
              child: const Text('Clear sort'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// Show hide columns dialog
  void _showHideColumnsDialog() {
    if (_board == null) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Show/Hide Columns'),
          content: SizedBox(
            width: 300,
            height: 400,
            child: ListView(
              children: _board!.columns.map((col) {
                final isHidden = _hiddenColumns.contains(col.key);
                return CheckboxListTile(
                  title: Text(col.title),
                  secondary: Icon(_getColumnIcon(col.type)),
                  value: !isHidden,
                  onChanged: (show) {
                    setDialogState(() {
                      if (show == true) {
                        _hiddenColumns.remove(col.key);
                      } else {
                        _hiddenColumns.add(col.key);
                      }
                    });
                    setState(() {}); // Update main UI
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _hiddenColumns.clear());
                setDialogState(() {});
              },
              child: const Text('Show all'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  /// Show group by dialog
  void _showGroupByDialog() {
    if (_board == null) return;

    // Get columns that make sense for grouping (status, person, dropdown, etc.)
    final groupableColumns = _board!.columns.where((c) =>
      c.type == ColumnType.status ||
      c.type == ColumnType.person ||
      c.type == ColumnType.dropdown ||
      c.type == ColumnType.priority
    ).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Group by'),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Default groups option
              ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('Default Groups'),
                selected: _groupByColumn == null,
                onTap: () {
                  setState(() => _groupByColumn = null);
                  Navigator.pop(ctx);
                },
              ),
              const Divider(),
              // Groupable columns
              if (groupableColumns.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No groupable columns found. Add Status, Person, or Dropdown columns to enable grouping.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                ...groupableColumns.map((col) => ListTile(
                  leading: Icon(_getColumnIcon(col.type)),
                  title: Text(col.title),
                  selected: _groupByColumn == col.key,
                  onTap: () {
                    setState(() => _groupByColumn = col.key);
                    Navigator.pop(ctx);
                  },
                )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildMainView() {
    switch (_viewType) {
      case BoardViewType.table:
        return _buildTableView();
      case BoardViewType.kanban:
        return _buildKanbanView();
      case BoardViewType.calendar:
        return _buildCalendarView();
      case BoardViewType.timeline:
        return _buildTimelineView();
    }
  }

  Widget _buildKanbanView() {
    if (_board == null) return const SizedBox.shrink();

    return KanbanView(
      board: _board!,
      username: widget.username,
      onItemTap: (item) => setState(() => _selectedItem = item),
      onItemMoved: (itemId, groupId) async {
        // Optimistic update - move item locally first
        _moveItemLocally(itemId, groupId);
        // Sync with server in background
        await SundayService.moveItem(itemId, groupId, widget.username);
      },
      onAddItem: (groupId, name) async {
        // Create on server first to get ID, then add locally
        final newItemId = await SundayService.createItem(
          boardId: widget.boardId,
          groupId: groupId,
          name: name,
          username: widget.username,
        );
        if (newItemId != null) {
          // Add a temporary item locally while silent refresh catches up
          final tempItem = SundayItem(
            id: newItemId,
            boardId: widget.boardId,
            groupId: groupId,
            name: name,
            createdBy: widget.username,
            createdAt: DateTime.now(),
          );
          _addItemLocally(groupId, tempItem);
        }
      },
      onRefresh: _loadBoard,
    );
  }

  Widget _buildTableView() {
    if (_board == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Filter out hidden columns (both from column settings and user filter)
    final visibleColumns = _board!.columns.where((c) =>
      !c.isHidden && !_hiddenColumns.contains(c.key)
    ).toList();
    final tableBgColor = isDark ? Theme.of(context).cardColor : Colors.white;
    final headerBgColor = isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.grey.shade50;
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    return Container(
      color: tableBgColor,
      child: Column(
        children: [
          // Filter toolbar
          _buildFilterToolbar(),

          // Column headers
          Container(
            decoration: BoxDecoration(
              color: headerBgColor,
              border: Border(
                bottom: BorderSide(color: borderColor),
              ),
            ),
            child: Row(
              children: [
                // Name column header (fixed, not reorderable, but resizable)
                // Width includes space for drag handle + menu in item rows
                _buildNameColumnHeader(borderColor),
                // Reorderable column headers
                if (_isSundayAdmin && visibleColumns.isNotEmpty)
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ReorderableListView(
                        scrollDirection: Axis.horizontal,
                        buildDefaultDragHandles: false,
                        onReorder: (oldIndex, newIndex) {
                          if (newIndex > oldIndex) newIndex--;
                          _reorderColumns(oldIndex, newIndex);
                        },
                        children: [
                          for (int i = 0; i < visibleColumns.length; i++)
                            ReorderableDragStartListener(
                              key: ValueKey('col_${visibleColumns[i].id}'),
                              index: i,
                              child: ColumnHeader(
                                column: visibleColumns[i],
                                width: _columnWidths[visibleColumns[i].key] ?? 150,
                                isDraggable: true,
                                onWidthChanged: (width) {
                                  setState(() => _columnWidths[visibleColumns[i].key] = width);
                                },
                                onSettings: () {
                                  _showColumnSettings(visibleColumns[i]);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  )
                else
                  // Non-admin: static column headers
                  ...visibleColumns.map((col) => ColumnHeader(
                        column: col,
                        width: _columnWidths[col.key] ?? 150,
                        onWidthChanged: (width) {
                          setState(() => _columnWidths[col.key] = width);
                        },
                        onSettings: () {},
                      )),
                // Add column button
                if (_isSundayAdmin)
                  IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    onPressed: _showAddColumnDialog,
                    tooltip: 'Add column',
                  ),
              ],
            ),
          ),

          // Groups and items
          Expanded(
            child: _isSundayAdmin
                ? _buildReorderableGroupsList(visibleColumns)
                : ListView.builder(
                    itemCount: _board!.groups.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _board!.groups.length) {
                        return const SizedBox.shrink();
                      }
                      final group = _board!.groups[index];
                      return _buildGroupWidget(group, visibleColumns, index);
                    },
                  ),
          ),
          // Add group button (only for admin, outside the list to avoid reorder issues)
          if (_isSundayAdmin)
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton.icon(
                onPressed: _showAddGroupDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Group'),
              ),
            ),
        ],
      ),
    );
  }

  /// Build a reorderable list of groups for admin users
  Widget _buildReorderableGroupsList(List<SundayColumn> visibleColumns) {
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      itemCount: _board!.groups.length,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex--;
        _reorderGroups(oldIndex, newIndex);
      },
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final animValue = Curves.easeInOut.transform(animation.value);
            final elevation = lerpDouble(0, 6, animValue)!;
            return Material(
              elevation: elevation,
              color: Colors.transparent,
              shadowColor: Colors.black26,
              child: child,
            );
          },
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final group = _board!.groups[index];
        return ReorderableDragStartListener(
          key: ValueKey('group_reorder_${group.id}'),
          index: index,
          child: _buildGroupWidget(group, visibleColumns, index),
        );
      },
    );
  }

  /// Build a single group widget with all its items
  Widget _buildGroupWidget(SundayGroup group, List<SundayColumn> visibleColumns, int index) {
    final isCollapsed = _collapsedGroups.contains(group.id);

    // Filter items based on active filters
    final filteredItems = _getFilteredItems(group.items);

    // Build list of items with drop targets for reordering
    final List<Widget> itemWidgets = [];

    if (!isCollapsed) {
      for (int i = 0; i < filteredItems.length; i++) {
        final item = filteredItems[i];

        // Add drop target before each item
        itemWidgets.add(_buildItemDropTarget(group.id, i));

        // Add the draggable item row
        itemWidgets.add(
          DraggableItemRow(
            key: ValueKey('item_${item.id}'),
            item: item,
            columns: visibleColumns,
            columnWidths: _columnWidths,
            isSelected: _selectedItem?.id == item.id,
            isAdmin: _isSundayAdmin,
            isDraggable: true, // Allow all users to drag
            nameColumnWidth: _columnWidths['__name__'] ?? 300.0,
            username: widget.username,
            onTap: () {
              setState(() => _selectedItem = item);
            },
            onValueChanged: (columnKey, value) async {
              // Optimistic update - update UI immediately
              _updateItemValueLocally(item.id, columnKey, value);
              // Sync with server in background
              await SundayService.updateColumnValue(
                itemId: item.id,
                columnKey: columnKey,
                value: value,
                username: widget.username,
              );
            },
            onDelete: () => _confirmDeleteItem(item),
            onRename: (newName) async {
              // Optimistic update - update UI immediately
              _updateItemNameLocally(item.id, newName);
              // Sync with server in background
              await SundayService.renameItem(
                itemId: item.id,
                name: newName,
                username: widget.username,
              );
            },
            onDuplicate: () async {
              final newItemId = await SundayService.duplicateItem(item.id, widget.username);
              if (newItemId != null) {
                final duplicatedItem = item.copyWith(
                  id: newItemId,
                  name: '${item.name} (Copy)',
                  createdAt: DateTime.now(),
                );
                _addItemLocally(item.groupId, duplicatedItem);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Item "${item.name}" duplicated')),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to duplicate item'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            onMoveToBoard: () => _showMoveToBoardDialog(item),
            onMoveToGroup: () => _showMoveToGroupDialog(item),
            onManageAccess: _isSundayAdmin ? () => _showItemAccessDialog(item) : null,
            onAddLabel: _handleAddColumnLabel,
          ),
        );

        // Subitems under this item (only show when parent is selected)
        if (_selectedItem?.id == item.id && item.subitems.isNotEmpty) {
          for (final subitem in item.subitems) {
            itemWidgets.add(
              SubitemRow(
                subitem: subitem,
                columns: visibleColumns,
                columnWidths: _columnWidths,
                username: widget.username,
                onUpdated: _silentRefresh,
                onDeleted: _silentRefresh,
                nameColumnWidth: _columnWidths['__name__'] ?? 300.0,
                isAdmin: _isSundayAdmin,
                canShowMenu: true,
              ),
            );
          }
        }
      }

      // Add final drop target after all items
      itemWidgets.add(_buildItemDropTarget(group.id, group.items.length));

      // Add item row
      itemWidgets.add(
        AddItemRow(
          columns: visibleColumns,
          columnWidths: _columnWidths,
          nameColumnWidth: _columnWidths['__name__'] ?? 300.0,
          isAdmin: _isSundayAdmin,
          canShowMenu: true, // Users can add items, so they can show menu
          onAdd: (name, values) async {
            final newItemId = await SundayService.createItem(
              boardId: widget.boardId,
              groupId: group.id,
              name: name,
              username: widget.username,
              columnValues: values,
            );
            if (newItemId != null) {
              final tempItem = SundayItem(
                id: newItemId,
                boardId: widget.boardId,
                groupId: group.id,
                name: name,
                createdBy: widget.username,
                createdAt: DateTime.now(),
                columnValues: values,
              );
              _addItemLocally(group.id, tempItem);
            }
          },
        ),
      );
    }

    // Show filtered count vs total when filters are active
    final hasFilters = _searchQuery.isNotEmpty || _personFilter.isNotEmpty || _columnFilters.isNotEmpty;
    final displayItemCount = hasFilters ? filteredItems.length : group.items.length;

    final groupWidget = GroupWidget(
      key: ValueKey('group_content_${group.id}'),
      group: group,
      isCollapsed: isCollapsed,
      itemCount: displayItemCount,
      totalItemCount: hasFilters ? group.items.length : null,
      isAdmin: _isSundayAdmin,
      onToggleCollapse: () {
        setState(() {
          if (isCollapsed) {
            _collapsedGroups.remove(group.id);
          } else {
            _collapsedGroups.add(group.id);
          }
        });
      },
      onRename: (name) async {
        // Optimistic update
        _updateGroupLocally(group.id, title: name);
        // Sync with server
        await SundayService.updateGroup(
          groupId: group.id,
          username: widget.username,
          title: name,
        );
      },
      onChangeColor: (color) async {
        // Optimistic update
        _updateGroupLocally(group.id, color: color);
        // Sync with server
        await SundayService.updateGroup(
          groupId: group.id,
          username: widget.username,
          color: color,
        );
      },
      onDelete: () => _confirmDeleteGroup(group),
      onManageAccess: _isSundayAdmin ? () => _showGroupAccessDialog(group) : null,
      isDragTarget: false, // We handle drops at item level now
      onItemDropped: (itemId) => _moveItemToGroup(itemId, group.id),
      children: itemWidgets,
    );

    return groupWidget;
  }

  /// Build a drop target between items for reordering
  Widget _buildItemDropTarget(int groupId, int targetIndex) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        final itemId = details.data;
        _handleItemDrop(itemId, groupId, targetIndex);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: isHovering ? 40 : 4,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isHovering
                ? Theme.of(context).primaryColor.withValues(alpha: 0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: isHovering
                ? Border.all(color: Theme.of(context).primaryColor, width: 2)
                : null,
          ),
          child: isHovering
              ? Center(
                  child: Text(
                    'Drop here',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  /// Handle item drop for both reordering within group and moving between groups
  void _handleItemDrop(int itemId, int targetGroupId, int targetIndex) {
    if (_board == null) return;

    // Find the item and its current group
    SundayItem? item;
    int? sourceGroupId;
    int? sourceIndex;

    for (final group in _board!.groups) {
      final idx = group.items.indexWhere((i) => i.id == itemId);
      if (idx != -1) {
        item = group.items[idx];
        sourceGroupId = group.id;
        sourceIndex = idx;
        break;
      }
    }

    if (item == null || sourceGroupId == null || sourceIndex == null) return;

    if (sourceGroupId == targetGroupId) {
      // Reordering within the same group
      // Adjust target index if moving down within the same group
      int adjustedIndex = targetIndex;
      if (sourceIndex < targetIndex) {
        adjustedIndex = targetIndex - 1;
      }

      if (sourceIndex != adjustedIndex) {
        _reorderItemsInGroup(targetGroupId, sourceIndex, adjustedIndex);
      }
    } else {
      // Moving to a different group
      _moveItemToGroup(itemId, targetGroupId);
    }
  }

  Widget _buildCalendarView() {
    if (_board == null) return const SizedBox.shrink();

    return CalendarView(
      board: _board!,
      username: widget.username,
      onItemTap: (item) => setState(() => _selectedItem = item),
      onRefresh: _loadBoard,
    );
  }

  Widget _buildTimelineView() {
    if (_board == null) return const SizedBox.shrink();

    return TimelineView(
      board: _board!,
      username: widget.username,
      onItemTap: (item) => setState(() => _selectedItem = item),
      onRefresh: _loadBoard,
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'settings':
        _showBoardSettings();
        break;
      case 'members':
        _showBoardMembers();
        break;
      case 'export':
        _exportBoard();
        break;
      case 'import':
        _importData();
        break;
      case 'save_template':
        _showSaveTemplateDialog();
        break;
      case 'delete':
        _confirmDeleteBoard();
        break;
    }
  }

  void _showBoardMembers() {
    if (_board == null) return;
    showDialog(
      context: context,
      builder: (ctx) => BoardMembersDialog(
        boardId: widget.boardId,
        boardName: _board!.name,
        username: widget.username,
      ),
    );
  }

  void _showAddColumnDialog() async {
    final titleController = TextEditingController();
    ColumnType selectedType = ColumnType.text;
    String? selectedLabelCategory; // For custom label columns
    String? selectedPredefinedKey; // For columns with predefined keys like 'created_by'

    // Base column types
    final baseColumnTypes = [
      {'type': ColumnType.text, 'icon': Icons.text_fields, 'label': 'Text', 'desc': 'Simple text field'},
      {'type': ColumnType.longText, 'icon': Icons.notes, 'label': 'Long Text', 'desc': 'Multi-line text area'},
      {'type': ColumnType.number, 'icon': Icons.tag, 'label': 'Number', 'desc': 'Numeric value'},
      {'type': ColumnType.status, 'icon': Icons.circle, 'label': 'Status', 'desc': 'Colored status labels'},
      {'type': ColumnType.person, 'icon': Icons.person, 'label': 'Person', 'desc': 'Team member assignment'},
      {'type': ColumnType.date, 'icon': Icons.calendar_today, 'label': 'Date', 'desc': 'Date picker'},
      {'type': ColumnType.dateRange, 'icon': Icons.date_range, 'label': 'Date Range', 'desc': 'Start and end dates'},
      {'type': ColumnType.checkbox, 'icon': Icons.check_box, 'label': 'Checkbox', 'desc': 'Yes/No checkbox'},
      {'type': ColumnType.dropdown, 'icon': Icons.arrow_drop_down_circle, 'label': 'Dropdown', 'desc': 'Custom dropdown options'},
      {'type': ColumnType.email, 'icon': Icons.email, 'label': 'Email', 'desc': 'Email address'},
      {'type': ColumnType.phone, 'icon': Icons.phone, 'label': 'Phone', 'desc': 'Phone number'},
      {'type': ColumnType.link, 'icon': Icons.link, 'label': 'Link', 'desc': 'URL link'},
      {'type': ColumnType.file, 'icon': Icons.attach_file, 'label': 'File', 'desc': 'File attachment'},
      {'type': ColumnType.rating, 'icon': Icons.star, 'label': 'Rating', 'desc': 'Star rating'},
      {'type': ColumnType.currency, 'icon': Icons.attach_money, 'label': 'Currency', 'desc': 'Money amount'},
      {'type': ColumnType.location, 'icon': Icons.location_on, 'label': 'Location', 'desc': 'Address or location'},
      {'type': ColumnType.priority, 'icon': Icons.flag, 'label': 'Priority', 'desc': 'Priority level'},
      {'type': ColumnType.progress, 'icon': Icons.linear_scale, 'label': 'Progress', 'desc': 'Progress percentage'},
      {'type': ColumnType.tags, 'icon': Icons.sell, 'label': 'Tags', 'desc': 'Multiple tags'},
      {'type': ColumnType.timeTracking, 'icon': Icons.timer, 'label': 'Time Tracking', 'desc': 'Track time spent'},
      {'type': ColumnType.lastUpdated, 'icon': Icons.update, 'label': 'Last Updated', 'desc': 'Auto-updated timestamp'},
      {'type': ColumnType.createdAt, 'icon': Icons.add_circle_outline, 'label': 'Created At', 'desc': 'Item creation date'},
      {'type': ColumnType.person, 'icon': Icons.person_outline, 'label': 'Created By', 'desc': 'Shows item creator', 'key': 'created_by'},
      {'type': ColumnType.updateCounter, 'icon': Icons.mark_chat_unread, 'label': 'Update Counter', 'desc': 'Shows update count with read status'},
    ];

    // Load custom label categories
    final labelCategories = await SundayService.getLabelCategories(widget.username);

    // Filter out status and priority (already in base types) and create column type entries for custom categories
    final customLabelTypes = labelCategories
        .where((cat) => !cat.isBuiltin) // Only custom categories
        .map((cat) => {
              'type': ColumnType.label,
              'icon': _getLabelCategoryIcon(cat.icon),
              'label': cat.name,
              'desc': cat.description.isNotEmpty ? cat.description : 'Custom label column',
              'categoryKey': cat.key,
              'categoryColor': cat.color,
            })
        .toList();

    // Combine base types with custom label categories
    final columnTypes = [...baseColumnTypes, ...customLabelTypes];

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Column'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Column Title',
                    hintText: 'e.g., Status, Due Date, Priority',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Text('Column Type', style: TextStyle(fontWeight: FontWeight.w500)),
                    if (customLabelTypes.isNotEmpty) ...[
                      const Spacer(),
                      Text(
                        '${customLabelTypes.length} custom label type${customLabelTypes.length == 1 ? '' : 's'}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 350,
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 2.5,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: columnTypes.length,
                    itemBuilder: (ctx, index) {
                      final item = columnTypes[index];
                      final type = item['type'] as ColumnType;
                      final categoryKey = item['categoryKey'] as String?;
                      final predefinedKey = item['key'] as String?;
                      final isCustomLabel = type == ColumnType.label && categoryKey != null;
                      final hasPredefinedKey = predefinedKey != null;

                      // Check selection based on type, category, and predefined key
                      final isSelected = isCustomLabel
                          ? (selectedType == ColumnType.label && selectedLabelCategory == categoryKey)
                          : hasPredefinedKey
                              ? (selectedType == type && selectedPredefinedKey == predefinedKey)
                              : (selectedType == type && selectedLabelCategory == null && selectedPredefinedKey == null);

                      // Get color for custom labels
                      Color? customColor;
                      if (isCustomLabel && item['categoryColor'] != null) {
                        try {
                          final colorStr = item['categoryColor'] as String;
                          if (colorStr.startsWith('#')) {
                            customColor = Color(int.parse(colorStr.substring(1), radix: 16) | 0xFF000000);
                          }
                        } catch (_) {}
                      }

                      return InkWell(
                        onTap: () => setDialogState(() {
                          selectedType = type;
                          selectedLabelCategory = categoryKey;
                          selectedPredefinedKey = predefinedKey;
                          // Auto-fill title with the column type label
                          titleController.text = item['label'] as String;
                        }),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected
                                  ? (customColor ?? AppColors.accent)
                                  : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: isSelected
                                ? (customColor ?? AppColors.accent).withValues(alpha: 0.1)
                                : null,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item['icon'] as IconData,
                                size: 20,
                                color: isSelected
                                    ? (customColor ?? AppColors.accent)
                                    : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            item['label'] as String,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              color: isSelected ? (customColor ?? AppColors.accent) : null,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isCustomLabel) ...[
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: (customColor ?? Colors.grey).withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                            child: Text(
                                              'CUSTOM',
                                              style: TextStyle(
                                                fontSize: 8,
                                                fontWeight: FontWeight.w600,
                                                color: customColor ?? Colors.grey.shade600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      item['desc'] as String,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a column title')),
                  );
                  return;
                }

                Navigator.pop(ctx);

                // Use predefined key if available, otherwise generate from title
                String columnKey;
                if (selectedPredefinedKey != null) {
                  columnKey = selectedPredefinedKey!;
                } else {
                  final key = title.toLowerCase()
                      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
                      .replaceAll(RegExp(r'^_+|_+$'), '');
                  columnKey = key.isEmpty ? 'column_${DateTime.now().millisecondsSinceEpoch}' : key;
                }

                // Build settings for custom label columns
                Map<String, dynamic>? settings;
                if (selectedType == ColumnType.label && selectedLabelCategory != null) {
                  settings = {'labelCategory': selectedLabelCategory};
                }

                final columnId = await SundayService.addColumn(
                  boardId: widget.boardId,
                  key: columnKey,
                  title: title,
                  type: selectedType,
                  username: widget.username,
                  settings: settings,
                );

                if (!mounted) return;
                final scaffoldMessenger = ScaffoldMessenger.of(this.context);

                if (columnId != null) {
                  // Optimistic update - add column locally
                  final newColumn = SundayColumn(
                    id: columnId,
                    boardId: widget.boardId,
                    key: columnKey,
                    title: title,
                    type: selectedType,
                    sortOrder: _board?.columns.length ?? 0,
                    settings: settings,
                  );
                  _addColumnLocally(newColumn);
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Column "$title" added')),
                  );
                } else {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Failed to add column'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Add Column'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getLabelCategoryIcon(String iconName) {
    switch (iconName) {
      case 'circle':
        return Icons.circle_outlined;
      case 'flag':
        return Icons.flag_outlined;
      case 'label':
        return Icons.label_outline;
      case 'tag':
        return Icons.sell_outlined;
      case 'star':
        return Icons.star_outline;
      case 'bookmark':
        return Icons.bookmark_outline;
      case 'category':
        return Icons.category_outlined;
      case 'folder':
        return Icons.folder_outlined;
      case 'share':
        return Icons.share_outlined;
      case 'link':
        return Icons.link;
      case 'person':
        return Icons.person_outline;
      case 'group':
        return Icons.group_outlined;
      case 'check':
        return Icons.check_circle_outline;
      case 'priority':
        return Icons.priority_high;
      default:
        return Icons.label_outline;
    }
  }

  void _showColumnSettings(SundayColumn column) {
    final titleController = TextEditingController(text: column.title);
    final widthController = TextEditingController(text: column.width.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.settings),
            const SizedBox(width: 8),
            Text('Column: ${column.title}'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Column Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: widthController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Width (pixels)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Type: '),
                  Chip(
                    label: Text(column.type.name),
                    avatar: Icon(_getColumnTypeIcon(column.type), size: 16),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delete Column',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                          Text(
                            'This will delete the column and all its data',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        // Capture navigator before async gap
                        final menuNavigator = Navigator.of(ctx);
                        final confirm = await showDialog<bool>(
                          context: ctx,
                          builder: (c) => AlertDialog(
                            title: const Text('Delete Column?'),
                            content: Text('Are you sure you want to delete "${column.title}"? This cannot be undone.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(c, true),
                                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          if (!mounted) return;
                          menuNavigator.pop();
                          final success = await SundayService.deleteColumn(column.id, widget.username);
                          if (success) {
                            // Optimistic update - delete column locally
                            _deleteColumnLocally(column.id);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Column "${column.title}" deleted')),
                              );
                            }
                          }
                        }
                      },
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newTitle = titleController.text.trim();
              final newWidth = int.tryParse(widthController.text);

              if (newTitle.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Title cannot be empty')),
                );
                return;
              }

              Navigator.pop(ctx);

              final success = await SundayService.updateColumn(
                columnId: column.id,
                username: widget.username,
                title: newTitle != column.title ? newTitle : null,
                width: newWidth,
              );

              if (success) {
                // Optimistic update - update column locally
                _updateColumnLocally(
                  column.id,
                  title: newTitle != column.title ? newTitle : null,
                  width: newWidth,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Column "$newTitle" updated')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  IconData _getColumnTypeIcon(ColumnType type) {
    switch (type) {
      case ColumnType.text:
        return Icons.text_fields;
      case ColumnType.longText:
        return Icons.notes;
      case ColumnType.number:
        return Icons.tag;
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
        return Icons.linear_scale;
      case ColumnType.label:
        return Icons.label_outline;
      default:
        return Icons.text_fields;
    }
  }

  void _showAddGroupDialog() async {
    final controller = TextEditingController();
    String selectedColor = '#0073ea';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Group'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Group name',
                  hintText: 'e.g., In Progress',
                ),
              ),
              const SizedBox(height: 16),
              const Text('Color', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Primary colors
                  '#0073ea', '#00c875', '#fdab3d', '#e2445c', '#a25ddc',
                  '#579bfc', '#037f4c', '#9AADBD', '#FF5AC4', '#784BD1',
                  // Additional colors
                  '#BB3354', '#175A63', '#2B76E5', '#66CCFF', '#226A5E',
                  '#F04095', '#FFCB00', '#FF642E', '#7F5347', '#C4C4C4',
                  '#CAB641', '#9CD326', '#6161FF', '#999999', '#4ECCC6',
                ].map((color) {
                  return InkWell(
                    onTap: () => setDialogState(() => selectedColor = color),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(int.parse(color.replaceFirst('#', '0xFF'))),
                        shape: BoxShape.circle,
                        border: selectedColor == color
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: selectedColor == color
                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4)]
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.pop(ctx, {'name': controller.text.trim(), 'color': selectedColor});
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      // Create on server first to get ID
      final newGroupId = await SundayService.addGroup(
        boardId: widget.boardId,
        title: result['name'],
        color: result['color'],
        username: widget.username,
      );
      if (newGroupId != null) {
        // Add locally with server-generated ID
        final newGroup = SundayGroup(
          id: newGroupId,
          boardId: widget.boardId,
          title: result['name'],
          color: result['color'],
        );
        _addGroupLocally(newGroup);
      }
    }
  }

  void _confirmDeleteGroup(SundayGroup group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Group'),
        content: Text(
          'Are you sure you want to delete "${group.title}"?\n\n'
          'All items in this group will also be deleted.',
        ),
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
      // Optimistic delete
      _deleteGroupLocally(group.id);
      // Sync with server
      await SundayService.deleteGroup(group.id, widget.username);
    }
  }

  /// Show dialog to manage group access (assign users to specific groups)
  void _showGroupAccessDialog(SundayGroup group) {
    showDialog(
      context: context,
      builder: (ctx) => GroupMembersDialog(
        groupId: group.id,
        groupTitle: group.title,
        boardId: widget.boardId,
        boardName: _board?.name ?? 'Board',
        username: widget.username,
      ),
    );
  }

  /// Show dialog to manage item access (assign users to specific items)
  void _showItemAccessDialog(SundayItem item) {
    showDialog(
      context: context,
      builder: (ctx) => ItemMembersDialog(
        itemId: item.id,
        itemName: item.name,
        boardId: widget.boardId,
        boardName: _board?.name ?? 'Board',
        username: widget.username,
      ),
    );
  }

  /// Show dialog to move an item to a different board
  void _showMoveToBoardDialog(SundayItem item) async {
    if (_board == null) return;

    // Fetch available boards (excluding current board)
    final boards = await SundayService.getBoards(
      _board!.workspaceId,
      widget.username,
    );

    if (boards.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No other boards available')),
        );
      }
      return;
    }

    // Filter out current board
    final otherBoards = boards.where((b) => b.id != _board!.id).toList();

    if (otherBoards.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No other boards available to move to')),
        );
      }
      return;
    }

    if (!mounted) return;

    final selectedBoard = await showDialog<SundayBoard>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move Item to Board'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Move "${item.name}" to:',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              const Text(
                'Note: The item will be assigned to the target board\'s owner.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: otherBoards.length,
                  itemBuilder: (context, index) {
                    final board = otherBoards[index];
                    return ListTile(
                      leading: const Icon(Icons.dashboard),
                      title: Text(board.name),
                      subtitle: Text('Created by: ${board.createdBy}'),
                      onTap: () => Navigator.pop(ctx, board),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedBoard != null && mounted) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      final result = await SundayService.moveItemToBoard(
        itemId: item.id,
        targetBoardId: selectedBoard.id,
        username: widget.username,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading indicator
      }

      if (result != null && mounted) {
        // Remove item from local state
        _deleteItemLocally(item.id);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Item "${item.name}" moved to "${selectedBoard.name}"'),
            action: SnackBarAction(
              label: 'Go to Board',
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SundayBoardScreen(
                      boardId: selectedBoard.id,
                      username: widget.username,
                      role: widget.role,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to move item'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show dialog to move item to a different group within the same board
  void _showMoveToGroupDialog(SundayItem item) async {
    if (_board == null) return;

    // Get all groups in the current board, excluding the item's current group
    final otherGroups = _board!.groups.where((g) => g.id != item.groupId).toList();

    if (otherGroups.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No other groups available to move to')),
        );
      }
      return;
    }

    if (!mounted) return;

    final selectedGroup = await showDialog<SundayGroup>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move Item to Group'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Move "${item.name}" to:',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: otherGroups.length,
                  itemBuilder: (context, index) {
                    final group = otherGroups[index];
                    return ListTile(
                      leading: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: group.colorValue,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      title: Text(group.title),
                      subtitle: Text('${group.items.length} item(s)'),
                      onTap: () => Navigator.pop(ctx, group),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedGroup != null && mounted) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      final result = await SundayService.moveItemWithResult(
        item.id,
        selectedGroup.id,
        widget.username,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading indicator
      }

      if (result != null && mounted) {
        // Move item locally between groups
        _moveItemLocallyToGroup(item, selectedGroup.id);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Item "${item.name}" moved to "${selectedGroup.title}"'),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to move item'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Move item locally from one group to another
  void _moveItemLocallyToGroup(SundayItem item, int targetGroupId) {
    if (_board == null) return;

    setState(() {
      final groups = List<SundayGroup>.from(_board!.groups);

      // Find and remove item from source group
      for (int i = 0; i < groups.length; i++) {
        final items = List<SundayItem>.from(groups[i].items);
        final itemIndex = items.indexWhere((it) => it.id == item.id);
        if (itemIndex != -1) {
          items.removeAt(itemIndex);
          groups[i] = groups[i].copyWith(items: items);
          break;
        }
      }

      // Add item to target group
      final targetIndex = groups.indexWhere((g) => g.id == targetGroupId);
      if (targetIndex != -1) {
        final targetItems = List<SundayItem>.from(groups[targetIndex].items);
        final movedItem = item.copyWith(groupId: targetGroupId);
        targetItems.add(movedItem);
        groups[targetIndex] = groups[targetIndex].copyWith(items: targetItems);
      }

      _board = _board!.copyWith(groups: groups);
    });
  }

  void _confirmDeleteItem(SundayItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "${item.name}"?'),
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
      // Optimistic delete - removes item and clears selection
      _deleteItemLocally(item.id);
      // Sync with server
      await SundayService.deleteItem(item.id, widget.username);
    }
  }

  void _showBoardSettings() {
    if (_board == null) return;

    final nameController = TextEditingController(text: _board!.name);
    final descController = TextEditingController(text: _board!.description ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.settings),
            SizedBox(width: 8),
            Text('Board Settings'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Board Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Created by: ', style: TextStyle(color: Colors.grey.shade600)),
                  Text(_board!.createdBy),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('Created: ', style: TextStyle(color: Colors.grey.shade600)),
                  Text(_board!.createdAt.toString().split('.')[0]),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('Items: ', style: TextStyle(color: Colors.grey.shade600)),
                  Text('${_board!.itemCount}'),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Board name cannot be empty')),
                );
                return;
              }

              Navigator.pop(ctx);

              final success = await SundayService.updateBoard(
                boardId: widget.boardId,
                username: widget.username,
                name: newName,
                description: descController.text.trim(),
              );

              if (success) {
                // Optimistic update - update board metadata locally
                _updateBoardLocally(
                  name: newName,
                  description: descController.text.trim(),
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Board updated')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _exportBoard() async {
    if (_board == null) return;

    final format = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Board'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('CSV (Comma Separated)'),
              subtitle: const Text('Opens in Excel, Google Sheets'),
              onTap: () => Navigator.pop(ctx, 'csv'),
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('JSON'),
              subtitle: const Text('For developers and data transfer'),
              onTap: () => Navigator.pop(ctx, 'json'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (format == null) return;

    try {
      String content;
      String extension;

      if (format == 'csv') {
        final columns = _board!.columns;
        final buffer = StringBuffer();

        buffer.write('Name');
        for (final col in columns) {
          buffer.write(',${_escapeCsv(col.title)}');
        }
        buffer.write(',Group\n');

        for (final group in _board!.groups) {
          for (final item in group.items) {
            buffer.write(_escapeCsv(item.name));
            for (final col in columns) {
              final value = item.columnValues[col.key] ?? '';
              buffer.write(',${_escapeCsv(value.toString())}');
            }
            buffer.write(',${_escapeCsv(group.title)}\n');
          }
        }

        content = buffer.toString();
        extension = 'csv';
      } else {
        final data = {
          'board_name': _board!.name,
          'exported_at': DateTime.now().toIso8601String(),
          'columns': _board!.columns.map((c) => {
            'key': c.key,
            'title': c.title,
            'type': c.type.name,
          }).toList(),
          'groups': _board!.groups.map((g) => {
            'title': g.title,
            'color': g.color,
            'items': g.items.map((i) => {
              'name': i.name,
              'values': i.columnValues,
            }).toList(),
          }).toList(),
        };
        content = const JsonEncoder.withIndent('  ').convert(data);
        extension = 'json';
      }

      final fileName = '${_board!.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_export.$extension';
      final downloadsDir = Directory('${Platform.environment['USERPROFILE']}\\Downloads');
      final file = File('${downloadsDir.path}\\$fileName');
      await file.writeAsString(content);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported to Downloads\\$fileName'),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () {
                Process.run('explorer.exe', ['/select,', file.path]);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  void _importData() async {
    final option = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.add, color: Colors.blue.shade700),
              ),
              title: const Text('Import Items from CSV'),
              subtitle: const Text('Add items to this board from a CSV file'),
              onTap: () => Navigator.pop(ctx, 'csv'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (option == 'csv') {
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['csv'],
          dialogTitle: 'Select CSV File',
        );

        if (result != null && result.files.single.path != null) {
          final file = File(result.files.single.path!);
          final content = await file.readAsString();
          final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();

          if (lines.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('CSV file is empty')),
              );
            }
            return;
          }

          final headers = _parseCsvLine(lines[0]);
          int imported = 0;

          final targetGroupId = _board?.groups.isNotEmpty == true
              ? _board!.groups.first.id
              : null;

          if (targetGroupId == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Create a group first before importing')),
              );
            }
            return;
          }

          for (int i = 1; i < lines.length; i++) {
            final values = _parseCsvLine(lines[i]);
            if (values.isEmpty) continue;

            final name = values[0];
            if (name.isEmpty) continue;

            final columnValues = <String, dynamic>{};
            for (int j = 1; j < headers.length && j < values.length; j++) {
              final header = headers[j].toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
              if (values[j].isNotEmpty) {
                columnValues[header] = values[j];
              }
            }

            await SundayService.createItem(
              boardId: widget.boardId,
              groupId: targetGroupId,
              name: name,
              username: widget.username,
              columnValues: columnValues,
            );
            imported++;
          }

          _loadBoard();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Imported $imported items')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Import failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    var inQuotes = false;
    var current = StringBuffer();

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        result.add(current.toString());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString());
    return result;
  }

  void _showSaveTemplateDialog() async {
    if (_board == null) return;

    final nameController = TextEditingController(text: '${_board!.name} Template');
    final descController = TextEditingController();
    String selectedIcon = 'dashboard';
    String selectedColor = '#579bfc';
    String selectedCategory = 'Custom';
    bool includeItems = false;
    bool includeAutomations = true;
    bool isShared = true;

    final icons = [
      'dashboard', 'work', 'trending_up', 'check_circle', 'folder',
      'people', 'settings', 'build', 'assignment', 'event',
    ];

    final colors = [
      '#579bfc', '#fdab3d', '#00c875', '#e2445c', '#a25ddc',
      '#0086c0', '#9cd326', '#ff642e', '#c4c4c4', '#037f4c',
    ];

    final categories = ['Custom', 'Sales', 'Operations', 'General', 'Project Management'];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Save Board as Template'),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Template name',
                      hintText: 'e.g., Sales Pipeline Template',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      hintText: 'Describe what this template is for',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),

                  // Category
                  const Text('Category', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((cat) {
                      final isSelected = selectedCategory == cat;
                      return ChoiceChip(
                        selected: isSelected,
                        label: Text(cat),
                        onSelected: (selected) {
                          if (selected) setDialogState(() => selectedCategory = cat);
                        },
                        selectedColor: AppColors.accent.withValues(alpha: 0.2),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Icon
                  const Text('Icon', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: icons.map((iconName) {
                      final isSelected = selectedIcon == iconName;
                      return InkWell(
                        onTap: () => setDialogState(() => selectedIcon = iconName),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.accent.withValues(alpha: 0.2) : Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected ? Border.all(color: AppColors.accent, width: 2) : null,
                          ),
                          child: Icon(
                            _getIconData(iconName),
                            color: isSelected ? AppColors.accent : Colors.grey[600],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Color
                  const Text('Color', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: colors.map((colorHex) {
                      final isSelected = selectedColor == colorHex;
                      final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
                      return InkWell(
                        onTap: () => setDialogState(() => selectedColor = colorHex),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 3)
                                : null,
                            boxShadow: isSelected
                                ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white, size: 18)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Options
                  CheckboxListTile(
                    value: includeItems,
                    onChanged: (val) => setDialogState(() => includeItems = val ?? false),
                    title: const Text('Include items'),
                    subtitle: const Text('Save all current items with their values'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    value: includeAutomations,
                    onChanged: (val) => setDialogState(() => includeAutomations = val ?? true),
                    title: const Text('Include automations'),
                    subtitle: const Text('Save all board automations'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    value: isShared,
                    onChanged: (val) => setDialogState(() => isShared = val ?? true),
                    title: const Text('Share with team'),
                    subtitle: const Text('Other users can see and use this template'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  Navigator.pop(ctx, {
                    'name': nameController.text.trim(),
                    'description': descController.text.trim(),
                    'icon': selectedIcon,
                    'color': selectedColor,
                    'category': selectedCategory,
                    'include_items': includeItems,
                    'include_automations': includeAutomations,
                    'is_shared': isShared,
                  });
                }
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
              child: const Text('Save Template'),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saving template...')),
      );

      final templateId = await SundayService.saveBoardAsTemplate(
        boardId: widget.boardId,
        name: result['name'],
        username: widget.username,
        description: result['description'],
        icon: result['icon'],
        color: result['color'],
        category: result['category'],
        isShared: result['is_shared'],
        includeItems: result['include_items'],
        includeAutomations: result['include_automations'],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        if (templateId != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Template "${result['name']}" saved successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save template'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'dashboard': return Icons.dashboard;
      case 'work': return Icons.work;
      case 'trending_up': return Icons.trending_up;
      case 'check_circle': return Icons.check_circle;
      case 'folder': return Icons.folder;
      case 'people': return Icons.people;
      case 'settings': return Icons.settings;
      case 'build': return Icons.build;
      case 'assignment': return Icons.assignment;
      case 'event': return Icons.event;
      default: return Icons.dashboard;
    }
  }

  /// Get icon for a column type
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

  /// Build a resizable Name column header with separate actions column
  Widget _buildNameColumnHeader(Color borderColor) {
    final nameWidth = _columnWidths['__name__'] ?? 300.0;
    // Actions column width matches item rows: drag (20) is available to everyone + menu (32)
    // Since everyone can drag, always include drag handle width
    const actionsWidth = 52.0; // 20 (drag) + 32 (menu) - consistent for all users

    return MouseRegion(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Actions column header (empty, just for alignment)
          Container(
            width: actionsWidth,
            height: 44,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: borderColor.withValues(alpha: 0.5)),
              ),
            ),
          ),
          // Name column header
          Container(
            width: nameWidth,
            height: 44,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: borderColor),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
                const Icon(Icons.text_fields, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Name',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                // Resize handle
                GestureDetector(
                  onHorizontalDragStart: (details) {
                    // Store initial values for drag
                  },
                  onHorizontalDragUpdate: (details) {
                    final newWidth = (nameWidth + details.delta.dx).clamp(150.0, 500.0);
                    setState(() => _columnWidths['__name__'] = newWidth);
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeColumn,
                    child: Container(
                      width: 6,
                      height: 40,
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteBoard() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Board'),
        content: Text(
          'Are you sure you want to delete "${_board?.name}"?\n\n'
          'This action cannot be undone.',
        ),
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
      final success = await SundayService.deleteBoard(widget.boardId, widget.username);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Board deleted')),
        );
        // For embedded view, use onBack callback; otherwise pop
        if (widget.embedded && widget.onBack != null) {
          widget.onBoardUpdated?.call();
          widget.onBack!();
        } else {
          Navigator.pop(context);
        }
      }
    }
  }
}

/// A chip-style button for the filter toolbar
class _FilterChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final int? activeCount;
  final Widget? suffix;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.icon,
    required this.label,
    required this.isActive,
    this.activeCount,
    this.suffix,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = Theme.of(context).primaryColor;
    final defaultColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final bgColor = isActive
        ? activeColor.withValues(alpha: 0.1)
        : (isDark ? Colors.grey.shade800 : Colors.grey.shade100);
    final borderColor = isActive
        ? activeColor
        : (isDark ? Colors.grey.shade700 : Colors.grey.shade300);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? activeColor : defaultColor,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: isActive ? activeColor : defaultColor,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (activeCount != null && activeCount! > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: activeColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$activeCount',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (suffix != null) ...[
                const SizedBox(width: 4),
                suffix!,
              ],
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_drop_down,
                size: 16,
                color: isActive ? activeColor : defaultColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog to filter by assigned person
class _PersonFilterDialog extends StatefulWidget {
  final Set<String> currentSelection;
  final Function(Set<String>) onApply;
  final String? username; // Current user for API authentication

  const _PersonFilterDialog({
    required this.currentSelection,
    required this.onApply,
    this.username,
  });

  @override
  State<_PersonFilterDialog> createState() => _PersonFilterDialogState();
}

class _PersonFilterDialogState extends State<_PersonFilterDialog> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String _searchQuery = '';
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.currentSelection);
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final users = await SundayService.getAppUsers(requestingUsername: widget.username);
    if (mounted) {
      setState(() {
        _users = users;
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) return _users;
    final query = _searchQuery.toLowerCase();
    return _users.where((u) =>
      (u['name']?.toString() ?? '').toLowerCase().contains(query) ||
      (u['username']?.toString() ?? '').toLowerCase().contains(query)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter by Person'),
      content: SizedBox(
        width: 300,
        height: 400,
        child: Column(
          children: [
            // Search field
            TextField(
              decoration: InputDecoration(
                hintText: 'Search people...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
            const SizedBox(height: 12),

            // Selected chips
            if (_selected.isNotEmpty)
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: _selected.map((name) => Chip(
                  label: Text(name, style: const TextStyle(fontSize: 12)),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () => setState(() => _selected.remove(name)),
                  visualDensity: VisualDensity.compact,
                )).toList(),
              ),
            if (_selected.isNotEmpty) const SizedBox(height: 8),

            // User list
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredUsers.isEmpty
                      ? Center(
                          child: Text(
                            _searchQuery.isEmpty ? 'No users found' : 'No matching users',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = _filteredUsers[index];
                            final name = (user['name']?.toString() ?? user['username']?.toString() ?? '');
                            final isSelected = _selected.contains(name);

                            return CheckboxListTile(
                              title: Text(name),
                              subtitle: Text('@${user['username']?.toString() ?? ''}'),
                              value: isSelected,
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selected.add(name);
                                  } else {
                                    _selected.remove(name);
                                  }
                                });
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => _selected.clear()),
          child: const Text('Clear'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => widget.onApply(_selected),
          child: Text('Apply (${_selected.length})'),
        ),
      ],
    );
  }
}

/// Model for column-based filters
class ColumnFilter {
  final String columnKey;
  final FilterOperator operator;
  final String value;

  const ColumnFilter({
    required this.columnKey,
    required this.operator,
    required this.value,
  });

  /// Check if an item matches this filter
  bool matches(SundayItem item) {
    // Handle special columns
    dynamic itemValue;
    if (columnKey == '__name__') {
      itemValue = item.name;
    } else {
      itemValue = item.columnValues[columnKey];
    }

    final stringValue = itemValue?.toString().toLowerCase() ?? '';
    final filterValue = value.toLowerCase();

    switch (operator) {
      case FilterOperator.contains:
        return stringValue.contains(filterValue);
      case FilterOperator.notContains:
        return !stringValue.contains(filterValue);
      case FilterOperator.equals:
        return stringValue == filterValue;
      case FilterOperator.notEquals:
        return stringValue != filterValue;
      case FilterOperator.isEmpty:
        return stringValue.isEmpty;
      case FilterOperator.isNotEmpty:
        return stringValue.isNotEmpty;
      case FilterOperator.startsWith:
        return stringValue.startsWith(filterValue);
      case FilterOperator.endsWith:
        return stringValue.endsWith(filterValue);
    }
  }
}

/// Filter operators
enum FilterOperator {
  contains,
  notContains,
  equals,
  notEquals,
  isEmpty,
  isNotEmpty,
  startsWith,
  endsWith,
}

/// Get display label for filter operator
String getFilterOperatorLabel(FilterOperator op) {
  switch (op) {
    case FilterOperator.contains:
      return 'contains';
    case FilterOperator.notContains:
      return 'does not contain';
    case FilterOperator.equals:
      return 'is';
    case FilterOperator.notEquals:
      return 'is not';
    case FilterOperator.isEmpty:
      return 'is empty';
    case FilterOperator.isNotEmpty:
      return 'is not empty';
    case FilterOperator.startsWith:
      return 'starts with';
    case FilterOperator.endsWith:
      return 'ends with';
  }
}

/// Dialog to manage column-based filters
class _ColumnFilterDialog extends StatefulWidget {
  final SundayBoard board;
  final List<ColumnFilter> currentFilters;
  final Function(List<ColumnFilter>) onApply;

  const _ColumnFilterDialog({
    required this.board,
    required this.currentFilters,
    required this.onApply,
  });

  @override
  State<_ColumnFilterDialog> createState() => _ColumnFilterDialogState();
}

class _ColumnFilterDialogState extends State<_ColumnFilterDialog> {
  late List<_FilterRow> _filterRows;

  @override
  void initState() {
    super.initState();
    // Initialize from current filters
    _filterRows = widget.currentFilters.map((f) => _FilterRow(
      columnKey: f.columnKey,
      operator: f.operator,
      value: f.value,
    )).toList();
    // Add an empty row if no filters
    if (_filterRows.isEmpty) {
      _filterRows.add(_FilterRow(columnKey: '__name__', operator: FilterOperator.contains, value: ''));
    }
  }

  List<_ColumnOption> get _columnOptions {
    final options = <_ColumnOption>[
      const _ColumnOption(key: '__name__', title: 'Name', icon: Icons.text_fields),
    ];
    for (final col in widget.board.columns.where((c) => !c.isHidden)) {
      options.add(_ColumnOption(
        key: col.key,
        title: col.title,
        icon: _getColumnIcon(col.type),
      ));
    }
    return options;
  }

  IconData _getColumnIcon(ColumnType type) {
    switch (type) {
      case ColumnType.text:
        return Icons.text_fields;
      case ColumnType.number:
        return Icons.numbers;
      case ColumnType.status:
        return Icons.flag;
      case ColumnType.label:
        return Icons.label;
      case ColumnType.date:
        return Icons.calendar_today;
      case ColumnType.person:
        return Icons.person;
      case ColumnType.technician:
        return Icons.engineering;
      case ColumnType.checkbox:
        return Icons.check_box;
      case ColumnType.dropdown:
        return Icons.arrow_drop_down_circle;
      case ColumnType.link:
        return Icons.link;
      case ColumnType.phone:
        return Icons.phone;
      case ColumnType.email:
        return Icons.email;
      case ColumnType.longText:
        return Icons.notes;
      case ColumnType.file:
        return Icons.attach_file;
      case ColumnType.formula:
        return Icons.functions;
      case ColumnType.timeline:
        return Icons.timeline;
      case ColumnType.tags:
        return Icons.local_offer;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.filter_list),
          const SizedBox(width: 8),
          const Text('Filter Items'),
          const Spacer(),
          if (_filterRows.isNotEmpty && _filterRows.any((r) => r.value.isNotEmpty))
            TextButton(
              onPressed: () {
                setState(() {
                  _filterRows.clear();
                  _filterRows.add(_FilterRow(columnKey: '__name__', operator: FilterOperator.contains, value: ''));
                });
              },
              child: const Text('Clear All'),
            ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Filter rows
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _filterRows.length,
                itemBuilder: (context, index) {
                  return _buildFilterRow(index);
                },
              ),
            ),
            const SizedBox(height: 12),
            // Add filter button
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _filterRows.add(_FilterRow(columnKey: '__name__', operator: FilterOperator.contains, value: ''));
                });
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Filter'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            // Build filters from rows (skip empty ones)
            final filters = _filterRows
                .where((r) => r.value.isNotEmpty || r.operator == FilterOperator.isEmpty || r.operator == FilterOperator.isNotEmpty)
                .map((r) => ColumnFilter(
                  columnKey: r.columnKey,
                  operator: r.operator,
                  value: r.value,
                ))
                .toList();
            widget.onApply(filters);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _buildFilterRow(int index) {
    final row = _filterRows[index];
    final options = _columnOptions;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Column dropdown
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              initialValue: row.columnKey,
              isExpanded: true,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(),
              ),
              items: options.map((opt) => DropdownMenuItem(
                value: opt.key,
                child: Row(
                  children: [
                    Icon(opt.icon, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        opt.title,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _filterRows[index].columnKey = value);
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          // Operator dropdown
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<FilterOperator>(
              initialValue: row.operator,
              isExpanded: true,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(),
              ),
              items: FilterOperator.values.map((op) => DropdownMenuItem(
                value: op,
                child: Text(
                  getFilterOperatorLabel(op),
                  overflow: TextOverflow.ellipsis,
                ),
              )).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _filterRows[index].operator = value);
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          // Value field (hidden for isEmpty/isNotEmpty)
          Expanded(
            flex: 2,
            child: row.operator == FilterOperator.isEmpty || row.operator == FilterOperator.isNotEmpty
                ? const SizedBox.shrink()
                : TextField(
                    controller: TextEditingController(text: row.value),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(),
                      hintText: 'Value...',
                    ),
                    onChanged: (value) {
                      _filterRows[index].value = value;
                    },
                  ),
          ),
          const SizedBox(width: 4),
          // Remove button
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: _filterRows.length > 1
                ? () {
                    setState(() => _filterRows.removeAt(index));
                  }
                : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

/// Internal class to hold filter row state
class _FilterRow {
  String columnKey;
  FilterOperator operator;
  String value;

  _FilterRow({
    required this.columnKey,
    required this.operator,
    required this.value,
  });
}

/// Column option for the filter dialog
class _ColumnOption {
  final String key;
  final String title;
  final IconData icon;

  const _ColumnOption({
    required this.key,
    required this.title,
    required this.icon,
  });
}
