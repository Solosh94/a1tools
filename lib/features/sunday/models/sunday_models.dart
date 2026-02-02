/// Sunday Data Models for A1 Tools
/// Replaces Monday.com functionality with enhanced features
library;

import 'dart:convert';
import 'package:flutter/material.dart';

// ============================================
// HELPER FUNCTIONS
// ============================================

/// Safely parse JSON settings that may come as string from PHP
Map<String, dynamic>? _parseSettings(dynamic settings) {
  if (settings == null) return null;
  if (settings is Map) {
    return Map<String, dynamic>.from(settings);
  }
  if (settings is String && settings.isNotEmpty) {
    try {
      final decoded = jsonDecode(settings);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Invalid JSON, return null
    }
  }
  return null;
}

// ============================================
// WORKSPACE MODEL
// ============================================

/// A workspace contains multiple boards (like Monday workspaces)
class SundayWorkspace {
  final int id;
  final String name;
  final String? description;
  final String? icon;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<SundayBoard> boards;

  const SundayWorkspace({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.boards = const [],
  });

  factory SundayWorkspace.fromJson(Map<String, dynamic> json) {
    return SundayWorkspace(
      id: _parseInt(json['id']),
      name: json['name'] as String? ?? 'Untitled',
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      createdBy: (json['owner_username'] ?? json['created_by']) as String? ?? 'unknown',
      createdAt: _parseRequiredDateTime(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? _parseDateTime(json['updated_at'])
          : null,
      boards: (json['boards'] as List<dynamic>?)
              ?.map((b) => SundayBoard.fromJson(b as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.parse(value);
    return 0;
  }

  /// Parse a DateTime value, with special handling for null/invalid values.
  /// Returns a sentinel date (epoch) for null values to distinguish from "just created".
  /// For required dates (like created_at), the caller should handle null separately.
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) {
      // Return epoch as sentinel value to distinguish from actual current dates
      // Callers can check for epoch to detect missing dates
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    if (value is DateTime) return value;
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) {
      // Log invalid date for debugging in debug mode
      assert(() {
        // ignore: avoid_print
        print('[SundayModels] WARNING: Invalid date format "$value", defaulting to epoch');
        return true;
      }());
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    return parsed;
  }

  /// Parse a DateTime that is required (like created_at), falling back to now if missing
  static DateTime _parseRequiredDateTime(dynamic value) {
    final parsed = _parseDateTime(value);
    // If it's epoch (our sentinel), use current time as fallback
    if (parsed.millisecondsSinceEpoch == 0) {
      return DateTime.now();
    }
    return parsed;
  }

  /// Check if a DateTime is the sentinel value (indicating missing/null)
  static bool isDateMissing(DateTime date) {
    return date.millisecondsSinceEpoch == 0;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'icon': icon,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };
}

// ============================================
// BOARD MODEL
// ============================================

/// Board types - similar to Monday board types
enum BoardType {
  main, // Main board
  shareable, // Shareable with guests
  private_, // Private board
}

/// A folder to organize boards within a workspace
class SundayBoardFolder {
  final int id;
  final int workspaceId;
  final String name;
  final String color;
  final int position;
  final bool isExpanded;

  const SundayBoardFolder({
    required this.id,
    required this.workspaceId,
    required this.name,
    this.color = '#808080',
    this.position = 0,
    this.isExpanded = true,
  });

  factory SundayBoardFolder.fromJson(Map<String, dynamic> json) {
    return SundayBoardFolder(
      id: SundayWorkspace._parseInt(json['id']),
      workspaceId: SundayWorkspace._parseInt(json['workspace_id']),
      name: json['name'] as String? ?? 'Untitled Folder',
      color: (json['color'] as String?) ?? '#808080',
      position: SundayWorkspace._parseInt(json['position'] ?? 0),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'workspace_id': workspaceId,
    'name': name,
    'color': color,
    'position': position,
  };

  SundayBoardFolder copyWith({
    int? id,
    int? workspaceId,
    String? name,
    String? color,
    int? position,
    bool? isExpanded,
  }) {
    return SundayBoardFolder(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      name: name ?? this.name,
      color: color ?? this.color,
      position: position ?? this.position,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }
}

/// Label category for dynamic label groups (e.g., status, priority, custom ones like "socials")
class LabelCategory {
  final String key;
  final String name;
  final String description;
  final String icon;
  final String color;
  final int position;
  final bool isBuiltin;
  final int labelCount;

  const LabelCategory({
    required this.key,
    required this.name,
    this.description = '',
    this.icon = 'label',
    this.color = '#808080',
    this.position = 0,
    this.isBuiltin = false,
    this.labelCount = 0,
  });

  factory LabelCategory.fromJson(Map<String, dynamic> json) {
    return LabelCategory(
      key: (json['key'] ?? json['id'] ?? '') as String,
      name: (json['name'] ?? json['display_name'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      icon: (json['icon'] ?? 'label') as String,
      color: (json['color'] ?? '#808080') as String,
      position: SundayWorkspace._parseInt(json['position'] ?? 0),
      isBuiltin: json['is_builtin'] == true || json['is_builtin'] == 1,
      labelCount: SundayWorkspace._parseInt(json['label_count'] ?? 0),
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'name': name,
    'description': description,
    'icon': icon,
    'color': color,
    'position': position,
    'is_builtin': isBuiltin,
    'label_count': labelCount,
  };
}

/// Default label for Sunday settings (used as templates for status columns)
class SundayDefaultLabel {
  final int id;
  final String type;
  final String name;
  final String color;
  final int position;
  final bool isDone;
  final bool isDefault;

  const SundayDefaultLabel({
    required this.id,
    this.type = 'status',
    required this.name,
    this.color = '#808080',
    this.position = 0,
    this.isDone = false,
    this.isDefault = false,
  });

  factory SundayDefaultLabel.fromJson(Map<String, dynamic> json) {
    return SundayDefaultLabel(
      id: SundayWorkspace._parseInt(json['id']),
      type: (json['label_type'] as String?) ?? 'status',
      name: (json['label_name'] as String?) ?? '',
      color: (json['color'] as String?) ?? '#808080',
      position: SundayWorkspace._parseInt(json['position'] ?? 0),
      isDone: json['is_done'] == 1 || json['is_done'] == true,
      isDefault: json['is_default'] == 1 || json['is_default'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label_type': type,
    'label_name': name,
    'color': color,
    'position': position,
    'is_done': isDone ? 1 : 0,
    'is_default': isDefault ? 1 : 0,
  };
}

/// A board contains groups and items (like Monday boards)
/// User's access scope to a board (different from BoardAccessLevel which is for members)
enum UserBoardAccessScope {
  full,     // Board member/owner/admin - can see all items
  itemOnly, // Can only see items they created or are assigned to
  none,     // No access
}

class SundayBoard {
  final int id;
  final int workspaceId;
  final int? folderId;
  final String name;
  final String? description;
  final BoardType type;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<SundayColumn> columns;
  final List<SundayGroup> groups;
  final int itemCount;
  final int groupCount;
  final int position;
  final UserBoardAccessScope userAccessLevel; // User's access scope to this board

  const SundayBoard({
    required this.id,
    required this.workspaceId,
    this.folderId,
    required this.name,
    this.description,
    this.type = BoardType.main,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.columns = const [],
    this.groups = const [],
    this.itemCount = 0,
    this.groupCount = 0,
    this.position = 0,
    this.userAccessLevel = UserBoardAccessScope.full,
  });

  factory SundayBoard.fromJson(Map<String, dynamic> json) {
    // Parse user access scope from API response
    UserBoardAccessScope accessLevel = UserBoardAccessScope.full;
    final accessStr = json['user_access_level'] as String?;
    if (accessStr == 'item_only') {
      accessLevel = UserBoardAccessScope.itemOnly;
    } else if (accessStr == 'none') {
      accessLevel = UserBoardAccessScope.none;
    }

    return SundayBoard(
      id: SundayWorkspace._parseInt(json['id']),
      workspaceId: SundayWorkspace._parseInt(json['workspace_id']),
      folderId: json['folder_id'] != null ? SundayWorkspace._parseInt(json['folder_id']) : null,
      name: json['name'] as String? ?? 'Untitled Board',
      description: json['description'] as String?,
      type: BoardType.values.firstWhere(
        (e) => e.name == (json['board_type'] ?? json['type']),
        orElse: () => BoardType.main,
      ),
      createdBy: (json['owner_username'] ?? json['created_by']) as String? ?? 'unknown',
      createdAt: SundayWorkspace._parseRequiredDateTime(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? SundayWorkspace._parseDateTime(json['updated_at'])
          : null,
      columns: (json['columns'] as List<dynamic>?)
              ?.map((c) => SundayColumn.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      groups: (json['groups'] as List<dynamic>?)
              ?.map((g) => SundayGroup.fromJson(g as Map<String, dynamic>))
              .toList() ??
          [],
      itemCount: SundayWorkspace._parseInt(json['item_count'] ?? 0),
      groupCount: SundayWorkspace._parseInt(json['group_count'] ?? (json['groups'] as List?)?.length ?? 0),
      position: SundayWorkspace._parseInt(json['position'] ?? 0),
      userAccessLevel: accessLevel,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'workspace_id': workspaceId,
        'name': name,
        'description': description,
        'type': type.name,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  SundayBoard copyWith({
    int? id,
    int? workspaceId,
    int? folderId,
    String? name,
    String? description,
    BoardType? type,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<SundayColumn>? columns,
    List<SundayGroup>? groups,
    int? itemCount,
    int? groupCount,
    int? position,
    UserBoardAccessScope? userAccessLevel,
  }) {
    return SundayBoard(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      folderId: folderId ?? this.folderId,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      columns: columns ?? this.columns,
      groups: groups ?? this.groups,
      itemCount: itemCount ?? this.itemCount,
      groupCount: groupCount ?? this.groupCount,
      position: position ?? this.position,
      userAccessLevel: userAccessLevel ?? this.userAccessLevel,
    );
  }

  /// Check if user has full access (can see all items)
  bool get hasFullAccess => userAccessLevel == UserBoardAccessScope.full;

  /// Check if user has item-only access (can only see assigned items)
  bool get hasItemOnlyAccess => userAccessLevel == UserBoardAccessScope.itemOnly;
}

// ============================================
// COLUMN MODEL
// ============================================

/// Column types - similar to Monday column types with A1 specific additions
enum ColumnType {
  text, // Simple text
  longText, // Multi-line text
  number, // Numeric value
  status, // Status with colors (dropdown)
  person, // Assigned person(s)
  date, // Date picker
  dateRange, // Date range (start/end)
  timeline, // Timeline (like Gantt)
  checkbox, // Yes/No checkbox
  dropdown, // Custom dropdown
  email, // Email address
  phone, // Phone number
  link, // URL link
  file, // File attachment
  rating, // Star rating
  currency, // Money amount
  location, // Address/location
  tags, // Multiple tags
  priority, // Priority level
  progress, // Progress percentage
  formula, // Calculated field
  mirror, // Mirror from linked item
  dependency, // Item dependency
  timeTracking, // Time tracking
  lastUpdated, // Auto last updated
  createdAt, // Auto created date
  workizJob, // A1 specific: Link to Workiz job
  technician, // A1 specific: Assigned technician
  label, // Custom label category (configurable via settings.labelCategory)
  updateCounter, // Shows count of updates with read/unread status coloring
}

/// Column definition for a board
class SundayColumn {
  final int id;
  final int boardId;
  final String key; // Unique key within board
  final String title;
  final ColumnType type;
  final int sortOrder;
  final int width;
  final bool isRequired;
  final bool isHidden;
  final Map<String, dynamic>? settings; // Type-specific settings
  final List<StatusLabel> _statusLabels; // Status labels from API

  const SundayColumn({
    required this.id,
    required this.boardId,
    required this.key,
    required this.title,
    required this.type,
    this.sortOrder = 0,
    this.width = 150,
    this.isRequired = false,
    this.isHidden = false,
    this.settings,
    List<StatusLabel>? statusLabels,
  }) : _statusLabels = statusLabels ?? const [];

  factory SundayColumn.fromJson(Map<String, dynamic> json) {
    // Handle both 'column_key' and 'key' field names
    final columnKey = (json['column_key'] ?? json['key']) as String? ?? 'col_${json['id']}';
    // Handle both 'type' and 'column_type' field names
    final typeStr = (json['type'] ?? json['column_type']) as String? ?? 'text';

    // Parse status_labels from JSON (returned by API)
    List<StatusLabel> statusLabels = [];
    if (json['status_labels'] != null && json['status_labels'] is List) {
      statusLabels = (json['status_labels'] as List)
          .map((l) => StatusLabel.fromJson(l as Map<String, dynamic>))
          .toList();
    }

    return SundayColumn(
      id: SundayWorkspace._parseInt(json['id']),
      boardId: SundayWorkspace._parseInt(json['board_id']),
      key: columnKey,
      title: json['title'] as String? ?? 'Column',
      type: ColumnType.values.firstWhere(
        (e) => e.name == typeStr,
        orElse: () => ColumnType.text,
      ),
      sortOrder: SundayWorkspace._parseInt(json['position'] ?? json['sort_order'] ?? 0),
      width: SundayWorkspace._parseInt(json['width'] ?? 150),
      isRequired: json['is_required'] == 1 || json['is_required'] == true,
      isHidden: json['is_hidden'] == 1 || json['is_hidden'] == true,
      settings: _parseSettings(json['settings']),
      statusLabels: statusLabels,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'board_id': boardId,
        'column_key': key,
        'title': title,
        'column_type': type.name,
        'sort_order': sortOrder,
        'width': width,
        'is_required': isRequired,
        'is_hidden': isHidden,
        'settings': settings,
      };

  SundayColumn copyWith({
    int? id,
    int? boardId,
    String? key,
    String? title,
    ColumnType? type,
    int? sortOrder,
    int? width,
    bool? isRequired,
    bool? isHidden,
    Map<String, dynamic>? settings,
    List<StatusLabel>? statusLabels,
  }) {
    return SundayColumn(
      id: id ?? this.id,
      boardId: boardId ?? this.boardId,
      key: key ?? this.key,
      title: title ?? this.title,
      type: type ?? this.type,
      sortOrder: sortOrder ?? this.sortOrder,
      width: width ?? this.width,
      isRequired: isRequired ?? this.isRequired,
      isHidden: isHidden ?? this.isHidden,
      settings: settings ?? this.settings,
      statusLabels: statusLabels ?? _statusLabels,
    );
  }

  /// Get status labels - from API or settings
  List<StatusLabel> get statusLabels {
    // First check if we have labels from the API (status_labels field)
    if (_statusLabels.isNotEmpty) {
      return _statusLabels;
    }
    // Fallback to settings['labels'] for backwards compatibility
    if (type != ColumnType.status || settings == null) return [];
    final labels = settings!['labels'] as List<dynamic>?;
    if (labels == null) return [];
    return labels
        .map((l) => StatusLabel.fromJson(l as Map<String, dynamic>))
        .toList();
  }
}

/// Status label for status columns
class StatusLabel {
  final String id;
  final String label;
  final String color;
  final bool isDone; // Marks item as complete

  const StatusLabel({
    required this.id,
    required this.label,
    required this.color,
    this.isDone = false,
  });

  factory StatusLabel.fromJson(Map<String, dynamic> json) {
    return StatusLabel(
      id: (json['label_key'] ?? json['id']).toString(),
      label: json['label'] as String? ?? '',
      color: json['color'] as String? ?? '#808080',
      isDone: json['is_done'] == true || json['is_done'] == 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'color': color,
        'is_done': isDone,
      };

  Color get colorValue {
    try {
      return Color(int.parse(color.replaceFirst('#', '0xFF')));
    } catch (_) {
      // Log invalid color for debugging
      assert(() {
        // ignore: avoid_print
        print('[SundayModels] WARNING: Invalid color format "$color" for status label "$label", using grey');
        return true;
      }());
      return Colors.grey;
    }
  }
}

// ============================================
// GROUP MODEL
// ============================================

/// A group within a board (like Monday groups)
class SundayGroup {
  final int id;
  final int boardId;
  final String title;
  final String color;
  final int sortOrder;
  final bool isCollapsed;
  final List<SundayItem> items;

  const SundayGroup({
    required this.id,
    required this.boardId,
    required this.title,
    this.color = '#0073ea',
    this.sortOrder = 0,
    this.isCollapsed = false,
    this.items = const [],
  });

  factory SundayGroup.fromJson(Map<String, dynamic> json) {
    return SundayGroup(
      id: SundayWorkspace._parseInt(json['id']),
      boardId: SundayWorkspace._parseInt(json['board_id']),
      title: json['title'] as String? ?? 'Untitled',
      color: json['color'] as String? ?? '#0073ea',
      sortOrder: SundayWorkspace._parseInt(json['position'] ?? json['sort_order'] ?? 0),
      isCollapsed: json['is_collapsed'] == 1 || json['is_collapsed'] == true,
      items: (json['items'] as List<dynamic>?)
              ?.map((i) => SundayItem.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'board_id': boardId,
        'title': title,
        'color': color,
        'sort_order': sortOrder,
        'is_collapsed': isCollapsed,
      };

  Color get colorValue {
    try {
      return Color(int.parse(color.replaceFirst('#', '0xFF')));
    } catch (_) {
      // Log invalid color for debugging
      assert(() {
        // ignore: avoid_print
        print('[SundayModels] WARNING: Invalid color format "$color" for group "$title", using default blue');
        return true;
      }());
      return const Color(0xFF0073ea);
    }
  }

  /// Create a copy with updated fields (for optimistic updates)
  SundayGroup copyWith({
    int? id,
    int? boardId,
    String? title,
    String? color,
    int? sortOrder,
    bool? isCollapsed,
    List<SundayItem>? items,
  }) {
    return SundayGroup(
      id: id ?? this.id,
      boardId: boardId ?? this.boardId,
      title: title ?? this.title,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      isCollapsed: isCollapsed ?? this.isCollapsed,
      items: items ?? this.items,
    );
  }
}

// ============================================
// ITEM MODEL
// ============================================

/// An item within a group (like Monday items/rows)
class SundayItem {
  final int id;
  final int boardId;
  final int groupId;
  final String name;
  final int sortOrder;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> columnValues; // column_key -> value
  final List<SundaySubitem> subitems;
  final int? parentItemId; // For subitems

  const SundayItem({
    required this.id,
    required this.boardId,
    required this.groupId,
    required this.name,
    this.sortOrder = 0,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.columnValues = const {},
    this.subitems = const [],
    this.parentItemId,
  });

  factory SundayItem.fromJson(Map<String, dynamic> json) {
    return SundayItem(
      id: SundayWorkspace._parseInt(json['id']),
      boardId: SundayWorkspace._parseInt(json['board_id']),
      groupId: SundayWorkspace._parseInt(json['group_id']),
      name: json['name'] as String? ?? '',
      sortOrder: SundayWorkspace._parseInt(json['position'] ?? json['sort_order'] ?? 0),
      createdBy: json['created_by'] as String? ?? 'unknown',
      createdAt: SundayWorkspace._parseRequiredDateTime(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? SundayWorkspace._parseDateTime(json['updated_at'])
          : null,
      columnValues: json['column_values'] != null
          ? Map<String, dynamic>.from(json['column_values'] as Map)
          : {},
      subitems: (json['subitems'] as List<dynamic>?)
              ?.map((s) => SundaySubitem.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      parentItemId: json['parent_item_id'] != null
          ? SundayWorkspace._parseInt(json['parent_item_id'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'board_id': boardId,
        'group_id': groupId,
        'name': name,
        'sort_order': sortOrder,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        'column_values': columnValues,
        'parent_item_id': parentItemId,
      };

  /// Get value for a specific column
  T? getValue<T>(String columnKey) {
    return columnValues[columnKey] as T?;
  }

  /// Check if item has subitems
  bool get hasSubitems => subitems.isNotEmpty;

  /// Create a copy with updated fields (for optimistic updates)
  SundayItem copyWith({
    int? id,
    int? boardId,
    int? groupId,
    String? name,
    int? sortOrder,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? columnValues,
    List<SundaySubitem>? subitems,
    int? parentItemId,
  }) {
    return SundayItem(
      id: id ?? this.id,
      boardId: boardId ?? this.boardId,
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      columnValues: columnValues ?? this.columnValues,
      subitems: subitems ?? this.subitems,
      parentItemId: parentItemId ?? this.parentItemId,
    );
  }
}

/// Subitem (child item)
class SundaySubitem {
  final int id;
  final int parentItemId;
  final String name;
  final int sortOrder;
  final String status;
  final DateTime? dueDate;
  final String? assignee;
  final Map<String, dynamic> columnValues;

  const SundaySubitem({
    required this.id,
    required this.parentItemId,
    required this.name,
    this.sortOrder = 0,
    this.status = 'pending',
    this.dueDate,
    this.assignee,
    this.columnValues = const {},
  });

  factory SundaySubitem.fromJson(Map<String, dynamic> json) {
    DateTime? dueDate;
    if (json['due_date'] != null && json['due_date'].toString().isNotEmpty) {
      dueDate = DateTime.tryParse(json['due_date'].toString());
    }

    return SundaySubitem(
      id: SundayWorkspace._parseInt(json['id']),
      parentItemId: SundayWorkspace._parseInt(json['parent_item_id']),
      name: json['name'] as String? ?? '',
      sortOrder: SundayWorkspace._parseInt(json['position'] ?? json['sort_order'] ?? 0),
      status: json['status'] as String? ?? 'pending',
      dueDate: dueDate,
      assignee: json['assignee'] as String?,
      columnValues: json['column_values'] != null
          ? Map<String, dynamic>.from(json['column_values'] as Map)
          : {},
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'parent_item_id': parentItemId,
        'name': name,
        'sort_order': sortOrder,
        'status': status,
        'due_date': dueDate?.toIso8601String(),
        'assignee': assignee,
        'column_values': columnValues,
      };
}

// ============================================
// ITEM UPDATE MODEL (Comments/Activity)
// ============================================

/// An update/comment on an item
class SundayItemUpdate {
  final int id;
  final int itemId;
  final String body;
  final String? bodyHtml;
  final String createdBy;
  final DateTime createdAt;
  final List<SundayUpdateReply> replies;
  final List<String> likedBy;
  final List<SundayAttachment> attachments;

  const SundayItemUpdate({
    required this.id,
    required this.itemId,
    required this.body,
    this.bodyHtml,
    required this.createdBy,
    required this.createdAt,
    this.replies = const [],
    this.likedBy = const [],
    this.attachments = const [],
  });

  factory SundayItemUpdate.fromJson(Map<String, dynamic> json) {
    return SundayItemUpdate(
      id: SundayWorkspace._parseInt(json['id']),
      itemId: SundayWorkspace._parseInt(json['item_id']),
      body: json['body'] as String? ?? '',
      bodyHtml: json['body_html'] as String?,
      createdBy: json['created_by'] as String? ?? 'unknown',
      createdAt: SundayWorkspace._parseRequiredDateTime(json['created_at']),
      replies: (json['replies'] as List<dynamic>?)
              ?.map((r) => SundayUpdateReply.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      likedBy: (json['liked_by'] as List<dynamic>?)
              ?.map((l) => l as String)
              .toList() ??
          [],
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map((a) => SundayAttachment.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Get image URLs from attachments (filters by image mime types)
  List<String> get images => attachments
      .where((a) {
        // Check mime type first, fallback to extension check
        if (a.mimeType?.startsWith('image/') == true) return true;
        final lowerUrl = a.url.toLowerCase();
        return lowerUrl.endsWith('.jpg') ||
            lowerUrl.endsWith('.jpeg') ||
            lowerUrl.endsWith('.png') ||
            lowerUrl.endsWith('.gif') ||
            lowerUrl.endsWith('.webp');
      })
      .map((a) => a.url)
      .toList();
}

/// Reply to an update
class SundayUpdateReply {
  final int id;
  final int updateId;
  final String body;
  final String createdBy;
  final DateTime createdAt;

  const SundayUpdateReply({
    required this.id,
    required this.updateId,
    required this.body,
    required this.createdBy,
    required this.createdAt,
  });

  factory SundayUpdateReply.fromJson(Map<String, dynamic> json) {
    return SundayUpdateReply(
      id: SundayWorkspace._parseInt(json['id']),
      updateId: SundayWorkspace._parseInt(json['update_id']),
      body: json['body'] as String? ?? '',
      createdBy: json['created_by'] as String? ?? 'unknown',
      createdAt: SundayWorkspace._parseRequiredDateTime(json['created_at']),
    );
  }
}

/// File attachment
class SundayAttachment {
  final int id;
  final String name;
  final String url;
  final String? mimeType;
  final int? size;

  const SundayAttachment({
    required this.id,
    required this.name,
    required this.url,
    this.mimeType,
    this.size,
  });

  factory SundayAttachment.fromJson(Map<String, dynamic> json) {
    return SundayAttachment(
      id: SundayWorkspace._parseInt(json['id']),
      name: json['name'] as String? ?? '',
      url: json['url'] as String? ?? '',
      mimeType: json['mime_type'] as String?,
      size: json['size'] != null ? SundayWorkspace._parseInt(json['size']) : null,
    );
  }
}

// ============================================
// VIEW MODEL
// ============================================

/// View types - how to display board data
enum ViewType {
  table, // Default table view
  kanban, // Kanban board
  calendar, // Calendar view
  timeline, // Gantt/timeline view
  chart, // Charts/analytics
  form, // Form view for input
  map, // Map view for locations
}

/// Saved view configuration
class SundayView {
  final int id;
  final int boardId;
  final String name;
  final ViewType type;
  final String createdBy;
  final bool isDefault;
  final Map<String, dynamic> settings; // Filters, sorts, column visibility

  const SundayView({
    required this.id,
    required this.boardId,
    required this.name,
    required this.type,
    required this.createdBy,
    this.isDefault = false,
    this.settings = const {},
  });

  factory SundayView.fromJson(Map<String, dynamic> json) {
    return SundayView(
      id: SundayWorkspace._parseInt(json['id']),
      boardId: SundayWorkspace._parseInt(json['board_id']),
      name: json['name'] as String? ?? '',
      type: ViewType.values.firstWhere(
        (e) => e.name == (json['view_type'] ?? json['type']),
        orElse: () => ViewType.table,
      ),
      createdBy: json['created_by'] as String? ?? 'unknown',
      isDefault: json['is_default'] == 1 || json['is_default'] == true,
      settings: json['settings'] != null
          ? Map<String, dynamic>.from(json['settings'] as Map)
          : {},
    );
  }
}

// ============================================
// BOARD PERMISSION MODEL
// ============================================

/// Board access level
enum BoardAccessLevel {
  owner, // Full control
  editor, // Can edit items
  viewer, // Read only
}

/// Board member with access
class SundayBoardMember {
  final int id;
  final int boardId;
  final String username;
  final BoardAccessLevel accessLevel;
  final DateTime addedAt;
  final String addedBy;

  const SundayBoardMember({
    required this.id,
    required this.boardId,
    required this.username,
    required this.accessLevel,
    required this.addedAt,
    required this.addedBy,
  });

  factory SundayBoardMember.fromJson(Map<String, dynamic> json) {
    // Map PHP access levels to Dart enum: edit -> editor, view -> viewer
    final accessStr = json['access_level'] as String? ?? 'view';
    final accessLevel = switch (accessStr) {
      'owner' => BoardAccessLevel.owner,
      'edit' => BoardAccessLevel.editor,
      'editor' => BoardAccessLevel.editor,
      'view' => BoardAccessLevel.viewer,
      'viewer' => BoardAccessLevel.viewer,
      _ => BoardAccessLevel.viewer,
    };

    return SundayBoardMember(
      id: SundayWorkspace._parseInt(json['id']),
      boardId: SundayWorkspace._parseInt(json['board_id']),
      username: json['username'] as String? ?? '',
      accessLevel: accessLevel,
      addedAt: SundayWorkspace._parseDateTime(json['added_at']),
      addedBy: json['added_by'] as String? ?? 'unknown',
    );
  }
}

/// Access level for group/item members (subset of board access)
enum GranularAccessLevel {
  edit, // Can edit
  view, // Read only
}

/// Group member with access (for granular group-level permissions)
class GroupMember {
  final int id;
  final int groupId;
  final int boardId;
  final String username;
  final String? name; // Display name from user lookup
  final GranularAccessLevel accessLevel;
  final DateTime addedAt;
  final String addedBy;

  const GroupMember({
    required this.id,
    required this.groupId,
    required this.boardId,
    required this.username,
    this.name,
    required this.accessLevel,
    required this.addedAt,
    required this.addedBy,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    final accessStr = json['access_level'] as String? ?? 'view';
    final accessLevel = switch (accessStr) {
      'edit' => GranularAccessLevel.edit,
      _ => GranularAccessLevel.view,
    };

    return GroupMember(
      id: SundayWorkspace._parseInt(json['id']),
      groupId: SundayWorkspace._parseInt(json['group_id']),
      boardId: SundayWorkspace._parseInt(json['board_id']),
      username: json['username'] as String? ?? '',
      name: json['name'] as String?,
      accessLevel: accessLevel,
      addedAt: SundayWorkspace._parseDateTime(json['added_at']),
      addedBy: json['added_by'] as String? ?? 'unknown',
    );
  }

  /// Display name (name if available, otherwise username)
  String get displayName => name?.isNotEmpty == true ? name! : username;
}

/// Item member with access (for granular item-level permissions)
class ItemMember {
  final int id;
  final int itemId;
  final int boardId;
  final String username;
  final String? name; // Display name from user lookup
  final GranularAccessLevel accessLevel;
  final DateTime addedAt;
  final String addedBy;

  const ItemMember({
    required this.id,
    required this.itemId,
    required this.boardId,
    required this.username,
    this.name,
    required this.accessLevel,
    required this.addedAt,
    required this.addedBy,
  });

  factory ItemMember.fromJson(Map<String, dynamic> json) {
    final accessStr = json['access_level'] as String? ?? 'view';
    final accessLevel = switch (accessStr) {
      'edit' => GranularAccessLevel.edit,
      _ => GranularAccessLevel.view,
    };

    return ItemMember(
      id: SundayWorkspace._parseInt(json['id']),
      itemId: SundayWorkspace._parseInt(json['item_id']),
      boardId: SundayWorkspace._parseInt(json['board_id']),
      username: json['username'] as String? ?? '',
      name: json['name'] as String?,
      accessLevel: accessLevel,
      addedAt: SundayWorkspace._parseDateTime(json['added_at']),
      addedBy: json['added_by'] as String? ?? 'unknown',
    );
  }

  /// Display name (name if available, otherwise username)
  String get displayName => name?.isNotEmpty == true ? name! : username;
}

// ============================================
// ACTIVITY LOG MODEL
// ============================================

/// Types of activity that can occur
enum ActivityType {
  itemCreated,
  itemUpdated,
  itemDeleted,
  itemMoved,
  statusChanged,
  personAssigned,
  commentAdded,
  fileUploaded,
  columnValueChanged,
  groupCreated,
  groupDeleted,
  boardSettingsChanged,
  automationTriggered,
}

/// Activity log entry for tracking board changes
class SundayActivityLog {
  final int id;
  final int boardId;
  final int? itemId;
  final String? itemName;
  final ActivityType activityType;
  final String description;
  final String performedBy;
  final DateTime performedAt;
  final Map<String, dynamic>? oldValue;
  final Map<String, dynamic>? newValue;
  final String? columnKey;

  const SundayActivityLog({
    required this.id,
    required this.boardId,
    this.itemId,
    this.itemName,
    required this.activityType,
    required this.description,
    required this.performedBy,
    required this.performedAt,
    this.oldValue,
    this.newValue,
    this.columnKey,
  });

  factory SundayActivityLog.fromJson(Map<String, dynamic> json) {
    return SundayActivityLog(
      id: SundayWorkspace._parseInt(json['id']),
      boardId: SundayWorkspace._parseInt(json['board_id']),
      itemId: json['item_id'] != null ? SundayWorkspace._parseInt(json['item_id']) : null,
      itemName: json['item_name'] as String?,
      activityType: ActivityType.values.firstWhere(
        (e) => e.name == (json['activity_type'] ?? json['action']),
        orElse: () => ActivityType.itemUpdated,
      ),
      description: json['description'] as String? ?? '',
      performedBy: (json['performed_by'] ?? json['username']) as String? ?? 'unknown',
      performedAt: SundayWorkspace._parseDateTime(json['performed_at'] ?? json['created_at']),
      oldValue: json['old_value'] != null
          ? Map<String, dynamic>.from(json['old_value'] as Map)
          : null,
      newValue: json['new_value'] != null
          ? Map<String, dynamic>.from(json['new_value'] as Map)
          : null,
      columnKey: json['column_key'] as String?,
    );
  }

  /// Get icon for activity type
  IconData get icon {
    switch (activityType) {
      case ActivityType.itemCreated:
        return Icons.add_circle_outline;
      case ActivityType.itemUpdated:
        return Icons.edit_outlined;
      case ActivityType.itemDeleted:
        return Icons.delete_outline;
      case ActivityType.itemMoved:
        return Icons.drive_file_move_outlined;
      case ActivityType.statusChanged:
        return Icons.swap_horiz;
      case ActivityType.personAssigned:
        return Icons.person_add_outlined;
      case ActivityType.commentAdded:
        return Icons.comment_outlined;
      case ActivityType.fileUploaded:
        return Icons.attach_file;
      case ActivityType.columnValueChanged:
        return Icons.edit_note;
      case ActivityType.groupCreated:
        return Icons.create_new_folder_outlined;
      case ActivityType.groupDeleted:
        return Icons.folder_delete_outlined;
      case ActivityType.boardSettingsChanged:
        return Icons.settings_outlined;
      case ActivityType.automationTriggered:
        return Icons.bolt;
    }
  }

  /// Get color for activity type
  Color get color {
    switch (activityType) {
      case ActivityType.itemCreated:
        return const Color(0xFF00C875);
      case ActivityType.itemDeleted:
        return const Color(0xFFE2445C);
      case ActivityType.statusChanged:
        return const Color(0xFF0073EA);
      case ActivityType.personAssigned:
        return const Color(0xFFA25DDC);
      case ActivityType.automationTriggered:
        return const Color(0xFFFDAB3D);
      default:
        return const Color(0xFF808080);
    }
  }
}

// ============================================
// NEW HIGH-VALUE FEATURE MODELS
// ============================================

/// Dashboard data with KPIs
class SundayDashboardData {
  final Map<String, dynamic> board;
  final SundayKpis kpis;
  final List<SundayGroupStat> groupStats;
  final Map<String, SundayStatusStat> statusStats;
  final Map<String, SundayPersonStat> personStats;
  final Map<String, SundayDateStat> dateStats;

  SundayDashboardData({
    required this.board,
    required this.kpis,
    required this.groupStats,
    required this.statusStats,
    required this.personStats,
    required this.dateStats,
  });

  factory SundayDashboardData.fromJson(Map<String, dynamic> json) {
    return SundayDashboardData(
      board: Map<String, dynamic>.from(json['board'] ?? {}),
      kpis: SundayKpis.fromJson(json['kpis'] ?? {}),
      groupStats: (json['group_stats'] as List?)
              ?.map((g) => SundayGroupStat.fromJson(g))
              .toList() ??
          [],
      statusStats: (json['status_stats'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), SundayStatusStat.fromJson(v)),
          ) ??
          {},
      personStats: (json['person_stats'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), SundayPersonStat.fromJson(v)),
          ) ??
          {},
      dateStats: (json['date_stats'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), SundayDateStat.fromJson(v)),
          ) ??
          {},
    );
  }
}

/// Key Performance Indicators
class SundayKpis {
  final int totalItems;
  final int completedItems;
  final double completionRate;
  final int itemsThisWeek;
  final int recentActivity;

  SundayKpis({
    required this.totalItems,
    required this.completedItems,
    required this.completionRate,
    required this.itemsThisWeek,
    required this.recentActivity,
  });

  factory SundayKpis.fromJson(Map<String, dynamic> json) {
    return SundayKpis(
      totalItems: SundayWorkspace._parseInt(json['total_items'] ?? 0),
      completedItems: SundayWorkspace._parseInt(json['completed_items'] ?? 0),
      completionRate: (json['completion_rate'] ?? 0).toDouble(),
      itemsThisWeek: SundayWorkspace._parseInt(json['items_this_week'] ?? 0),
      recentActivity: SundayWorkspace._parseInt(json['recent_activity'] ?? 0),
    );
  }
}

/// Group statistics
class SundayGroupStat {
  final int id;
  final String title;
  final String color;
  final int itemCount;

  SundayGroupStat({
    required this.id,
    required this.title,
    required this.color,
    required this.itemCount,
  });

  factory SundayGroupStat.fromJson(Map<String, dynamic> json) {
    return SundayGroupStat(
      id: SundayWorkspace._parseInt(json['id']),
      title: json['title'] ?? '',
      color: json['color'] ?? '#808080',
      itemCount: SundayWorkspace._parseInt(json['item_count'] ?? 0),
    );
  }
}

/// Status column statistics
class SundayStatusStat {
  final String title;
  final List<SundayLabelCount> labels;

  SundayStatusStat({required this.title, required this.labels});

  factory SundayStatusStat.fromJson(Map<String, dynamic> json) {
    return SundayStatusStat(
      title: json['title'] ?? '',
      labels: (json['labels'] as List?)
              ?.map((l) => SundayLabelCount.fromJson(l))
              .toList() ??
          [],
    );
  }
}

/// Label count for status stats
class SundayLabelCount {
  final String key;
  final String label;
  final String color;
  final bool isDone;
  final int count;

  SundayLabelCount({
    required this.key,
    required this.label,
    required this.color,
    required this.isDone,
    required this.count,
  });

  factory SundayLabelCount.fromJson(Map<String, dynamic> json) {
    return SundayLabelCount(
      key: json['key'] ?? '',
      label: json['label'] ?? '',
      color: json['color'] ?? '#808080',
      isDone: json['is_done'] == true,
      count: SundayWorkspace._parseInt(json['count'] ?? 0),
    );
  }
}

/// Person/assignee statistics
class SundayPersonStat {
  final String title;
  final List<Map<String, dynamic>> assignments;
  final int unassigned;

  SundayPersonStat({
    required this.title,
    required this.assignments,
    required this.unassigned,
  });

  factory SundayPersonStat.fromJson(Map<String, dynamic> json) {
    return SundayPersonStat(
      title: json['title'] ?? '',
      assignments: (json['assignments'] as List?)
              ?.map((a) => Map<String, dynamic>.from(a))
              .toList() ??
          [],
      unassigned: SundayWorkspace._parseInt(json['unassigned'] ?? 0),
    );
  }
}

/// Date column statistics
class SundayDateStat {
  final String title;
  final int overdue;
  final int dueToday;
  final int upcoming7Days;

  SundayDateStat({
    required this.title,
    required this.overdue,
    required this.dueToday,
    required this.upcoming7Days,
  });

  factory SundayDateStat.fromJson(Map<String, dynamic> json) {
    return SundayDateStat(
      title: json['title'] ?? '',
      overdue: SundayWorkspace._parseInt(json['overdue'] ?? 0),
      dueToday: SundayWorkspace._parseInt(json['due_today'] ?? 0),
      upcoming7Days: SundayWorkspace._parseInt(json['upcoming_7_days'] ?? 0),
    );
  }
}

/// Analytics data for a board
class SundayAnalyticsData {
  final List<Map<String, dynamic>> itemsPerDay;
  final List<Map<String, dynamic>> activityPerDay;
  final List<Map<String, dynamic>> activityByUser;
  final List<Map<String, dynamic>> activityByType;
  final Map<String, String> period;

  SundayAnalyticsData({
    required this.itemsPerDay,
    required this.activityPerDay,
    required this.activityByUser,
    required this.activityByType,
    required this.period,
  });

  factory SundayAnalyticsData.fromJson(Map<String, dynamic> json) {
    return SundayAnalyticsData(
      itemsPerDay: (json['items_per_day'] as List?)
              ?.map((i) => Map<String, dynamic>.from(i))
              .toList() ??
          [],
      activityPerDay: (json['activity_per_day'] as List?)
              ?.map((a) => Map<String, dynamic>.from(a))
              .toList() ??
          [],
      activityByUser: (json['activity_by_user'] as List?)
              ?.map((a) => Map<String, dynamic>.from(a))
              .toList() ??
          [],
      activityByType: (json['activity_by_type'] as List?)
              ?.map((a) => Map<String, dynamic>.from(a))
              .toList() ??
          [],
      period: Map<String, String>.from(json['period'] ?? {}),
    );
  }
}

/// Saved filter
class SundaySavedFilter {
  final int id;
  final int boardId;
  final String name;
  final String? description;
  final Map<String, dynamic> filterConfig;
  final bool isShared;
  final String createdBy;
  final DateTime createdAt;

  SundaySavedFilter({
    required this.id,
    required this.boardId,
    required this.name,
    this.description,
    required this.filterConfig,
    required this.isShared,
    required this.createdBy,
    required this.createdAt,
  });

  factory SundaySavedFilter.fromJson(Map<String, dynamic> json) {
    return SundaySavedFilter(
      id: SundayWorkspace._parseInt(json['id']),
      boardId: SundayWorkspace._parseInt(json['board_id']),
      name: json['name'] ?? '',
      description: json['description'],
      filterConfig: Map<String, dynamic>.from(json['filter_config'] ?? {}),
      isShared: json['is_shared'] == 1 || json['is_shared'] == true,
      createdBy: json['created_by'] ?? '',
      createdAt: SundayWorkspace._parseRequiredDateTime(json['created_at']),
    );
  }
}

/// Filter result
class SundayFilterResult {
  final List<SundayItem> items;
  final int total;
  final int limit;
  final int offset;

  SundayFilterResult({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  factory SundayFilterResult.fromJson(Map<String, dynamic> json) {
    return SundayFilterResult(
      items: (json['items'] as List?)
              ?.map((i) => SundayItem.fromJson(i))
              .toList() ??
          [],
      total: SundayWorkspace._parseInt(json['total'] ?? 0),
      limit: SundayWorkspace._parseInt(json['limit'] ?? 100),
      offset: SundayWorkspace._parseInt(json['offset'] ?? 0),
    );
  }
}

/// Bulk operation result
class SundayBulkResult {
  final int successCount;
  final int totalCount;
  final String? message;
  final List<String> errors;

  SundayBulkResult({
    required this.successCount,
    required this.totalCount,
    this.message,
    this.errors = const [],
  });

  factory SundayBulkResult.fromJson(Map<String, dynamic> json) {
    return SundayBulkResult(
      successCount: SundayWorkspace._parseInt(json['updated_count'] ?? json['moved_count'] ?? json['deleted_count'] ?? 0),
      totalCount: SundayWorkspace._parseInt(json['total_count'] ?? 0),
      message: json['message'],
      errors: (json['errors'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  bool get isSuccess => errors.isEmpty && successCount == totalCount;
}

/// Bulk duplicate result
class SundayBulkDuplicateResult {
  final List<int> duplicatedIds;
  final int duplicatedCount;
  final String? message;

  SundayBulkDuplicateResult({
    required this.duplicatedIds,
    required this.duplicatedCount,
    this.message,
  });

  factory SundayBulkDuplicateResult.fromJson(Map<String, dynamic> json) {
    return SundayBulkDuplicateResult(
      duplicatedIds: (json['duplicated_ids'] as List?)
              ?.map((id) => SundayWorkspace._parseInt(id))
              .toList() ??
          [],
      duplicatedCount: SundayWorkspace._parseInt(json['duplicated_count'] ?? 0),
      message: json['message'],
    );
  }
}

/// Item dependencies
class SundayDependencies {
  final List<SundayDependency> blockedBy;
  final List<SundayDependency> blocking;

  SundayDependencies({required this.blockedBy, required this.blocking});

  factory SundayDependencies.fromJson(Map<String, dynamic> json) {
    return SundayDependencies(
      blockedBy: (json['blocked_by'] as List?)
              ?.map((d) => SundayDependency.fromJson(d))
              .toList() ??
          [],
      blocking: (json['blocking'] as List?)
              ?.map((d) => SundayDependency.fromJson(d))
              .toList() ??
          [],
    );
  }
}

/// Single dependency
class SundayDependency {
  final int id;
  final int itemId;
  final int dependsOnItemId;
  final String itemName;
  final int boardId;
  final String type;

  SundayDependency({
    required this.id,
    required this.itemId,
    required this.dependsOnItemId,
    required this.itemName,
    required this.boardId,
    required this.type,
  });

  factory SundayDependency.fromJson(Map<String, dynamic> json) {
    return SundayDependency(
      id: SundayWorkspace._parseInt(json['id']),
      itemId: SundayWorkspace._parseInt(json['item_id']),
      dependsOnItemId: SundayWorkspace._parseInt(json['depends_on_item_id']),
      itemName: json['item_name'] ?? '',
      boardId: SundayWorkspace._parseInt(json['board_id']),
      type: json['dependency_type'] ?? 'blocks',
    );
  }
}

/// Formula function definition
class FormulaFunction {
  final String name;
  final String description;
  final String syntax;

  FormulaFunction({
    required this.name,
    required this.description,
    required this.syntax,
  });

  factory FormulaFunction.fromJson(Map<String, dynamic> json) {
    return FormulaFunction(
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      syntax: json['syntax'] ?? '',
    );
  }
}

/// Duplicate detection result
class SundayDuplicate {
  final String type;
  final String? columnKey;
  final String value;
  final List<int> itemIds;
  final int count;

  SundayDuplicate({
    required this.type,
    this.columnKey,
    required this.value,
    required this.itemIds,
    required this.count,
  });

  factory SundayDuplicate.fromJson(Map<String, dynamic> json) {
    return SundayDuplicate(
      type: json['type'] ?? 'name',
      columnKey: json['column_key'],
      value: json['value'] ?? '',
      itemIds: (json['item_ids'] as List?)
              ?.map((id) => SundayWorkspace._parseInt(id))
              .toList() ??
          [],
      count: SundayWorkspace._parseInt(json['count'] ?? 0),
    );
  }
}

/// Similar item (from duplicate detection)
class SundaySimilarItem {
  final int id;
  final String name;
  final double similarity;

  SundaySimilarItem({
    required this.id,
    required this.name,
    required this.similarity,
  });

  factory SundaySimilarItem.fromJson(Map<String, dynamic> json) {
    return SundaySimilarItem(
      id: SundayWorkspace._parseInt(json['id']),
      name: json['name'] ?? '',
      similarity: (json['similarity'] ?? 0).toDouble(),
    );
  }
}

/// Export result
class SundayExportResult {
  final String filename;
  final String content;
  final int? rows;
  final Map<String, dynamic>? board;

  SundayExportResult({
    required this.filename,
    required this.content,
    this.rows,
    this.board,
  });

  factory SundayExportResult.fromJson(Map<String, dynamic> json) {
    return SundayExportResult(
      filename: json['filename'] ?? 'export',
      content: json['content'] ?? '',
      rows: json['rows'] != null ? SundayWorkspace._parseInt(json['rows']) : null,
      board: json['board'] != null ? Map<String, dynamic>.from(json['board']) : null,
    );
  }
}

/// Item template
class SundayItemTemplate {
  final int id;
  final int boardId;
  final String name;
  final String? description;
  final Map<String, dynamic> defaultValues;
  final bool isShared;
  final String createdBy;
  final DateTime createdAt;

  SundayItemTemplate({
    required this.id,
    required this.boardId,
    required this.name,
    this.description,
    required this.defaultValues,
    required this.isShared,
    required this.createdBy,
    required this.createdAt,
  });

  factory SundayItemTemplate.fromJson(Map<String, dynamic> json) {
    return SundayItemTemplate(
      id: SundayWorkspace._parseInt(json['id']),
      boardId: SundayWorkspace._parseInt(json['board_id']),
      name: json['name'] ?? '',
      description: json['description'],
      defaultValues: Map<String, dynamic>.from(json['default_values'] ?? {}),
      isShared: json['is_shared'] == 1 || json['is_shared'] == true,
      createdBy: json['created_by'] ?? '',
      createdAt: SundayWorkspace._parseRequiredDateTime(json['created_at']),
    );
  }
}

// ============================================
// BOARD TEMPLATES (Saved Templates)
// ============================================

/// List of board templates (built-in + saved)
class SundayBoardTemplateList {
  final List<SundayBoardTemplateInfo> builtinTemplates;
  final List<SundayBoardTemplateInfo> savedTemplates;
  final List<String> categories;

  SundayBoardTemplateList({
    required this.builtinTemplates,
    required this.savedTemplates,
    required this.categories,
  });

  /// All templates combined
  List<SundayBoardTemplateInfo> get allTemplates => [...builtinTemplates, ...savedTemplates];

  factory SundayBoardTemplateList.fromJson(Map<String, dynamic> json) {
    return SundayBoardTemplateList(
      builtinTemplates: (json['builtin_templates'] as List?)
              ?.map((t) => SundayBoardTemplateInfo.fromJson(t, isBuiltin: true))
              .toList() ??
          [],
      savedTemplates: (json['saved_templates'] as List?)
              ?.map((t) => SundayBoardTemplateInfo.fromJson(t, isBuiltin: false))
              .toList() ??
          [],
      categories: List<String>.from(json['categories'] ?? []),
    );
  }
}

/// Board template summary info (for listing)
class SundayBoardTemplateInfo {
  final String id;
  final String name;
  final String? description;
  final String icon;
  final String color;
  final String category;
  final bool isBuiltin;
  final bool isShared;
  final bool includeItems;
  final String? createdBy;
  final DateTime? createdAt;

  SundayBoardTemplateInfo({
    required this.id,
    required this.name,
    this.description,
    required this.icon,
    required this.color,
    required this.category,
    required this.isBuiltin,
    this.isShared = true,
    this.includeItems = false,
    this.createdBy,
    this.createdAt,
  });

  factory SundayBoardTemplateInfo.fromJson(Map<String, dynamic> json, {bool isBuiltin = false}) {
    return SundayBoardTemplateInfo(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      icon: json['icon'] ?? 'dashboard',
      color: json['color'] ?? '#579bfc',
      category: json['category'] ?? 'Custom',
      isBuiltin: json['is_builtin'] == true || isBuiltin,
      isShared: json['is_shared'] == 1 || json['is_shared'] == true,
      includeItems: json['include_items'] == 1 || json['include_items'] == true,
      createdBy: json['created_by'],
      createdAt: json['created_at'] != null ? SundayWorkspace._parseRequiredDateTime(json['created_at']) : null,
    );
  }
}

/// Full saved board template with data
class SundaySavedBoardTemplate {
  final String id;
  final String name;
  final String? description;
  final String icon;
  final String color;
  final String category;
  final bool isBuiltin;
  final bool isShared;
  final bool includeItems;
  final SundayBoardTemplateData templateData;
  final int? sourceBoardId;
  final String? createdBy;
  final DateTime? createdAt;

  SundaySavedBoardTemplate({
    required this.id,
    required this.name,
    this.description,
    required this.icon,
    required this.color,
    required this.category,
    required this.isBuiltin,
    this.isShared = true,
    this.includeItems = false,
    required this.templateData,
    this.sourceBoardId,
    this.createdBy,
    this.createdAt,
  });

  factory SundaySavedBoardTemplate.fromJson(Map<String, dynamic> json) {
    return SundaySavedBoardTemplate(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      icon: json['icon'] ?? 'dashboard',
      color: json['color'] ?? '#579bfc',
      category: json['category'] ?? 'Custom',
      isBuiltin: json['is_builtin'] == true,
      isShared: json['is_shared'] == 1 || json['is_shared'] == true,
      includeItems: json['include_items'] == 1 || json['include_items'] == true,
      templateData: SundayBoardTemplateData.fromJson(json['template_data'] ?? {}),
      sourceBoardId: json['source_board_id'] != null ? SundayWorkspace._parseInt(json['source_board_id']) : null,
      createdBy: json['created_by'],
      createdAt: json['created_at'] != null ? SundayWorkspace._parseRequiredDateTime(json['created_at']) : null,
    );
  }
}

/// Template data containing columns, groups, and optionally items
class SundayBoardTemplateData {
  final List<SundayTemplateColumn> columns;
  final List<SundayTemplateGroup> groups;
  final List<SundayTemplateItem>? items;

  SundayBoardTemplateData({
    required this.columns,
    required this.groups,
    this.items,
  });

  factory SundayBoardTemplateData.fromJson(Map<String, dynamic> json) {
    return SundayBoardTemplateData(
      columns: (json['columns'] as List?)
              ?.map((c) => SundayTemplateColumn.fromJson(c))
              .toList() ??
          [],
      groups: (json['groups'] as List?)
              ?.map((g) => SundayTemplateGroup.fromJson(g))
              .toList() ??
          [],
      items: json['items'] != null
          ? (json['items'] as List).map((i) => SundayTemplateItem.fromJson(i)).toList()
          : null,
    );
  }
}

/// Column definition in a template
class SundayTemplateColumn {
  final String columnKey;
  final String title;
  final String type;
  final int? width;
  final Map<String, dynamic>? settings;
  final List<SundayTemplateStatusLabel>? statusLabels;

  SundayTemplateColumn({
    required this.columnKey,
    required this.title,
    required this.type,
    this.width,
    this.settings,
    this.statusLabels,
  });

  factory SundayTemplateColumn.fromJson(Map<String, dynamic> json) {
    return SundayTemplateColumn(
      columnKey: json['column_key'] ?? json['key'] ?? '',
      title: json['title'] ?? '',
      type: json['type'] ?? 'text',
      width: json['width'],
      settings: json['settings'] is Map ? Map<String, dynamic>.from(json['settings']) : null,
      statusLabels: json['status_labels'] != null
          ? (json['status_labels'] as List).map((l) => SundayTemplateStatusLabel.fromJson(l)).toList()
          : null,
    );
  }
}

/// Status label in a template column
class SundayTemplateStatusLabel {
  final String labelKey;
  final String label;
  final String color;
  final bool isDone;

  SundayTemplateStatusLabel({
    required this.labelKey,
    required this.label,
    required this.color,
    this.isDone = false,
  });

  factory SundayTemplateStatusLabel.fromJson(Map<String, dynamic> json) {
    return SundayTemplateStatusLabel(
      labelKey: json['label_key'] ?? '',
      label: json['label'] ?? '',
      color: json['color'] ?? '#c4c4c4',
      isDone: json['is_done'] == 1 || json['is_done'] == true,
    );
  }
}

/// Group definition in a template
class SundayTemplateGroup {
  final String title;
  final String? color;
  final bool isCollapsed;

  SundayTemplateGroup({
    required this.title,
    this.color,
    this.isCollapsed = false,
  });

  factory SundayTemplateGroup.fromJson(Map<String, dynamic> json) {
    return SundayTemplateGroup(
      title: json['title'] ?? '',
      color: json['color'],
      isCollapsed: json['is_collapsed'] == true || json['is_collapsed'] == 1,
    );
  }
}

/// Item definition in a template (when includeItems is true)
class SundayTemplateItem {
  final String name;
  final int groupIndex;
  final Map<String, dynamic> columnValues;

  SundayTemplateItem({
    required this.name,
    required this.groupIndex,
    required this.columnValues,
  });

  factory SundayTemplateItem.fromJson(Map<String, dynamic> json) {
    return SundayTemplateItem(
      name: json['name'] ?? '',
      groupIndex: json['group_index'] ?? 0,
      columnValues: Map<String, dynamic>.from(json['column_values'] ?? {}),
    );
  }
}
