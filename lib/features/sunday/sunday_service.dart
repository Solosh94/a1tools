/// Sunday Service for A1 Tools
/// Handles all Sunday board, item, and automation operations
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/api_config.dart';
import 'models/sunday_models.dart';
import 'models/automation_models.dart';

// ============================================
// Sunday SERVICE RESULT TYPE
// ============================================

/// Result wrapper for Sunday service operations that provides error details
class SundayResult<T> {
  final T? data;
  final String? error;
  final bool success;
  final List<String>? warnings;

  const SundayResult.success(this.data, {this.warnings})
      : success = true,
        error = null;

  const SundayResult.failure(this.error)
      : success = false,
        data = null,
        warnings = null;

  /// Check if operation had warnings (even if successful)
  bool get hasWarnings => warnings != null && warnings!.isNotEmpty;
}

/// Main Sunday service - handles all API calls for boards, items, automations
class SundayService {
  SundayService._();

  static const String _baseUrl = '${ApiConfig.apiBase}/sunday';

  /// Safe int parser for API responses (handles both int and String)
  static int? _parseId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  /// Extract error message from API response or exception
  static String _extractError(dynamic e, [http.Response? response]) {
    if (response != null && response.statusCode != 200) {
      try {
        final data = jsonDecode(response.body);
        if (data['error'] != null) return data['error'].toString();
      } catch (_) {}
      return 'HTTP ${response.statusCode}: ${response.reasonPhrase}';
    }
    if (e is SocketException) return 'Network error: Unable to connect';
    if (e is FormatException) return 'Invalid response format';
    return e.toString();
  }

  // ============================================
  // ADMIN CHECK METHODS
  // ============================================

  /// Check if user has Sunday admin privileges
  /// Sunday admins can create/delete workspaces, boards, manage members, etc.
  static Future<bool> hasSundayAdminAccess(String username) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.userManagement}?action=get_crm_admin&username=$username&requesting_username=$username'),
        headers: {'X-Username': username},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['crm_admin'] == true || data['crm_admin'] == 1;
        }
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error checking Sunday admin: $e');
      return false;
    }
  }

  /// Check if user has Sunday admin based on role (fallback)
  /// Developers, administrators, management, and dispatchers have Sunday admin by default
  static bool hasRoleBasedSundayAccess(String role) {
    final adminRoles = ['developer', 'administrator', 'management', 'dispatcher'];
    return adminRoles.contains(role.toLowerCase());
  }

  // ============================================
  // LOCAL PREFERENCES - Column Widths, View Settings
  // ============================================

  static const String _columnWidthsKeyPrefix = 'crm_column_widths_';
  static const String _viewTypeKeyPrefix = 'crm_view_type_';
  static const String _collapsedGroupsKeyPrefix = 'crm_collapsed_groups_';

  /// Save column widths for a board to local storage
  static Future<void> saveColumnWidths(int boardId, Map<String, double> widths) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_columnWidthsKeyPrefix$boardId';
      // Convert double values to String for JSON serialization
      final stringWidths = widths.map((k, v) => MapEntry(k, v.toString()));
      await prefs.setString(key, jsonEncode(stringWidths));
    } catch (e) {
      debugPrint('[SundayService] Error saving column widths: $e');
    }
  }

  /// Load column widths for a board from local storage
  static Future<Map<String, double>> loadColumnWidths(int boardId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_columnWidthsKeyPrefix$boardId';
      final stored = prefs.getString(key);
      if (stored != null) {
        final decoded = jsonDecode(stored) as Map<String, dynamic>;
        return decoded.map((k, v) => MapEntry(k, double.tryParse(v.toString()) ?? 150.0));
      }
    } catch (e) {
      debugPrint('[SundayService] Error loading column widths: $e');
    }
    return {};
  }

  /// Save the preferred view type for a board
  static Future<void> saveViewType(int boardId, String viewType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_viewTypeKeyPrefix$boardId', viewType);
    } catch (e) {
      debugPrint('[SundayService] Error saving view type: $e');
    }
  }

  /// Load the preferred view type for a board
  static Future<String?> loadViewType(int boardId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('$_viewTypeKeyPrefix$boardId');
    } catch (e) {
      debugPrint('[SundayService] Error loading view type: $e');
    }
    return null;
  }

  /// Save collapsed groups state for a board
  static Future<void> saveCollapsedGroups(int boardId, Set<int> collapsedGroupIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_collapsedGroupsKeyPrefix$boardId';
      await prefs.setStringList(key, collapsedGroupIds.map((id) => id.toString()).toList());
    } catch (e) {
      debugPrint('[SundayService] Error saving collapsed groups: $e');
    }
  }

  /// Load collapsed groups state for a board
  static Future<Set<int>> loadCollapsedGroups(int boardId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_collapsedGroupsKeyPrefix$boardId';
      final stored = prefs.getStringList(key);
      if (stored != null) {
        return stored.map((s) => int.tryParse(s) ?? 0).where((id) => id > 0).toSet();
      }
    } catch (e) {
      debugPrint('[SundayService] Error loading collapsed groups: $e');
    }
    return {};
  }

  // ============================================
  // USER METHODS - For Person Column
  // ============================================

  /// Get all app users for person assignment
  /// Returns list of {username, name, email, first_name, last_name} maps
  /// [requestingUsername] is required for authentication
  static Future<List<Map<String, dynamic>>> getAppUsers({String? requestingUsername}) async {
    try {
      // Use the Sunday API endpoint which has lighter authentication requirements
      final url = '$_baseUrl/boards.php?action=get_users&username=${requestingUsername ?? ''}';

      final response = await http.get(Uri.parse(url));

      debugPrint('[SundayService] getAppUsers response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null && data['data']['users'] != null) {
          return (data['data']['users'] as List).map((u) {
            final firstName = u['first_name']?.toString() ?? '';
            final lastName = u['last_name']?.toString() ?? '';
            final fullName = '$firstName $lastName'.trim();
            final email = u['email']?.toString() ?? '';
            return <String, dynamic>{
              'username': u['username']?.toString() ?? '',
              'name': fullName.isNotEmpty ? fullName : u['username']?.toString() ?? '',
              'first_name': firstName,
              'last_name': lastName,
              'email': email,
            };
          }).toList();
        } else {
          debugPrint('[SundayService] getAppUsers API error: ${data['error']}');
        }
      } else {
        debugPrint('[SundayService] getAppUsers HTTP error: ${response.statusCode} - ${response.body}');
      }
      return [];
    } catch (e) {
      debugPrint('[SundayService] Error getting app users: $e');
      return [];
    }
  }

  // ============================================
  // WORKSPACE METHODS
  // ============================================

  /// Get all workspaces for current user
  static Future<List<SundayWorkspace>> getWorkspaces(String username) async {
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse('$_baseUrl/workspaces.php?action=list&username=$username&_t=$ts'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final workspaces = (data['data']['workspaces'] as List)
              .map((w) => SundayWorkspace.fromJson(w))
              .toList();
          return workspaces;
        }
      }
      return [];
    } catch (e) {
      debugPrint('[SundayService] Error getting workspaces: $e');
      return [];
    }
  }

  /// Create a new workspace
  static Future<int?> createWorkspace({
    required String name,
    String? description,
    String? color,
    String? icon,
    required String username,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/workspaces.php'),
        body: {
          'action': 'create',
          'name': name,
          'description': description ?? '',
          'color': color ?? '#0073ea',
          'icon': icon ?? 'folder',
          'username': username,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return _parseId(data['data']['id']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[SundayService] Error creating workspace: $e');
      return null;
    }
  }

  /// Update workspace (rename, change color, etc.)
  static Future<bool> updateWorkspace({
    required int workspaceId,
    required String username,
    String? name,
    String? description,
    String? color,
    String? icon,
  }) async {
    try {
      final body = <String, String>{
        'action': 'update',
        'id': workspaceId.toString(),
        'username': username,
      };
      if (name != null) body['name'] = name;
      if (description != null) body['description'] = description;
      if (color != null) body['color'] = color;
      if (icon != null) body['icon'] = icon;

      final response = await http.post(
        Uri.parse('$_baseUrl/workspaces.php'),
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error updating workspace: $e');
      return false;
    }
  }

  /// Delete a workspace
  static Future<bool> deleteWorkspace(int workspaceId, String username) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/workspaces.php'),
        body: {
          'action': 'delete',
          'id': workspaceId.toString(),
          'username': username,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error deleting workspace: $e');
      return false;
    }
  }

  // ============================================
  // BOARD METHODS
  // ============================================

  /// Get all boards in a workspace
  static Future<List<SundayBoard>> getBoards(int workspaceId, String username) async {
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse('$_baseUrl/boards.php?action=list&workspace_id=$workspaceId&username=$username&_t=$ts'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data']['boards'] as List)
              .map((b) => SundayBoard.fromJson(b))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('[SundayService] Error getting boards: $e');
      return [];
    }
  }

  /// Get boards and folders for a workspace
  static Future<({List<SundayBoard> boards, List<SundayBoardFolder> folders})> getBoardsWithFolders(
      int workspaceId, String username) async {
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse('$_baseUrl/boards.php?action=list&workspace_id=$workspaceId&username=$username&_t=$ts'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final boards = (data['data']['boards'] as List)
              .map((b) => SundayBoard.fromJson(b))
              .toList();
          final folders = (data['data']['folders'] as List? ?? [])
              .map((f) => SundayBoardFolder.fromJson(f))
              .toList();
          return (boards: boards, folders: folders);
        }
      }
      return (boards: <SundayBoard>[], folders: <SundayBoardFolder>[]);
    } catch (e) {
      debugPrint('[SundayService] Error getting boards with folders: $e');
      return (boards: <SundayBoard>[], folders: <SundayBoardFolder>[]);
    }
  }

  /// Create a new folder in a workspace
  static Future<int?> createFolder({
    required int workspaceId,
    required String name,
    required String username,
    String color = '#808080',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/boards.php'),
        body: {
          'action': 'create_folder',
          'workspace_id': workspaceId.toString(),
          'name': name,
          'color': color,
          'username': username,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data']['folder_id'];
        }
      }
      return null;
    } catch (e) {
      debugPrint('[SundayService] Error creating folder: $e');
      return null;
    }
  }

  /// Update a folder
  static Future<bool> updateFolder({
    required int folderId,
    required String username,
    String? name,
    String? color,
  }) async {
    try {
      final body = <String, String>{
        'action': 'update_folder',
        'id': folderId.toString(),
        'username': username,
      };
      if (name != null) body['name'] = name;
      if (color != null) body['color'] = color;

      final response = await http.post(
        Uri.parse('$_baseUrl/boards.php'),
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error updating folder: $e');
      return false;
    }
  }

  /// Delete a folder
  static Future<bool> deleteFolder(int folderId, String username) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/boards.php'),
        body: {
          'action': 'delete_folder',
          'id': folderId.toString(),
          'username': username,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error deleting folder: $e');
      return false;
    }
  }

  /// Move a board to a folder (or to root if folderId is null)
  static Future<bool> moveBoard({
    required int boardId,
    required String username,
    int? folderId,
  }) async {
    try {
      final body = <String, String>{
        'action': 'move_board',
        'board_id': boardId.toString(),
        'username': username,
      };
      if (folderId != null) body['folder_id'] = folderId.toString();

      final response = await http.post(
        Uri.parse('$_baseUrl/boards.php'),
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error moving board: $e');
      return false;
    }
  }

  /// Reorder boards in a workspace
  static Future<bool> reorderBoards({
    required int workspaceId,
    required List<int> boardOrder,
    required String username,
    int? folderId,
  }) async {
    try {
      final body = {
        'action': 'reorder_boards',
        'workspace_id': workspaceId.toString(),
        'order': jsonEncode(boardOrder),
        'username': username,
      };

      if (folderId != null) {
        body['folder_id'] = folderId.toString();
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/boards.php'),
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error reordering boards: $e');
      return false;
    }
  }

  /// Reorder folders in a workspace
  static Future<bool> reorderFolders(List<int> folderOrder, String username) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/boards.php'),
        body: {
          'action': 'reorder_folders',
          'order': jsonEncode(folderOrder),
          'username': username,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error reordering folders: $e');
      return false;
    }
  }

  /// Get a single board with all data (columns, groups, items)
  static Future<SundayBoard?> getBoard(int boardId, String username) async {
    try {
      // Add timestamp to bust cache
      final ts = DateTime.now().millisecondsSinceEpoch;
      final url = '$_baseUrl/boards.php?action=get&id=$boardId&username=$username&_t=$ts';
      debugPrint('[SundayService] Fetching board: $url');

      final response = await http.get(Uri.parse(url));

      debugPrint('[SundayService] Response status: ${response.statusCode}');
      final bodyPreview = response.body.length > 1000
          ? response.body.substring(0, 1000)
          : response.body;
      debugPrint('[SundayService] Response body preview: $bodyPreview');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          try {
            final board = SundayBoard.fromJson(data['data']);
            debugPrint('[SundayService] Board parsed successfully: ${board.name}, ${board.groups.length} groups');
            return board;
          } catch (parseError, parseStack) {
            debugPrint('[SundayService] Error parsing board JSON: $parseError');
            debugPrint('[SundayService] Parse stack: $parseStack');
            debugPrint('[SundayService] Raw data: ${data['data']}');
            return null;
          }
        } else {
          debugPrint('[SundayService] API returned success=false or no data: ${data['error'] ?? 'unknown error'}');
        }
      } else {
        debugPrint('[SundayService] HTTP error: ${response.statusCode}');
      }
      return null;
    } catch (e, stackTrace) {
      debugPrint('[SundayService] Error getting board: $e');
      debugPrint('[SundayService] Stack trace: $stackTrace');
      return null;
    }
  }

  /// Create a new board
  static Future<int?> createBoard({
    required int workspaceId,
    required String name,
    String? description,
    bool isPrivate = false,
    int? folderId,
    required String username,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/boards.php'),
        body: {
          'action': 'create',
          'workspace_id': workspaceId.toString(),
          'name': name,
          'description': description ?? '',
          'is_private': isPrivate ? '1' : '0',
          if (folderId != null) 'folder_id': folderId.toString(),
          'username': username,
        },
      );

      debugPrint('[SundayService] createBoard response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return _parseId(data['data']['id']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[SundayService] Error creating board: $e');
      return null;
    }
  }

  /// Create board from template
  static Future<int?> createBoardFromTemplate({
    required int workspaceId,
    required String name,
    required String templateId,
    int? folderId,
    required String username,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/boards.php'),
        body: {
          'action': 'create_from_template',
          'workspace_id': workspaceId.toString(),
          'name': name,
          'template': templateId,
          if (folderId != null) 'folder_id': folderId.toString(),
          'username': username,
        },
      );

      debugPrint('[SundayService] createBoardFromTemplate response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return _parseId(data['data']['id']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[SundayService] Error creating board from template: $e');
      return null;
    }
  }

  /// Update board details
  static Future<bool> updateBoard({
    required int boardId,
    required String username,
    String? name,
    String? description,
    bool? isArchived,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/boards.php'),
        body: {
          'action': 'update',
          'id': boardId.toString(),
          'username': username,
          if (name != null) 'name': name,
          if (description != null) 'description': description,
          if (isArchived != null) 'is_archived': isArchived ? '1' : '0',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error updating board: $e');
      return false;
    }
  }

  /// Delete a board
  static Future<bool> deleteBoard(int boardId, String username) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/boards.php'),
        body: {
          'action': 'delete',
          'id': boardId.toString(),
          'username': username,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error deleting board: $e');
      return false;
    }
  }

  // ============================================
  // COLUMN METHODS
  // ============================================

  /// Add a column to a board
  static Future<int?> addColumn({
    required int boardId,
    required String key,
    required String title,
    required ColumnType type,
    required String username,
    int? width,
    Map<String, dynamic>? settings,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/boards.php'),
        body: {
          'action': 'add_column',
          'board_id': boardId.toString(),
          'key': key,
          'title': title,
          'type': type.name,
          'username': username,
          if (width != null) 'width': width.toString(),
          if (settings != null) 'settings': jsonEncode(settings),
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return _parseId(data['data']['id']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[SundayService] Error adding column: $e');
      return null;
    }
  }

  /// Update column settings
  static Future<bool> updateColumn({
    required int columnId,
    required String username,
    String? title,
    int? width,
    bool? isHidden,
    List<Map<String, dynamic>>? statusLabels,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/boards.php'),
        body: {
          'action': 'update_column',
          'id': columnId.toString(),
          'username': username,
          if (title != null) 'title': title,
          if (width != null) 'width': width.toString(),
          if (isHidden != null) 'is_hidden': isHidden ? '1' : '0',
          if (statusLabels != null) 'status_labels': jsonEncode(statusLabels),
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error updating column: $e');
      return false;
    }
  }

  /// Delete a column
  static Future<bool> deleteColumn(int columnId, String username) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/boards.php'),
        body: {
          'action': 'delete_column',
          'id': columnId.toString(),
          'username': username,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error deleting column: $e');
      return false;
    }
  }

  /// Add a new label to a status/label column (board-specific)
  static Future<StatusLabel?> addColumnLabel({
    required int columnId,
    required String label,
    required String color,
    required String username,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/boards.php'),
        body: {
          'action': 'add_column_label',
          'column_id': columnId.toString(),
          'label': label,
          'color': color,
          'username': username,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return StatusLabel(
            id: data['label_key'] ?? data['id'].toString(),
            label: data['label'],
            color: data['color'],
          );
        }
      }
      return null;
    } catch (e) {
      debugPrint('[SundayService] Error adding column label: $e');
      return null;
    }
  }

  /// Reorder columns
  static Future<bool> reorderColumns(
      int boardId, List<int> columnIds, String username) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/boards.php'),
        body: {
          'action': 'reorder_columns',
          'board_id': boardId.toString(),
          'username': username,
          'order': jsonEncode(columnIds),
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error reordering columns: $e');
      return false;
    }
  }

  // ============================================
  // GROUP METHODS
  // ============================================

  /// Add a group to a board
  static Future<int?> addGroup({
    required int boardId,
    required String title,
    required String username,
    String color = '#579bfc',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/boards.php'),
        body: {
          'action': 'add_group',
          'board_id': boardId.toString(),
          'title': title,
          'color': color,
          'username': username,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return _parseId(data['data']['id']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[SundayService] Error adding group: $e');
      return null;
    }
  }

  /// Update a group
  static Future<bool> updateGroup({
    required int groupId,
    required String username,
    String? title,
    String? color,
    bool? isCollapsed,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/boards.php'),
        body: {
          'action': 'update_group',
          'id': groupId.toString(),
          'username': username,
          if (title != null) 'title': title,
          if (color != null) 'color': color,
          if (isCollapsed != null) 'is_collapsed': isCollapsed ? '1' : '0',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error updating group: $e');
      return false;
    }
  }

  /// Delete a group (moves items to another group or deletes them)
  static Future<bool> deleteGroup(int groupId, String username, {int? moveToGroupId}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/boards.php'),
        body: {
          'action': 'delete_group',
          'id': groupId.toString(),
          'username': username,
          if (moveToGroupId != null) 'move_items_to': moveToGroupId.toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error deleting group: $e');
      return false;
    }
  }

  /// Reorder groups
  static Future<bool> reorderGroups(int boardId, List<int> groupIds, String username) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/boards.php'),
        body: {
          'action': 'reorder_groups',
          'board_id': boardId.toString(),
          'username': username,
          'order': jsonEncode(groupIds),
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error reordering groups: $e');
      return false;
    }
  }

  // ============================================
  // ITEM METHODS
  // ============================================

  /// Get items for a board with optional filters
  static Future<List<SundayItem>> getItems({
    required int boardId,
    int? groupId,
    int limit = 100,
    int offset = 0,
    String? username, // For item-level access filtering
  }) async {
    try {
      final queryParams = {
        'action': 'list',
        'board_id': boardId.toString(),
        if (groupId != null) 'group_id': groupId.toString(),
        'limit': limit.toString(),
        'offset': offset.toString(),
        if (username != null) 'username': username,
      };

      final response = await http.get(
        Uri.parse('$_baseUrl/items.php').replace(queryParameters: queryParams),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data']['items'] as List)
              .map((i) => SundayItem.fromJson(i))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('[SundayService] Error getting items: $e');
      return [];
    }
  }

  /// Get a single item with all details
  static Future<SundayItem?> getItem(int itemId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/items.php?action=get&id=$itemId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return SundayItem.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[SundayService] Error getting item: $e');
      return null;
    }
  }

  /// Create a new item
  static Future<int?> createItem({
    required int boardId,
    required int groupId,
    required String name,
    required String username,
    Map<String, dynamic>? columnValues,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/items.php'),
        body: {
          'action': 'create',
          'board_id': boardId.toString(),
          'group_id': groupId.toString(),
          'name': name,
          'username': username,
          if (columnValues != null) 'column_values': jsonEncode(columnValues),
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return _parseId(data['data']['id']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[SundayService] Error creating item: $e');
      return null;
    }
  }

  /// Update item name
  static Future<bool> updateItem({
    required int itemId,
    required String name,
    required String username,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/items.php'),
        body: {
          'action': 'update',
          'id': itemId.toString(),
          'name': name,
          'username': username,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error updating item: $e');
      return false;
    }
  }

  /// Rename item (alias for updateItem)
  static Future<bool> renameItem({
    required int itemId,
    required String name,
    required String username,
  }) async {
    return updateItem(itemId: itemId, name: name, username: username);
  }

  /// Update a single column value
  static Future<bool> updateColumnValue({
    required int itemId,
    required String columnKey,
    required dynamic value,
    required String username,
  }) async {
    final result = await updateColumnValueWithResult(
      itemId: itemId,
      columnKey: columnKey,
      value: value,
      username: username,
    );
    return result.success;
  }

  /// Update a single column value with detailed result
  static Future<SundayResult<void>> updateColumnValueWithResult({
    required int itemId,
    required String columnKey,
    required dynamic value,
    required String username,
  }) async {
    try {
      // Encode arrays/lists as JSON strings so PHP can decode them properly
      String encodedValue;
      if (value == null) {
        encodedValue = '';
      } else if (value is List) {
        encodedValue = jsonEncode(value);
      } else {
        encodedValue = value.toString();
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/items.php'),
        body: {
          'action': 'update_value',
          'item_id': itemId.toString(),
          'column_key': columnKey,
          'value': encodedValue,
          'username': username,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return const SundayResult.success(null);
        }
        return SundayResult.failure(data['error']?.toString() ?? 'Failed to update value');
      }
      return SundayResult.failure('Server error: ${response.statusCode}');
    } catch (e) {
      debugPrint('[SundayService] Error updating column value: $e');
      return SundayResult.failure(_extractError(e));
    }
  }

  /// Update multiple column values
  static Future<bool> updateColumnValues({
    required int itemId,
    required Map<String, dynamic> values,
    required String username,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/items.php'),
        body: {
          'action': 'update_values',
          'item_id': itemId.toString(),
          'values': jsonEncode(values),
          'username': username,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error updating column values: $e');
      return false;
    }
  }

  /// Delete an item
  static Future<bool> deleteItem(int itemId, String username) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/items.php'),
        body: {
          'action': 'delete',
          'id': itemId.toString(),
          'username': username,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error deleting item: $e');
      return false;
    }
  }

  /// Duplicate an item with all its column values
  static Future<int?> duplicateItem(int itemId, String username, {String? newName}) async {
    try {
      final body = <String, String>{
        'action': 'duplicate',
        'id': itemId.toString(),
        'username': username,
      };
      if (newName != null) body['name'] = newName;

      final response = await http.post(
        Uri.parse('$_baseUrl/items.php'),
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return _parseId(data['data']['id']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[SundayService] Error duplicating item: $e');
      return null;
    }
  }

  /// Move an item to another group
  static Future<bool> moveItem(int itemId, int targetGroupId, String username) async {
    final result = await moveItemWithResult(itemId, targetGroupId, username);
    return result.success;
  }

  /// Move an item to another group with detailed result
  static Future<SundayResult<void>> moveItemWithResult(int itemId, int targetGroupId, String username) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/items.php'),
        body: {
          'action': 'move',
          'item_id': itemId.toString(),
          'group_id': targetGroupId.toString(),
          'username': username,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return const SundayResult.success(null);
        }
        return SundayResult.failure(data['error']?.toString() ?? 'Failed to move item');
      }
      return SundayResult.failure('Server error: ${response.statusCode}');
    } catch (e) {
      debugPrint('[SundayService] Error moving item: $e');
      return SundayResult.failure(_extractError(e));
    }
  }

  /// Move an item to a different board
  /// This removes the item from the current board and places it in the target board
  /// The person assignment is updated to the target board's owner
  static Future<Map<String, dynamic>?> moveItemToBoard({
    required int itemId,
    required int targetBoardId,
    required String username,
    int? targetGroupId,
  }) async {
    try {
      final body = {
        'action': 'move_to_board',
        'item_id': itemId.toString(),
        'target_board_id': targetBoardId.toString(),
        'username': username,
      };

      if (targetGroupId != null) {
        body['target_group_id'] = targetGroupId.toString();
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/items.php'),
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      debugPrint('[SundayService] Error moving item to board: $e');
      return null;
    }
  }

  /// Reorder items within a group
  static Future<bool> reorderItems(int groupId, List<int> itemIds, String username) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/items.php'),
        body: {
          'action': 'reorder',
          'group_id': groupId.toString(),
          'username': username,
          'order': jsonEncode(itemIds),
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error reordering items: $e');
      return false;
    }
  }

  /// Search items
  static Future<List<SundayItem>> searchItems({
    required int boardId,
    required String query,
    int limit = 50,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/items.php?action=search&board_id=$boardId&q=${Uri.encodeComponent(query)}&limit=$limit'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data']['items'] as List)
              .map((i) => SundayItem.fromJson(i))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('[SundayService] Error searching items: $e');
      return [];
    }
  }

  // ============================================
  // SUBITEM METHODS
  // ============================================

  /// Get subitems for an item
  static Future<List<SundaySubitem>> getSubitems(int parentItemId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/items.php?action=subitems&item_id=$parentItemId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data']['subitems'] as List)
              .map((s) => SundaySubitem.fromJson(s))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('[SundayService] Error getting subitems: $e');
      return [];
    }
  }

  /// Create a subitem
  static Future<int?> createSubitem({
    required int parentItemId,
    required String name,
    required String username,
    Map<String, dynamic>? columnValues,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/items.php'),
        body: {
          'action': 'create_subitem',
          'parent_item_id': parentItemId.toString(),
          'name': name,
          'username': username,
          if (columnValues != null) 'column_values': jsonEncode(columnValues),
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return _parseId(data['data']['id']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[SundayService] Error creating subitem: $e');
      return null;
    }
  }

  /// Update a subitem
  static Future<bool> updateSubitem({
    required int subitemId,
    required String username,
    String? name,
    Map<String, dynamic>? columnValues,
  }) async {
    try {
      final body = <String, String>{
        'action': 'update_subitem',
        'id': subitemId.toString(),
        'username': username,
      };
      if (name != null) body['name'] = name;
      if (columnValues != null) body['column_values'] = jsonEncode(columnValues);

      final response = await http.post(
        Uri.parse('$_baseUrl/items.php'),
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error updating subitem: $e');
      return false;
    }
  }

  /// Delete a subitem
  static Future<bool> deleteSubitem(int subitemId, String username) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/items.php'),
        body: {
          'action': 'delete_subitem',
          'id': subitemId.toString(),
          'username': username,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error deleting subitem: $e');
      return false;
    }
  }

  // ============================================
  // ITEM UPDATES (Comments)
  // ============================================

  /// Get updates for an item
  static Future<List<SundayItemUpdate>> getItemUpdates(int itemId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/items.php?action=updates&item_id=$itemId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data']['updates'] as List)
              .map((u) => SundayItemUpdate.fromJson(u))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('[SundayService] Error getting updates: $e');
      return [];
    }
  }

  /// Post an update/comment
  static Future<int?> postUpdate({
    required int itemId,
    required String body,
    required String username,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/items.php'),
        body: {
          'action': 'post_update',
          'item_id': itemId.toString(),
          'body': body,
          'username': username,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return _parseId(data['data']['id']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[SundayService] Error posting update: $e');
      return null;
    }
  }

  /// Delete an update
  static Future<bool> deleteUpdate(int updateId, String username) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/items.php'),
        body: {
          'action': 'delete_update',
          'id': updateId.toString(),
          'username': username,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error deleting update: $e');
      return false;
    }
  }

  /// Edit an update
  static Future<bool> editUpdate({
    required int updateId,
    required String body,
    required String username,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/items.php'),
        body: {
          'action': 'edit_update',
          'id': updateId.toString(),
          'body': body,
          'username': username,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error editing update: $e');
      return false;
    }
  }

  /// Mark all updates for an item as read
  static Future<bool> markUpdatesRead({
    required int itemId,
    required String username,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/items.php'),
        body: {
          'action': 'mark_updates_read',
          'item_id': itemId.toString(),
          'username': username,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error marking updates as read: $e');
      return false;
    }
  }

  /// Attachment file data for uploads
  static MediaType _getMediaType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'gif':
        return MediaType('image', 'gif');
      case 'webp':
        return MediaType('image', 'webp');
      case 'bmp':
        return MediaType('image', 'bmp');
      case 'pdf':
        return MediaType('application', 'pdf');
      case 'doc':
        return MediaType('application', 'msword');
      case 'docx':
        return MediaType('application', 'vnd.openxmlformats-officedocument.wordprocessingml.document');
      case 'xls':
        return MediaType('application', 'vnd.ms-excel');
      case 'xlsx':
        return MediaType('application', 'vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      case 'ppt':
        return MediaType('application', 'vnd.ms-powerpoint');
      case 'pptx':
        return MediaType('application', 'vnd.openxmlformats-officedocument.presentationml.presentation');
      case 'txt':
        return MediaType('text', 'plain');
      case 'csv':
        return MediaType('text', 'csv');
      case 'zip':
        return MediaType('application', 'zip');
      case 'rar':
        return MediaType('application', 'x-rar-compressed');
      case '7z':
        return MediaType('application', 'x-7z-compressed');
      default:
        return MediaType('application', 'octet-stream');
    }
  }

  /// Upload multiple files to an update
  /// Returns the upload result with file details if successful, null otherwise
  static Future<Map<String, dynamic>?> uploadUpdateFiles({
    required int itemId,
    required String username,
    required String body,
    required List<({Uint8List bytes, String filename})> files,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/uploads.php');
      final request = http.MultipartRequest('POST', uri);

      // Add fields
      request.fields['action'] = 'upload';
      request.fields['item_id'] = itemId.toString();
      request.fields['username'] = username;
      request.fields['body'] = body;

      // Add files
      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        request.files.add(http.MultipartFile.fromBytes(
          'files[]', // Array notation for multiple files
          file.bytes,
          filename: file.filename,
          contentType: _getMediaType(file.filename),
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('[SundayService] Upload response status: ${response.statusCode}');
      debugPrint('[SundayService] Upload response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data'] as Map<String, dynamic>;
        } else {
          debugPrint('[SundayService] Upload API returned error: ${data['message'] ?? 'Unknown error'}');
        }
      } else {
        debugPrint('[SundayService] Upload HTTP error: ${response.statusCode}');
      }
      debugPrint('[SundayService] Upload failed response: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('[SundayService] Error uploading files: $e');
      return null;
    }
  }

  /// Upload single image to an update (legacy support)
  /// Returns the attachment data if successful, null otherwise
  static Future<Map<String, dynamic>?> uploadUpdateImage({
    required int itemId,
    required String username,
    required String body,
    required Uint8List imageBytes,
  }) async {
    final result = await uploadUpdateFiles(
      itemId: itemId,
      username: username,
      body: body,
      files: [(bytes: imageBytes, filename: 'image_${DateTime.now().millisecondsSinceEpoch}.jpg')],
    );
    return result;
  }

  /// Post update with optional files (images and/or documents)
  static Future<int?> postUpdateWithFiles({
    required int itemId,
    required String body,
    required String username,
    List<({Uint8List bytes, String filename})>? files,
  }) async {
    if (files != null && files.isNotEmpty) {
      // Upload with files
      final result = await uploadUpdateFiles(
        itemId: itemId,
        username: username,
        body: body,
        files: files,
      );
      if (result != null) {
        return result['update_id'] as int?;
      }
      return null;
    } else {
      // Regular text-only update
      return postUpdate(itemId: itemId, body: body, username: username);
    }
  }

  /// Post update with optional image (legacy - calls postUpdateWithFiles)
  static Future<int?> postUpdateWithImage({
    required int itemId,
    required String body,
    required String username,
    Uint8List? imageBytes,
  }) async {
    if (imageBytes != null) {
      return postUpdateWithFiles(
        itemId: itemId,
        body: body,
        username: username,
        files: [(bytes: imageBytes, filename: 'image_${DateTime.now().millisecondsSinceEpoch}.jpg')],
      );
    } else {
      return postUpdate(itemId: itemId, body: body, username: username);
    }
  }

  // ============================================
  // AUTOMATION METHODS
  // ============================================

  /// Get automations for a board
  static Future<List<SundayAutomation>> getAutomations(int boardId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/automations.php?action=list&board_id=$boardId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data']['automations'] as List)
              .map((a) => SundayAutomation.fromJson(a))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('[SundayService] Error getting automations: $e');
      return [];
    }
  }

  /// Get a single automation with full details (actions, conditions)
  static Future<SundayAutomation?> getAutomation(int automationId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/automations.php?action=get&id=$automationId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return SundayAutomation.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[SundayService] Error getting automation: $e');
      return null;
    }
  }

  /// Create an automation
  static Future<int?> createAutomation({
    required int boardId,
    required String name,
    String? description,
    required AutomationTrigger trigger,
    Map<String, dynamic>? triggerConfig,
    required List<AutomationActionConfig> actions,
    List<AutomationCondition>? conditions,
    required String username,
  }) async {
    try {
      debugPrint('[SundayService] createAutomation called with:');
      debugPrint('[SundayService]   boardId: $boardId');
      debugPrint('[SundayService]   name: $name');
      debugPrint('[SundayService]   trigger: ${trigger.name}');
      debugPrint('[SundayService]   triggerConfig: $triggerConfig');
      debugPrint('[SundayService]   actions count: ${actions.length}');
      for (int i = 0; i < actions.length; i++) {
        debugPrint('[SundayService]   action[$i]: ${actions[i].action.name} - config: ${actions[i].config}');
      }

      final actionsJson = jsonEncode(actions.map((a) => a.toJson()).toList());
      debugPrint('[SundayService]   actions JSON: $actionsJson');

      final body = {
        'action': 'create',
        'board_id': boardId.toString(),
        'name': name,
        'description': description ?? '',
        'trigger_type': trigger.name,
        if (triggerConfig != null) 'trigger_config': jsonEncode(triggerConfig),
        'actions': actionsJson,
        if (conditions != null && conditions.isNotEmpty)
          'conditions': jsonEncode(conditions.map((c) => c.toJson()).toList()),
        'username': username,
      };

      debugPrint('[SundayService] createAutomation request body: $body');

      final response = await http.post(
        Uri.parse('$_baseUrl/automations.php'),
        body: body,
      );

      debugPrint('[SundayService] createAutomation response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          // Check for warnings from PHP (e.g., actions not inserted)
          if (data['data']['warnings'] != null || data['data']['warning'] == true) {
            debugPrint('[SundayService] Automation created with warnings: ${data['data']['warnings'] ?? data['data']['message']}');
          }
          return _parseId(data['data']['id']);
        } else {
          debugPrint('[SundayService] API returned success=false: ${data['error'] ?? 'unknown error'}');
        }
      } else {
        debugPrint('[SundayService] HTTP error ${response.statusCode}: ${response.body}');
      }
      return null;
    } catch (e, stackTrace) {
      debugPrint('[SundayService] Error creating automation: $e');
      debugPrint('[SundayService] Stack trace: $stackTrace');
      return null;
    }
  }

  /// Create automation with detailed result (use this for better error handling)
  static Future<SundayResult<int>> createAutomationWithResult({
    required int boardId,
    required String name,
    String? description,
    required AutomationTrigger trigger,
    Map<String, dynamic>? triggerConfig,
    required List<AutomationActionConfig> actions,
    List<AutomationCondition>? conditions,
    required String username,
  }) async {
    try {
      final actionsJson = jsonEncode(actions.map((a) => a.toJson()).toList());

      final body = {
        'action': 'create',
        'board_id': boardId.toString(),
        'name': name,
        'description': description ?? '',
        'trigger_type': trigger.name,
        if (triggerConfig != null) 'trigger_config': jsonEncode(triggerConfig),
        'actions': actionsJson,
        if (conditions != null && conditions.isNotEmpty)
          'conditions': jsonEncode(conditions.map((c) => c.toJson()).toList()),
        'username': username,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/automations.php'),
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final id = _parseId(data['data']['id']);
          if (id == null) {
            return const SundayResult.failure('Failed to parse automation ID');
          }
          // Capture any warnings
          List<String>? warnings;
          if (data['data']['warnings'] != null) {
            warnings = List<String>.from(data['data']['warnings']);
          } else if (data['data']['warning'] == true) {
            warnings = [data['data']['message'] ?? 'Unknown warning'];
          }
          return SundayResult.success(id, warnings: warnings);
        } else {
          return SundayResult.failure(data['error']?.toString() ?? 'Unknown error');
        }
      } else {
        return SundayResult.failure(_extractError(null, response));
      }
    } catch (e) {
      return SundayResult.failure(_extractError(e));
    }
  }

  /// Create automation from template
  static Future<int?> createAutomationFromTemplate({
    required int boardId,
    required String templateId,
    required String username,
    String? name,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/automations.php'),
        body: {
          'action': 'create_from_template',
          'board_id': boardId.toString(),
          'template_id': templateId,
          'username': username,
          if (name != null) 'name': name,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return _parseId(data['data']['id']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[SundayService] Error creating automation from template: $e');
      return null;
    }
  }

  /// Update automation
  static Future<bool> updateAutomation({
    required int automationId,
    required String username,
    String? name,
    String? description,
    bool? isActive,
    AutomationTrigger? trigger,
    Map<String, dynamic>? triggerConfig,
    List<AutomationActionConfig>? actions,
    List<AutomationCondition>? conditions,
  }) async {
    try {
      debugPrint('[SundayService] updateAutomation called with:');
      debugPrint('[SundayService]   automationId: $automationId');
      debugPrint('[SundayService]   trigger: ${trigger?.name}');
      debugPrint('[SundayService]   triggerConfig: $triggerConfig');
      debugPrint('[SundayService]   actions count: ${actions?.length}');
      if (actions != null) {
        for (int i = 0; i < actions.length; i++) {
          debugPrint('[SundayService]   action[$i]: ${actions[i].action.name} - config: ${actions[i].config}');
        }
      }

      final body = <String, String>{
        'action': 'update',
        'id': automationId.toString(),
        'username': username,
      };
      if (name != null) body['name'] = name;
      if (description != null) body['description'] = description;
      if (isActive != null) body['is_active'] = isActive ? '1' : '0';
      if (trigger != null) body['trigger_type'] = trigger.name;
      if (triggerConfig != null) body['trigger_config'] = jsonEncode(triggerConfig);
      if (actions != null) body['actions'] = jsonEncode(actions.map((a) => a.toJson()).toList());
      if (conditions != null) body['conditions'] = jsonEncode(conditions.map((c) => c.toJson()).toList());

      debugPrint('[SundayService] updateAutomation request body: $body');

      final response = await http.post(
        Uri.parse('$_baseUrl/automations.php'),
        body: body,
      );

      debugPrint('[SundayService] updateAutomation response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e, stackTrace) {
      debugPrint('[SundayService] Error updating automation: $e');
      debugPrint('[SundayService] Stack trace: $stackTrace');
      return false;
    }
  }

  /// Delete an automation
  static Future<bool> deleteAutomation(int automationId, String username) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/automations.php'),
        body: {
          'action': 'delete',
          'id': automationId.toString(),
          'username': username,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error deleting automation: $e');
      return false;
    }
  }

  /// Toggle automation active state
  static Future<bool> toggleAutomation(int automationId, String username) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/automations.php'),
        body: {
          'action': 'toggle',
          'id': automationId.toString(),
          'username': username,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error toggling automation: $e');
      return false;
    }
  }

  /// Get automation logs
  static Future<List<AutomationLog>> getAutomationLogs(
    int automationId, {
    int limit = 50,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$_baseUrl/automations.php?action=logs&automation_id=$automationId&limit=$limit'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data']['logs'] as List)
              .map((l) => AutomationLog.fromJson(l))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('[SundayService] Error getting automation logs: $e');
      return [];
    }
  }

  /// Get automation templates
  static Future<List<Map<String, dynamic>>> getAutomationTemplates() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/automations.php?action=templates'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']['templates']);
        }
      }
      return [];
    } catch (e) {
      debugPrint('[SundayService] Error getting automation templates: $e');
      return [];
    }
  }

  // ============================================
  // VIEW METHODS
  // ============================================

  /// Get saved views for a board
  static Future<List<SundayView>> getViews(int boardId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/boards.php?action=views&board_id=$boardId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data']['views'] as List)
              .map((v) => SundayView.fromJson(v))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('[SundayService] Error getting views: $e');
      return [];
    }
  }

  /// Save a view
  static Future<int?> saveView({
    required int boardId,
    required String name,
    required ViewType type,
    required String username,
    Map<String, dynamic>? settings,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/boards.php'),
        body: {
          'action': 'create_view',
          'board_id': boardId.toString(),
          'name': name,
          'type': type.name,
          'username': username,
          if (settings != null) 'settings': jsonEncode(settings),
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return _parseId(data['data']['id']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[SundayService] Error saving view: $e');
      return null;
    }
  }

  /// Delete a view
  static Future<bool> deleteView(int viewId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/boards.php'),
        body: {
          'action': 'delete_view',
          'id': viewId.toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error deleting view: $e');
      return false;
    }
  }

  // ============================================
  // ACTIVITY LOG METHODS
  // ============================================

  /// Get activity log for a board
  static Future<List<SundayActivityLog>> getBoardActivityLog(
    int boardId, {
    int limit = 50,
    int? itemId,
  }) async {
    try {
      var url = '$_baseUrl/boards.php?action=activity_log&board_id=$boardId&limit=$limit';
      if (itemId != null) {
        url += '&item_id=$itemId';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data']['activities'] as List)
              .map((a) => SundayActivityLog.fromJson(a))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('[SundayService] Error getting activity log: $e');
      return [];
    }
  }

  /// Log an activity
  static Future<bool> logActivity({
    required int boardId,
    int? itemId,
    String? itemName,
    required ActivityType activityType,
    required String description,
    required String username,
    Map<String, dynamic>? oldValue,
    Map<String, dynamic>? newValue,
    String? columnKey,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/boards.php'),
        body: {
          'action': 'log_activity',
          'board_id': boardId.toString(),
          if (itemId != null) 'item_id': itemId.toString(),
          if (itemName != null) 'item_name': itemName,
          'activity_type': activityType.name,
          'description': description,
          'username': username,
          if (oldValue != null) 'old_value': jsonEncode(oldValue),
          if (newValue != null) 'new_value': jsonEncode(newValue),
          if (columnKey != null) 'column_key': columnKey,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error logging activity: $e');
      return false;
    }
  }

  // ============================================
  // BOARD MEMBER METHODS
  // ============================================

  /// Get members of a board
  static Future<List<SundayBoardMember>> getBoardMembers(int boardId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/boards.php?action=members&board_id=$boardId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data']['members'] as List)
              .map((m) => SundayBoardMember.fromJson(m))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('[SundayService] Error getting board members: $e');
      return [];
    }
  }

  /// Add a member to a board
  static Future<bool> addBoardMember({
    required int boardId,
    required String memberUsername,
    required BoardAccessLevel accessLevel,
    required String addedBy,
  }) async {
    try {
      // Convert enum to PHP expected values: editor -> edit, viewer -> view
      final accessLevelStr = switch (accessLevel) {
        BoardAccessLevel.owner => 'owner',
        BoardAccessLevel.editor => 'edit',
        BoardAccessLevel.viewer => 'view',
      };

      final requestBody = {
        'action': 'add_member',
        'board_id': boardId.toString(),
        'member_username': memberUsername,
        'access_level': accessLevelStr,
        'added_by': addedBy,
      };

      debugPrint('[SundayService] addBoardMember request URL: $_baseUrl/boards.php');
      debugPrint('[SundayService] addBoardMember request body: $requestBody');

      final response = await http.post(
        Uri.parse('$_baseUrl/boards.php'),
        body: requestBody,
      );

      debugPrint('[SundayService] addBoardMember response status: ${response.statusCode}');
      debugPrint('[SundayService] addBoardMember response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final success = data['success'] == true;
        if (!success) {
          debugPrint('[SundayService] addBoardMember API error: ${data['error'] ?? data['message'] ?? 'Unknown error'}');
        }
        return success;
      }
      debugPrint('[SundayService] addBoardMember HTTP error: ${response.statusCode}');
      return false;
    } catch (e, stackTrace) {
      debugPrint('[SundayService] Error adding board member: $e');
      debugPrint('[SundayService] Stack trace: $stackTrace');
      return false;
    }
  }

  /// Remove a member from a board
  static Future<bool> removeBoardMember(int memberId, String username) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/boards.php'),
        body: {
          'action': 'remove_member',
          'member_id': memberId.toString(),
          'username': username,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error removing board member: $e');
      return false;
    }
  }

  /// Update a member's access level
  static Future<bool> updateBoardMemberAccess({
    required int memberId,
    required BoardAccessLevel accessLevel,
    required String username,
  }) async {
    try {
      // Convert enum to PHP expected values: editor -> edit, viewer -> view
      final accessLevelStr = switch (accessLevel) {
        BoardAccessLevel.owner => 'owner',
        BoardAccessLevel.editor => 'edit',
        BoardAccessLevel.viewer => 'view',
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/boards.php'),
        body: {
          'action': 'update_member_access',
          'member_id': memberId.toString(),
          'access_level': accessLevelStr,
          'username': username,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error updating board member access: $e');
      return false;
    }
  }

  /// Check if user has access to a board
  static Future<bool> userHasBoardAccess(int boardId, String username) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/boards.php?action=check_access&board_id=$boardId&username=$username'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true && data['data']['has_access'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error checking board access: $e');
      return false;
    }
  }

  // ============================================
  // GROUP MEMBER MANAGEMENT (Granular Access Control)
  // ============================================

  /// Get all members assigned to a specific group
  static Future<List<GroupMember>> getGroupMembers(int groupId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/boards.php?action=group_members&group_id=$groupId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final members = (data['data']['members'] as List? ?? [])
              .map((m) => GroupMember.fromJson(m))
              .toList();
          return members;
        }
      }
      return [];
    } catch (e) {
      debugPrint('[SundayService] Error getting group members: $e');
      return [];
    }
  }

  /// Add a member to a group (grants group-level access to the board)
  static Future<bool> addGroupMember({
    required int groupId,
    required String memberUsername,
    required String accessLevel, // 'edit' or 'view'
    required String addedBy,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/boards.php'),
        body: {
          'action': 'add_group_member',
          'group_id': groupId.toString(),
          'member_username': memberUsername,
          'access_level': accessLevel,
          'added_by': addedBy,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error adding group member: $e');
      return false;
    }
  }

  /// Remove a member from a group
  static Future<bool> removeGroupMember(int memberId, String username) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/boards.php'),
        body: {
          'action': 'remove_group_member',
          'member_id': memberId.toString(),
          'username': username,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error removing group member: $e');
      return false;
    }
  }

  /// Update a group member's access level
  static Future<bool> updateGroupMemberAccess({
    required int memberId,
    required String accessLevel, // 'edit' or 'view'
    required String username,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/boards.php'),
        body: {
          'action': 'update_group_member_access',
          'member_id': memberId.toString(),
          'access_level': accessLevel,
          'username': username,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error updating group member access: $e');
      return false;
    }
  }

  // ============================================
  // ITEM MEMBER MANAGEMENT (Granular Access Control)
  // ============================================

  /// Get all members assigned to a specific item
  static Future<List<ItemMember>> getItemMembers(int itemId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/boards.php?action=item_members&item_id=$itemId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final members = (data['data']['members'] as List? ?? [])
              .map((m) => ItemMember.fromJson(m))
              .toList();
          return members;
        }
      }
      return [];
    } catch (e) {
      debugPrint('[SundayService] Error getting item members: $e');
      return [];
    }
  }

  /// Add a member to an item (grants item-level access to the board)
  static Future<bool> addItemMember({
    required int itemId,
    required String memberUsername,
    required String accessLevel, // 'edit' or 'view'
    required String addedBy,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/boards.php'),
        body: {
          'action': 'add_item_member',
          'item_id': itemId.toString(),
          'member_username': memberUsername,
          'access_level': accessLevel,
          'added_by': addedBy,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error adding item member: $e');
      return false;
    }
  }

  /// Remove a member from an item
  static Future<bool> removeItemMember(int memberId, String username) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/boards.php'),
        body: {
          'action': 'remove_item_member',
          'member_id': memberId.toString(),
          'username': username,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error removing item member: $e');
      return false;
    }
  }

  /// Update an item member's access level
  static Future<bool> updateItemMemberAccess({
    required int memberId,
    required String accessLevel, // 'edit' or 'view'
    required String username,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/boards.php'),
        body: {
          'action': 'update_item_member_access',
          'member_id': memberId.toString(),
          'access_level': accessLevel,
          'username': username,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error updating item member access: $e');
      return false;
    }
  }

  // ============================================
  // BOARD TEMPLATES
  // ============================================

  /// Get predefined board templates
  static List<BoardTemplate> get boardTemplates => [
    BoardTemplate(
      id: 'leads_pipeline',
      name: 'Leads Pipeline',
      description: 'Track and manage sales leads',
      icon: 'leaderboard',
      columns: [
        _templateColumn('status', 'Status', ColumnType.status, {
          'labels': [
            {'id': 'new', 'label': 'New Lead', 'color': '#579bfc'},
            {'id': 'contacted', 'label': 'Contacted', 'color': '#fdab3d'},
            {'id': 'qualified', 'label': 'Qualified', 'color': '#00c875'},
            {'id': 'proposal', 'label': 'Proposal Sent', 'color': '#a25ddc'},
            {'id': 'won', 'label': 'Won', 'color': '#037f4c', 'is_done': true},
            {'id': 'lost', 'label': 'Lost', 'color': '#e2445c'},
          ],
        }),
        _templateColumn('person', 'Owner', ColumnType.person, {}),
        _templateColumn('contact_name', 'Contact Name', ColumnType.text, {}),
        _templateColumn('phone', 'Phone', ColumnType.phone, {}),
        _templateColumn('email', 'Email', ColumnType.email, {}),
        _templateColumn('value', 'Deal Value', ColumnType.currency, {}),
        _templateColumn('close_date', 'Expected Close', ColumnType.date, {}),
        _templateColumn('source', 'Lead Source', ColumnType.dropdown, {
          'options': ['Website', 'Referral', 'Cold Call', 'Advertisement', 'Other'],
        }),
      ],
      groups: ['New Leads', 'In Progress', 'Closed Won', 'Closed Lost'],
    ),
    BoardTemplate(
      id: 'jobs_tracking',
      name: 'Jobs Tracking',
      description: 'Track chimney inspection and repair jobs',
      icon: 'work',
      columns: [
        _templateColumn('status', 'Status', ColumnType.status, {
          'labels': [
            {'id': 'scheduled', 'label': 'Scheduled', 'color': '#579bfc'},
            {'id': 'in_progress', 'label': 'In Progress', 'color': '#fdab3d'},
            {'id': 'completed', 'label': 'Completed', 'color': '#00c875', 'is_done': true},
            {'id': 'cancelled', 'label': 'Cancelled', 'color': '#e2445c'},
          ],
        }),
        _templateColumn('technician', 'Technician', ColumnType.technician, {}),
        _templateColumn('customer', 'Customer', ColumnType.text, {}),
        _templateColumn('address', 'Address', ColumnType.location, {}),
        _templateColumn('phone', 'Phone', ColumnType.phone, {}),
        _templateColumn('job_date', 'Job Date', ColumnType.date, {}),
        _templateColumn('job_type', 'Job Type', ColumnType.dropdown, {
          'options': ['Inspection', 'Cleaning', 'Repair', 'Installation', 'Emergency'],
        }),
        _templateColumn('workiz_job', 'Workiz Job', ColumnType.workizJob, {}),
        _templateColumn('notes', 'Notes', ColumnType.longText, {}),
      ],
      groups: ['This Week', 'Next Week', 'Completed', 'Cancelled'],
    ),
    BoardTemplate(
      id: 'tasks',
      name: 'Task Management',
      description: 'General task tracking board',
      icon: 'task_alt',
      columns: [
        _templateColumn('status', 'Status', ColumnType.status, {
          'labels': [
            {'id': 'todo', 'label': 'To Do', 'color': '#579bfc'},
            {'id': 'working', 'label': 'Working On It', 'color': '#fdab3d'},
            {'id': 'stuck', 'label': 'Stuck', 'color': '#e2445c'},
            {'id': 'done', 'label': 'Done', 'color': '#00c875', 'is_done': true},
          ],
        }),
        _templateColumn('person', 'Assigned To', ColumnType.person, {}),
        _templateColumn('priority', 'Priority', ColumnType.priority, {}),
        _templateColumn('due_date', 'Due Date', ColumnType.date, {}),
        _templateColumn('tags', 'Tags', ColumnType.tags, {}),
      ],
      groups: ['To Do', 'In Progress', 'Done'],
    ),
    BoardTemplate(
      id: 'projects',
      name: 'Project Tracker',
      description: 'Track project milestones and progress',
      icon: 'folder_special',
      columns: [
        _templateColumn('status', 'Status', ColumnType.status, {
          'labels': [
            {'id': 'planning', 'label': 'Planning', 'color': '#579bfc'},
            {'id': 'active', 'label': 'Active', 'color': '#fdab3d'},
            {'id': 'on_hold', 'label': 'On Hold', 'color': '#e2445c'},
            {'id': 'completed', 'label': 'Completed', 'color': '#00c875', 'is_done': true},
          ],
        }),
        _templateColumn('owner', 'Project Owner', ColumnType.person, {}),
        _templateColumn('timeline', 'Timeline', ColumnType.dateRange, {}),
        _templateColumn('progress', 'Progress', ColumnType.progress, {}),
        _templateColumn('budget', 'Budget', ColumnType.currency, {}),
        _templateColumn('priority', 'Priority', ColumnType.priority, {}),
      ],
      groups: ['Active Projects', 'Planning', 'Completed'],
    ),
  ];

  static Map<String, dynamic> _templateColumn(
    String key,
    String title,
    ColumnType type,
    Map<String, dynamic> settings,
  ) {
    return {
      'column_key': key,
      'title': title,
      'column_type': type.name,
      'settings': settings,
    };
  }

  // ============================================
  // MONDAY.COM IMPORT METHODS
  // ============================================

  /// Preview Monday.com Excel import - parses file using Python
  /// Returns parsed data without saving to database
  static Future<MondayImportPreview?> previewMondayImport(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        debugPrint('[SundayService] File not found: $filePath');
        return null;
      }

      // Parse Excel file using Python (more reliable than Dart excel package)
      final parsed = await _parseMondayExcelWithPython(filePath);
      if (parsed == null) return null;

      // Build preview
      final groups = <MondayGroupPreview>[];
      final allColumns = <String, MondayColumnPreview>{};
      int totalItems = 0;

      for (final group in parsed['groups'] as List<dynamic>) {
        final groupMap = group as Map<String, dynamic>;
        final items = groupMap['items'] as List<dynamic>;
        groups.add(MondayGroupPreview(
          title: groupMap['title'] as String,
          itemCount: items.length,
        ));
        totalItems += items.length;

        // Collect columns and sample values from items
        for (final item in items) {
          final itemMap = item as Map<String, dynamic>;
          final values = itemMap['values'] as Map<String, dynamic>;
          for (final entry in values.entries) {
            final value = entry.value?.toString() ?? '';
            if (!allColumns.containsKey(entry.key)) {
              allColumns[entry.key] = MondayColumnPreview(
                name: entry.key,
                key: _generateColumnKey(entry.key),
                type: _mapColumnType(entry.key),
                sampleValues: [if (value.isNotEmpty) value],
              );
            } else {
              // Add to sample values if less than 3
              final existing = allColumns[entry.key]!;
              if (existing.sampleValues.length < 3 && value.isNotEmpty) {
                allColumns[entry.key] = MondayColumnPreview(
                  name: existing.name,
                  key: existing.key,
                  type: existing.type,
                  sampleValues: [...existing.sampleValues, value],
                );
              }
            }
          }
        }
      }

      return MondayImportPreview(
        boardName: parsed['board_name'] as String,
        groups: groups,
        columns: allColumns.values.toList(),
        totalItems: totalItems,
      );
    } catch (e) {
      debugPrint('[SundayService] Error previewing Monday import: $e');
      return null;
    }
  }

  /// Import Monday.com Excel file to a workspace
  /// Parses using Python and sends parsed data to server
  static Future<MondayImportResult?> importMondayBoard({
    required String filePath,
    required int workspaceId,
    required String username,
    String? boardName,
  }) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        debugPrint('[SundayService] File not found: $filePath');
        return null;
      }

      // Parse Excel file using Python
      final parsed = await _parseMondayExcelWithPython(filePath);
      if (parsed == null) return null;

      // Send parsed data to server
      final requestBody = {
        'action': 'import_parsed',
        'workspace_id': workspaceId,
        'username': username,
        'board_name': boardName ?? parsed['board_name'],
        'parsed_data': parsed,
      };

      debugPrint('[SundayService] Sending import request to: $_baseUrl/import_monday.php');
      debugPrint('[SundayService] Request body keys: ${requestBody.keys.toList()}');
      debugPrint('[SundayService] Groups count: ${(parsed['groups'] as List).length}');

      final response = await http.post(
        Uri.parse('$_baseUrl/import_monday.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      debugPrint('[SundayService] Import response status: ${response.statusCode}');
      debugPrint('[SundayService] Import response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return MondayImportResult.fromJson(data['data']);
        } else {
          final errorMsg = data['error'] ?? 'Unknown server error';
          debugPrint('[SundayService] API returned error: $errorMsg');
          throw Exception(errorMsg);
        }
      } else {
        // Try to parse error from response body
        String errorMsg = 'HTTP error: ${response.statusCode}';
        try {
          final data = jsonDecode(response.body);
          if (data['error'] != null) {
            errorMsg = data['error'];
          }
        } catch (_) {
          // Body wasn't JSON, use HTTP error
          if (response.body.isNotEmpty) {
            errorMsg = response.body.substring(0, response.body.length.clamp(0, 200));
          }
        }
        debugPrint('[SundayService] HTTP error: $errorMsg');
        throw Exception(errorMsg);
      }
    } on Exception {
      rethrow;
    } catch (e) {
      debugPrint('[SundayService] Error importing Monday board: $e');
      throw Exception('Import error: $e');
    }
  }

  /// Parse Monday.com Excel export file using Python (more reliable)
  static Future<Map<String, dynamic>?> _parseMondayExcelWithPython(String filePath) async {
    try {
      // Python script to parse the Excel file
      const pythonScript = r'''
import openpyxl
import json
import sys
import re

def parse_monday_excel(file_path):
    try:
        wb = openpyxl.load_workbook(file_path, data_only=True)
        ws = wb.active

        rows = list(ws.iter_rows(values_only=True))
        if not rows:
            return None

        # First row is board name
        board_name = str(rows[0][0] or 'Imported Board').strip()

        groups = []
        current_columns = []
        current_group = None
        in_subitems = False

        for i in range(1, len(rows)):
            row = rows[i]
            # Convert row to list of strings
            row_values = [str(cell).strip() if cell is not None else '' for cell in row]
            first_cell = row_values[0] if row_values else ''

            # Skip completely empty rows
            if all(v == '' or v == 'None' for v in row_values):
                continue

            # Check if this is a main header row (starts with 'Name')
            if first_cell == 'Name':
                current_columns = [v for v in row_values if v and v != 'None']
                in_subitems = False
                continue

            # Check if this is a subitem header row
            if first_cell == 'Subitems':
                in_subitems = True
                continue

            # Count non-empty cells
            non_empty = [v for v in row_values if v and v != '' and v != 'None']

            # Check if this is a group header (only first cell has meaningful content,
            # and it's not a data row with Item ID)
            item_id_idx = current_columns.index('Item ID (auto generated)') if 'Item ID (auto generated)' in current_columns else -1
            has_item_id = item_id_idx >= 0 and item_id_idx < len(row_values) and row_values[item_id_idx] and row_values[item_id_idx] != 'None'

            if len(non_empty) == 1 and first_cell and not has_item_id and not re.match(r'^\d{4}-', first_cell):
                current_group = {
                    'title': first_cell,
                    'items': []
                }
                groups.append(current_group)
                in_subitems = False
                continue

            # Skip subitems
            if in_subitems:
                continue

            # Check if this is an item row
            if current_group is not None and first_cell and current_columns and has_item_id:
                item = {
                    'name': first_cell,
                    'monday_id': row_values[item_id_idx],
                    'values': {}
                }

                # Map column values
                for col_idx, col_name in enumerate(current_columns):
                    if col_name in ['Name', 'Item ID (auto generated)', 'Subitems', '']:
                        continue
                    if col_idx < len(row_values):
                        value = row_values[col_idx]
                        if value and value != 'None':
                            item['values'][col_name] = value

                current_group['items'].append(item)

        return {
            'board_name': board_name,
            'groups': groups
        }
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return None

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python script.py <excel_file>", file=sys.stderr)
        sys.exit(1)

    result = parse_monday_excel(sys.argv[1])
    if result:
        print(json.dumps(result, ensure_ascii=False))
    else:
        sys.exit(1)
''';

      // Write script to temp file
      final tempDir = Directory.systemTemp;
      final scriptFile = File('${tempDir.path}/parse_monday_excel.py');
      await scriptFile.writeAsString(pythonScript);

      // Run Python script
      final result = await Process.run(
        'python',
        [scriptFile.path, filePath],
        stdoutEncoding: const SystemEncoding(),
        stderrEncoding: const SystemEncoding(),
      );

      // Clean up
      try {
        await scriptFile.delete();
      } catch (_) {}

      if (result.exitCode != 0) {
        debugPrint('[SundayService] Python error: ${result.stderr}');
        return null;
      }

      final output = result.stdout.toString().trim();
      if (output.isEmpty) {
        debugPrint('[SundayService] Empty output from Python');
        return null;
      }

      return jsonDecode(output) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[SundayService] Error parsing Excel with Python: $e');
      return null;
    }
  }

  /// Generate column key from name
  static String _generateColumnKey(String name) {
    var key = name.toLowerCase().trim();
    key = key.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    key = key.replaceAll(RegExp(r'^_+|_+$'), '');
    if (key.length > 50) key = key.substring(0, 50);
    return key.isEmpty ? 'column' : key;
  }

  /// Map Monday column names to Sunday column types
  static String _mapColumnType(String columnName) {
    final name = columnName.toLowerCase();
    if (name.contains('status')) return 'status';
    if (name.contains('person') || name.contains('owner') || name.contains('assignee')) return 'person';
    if (name.contains('date') || name.contains('due')) return 'date';
    if (name.contains('priority')) return 'priority';
    if (name.contains('email')) return 'email';
    if (name.contains('phone')) return 'phone';
    if (name.contains('number') || name.contains('amount') || name.contains('value')) return 'number';
    if (name.contains('link') || name.contains('url')) return 'link';
    if (name.contains('tag')) return 'tags';
    if (name.contains('progress')) return 'progress';
    if (name.contains('rating')) return 'rating';
    if (name.contains('checkbox')) return 'checkbox';
    return 'text';
  }

  // ============================================
  // Sunday SETTINGS & DEFAULT LABELS
  // ============================================

  /// Get default labels for a given type (status, priority, etc.)
  static Future<List<SundayDefaultLabel>> getDefaultLabels({
    String type = 'status',
    required String username,
  }) async {
    try {
      // Add timestamp to bust cache
      final ts = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse('$_baseUrl/settings.php?action=list_default_labels&type=$type&username=$username&_t=$ts'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data']['labels'] as List)
              .map((l) => SundayDefaultLabel.fromJson(l))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('[SundayService] Error getting default labels: $e');
      return [];
    }
  }

  /// Create a new default label
  static Future<int?> createDefaultLabel({
    required String name,
    required String color,
    String type = 'status',
    bool isDone = false,
    bool isDefault = false,
    required String username,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/settings.php'),
        body: {
          'action': 'create_default_label',
          'type': type,
          'name': name,
          'color': color,
          'is_done': isDone ? '1' : '0',
          'is_default': isDefault ? '1' : '0',
          'username': username,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return _parseId(data['data']['id']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[SundayService] Error creating default label: $e');
      return null;
    }
  }

  /// Update a default label
  static Future<bool> updateDefaultLabel({
    required int id,
    String? name,
    String? color,
    bool? isDone,
    bool? isDefault,
    required String username,
  }) async {
    try {
      final body = <String, String>{
        'action': 'update_default_label',
        'id': id.toString(),
        'username': username,
      };

      if (name != null) body['name'] = name;
      if (color != null) body['color'] = color;
      if (isDone != null) body['is_done'] = isDone ? '1' : '0';
      if (isDefault != null) body['is_default'] = isDefault ? '1' : '0';

      final response = await http.post(
        Uri.parse('$_baseUrl/settings.php'),
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error updating default label: $e');
      return false;
    }
  }

  /// Delete a default label
  static Future<bool> deleteDefaultLabel(int id, String username) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/settings.php'),
        body: {
          'action': 'delete_default_label',
          'id': id.toString(),
          'username': username,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error deleting default label: $e');
      return false;
    }
  }

  /// Reorder default labels
  static Future<bool> reorderDefaultLabels(List<int> order, String username) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/settings.php'),
        body: {
          'action': 'reorder_default_labels',
          'order': jsonEncode(order),
          'username': username,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error reordering default labels: $e');
      return false;
    }
  }

  // ============================================
  // LABEL CATEGORIES (Dynamic label groups)
  // ============================================

  /// Get all label categories (status, priority, and custom ones)
  static Future<List<LabelCategory>> getLabelCategories(String username) async {
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse('$_baseUrl/settings.php?action=list_label_categories&username=$username&_t=$ts'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data']['categories'] as List)
              .map((c) => LabelCategory.fromJson(c))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('[SundayService] Error getting label categories: $e');
      return [];
    }
  }

  /// Create a new label category
  static Future<String?> createLabelCategory({
    required String key,
    required String name,
    String? description,
    String icon = 'label',
    String color = '#808080',
    required String username,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/settings.php'),
        body: {
          'action': 'create_label_category',
          'key': key,
          'name': name,
          if (description != null) 'description': description,
          'icon': icon,
          'color': color,
          'username': username,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data']['key'] as String?;
        }
      }
      return null;
    } catch (e) {
      debugPrint('[SundayService] Error creating label category: $e');
      return null;
    }
  }

  /// Update a label category
  static Future<bool> updateLabelCategory({
    required String key,
    String? name,
    String? description,
    String? icon,
    String? color,
    int? position,
    required String username,
  }) async {
    try {
      final body = <String, String>{
        'action': 'update_label_category',
        'key': key,
        'username': username,
      };

      if (name != null) body['name'] = name;
      if (description != null) body['description'] = description;
      if (icon != null) body['icon'] = icon;
      if (color != null) body['color'] = color;
      if (position != null) body['position'] = position.toString();

      final response = await http.post(
        Uri.parse('$_baseUrl/settings.php'),
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error updating label category: $e');
      return false;
    }
  }

  /// Delete a label category and all its labels
  static Future<bool> deleteLabelCategory(String key, String username) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/settings.php'),
        body: {
          'action': 'delete_label_category',
          'key': key,
          'username': username,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error deleting label category: $e');
      return false;
    }
  }

  // ============================================
  // DASHBOARD & ANALYTICS (NEW HIGH-VALUE FEATURES)
  // ============================================

  /// Get dashboard data with KPIs for a board
  static Future<SundayDashboardData?> getDashboard(int boardId, {String? username}) async {
    try {
      var url = '$_baseUrl/features.php?action=dashboard&board_id=$boardId';
      if (username != null) url += '&username=$username';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return SundayDashboardData.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[SundayService] Error getting dashboard: $e');
      return null;
    }
  }

  /// Get detailed analytics for a board
  static Future<SundayAnalyticsData?> getAnalytics(
    int boardId, {
    String? startDate,
    String? endDate,
  }) async {
    try {
      var url = '$_baseUrl/features.php?action=analytics&board_id=$boardId';
      if (startDate != null) url += '&start_date=$startDate';
      if (endDate != null) url += '&end_date=$endDate';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return SundayAnalyticsData.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[SundayService] Error getting analytics: $e');
      return null;
    }
  }

  /// Get statistics for a specific column
  static Future<Map<String, dynamic>?> getColumnStats(int boardId, String columnKey) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/features.php?action=column_stats&board_id=$boardId&column_key=$columnKey'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return Map<String, dynamic>.from(data['data']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[SundayService] Error getting column stats: $e');
      return null;
    }
  }

  // ============================================
  // SAVED FILTERS
  // ============================================

  /// List saved filters for a board
  static Future<List<SundaySavedFilter>> getSavedFilters(int boardId, String username) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/features.php?action=list_filters&board_id=$boardId&username=$username'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data']['filters'] as List)
              .map((f) => SundaySavedFilter.fromJson(f))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('[SundayService] Error getting saved filters: $e');
      return [];
    }
  }

  /// Save a filter
  static Future<int?> saveFilter({
    required int boardId,
    required String name,
    required String username,
    required Map<String, dynamic> filterConfig,
    String? description,
    bool isShared = false,
    int? filterId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/features.php'),
        body: {
          'action': 'save_filter',
          'board_id': boardId.toString(),
          'name': name,
          'username': username,
          'filter_config': jsonEncode(filterConfig),
          if (description != null) 'description': description,
          'is_shared': isShared ? '1' : '0',
          if (filterId != null) 'id': filterId.toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return _parseId(data['data']['id']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[SundayService] Error saving filter: $e');
      return null;
    }
  }

  /// Delete a saved filter
  static Future<bool> deleteFilter(int filterId, String username) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/features.php'),
        body: {
          'action': 'delete_filter',
          'id': filterId.toString(),
          'username': username,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error deleting filter: $e');
      return false;
    }
  }

  /// Apply a filter and get matching items
  static Future<SundayFilterResult?> applyFilter({
    required int boardId,
    required Map<String, dynamic> filterConfig,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/features.php'),
        body: {
          'action': 'apply_filter',
          'board_id': boardId.toString(),
          'filter_config': jsonEncode(filterConfig),
          'limit': limit.toString(),
          'offset': offset.toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return SundayFilterResult.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[SundayService] Error applying filter: $e');
      return null;
    }
  }

  // ============================================
  // BULK ACTIONS
  // ============================================

  /// Update multiple items at once
  static Future<SundayBulkResult> bulkUpdate({
    required List<int> itemIds,
    required Map<String, dynamic> updates,
    required String username,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/features.php'),
        body: {
          'action': 'bulk_update',
          'item_ids': jsonEncode(itemIds),
          'updates': jsonEncode(updates),
          'username': username,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return SundayBulkResult.fromJson(data['data']);
        }
      }
      return SundayBulkResult(successCount: 0, totalCount: itemIds.length, errors: ['Request failed']);
    } catch (e) {
      debugPrint('[SundayService] Error in bulk update: $e');
      return SundayBulkResult(successCount: 0, totalCount: itemIds.length, errors: [e.toString()]);
    }
  }

  /// Move multiple items to a group
  static Future<SundayBulkResult> bulkMove({
    required List<int> itemIds,
    required int groupId,
    required String username,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/features.php'),
        body: {
          'action': 'bulk_move',
          'item_ids': jsonEncode(itemIds),
          'group_id': groupId.toString(),
          'username': username,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return SundayBulkResult(
            successCount: data['data']['moved_count'] ?? 0,
            totalCount: itemIds.length,
            message: data['data']['message'],
          );
        }
      }
      return SundayBulkResult(successCount: 0, totalCount: itemIds.length, errors: ['Request failed']);
    } catch (e) {
      debugPrint('[SundayService] Error in bulk move: $e');
      return SundayBulkResult(successCount: 0, totalCount: itemIds.length, errors: [e.toString()]);
    }
  }

  /// Delete multiple items
  static Future<SundayBulkResult> bulkDelete({
    required List<int> itemIds,
    required String username,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/features.php'),
        body: {
          'action': 'bulk_delete',
          'item_ids': jsonEncode(itemIds),
          'username': username,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return SundayBulkResult(
            successCount: data['data']['deleted_count'] ?? 0,
            totalCount: itemIds.length,
            message: data['data']['message'],
          );
        }
      }
      return SundayBulkResult(successCount: 0, totalCount: itemIds.length, errors: ['Request failed']);
    } catch (e) {
      debugPrint('[SundayService] Error in bulk delete: $e');
      return SundayBulkResult(successCount: 0, totalCount: itemIds.length, errors: [e.toString()]);
    }
  }

  /// Duplicate multiple items
  static Future<SundayBulkDuplicateResult> bulkDuplicate({
    required List<int> itemIds,
    required String username,
    int? targetGroupId,
  }) async {
    try {
      final body = {
        'action': 'bulk_duplicate',
        'item_ids': jsonEncode(itemIds),
        'username': username,
      };
      if (targetGroupId != null) body['target_group_id'] = targetGroupId.toString();

      final response = await http.post(
        Uri.parse('$_baseUrl/features.php'),
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return SundayBulkDuplicateResult.fromJson(data['data']);
        }
      }
      return SundayBulkDuplicateResult(duplicatedIds: [], duplicatedCount: 0);
    } catch (e) {
      debugPrint('[SundayService] Error in bulk duplicate: $e');
      return SundayBulkDuplicateResult(duplicatedIds: [], duplicatedCount: 0);
    }
  }

  // ============================================
  // DEPENDENCIES
  // ============================================

  /// Get dependencies for an item
  static Future<SundayDependencies?> getItemDependencies(int itemId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/features.php?action=dependencies&item_id=$itemId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return SundayDependencies.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[SundayService] Error getting dependencies: $e');
      return null;
    }
  }

  /// Add a dependency between items
  static Future<int?> addDependency({
    required int itemId,
    required int dependsOnItemId,
    required String username,
    String type = 'blocks',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/features.php'),
        body: {
          'action': 'add_dependency',
          'item_id': itemId.toString(),
          'depends_on_item_id': dependsOnItemId.toString(),
          'username': username,
          'type': type,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return _parseId(data['data']['id']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[SundayService] Error adding dependency: $e');
      return null;
    }
  }

  /// Remove a dependency
  static Future<bool> removeDependency(int dependencyId, String username) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/features.php'),
        body: {
          'action': 'remove_dependency',
          'id': dependencyId.toString(),
          'username': username,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error removing dependency: $e');
      return false;
    }
  }

  // ============================================
  // FORMULA COLUMNS
  // ============================================

  /// Evaluate a formula for an item
  static Future<dynamic> evaluateFormula(int itemId, String formula) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/features.php'),
        body: {
          'action': 'evaluate_formula',
          'item_id': itemId.toString(),
          'formula': formula,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data']['result'];
        }
      }
      return null;
    } catch (e) {
      debugPrint('[SundayService] Error evaluating formula: $e');
      return null;
    }
  }

  /// Get available formula functions
  static Future<List<FormulaFunction>> getFormulaFunctions() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/features.php?action=formula_functions'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data']['functions'] as List)
              .map((f) => FormulaFunction.fromJson(f))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('[SundayService] Error getting formula functions: $e');
      return [];
    }
  }

  // ============================================
  // DUPLICATE DETECTION
  // ============================================

  /// Check for duplicates in a board
  static Future<List<SundayDuplicate>> checkDuplicates(int boardId, {String columnKeys = 'name'}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/features.php?action=check_duplicates&board_id=$boardId&column_keys=$columnKeys'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data']['duplicates'] as List)
              .map((d) => SundayDuplicate.fromJson(d))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('[SundayService] Error checking duplicates: $e');
      return [];
    }
  }

  /// Find similar items to a given name
  static Future<List<SundaySimilarItem>> findSimilarItems(int boardId, String name, {int threshold = 70}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/features.php?action=find_similar&board_id=$boardId&name=${Uri.encodeComponent(name)}&threshold=$threshold'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data']['similar_items'] as List)
              .map((s) => SundaySimilarItem.fromJson(s))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('[SundayService] Error finding similar items: $e');
      return [];
    }
  }

  // ============================================
  // EXPORT
  // ============================================

  /// Export board to CSV
  static Future<SundayExportResult?> exportToCsv(int boardId, {bool includeSubitems = false}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/features.php?action=export_csv&board_id=$boardId&include_subitems=${includeSubitems ? 1 : 0}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return SundayExportResult.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[SundayService] Error exporting to CSV: $e');
      return null;
    }
  }

  /// Export board to JSON
  static Future<SundayExportResult?> exportToJson(int boardId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/features.php?action=export_json&board_id=$boardId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return SundayExportResult.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[SundayService] Error exporting to JSON: $e');
      return null;
    }
  }

  // ============================================
  // ITEM TEMPLATES
  // ============================================

  /// List item templates for a board
  static Future<List<SundayItemTemplate>> getItemTemplates(int boardId, String username) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/features.php?action=list_templates&board_id=$boardId&username=$username'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data']['templates'] as List)
              .map((t) => SundayItemTemplate.fromJson(t))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('[SundayService] Error getting item templates: $e');
      return [];
    }
  }

  /// Save an item template
  static Future<int?> saveItemTemplate({
    required int boardId,
    required String name,
    required String username,
    required Map<String, dynamic> defaultValues,
    String? description,
    bool isShared = false,
    int? templateId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/features.php'),
        body: {
          'action': 'save_template',
          'board_id': boardId.toString(),
          'name': name,
          'username': username,
          'default_values': jsonEncode(defaultValues),
          if (description != null) 'description': description,
          'is_shared': isShared ? '1' : '0',
          if (templateId != null) 'id': templateId.toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return _parseId(data['data']['id']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[SundayService] Error saving item template: $e');
      return null;
    }
  }

  /// Delete an item template
  static Future<bool> deleteItemTemplate(int templateId, String username) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/features.php'),
        body: {
          'action': 'delete_template',
          'id': templateId.toString(),
          'username': username,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error deleting item template: $e');
      return false;
    }
  }

  /// Create item from template
  static Future<int?> createItemFromTemplate({
    required int templateId,
    required int groupId,
    required String name,
    required String username,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/features.php'),
        body: {
          'action': 'create_from_template',
          'template_id': templateId.toString(),
          'group_id': groupId.toString(),
          'name': name,
          'username': username,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return _parseId(data['data']['id']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[SundayService] Error creating item from template: $e');
      return null;
    }
  }

  // ============================================
  // BOARD TEMPLATES (Saved Templates)
  // ============================================

  /// Get all board templates (built-in + saved)
  static Future<SundayBoardTemplateList?> getBoardTemplates({String? username, String? category}) async {
    try {
      var url = '$_baseUrl/board_templates.php?action=list';
      if (username != null) url += '&username=$username';
      if (category != null) url += '&category=$category';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return SundayBoardTemplateList.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[SundayService] Error getting board templates: $e');
      return null;
    }
  }

  /// Get a specific board template with full data
  static Future<SundaySavedBoardTemplate?> getBoardTemplate(String templateId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/board_templates.php?action=get&id=$templateId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return SundaySavedBoardTemplate.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[SundayService] Error getting board template: $e');
      return null;
    }
  }

  /// Save a board as a template
  static Future<int?> saveBoardAsTemplate({
    required int boardId,
    required String name,
    required String username,
    String? description,
    String icon = 'dashboard',
    String color = '#579bfc',
    String category = 'Custom',
    bool isShared = true,
    bool includeItems = false,
    bool includeAutomations = true,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/board_templates.php'),
        body: {
          'action': 'save',
          'board_id': boardId.toString(),
          'name': name,
          'username': username,
          if (description != null) 'description': description,
          'icon': icon,
          'color': color,
          'category': category,
          'is_shared': isShared ? '1' : '0',
          'include_items': includeItems ? '1' : '0',
          'include_automations': includeAutomations ? '1' : '0',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return _parseId(data['data']['id']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[SundayService] Error saving board as template: $e');
      return null;
    }
  }

  /// Update a board template's metadata
  static Future<bool> updateBoardTemplate({
    required int templateId,
    required String username,
    String? name,
    String? description,
    String? icon,
    String? color,
    String? category,
    bool? isShared,
  }) async {
    try {
      final body = <String, String>{
        'action': 'update',
        'id': templateId.toString(),
        'username': username,
      };
      if (name != null) body['name'] = name;
      if (description != null) body['description'] = description;
      if (icon != null) body['icon'] = icon;
      if (color != null) body['color'] = color;
      if (category != null) body['category'] = category;
      if (isShared != null) body['is_shared'] = isShared ? '1' : '0';

      final response = await http.post(
        Uri.parse('$_baseUrl/board_templates.php'),
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error updating board template: $e');
      return false;
    }
  }

  /// Delete a board template
  static Future<bool> deleteBoardTemplate(int templateId, String username) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/board_templates.php'),
        body: {
          'action': 'delete',
          'id': templateId.toString(),
          'username': username,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[SundayService] Error deleting board template: $e');
      return false;
    }
  }

  /// Create a board from a saved template
  static Future<int?> createBoardFromSavedTemplate({
    required String templateId,
    required int workspaceId,
    required String name,
    required String username,
    int? folderId,
    bool includeItems = false,
    bool includeAutomations = true,
  }) async {
    try {
      final body = <String, String>{
        'action': 'create_board',
        'template_id': templateId,
        'workspace_id': workspaceId.toString(),
        'name': name,
        'username': username,
        'include_items': includeItems ? '1' : '0',
        'include_automations': includeAutomations ? '1' : '0',
      };
      if (folderId != null) body['folder_id'] = folderId.toString();

      final response = await http.post(
        Uri.parse('$_baseUrl/board_templates.php'),
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return _parseId(data['data']['board_id']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[SundayService] Error creating board from saved template: $e');
      return null;
    }
  }
}

/// Board template definition
class BoardTemplate {
  final String id;
  final String name;
  final String description;
  final String icon;
  final List<Map<String, dynamic>> columns;
  final List<String> groups;

  const BoardTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.columns,
    required this.groups,
  });
}

/// Monday import preview data
class MondayImportPreview {
  final String boardName;
  final List<MondayGroupPreview> groups;
  final List<MondayColumnPreview> columns;
  final int totalItems;

  MondayImportPreview({
    required this.boardName,
    required this.groups,
    required this.columns,
    required this.totalItems,
  });

  factory MondayImportPreview.fromJson(Map<String, dynamic> json) {
    return MondayImportPreview(
      boardName: json['board_name'] ?? 'Imported Board',
      groups: (json['groups'] as List?)
              ?.map((g) => MondayGroupPreview.fromJson(g))
              .toList() ??
          [],
      columns: (json['columns'] as List?)
              ?.map((c) => MondayColumnPreview.fromJson(c))
              .toList() ??
          [],
      totalItems: json['total_items'] ?? 0,
    );
  }
}

class MondayGroupPreview {
  final String title;
  final int itemCount;

  MondayGroupPreview({required this.title, required this.itemCount});

  factory MondayGroupPreview.fromJson(Map<String, dynamic> json) {
    return MondayGroupPreview(
      title: json['title'] ?? '',
      itemCount: json['item_count'] ?? 0,
    );
  }
}

class MondayColumnPreview {
  final String name;
  final String key;
  final String type;
  final List<String> sampleValues;

  MondayColumnPreview({
    required this.name,
    required this.key,
    required this.type,
    required this.sampleValues,
  });

  factory MondayColumnPreview.fromJson(Map<String, dynamic> json) {
    return MondayColumnPreview(
      name: json['name'] ?? '',
      key: json['key'] ?? '',
      type: json['type'] ?? 'text',
      sampleValues: List<String>.from(json['sample_values'] ?? []),
    );
  }
}

/// Monday import result
class MondayImportResult {
  final int boardId;
  final String boardName;
  final int groupsImported;
  final int itemsImported;
  final int columnsCreated;
  final String message;

  MondayImportResult({
    required this.boardId,
    required this.boardName,
    required this.groupsImported,
    required this.itemsImported,
    required this.columnsCreated,
    required this.message,
  });

  factory MondayImportResult.fromJson(Map<String, dynamic> json) {
    return MondayImportResult(
      boardId: json['board_id'] ?? 0,
      boardName: json['board_name'] ?? '',
      groupsImported: json['groups_imported'] ?? 0,
      itemsImported: json['items_imported'] ?? 0,
      columnsCreated: json['columns_created'] ?? 0,
      message: json['message'] ?? 'Import complete',
    );
  }
}
