/// Sunday Main Screen
/// Workspace and board selector - entry point for Sunday board functionality
library;

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../app_theme.dart';
import 'models/sunday_models.dart';
import 'sunday_service.dart';
import 'sunday_board_screen.dart';
import 'widgets/monday_import_dialog.dart';
import 'widgets/sunday_settings_dialog.dart';

class SundayScreen extends StatefulWidget {
  final String username;
  final String role;

  const SundayScreen({
    super.key,
    required this.username,
    required this.role,
  });

  @override
  State<SundayScreen> createState() => _SundayScreenState();
}

class _SundayScreenState extends State<SundayScreen> {
  List<SundayWorkspace> _workspaces = [];
  bool _loading = true;
  String? _error;

  // Currently selected workspace
  SundayWorkspace? _selectedWorkspace;

  // Boards and folders for selected workspace
  List<SundayBoard> _boards = [];
  List<SundayBoardFolder> _folders = [];
  final Set<int> _collapsedFolders = {};
  bool _loadingBoards = false;

  // Drag and drop state
  int? _dragTargetBoardId;
  int? _dragTargetFolderId;

  // Currently selected board (for inline display)
  SundayBoard? _selectedBoard;

  // Sunday Admin permission
  bool _isSundayAdmin = false;

  // Debounce timer for sidebar refresh
  Timer? _sidebarRefreshTimer;

  // Debounce timer for search
  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    _checkSundayAdmin();
    _loadWorkspaces();
  }

  @override
  void dispose() {
    _sidebarRefreshTimer?.cancel();
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  /// Refresh sidebar with debounce to avoid excessive API calls
  void _refreshSidebarDebounced() {
    _sidebarRefreshTimer?.cancel();
    _sidebarRefreshTimer = Timer(const Duration(milliseconds: 500), () {
      if (_selectedWorkspace != null && mounted) {
        _selectWorkspace(_selectedWorkspace!, closeBoard: false);
      }
    });
  }

  Future<void> _checkSundayAdmin() async {
    // First check role-based access (instant)
    final hasRoleAccess = SundayService.hasRoleBasedSundayAccess(widget.role);
    if (hasRoleAccess) {
      setState(() => _isSundayAdmin = true);
      return;
    }

    // Then check API for explicit Sunday admin flag
    final isAdmin = await SundayService.hasSundayAdminAccess(widget.username);
    if (mounted) {
      setState(() => _isSundayAdmin = isAdmin);
    }
  }

  Future<void> _loadWorkspaces() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final workspaces = await SundayService.getWorkspaces(widget.username);
      if (mounted) {
        setState(() {
          _workspaces = workspaces;
          _loading = false;

          // Auto-select first workspace if available
          if (workspaces.isNotEmpty && _selectedWorkspace == null) {
            _selectWorkspace(workspaces.first);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _selectWorkspace(SundayWorkspace workspace, {bool closeBoard = true}) async {
    setState(() {
      _selectedWorkspace = workspace;
      _loadingBoards = true;
      // Close any open board when selecting a workspace
      if (closeBoard) {
        _selectedBoard = null;
      }
    });

    final result = await SundayService.getBoardsWithFolders(workspace.id, widget.username);
    if (mounted) {
      setState(() {
        _boards = result.boards;
        _folders = result.folders;
        _loadingBoards = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = !isDesktop || screenWidth < 600;
    // Cache theme lookups to avoid redundant calls
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = theme.cardColor;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Sunday',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          // Settings icon - only visible to Sunday admins
          if (_isSundayAdmin)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Sunday Settings',
              onPressed: () => _showSettingsDialog(),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            height: 1,
          ),
        ),
      ),
      body: _buildBody(isMobile),
      floatingActionButton: _isSundayAdmin && _selectedBoard == null
          ? FloatingActionButton.extended(
              onPressed: _showCreateBoardDialog,
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('New Board'),
            )
          : null,
    );
  }

  Widget _buildBody(bool isMobile) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadWorkspaces,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_workspaces.isEmpty) {
      return _buildEmptyState();
    }

    if (isMobile) {
      return _buildMobileLayout();
    }

    return _buildDesktopLayout();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.dashboard_customize,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 24),
            const Text(
              'Welcome to Sunday',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Create your first workspace and board to start managing\nyour leads, jobs, and projects.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (_isSundayAdmin)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _showCreateWorkspaceDialog,
                    icon: const Icon(Icons.folder_copy),
                    label: const Text('Create Workspace'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      side: const BorderSide(color: AppColors.accent),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: _showTemplatesDialog,
                    icon: const Icon(Icons.rocket_launch),
                    label: const Text('Start with Template'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
                ],
              )
            else
              Text(
                'Contact your administrator to set up workspaces.',
                style: TextStyle(color: Colors.grey.shade500),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    return Row(
      children: [
        // Sidebar with workspaces and boards
        Container(
          width: 280,
          decoration: BoxDecoration(
            color: theme.cardColor,
            border: Border(
              right: BorderSide(color: borderColor),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Workspaces header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      'Workspaces',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey.shade400 : Colors.grey,
                      ),
                    ),
                    const Spacer(),
                    if (_isSundayAdmin)
                      IconButton(
                        icon: const Icon(Icons.add, size: 18),
                        onPressed: _showCreateWorkspaceDialog,
                        tooltip: 'New workspace',
                      ),
                  ],
                ),
              ),

              // Workspaces list
              Expanded(
                child: ListView.builder(
                  itemCount: _workspaces.length,
                  itemBuilder: (context, index) {
                    final workspace = _workspaces[index];
                    return _buildWorkspaceItem(workspace);
                  },
                ),
              ),
            ],
          ),
        ),

        // Main content - boards grid or selected board view
        Expanded(
          child: _selectedBoard != null
              ? SundayBoardScreen(
                  key: ValueKey('board_${_selectedBoard!.id}'),
                  boardId: _selectedBoard!.id,
                  username: widget.username,
                  role: widget.role,
                  embedded: true,
                  onBack: _closeBoard,
                  onBoardUpdated: _refreshSidebarDebounced,
                )
              : _buildBoardsContent(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return RefreshIndicator(
      onRefresh: _loadWorkspaces,
      color: AppColors.accent,
      child: CustomScrollView(
        slivers: [
          // Workspace selector
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Workspace',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                      const Spacer(),
                      if (_isSundayAdmin)
                        TextButton.icon(
                          onPressed: _showCreateWorkspaceDialog,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('New'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildWorkspaceDropdown(),
                ],
              ),
            ),
          ),

          // Boards header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'Boards',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_boards.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_boards.length}',
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Boards list
          if (_loadingBoards)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_boards.isEmpty)
            SliverFillRemaining(
              child: _buildNoBoardsMessage(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildBoardCard(_boards[index]),
                  childCount: _boards.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceItem(SundayWorkspace workspace) {
    final isSelected = _selectedWorkspace?.id == workspace.id;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final subtitleColor = isDark ? Colors.grey.shade500 : Colors.grey.shade500;

    return Column(
      children: [
        InkWell(
          onTap: () => _selectWorkspace(workspace),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.accent.withValues(alpha: 0.1) : null,
              border: Border(
                left: BorderSide(
                  color: isSelected ? AppColors.accent : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _getWorkspaceIcon(workspace.icon),
                  color: isSelected ? AppColors.accent : iconColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workspace.name,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? AppColors.accent : null,
                        ),
                      ),
                      if (workspace.description != null &&
                          workspace.description!.isNotEmpty)
                        Text(
                          workspace.description!,
                          style: TextStyle(
                            fontSize: 11,
                            color: subtitleColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (_isSundayAdmin)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: iconColor, size: 18),
                    onSelected: (action) => _handleWorkspaceAction(action, workspace),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'rename',
                        child: Text('Rename'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        // Show boards list when workspace is selected
        if (isSelected) _buildBoardsList(),
      ],
    );
  }

  Widget _buildBoardsList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    if (_loadingBoards) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }

    if (_boards.isEmpty && _folders.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          'No boards yet',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    // Organize boards: first by folders, then unfiled boards
    final boardsByFolder = <int?, List<SundayBoard>>{};
    for (final board in _boards) {
      boardsByFolder.putIfAbsent(board.folderId, () => []).add(board);
    }

    final items = <Widget>[];

    // Add folders with their boards
    for (final folder in _folders) {
      final folderBoards = boardsByFolder[folder.id] ?? [];
      final isCollapsed = _collapsedFolders.contains(folder.id);

      items.add(_buildFolderItem(folder, folderBoards.length, isCollapsed, borderColor, isDark));

      if (!isCollapsed) {
        for (final board in folderBoards) {
          items.add(_buildBoardItem(board, borderColor, isDark, indentLevel: 2, targetFolderId: folder.id));
        }
      }
    }

    // Add unfiled boards (boards without a folder)
    final unfiledBoards = boardsByFolder[null] ?? [];
    for (final board in unfiledBoards) {
      items.add(_buildBoardItem(board, borderColor, isDark, indentLevel: 1, targetFolderId: null));
    }

    // Add "Create folder" button for admins
    if (_isSundayAdmin) {
      items.add(
        InkWell(
          onTap: _showCreateFolderDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            margin: const EdgeInsets.only(left: 24),
            child: Row(
              children: [
                Icon(
                  Icons.create_new_folder_outlined,
                  size: 14,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                ),
                const SizedBox(width: 8),
                Text(
                  'New Folder',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(children: items);
  }

  Widget _buildFolderItem(SundayBoardFolder folder, int boardCount, bool isCollapsed, Color borderColor, bool isDark) {
    final folderColor = _parseColor(folder.color);
    final isDragTarget = _dragTargetFolderId == folder.id;

    final folderWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.only(left: 24),
      decoration: BoxDecoration(
        color: isDragTarget ? AppColors.accent.withValues(alpha: 0.1) : null,
        border: Border(
          left: BorderSide(color: isDragTarget ? AppColors.accent : borderColor),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isCollapsed ? Icons.folder : Icons.folder_open,
            size: 16,
            color: isDragTarget ? AppColors.accent : folderColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              folder.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDragTarget ? AppColors.accent : folderColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '$boardCount',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
            ),
          ),
          if (_isSundayAdmin)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 16, color: isDark ? Colors.grey.shade500 : Colors.grey.shade500),
              padding: EdgeInsets.zero,
              onSelected: (action) => _handleFolderAction(action, folder),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'rename', child: Text('Rename')),
                const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
              ],
            ),
        ],
      ),
    );

    // Wrap with DragTarget to accept board drops
    if (!_isSundayAdmin) {
      return InkWell(
        onTap: () {
          setState(() {
            if (isCollapsed) {
              _collapsedFolders.remove(folder.id);
            } else {
              _collapsedFolders.add(folder.id);
            }
          });
        },
        child: folderWidget,
      );
    }

    return DragTarget<SundayBoard>(
      onWillAcceptWithDetails: (details) {
        // Accept if board is not already in this folder
        if (details.data.folderId != folder.id) {
          setState(() => _dragTargetFolderId = folder.id);
          return true;
        }
        return false;
      },
      onLeave: (_) => setState(() => _dragTargetFolderId = null),
      onAcceptWithDetails: (details) {
        setState(() => _dragTargetFolderId = null);
        _moveBoardToFolder(details.data, folder.id);
      },
      builder: (context, candidateData, rejectedData) {
        return InkWell(
          onTap: () {
            setState(() {
              if (isCollapsed) {
                _collapsedFolders.remove(folder.id);
              } else {
                _collapsedFolders.add(folder.id);
              }
            });
          },
          child: folderWidget,
        );
      },
    );
  }

  Widget _buildBoardItem(SundayBoard board, Color borderColor, bool isDark, {int indentLevel = 1, int? targetFolderId}) {
    final isBoardSelected = _selectedBoard?.id == board.id;
    final leftMargin = 16.0 + (indentLevel - 1) * 12.0;
    final isDragTarget = _dragTargetBoardId == board.id;

    final boardWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      margin: EdgeInsets.only(left: leftMargin),
      decoration: BoxDecoration(
        color: isBoardSelected ? AppColors.accent.withValues(alpha: 0.15) : null,
        border: Border(
          left: BorderSide(color: borderColor),
          top: isDragTarget ? const BorderSide(color: AppColors.accent, width: 2) : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          if (_isSundayAdmin)
            Icon(
              Icons.drag_indicator,
              size: 12,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
          if (_isSundayAdmin) const SizedBox(width: 4),
          Icon(
            Icons.dashboard_outlined,
            size: 14,
            color: isBoardSelected ? AppColors.accent : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              board.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBoardSelected ? FontWeight.w600 : FontWeight.normal,
                color: isBoardSelected ? AppColors.accent : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${board.itemCount}',
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );

    // Wrap in drag-and-drop widgets only for admins
    if (!_isSundayAdmin) {
      return InkWell(
        onTap: () => _openBoard(board),
        child: boardWidget,
      );
    }

    return DragTarget<SundayBoard>(
      onWillAcceptWithDetails: (details) {
        if (details.data.id != board.id) {
          setState(() => _dragTargetBoardId = board.id);
          return true;
        }
        return false;
      },
      onLeave: (_) => setState(() => _dragTargetBoardId = null),
      onAcceptWithDetails: (details) {
        setState(() => _dragTargetBoardId = null);
        _reorderBoard(details.data, board.position, targetFolderId);
      },
      builder: (context, candidateData, rejectedData) {
        return Draggable<SundayBoard>(
          data: board,
          feedback: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.dashboard_outlined, size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    board.name,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: boardWidget,
          ),
          child: InkWell(
            onTap: () => _openBoard(board),
            onSecondaryTapUp: (details) => _showBoardContextMenu(details, board),
            child: boardWidget,
          ),
        );
      },
    );
  }

  Color _parseColor(String colorString) {
    try {
      if (colorString.startsWith('#')) {
        return Color(int.parse(colorString.substring(1), radix: 16) | 0xFF000000);
      }
    } catch (_) {}
    return Colors.grey;
  }

  void _showBoardContextMenu(TapUpDetails details, SundayBoard board) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        details.globalPosition & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem(value: 'move_to_folder', child: Text('Move to folder...')),
        if (board.folderId != null)
          const PopupMenuItem(value: 'remove_from_folder', child: Text('Remove from folder')),
      ],
    ).then((value) {
      if (value == 'move_to_folder') {
        _showMoveBoardDialog(board);
      } else if (value == 'remove_from_folder') {
        _moveBoardToFolder(board, null);
      }
    });
  }

  void _showMoveBoardDialog(SundayBoard board) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Move "${board.name}" to folder'),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_folders.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No folders yet. Create a folder first.'),
                )
              else
                ..._folders.map((folder) => ListTile(
                  leading: Icon(Icons.folder, color: _parseColor(folder.color)),
                  title: Text(folder.name),
                  onTap: () {
                    Navigator.pop(ctx);
                    _moveBoardToFolder(board, folder.id);
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

  Future<void> _moveBoardToFolder(SundayBoard board, int? folderId) async {
    final success = await SundayService.moveBoard(
      boardId: board.id,
      username: widget.username,
      folderId: folderId,
    );

    if (success && _selectedWorkspace != null) {
      _selectWorkspace(_selectedWorkspace!, closeBoard: false);
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => SundaySettingsDialog(username: widget.username),
    );
  }

  void _showCreateFolderDialog() {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Folder'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Folder name',
            hintText: 'e.g., Marketing',
          ),
          onSubmitted: (_) => _createFolder(ctx, nameController.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => _createFolder(ctx, nameController.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createFolder(BuildContext ctx, String name) async {
    if (name.trim().isEmpty || _selectedWorkspace == null) return;

    Navigator.pop(ctx);

    final folderId = await SundayService.createFolder(
      workspaceId: _selectedWorkspace!.id,
      name: name.trim(),
      username: widget.username,
    );

    if (folderId != null) {
      _selectWorkspace(_selectedWorkspace!, closeBoard: false);
    }
  }

  Future<void> _reorderBoard(SundayBoard draggedBoard, int targetPosition, int? targetFolderId) async {
    if (_selectedWorkspace == null) return;

    // Build the new order: get boards in the target folder, insert dragged board at target position
    final boardsInTargetFolder = _boards.where((b) => b.folderId == targetFolderId).toList();
    boardsInTargetFolder.sort((a, b) => a.position.compareTo(b.position));

    // Remove the dragged board if it was in this folder
    boardsInTargetFolder.removeWhere((b) => b.id == draggedBoard.id);

    // Find insertion index based on target position
    int insertIndex = boardsInTargetFolder.indexWhere((b) => b.position >= targetPosition);
    if (insertIndex == -1) insertIndex = boardsInTargetFolder.length;

    // Insert at the correct position
    boardsInTargetFolder.insert(insertIndex, draggedBoard);

    // Build order list
    final boardOrder = boardsInTargetFolder.map((b) => b.id).toList();

    // Call API to reorder and move to folder if needed
    final success = await SundayService.reorderBoards(
      workspaceId: _selectedWorkspace!.id,
      boardOrder: boardOrder,
      username: widget.username,
      folderId: targetFolderId,
    );

    if (success) {
      _selectWorkspace(_selectedWorkspace!, closeBoard: false);
    }
  }

  void _handleFolderAction(String action, SundayBoardFolder folder) {
    switch (action) {
      case 'rename':
        _showRenameFolderDialog(folder);
        break;
      case 'delete':
        _confirmDeleteFolder(folder);
        break;
    }
  }

  void _showRenameFolderDialog(SundayBoardFolder folder) {
    final nameController = TextEditingController(text: folder.name);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Folder'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Folder name'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              nameController.dispose();
              Navigator.pop(ctx);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              nameController.dispose();
              Navigator.pop(ctx);
              try {
                final success = await SundayService.updateFolder(
                  folderId: folder.id,
                  username: widget.username,
                  name: name,
                );
                if (success && _selectedWorkspace != null && mounted) {
                  _selectWorkspace(_selectedWorkspace!, closeBoard: false);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to rename folder: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((_) {
      // Ensure disposal if dialog dismissed by tapping outside
      if (nameController.hasListeners) {
        nameController.dispose();
      }
    });
  }

  void _confirmDeleteFolder(SundayBoardFolder folder) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Folder'),
        content: Text('Delete "${folder.name}"? Boards in this folder will be moved to the root level.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final success = await SundayService.deleteFolder(folder.id, widget.username);
                if (success && _selectedWorkspace != null && mounted) {
                  _selectWorkspace(_selectedWorkspace!, closeBoard: false);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete folder: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<int>(
        value: _selectedWorkspace?.id,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        hint: const Text('Select workspace'),
        items: _workspaces.map((workspace) {
          return DropdownMenuItem(
            value: workspace.id,
            child: Row(
              children: [
                Icon(
                  _getWorkspaceIcon(workspace.icon),
                  size: 18,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Text(workspace.name),
              ],
            ),
          );
        }).toList(),
        onChanged: (workspaceId) {
          if (workspaceId != null) {
            final workspace = _workspaces.where((w) => w.id == workspaceId).firstOrNull;
            if (workspace != null) {
              _selectWorkspace(workspace);
            }
          }
        },
      ),
    );
  }

  Widget _buildBoardsContent() {
    if (_selectedWorkspace == null) {
      return Center(
        child: Text(
          'Select a workspace to view boards',
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }

    if (_loadingBoards) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_boards.isEmpty && _folders.isEmpty) {
      return _buildNoBoardsMessage();
    }

    // Build items: folders first (with their boards), then unfiled boards
    final items = <Widget>[];
    final boardsByFolder = <int?, List<SundayBoard>>{};
    for (final board in _boards) {
      boardsByFolder.putIfAbsent(board.folderId, () => []).add(board);
    }

    // Add folder sections
    for (final folder in _folders) {
      final folderBoards = boardsByFolder[folder.id] ?? [];
      items.add(_buildFolderGridSection(folder, folderBoards));
    }

    // Add unfiled boards section if there are any
    final unfiledBoards = boardsByFolder[null] ?? [];
    if (unfiledBoards.isNotEmpty) {
      if (_folders.isNotEmpty) {
        // Add a separator for unfiled boards only if there are folders
        items.add(_buildUnfiledBoardsSection(unfiledBoards));
      } else {
        // No folders, just show boards in grid
        items.add(_buildBoardsGridSection(unfiledBoards));
      }
    }

    // Build folder widgets with drag target keys
    final folderWidgets = <Widget>[];
    for (int i = 0; i < _folders.length; i++) {
      final folder = _folders[i];
      final folderBoards = boardsByFolder[folder.id] ?? [];
      folderWidgets.add(
        _buildDraggableFolderSection(folder, folderBoards, i),
      );
    }

    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Draggable folder sections
            if (_isSundayAdmin && _folders.isNotEmpty)
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorder: _onReorderFolders,
                children: folderWidgets,
              )
            else
              ...items,

            // Unfiled boards (always at the bottom)
            if (unfiledBoards.isNotEmpty && _isSundayAdmin && _folders.isNotEmpty)
              _buildUnfiledBoardsSection(unfiledBoards)
            else if (unfiledBoards.isNotEmpty && _folders.isEmpty)
              _buildBoardsGridSection(unfiledBoards),
          ],
        ),
      ),
    );
  }

  void _onReorderFolders(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex == newIndex) return;

    final folder = _folders.removeAt(oldIndex);
    _folders.insert(newIndex, folder);
    setState(() {});

    // Update order on backend
    final order = _folders.map((f) => f.id).toList();
    await SundayService.reorderFolders(order, widget.username);
  }

  Widget _buildDraggableFolderSection(SundayBoardFolder folder, List<SundayBoard> boards, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final folderColor = _parseColor(folder.color);
    final isExpanded = !_collapsedFolders.contains(folder.id);

    return Container(
      key: ValueKey('folder_${folder.id}'),
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Folder header with drag handle
          Row(
            children: [
              // Drag handle
              ReorderableDragStartListener(
                index: index,
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.drag_indicator,
                      color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                      size: 20,
                    ),
                  ),
                ),
              ),

              // Folder header content
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        _collapsedFolders.add(folder.id);
                      } else {
                        _collapsedFolders.remove(folder.id);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Row(
                      children: [
                        Icon(
                          isExpanded ? Icons.folder_open : Icons.folder,
                          color: folderColor,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          folder.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: folderColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${boards.length})',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Folder boards
          if (isExpanded && boards.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildBoardsGridSection(boards),
          ],

          if (isExpanded && boards.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  Text(
                    'No boards in this folder',
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  if (_isSundayAdmin) ...[
                    const SizedBox(width: 16),
                    TextButton.icon(
                      onPressed: () => _showCreateBoardDialog(folderId: folder.id),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Board'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFolderGridSection(SundayBoardFolder folder, List<SundayBoard> boards) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final folderColor = _parseColor(folder.color);
    final isExpanded = !_collapsedFolders.contains(folder.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Folder header
        InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _collapsedFolders.add(folder.id);
              } else {
                _collapsedFolders.remove(folder.id);
              }
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.folder_open : Icons.folder,
                  color: folderColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  folder.name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: folderColor,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${boards.length})',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                  ),
                ),
                const Spacer(),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ),

        // Folder boards
        if (isExpanded && boards.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildBoardsGridSection(boards),
        ],

        if (isExpanded && boards.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Text(
                  'No boards in this folder',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (_isSundayAdmin) ...[
                  const SizedBox(width: 16),
                  TextButton.icon(
                    onPressed: () => _showCreateBoardDialog(folderId: folder.id),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Board'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accent,
                    ),
                  ),
                ],
              ],
            ),
          ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildUnfiledBoardsSection(List<SundayBoard> boards) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.dashboard_outlined,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              'Boards',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${boards.length})',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildBoardsGridSection(boards),
      ],
    );
  }

  Widget _buildBoardsGridSection(List<SundayBoard> boards) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 320,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.4,
      ),
      itemCount: boards.length,
      itemBuilder: (context, index) => _buildBoardCard(boards[index]),
    );
  }

  Widget _buildBoardCard(SundayBoard board) {
    // Get a summary of the board - use groupCount from API or fallback to groups.length
    final groupCount = board.groupCount > 0 ? board.groupCount : board.groups.length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openBoard(board),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Color bar header
            Container(
              height: 8,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.accent, Color(0xFFFF9800)],
                ),
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Board name
                    Text(
                      board.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    if (board.description != null &&
                        board.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        board.description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const Spacer(),

                    // Stats
                    Row(
                      children: [
                        _buildStat(Icons.view_list, '${board.itemCount}', 'items'),
                        const SizedBox(width: 16),
                        _buildStat(Icons.folder, '$groupCount', 'groups'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(
          '$value $label',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildNoBoardsMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dashboard, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'No boards yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first board to start tracking work',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            if (_isSundayAdmin)
              FilledButton.icon(
                onPressed: _showCreateBoardDialog,
                icon: const Icon(Icons.add),
                label: const Text('Create Board'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getWorkspaceIcon(String? icon) {
    switch (icon) {
      case 'work':
        return Icons.work;
      case 'home':
        return Icons.home;
      case 'star':
        return Icons.star;
      case 'favorite':
        return Icons.favorite;
      case 'folder':
      default:
        return Icons.folder;
    }
  }

  void _handleWorkspaceAction(String action, SundayWorkspace workspace) {
    switch (action) {
      case 'rename':
        _showRenameWorkspaceDialog(workspace);
        break;
      case 'delete':
        _confirmDeleteWorkspace(workspace);
        break;
    }
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Search Boards'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search by name...',
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: (query) {
            Navigator.pop(ctx);
            _searchBoardsDebounced(query);
          },
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

  void _searchBoardsDebounced(String query) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      _searchBoards(query);
    });
  }

  void _searchBoards(String query) async {
    if (query.trim().isEmpty) return;

    // Search in boards list first
    final matchingBoards = _boards.where((board) =>
        board.name.toLowerCase().contains(query.toLowerCase()) ||
        (board.description?.toLowerCase().contains(query.toLowerCase()) ?? false)
    ).toList();

    // Also search items in each board
    final List<Map<String, dynamic>> searchResults = [];

    for (final board in matchingBoards) {
      searchResults.add({
        'type': 'board',
        'board': board,
      });
    }

    // Search items in all boards (parallel for better performance)
    final searchFutures = _boards.map((board) async {
      try {
        final items = await SundayService.searchItems(
          boardId: board.id,
          query: query,
          limit: 10,
        );
        return items.map((item) => {
          'type': 'item',
          'item': item,
          'board': board,
        }).toList();
      } catch (e) {
        // Log error but don't fail the entire search
        debugPrint('Search error for board ${board.id}: $e');
        return <Map<String, dynamic>>[];
      }
    }).toList();

    final allResults = await Future.wait(searchFutures);
    for (final resultList in allResults) {
      searchResults.addAll(resultList);
    }

    if (!mounted) return;

    if (searchResults.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No results found for "$query"')),
      );
      return;
    }

    // Show search results dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.search),
            const SizedBox(width: 8),
            Text('Results for "$query"'),
          ],
        ),
        content: SizedBox(
          width: 500,
          height: 400,
          child: ListView.builder(
            itemCount: searchResults.length,
            itemBuilder: (ctx, index) {
              final result = searchResults[index];
              if (result['type'] == 'board') {
                final board = result['board'] as SundayBoard;
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.dashboard, color: AppColors.accent),
                  ),
                  title: Text(board.name),
                  subtitle: Text('Board in ${_selectedWorkspace?.name ?? "workspace"}'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openBoard(board);
                  },
                );
              } else {
                final item = result['item'];
                final board = result['board'];
                if (item is! SundayItem || board is! SundayBoard) {
                  return const SizedBox.shrink();
                }
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.article, color: Colors.grey),
                  ),
                  title: Text(item.name),
                  subtitle: Text('Item in ${board.name}'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openBoard(board);
                  },
                );
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showCreateWorkspaceDialog() async {
    final controller = TextEditingController();
    final descController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Workspace'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Workspace name',
                hintText: 'e.g., Sales, Operations',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
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
                Navigator.pop(ctx, {
                  'name': controller.text.trim(),
                  'description': descController.text.trim(),
                });
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null) {
      final workspaceId = await SundayService.createWorkspace(
        name: result['name']!,
        description: result['description'],
        username: widget.username,
      );
      if (workspaceId != null) {
        _loadWorkspaces();
      }
    }
  }

  void _showCreateBoardDialog({int? folderId}) async {
    if (_selectedWorkspace == null && _workspaces.isEmpty) {
      // Need to create workspace first
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a workspace first')),
      );
      _showCreateWorkspaceDialog();
      return;
    }

    final controller = TextEditingController();
    final descController = TextEditingController();
    String? selectedTemplate;
    bool isSavedTemplate = false;
    bool includeItems = false;
    int? selectedFolderId = folderId;

    // Fetch saved templates
    SundayBoardTemplateList? templateList;
    bool loadingTemplates = true;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Load templates on first build
          if (loadingTemplates) {
            SundayService.getBoardTemplates(username: widget.username).then((list) {
              if (context.mounted) {
                setDialogState(() {
                  templateList = list;
                  loadingTemplates = false;
                });
              }
            });
          }

          return AlertDialog(
            title: const Text('Create Board'),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Board name',
                        hintText: 'e.g., Lead Pipeline, Job Tracker',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Folder selection dropdown
                    if (_folders.isNotEmpty) ...[
                      DropdownButtonFormField<int?>(
                        value: selectedFolderId,
                        decoration: const InputDecoration(
                          labelText: 'Folder (optional)',
                          prefixIcon: Icon(Icons.folder_outlined),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('No folder'),
                          ),
                          ..._folders.map((folder) => DropdownMenuItem<int?>(
                            value: folder.id,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.folder,
                                  size: 16,
                                  color: _parseColor(folder.color),
                                ),
                                const SizedBox(width: 8),
                                Text(folder.name),
                              ],
                            ),
                          )),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            selectedFolderId = value;
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                    ] else
                      const SizedBox(height: 4),
                    const Text(
                      'Start from template (optional)',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),

                    // Built-in templates section
                    if (loadingTemplates)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else ...[
                      // Built-in templates
                      if (templateList?.builtinTemplates.isNotEmpty ?? SundayService.boardTemplates.isNotEmpty) ...[
                        Text(
                          'Built-in Templates',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: (templateList?.builtinTemplates ?? []).map((template) {
                            final isSelected = selectedTemplate == template.id && !isSavedTemplate;
                            return FilterChip(
                              selected: isSelected,
                              avatar: Icon(
                                _getTemplateIcon(template.icon),
                                size: 18,
                                color: isSelected ? AppColors.accent : Colors.grey[600],
                              ),
                              label: Text(template.name),
                              onSelected: (selected) {
                                setDialogState(() {
                                  selectedTemplate = selected ? template.id : null;
                                  isSavedTemplate = false;
                                  includeItems = false;
                                  if (selected && controller.text.isEmpty) {
                                    controller.text = template.name;
                                  }
                                });
                              },
                              selectedColor: AppColors.accent.withValues(alpha: 0.2),
                              checkmarkColor: AppColors.accent,
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Saved templates section
                      if (templateList?.savedTemplates.isNotEmpty ?? false) ...[
                        Text(
                          'Saved Templates',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: templateList!.savedTemplates.map((template) {
                            final isSelected = selectedTemplate == template.id && isSavedTemplate;
                            return FilterChip(
                              selected: isSelected,
                              avatar: Stack(
                                children: [
                                  Icon(
                                    _getTemplateIcon(template.icon),
                                    size: 18,
                                    color: isSelected ? AppColors.accent : Colors.grey[600],
                                  ),
                                  if (template.includeItems)
                                    Positioned(
                                      right: -2,
                                      bottom: -2,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 1),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              label: Text(template.name),
                              onSelected: (selected) {
                                setDialogState(() {
                                  selectedTemplate = selected ? template.id : null;
                                  isSavedTemplate = selected;
                                  includeItems = selected && template.includeItems;
                                  if (selected && controller.text.isEmpty) {
                                    controller.text = template.name;
                                  }
                                });
                              },
                              selectedColor: AppColors.accent.withValues(alpha: 0.2),
                              checkmarkColor: AppColors.accent,
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Green dot indicates template includes items',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],

                      // Include items checkbox (only for saved templates with items)
                      if (isSavedTemplate && selectedTemplate != null) ...[
                        const SizedBox(height: 12),
                        Builder(builder: (context) {
                          final template = templateList?.savedTemplates
                              .where((t) => t.id == selectedTemplate)
                              .firstOrNull;
                          if (template?.includeItems ?? false) {
                            return CheckboxListTile(
                              value: includeItems,
                              onChanged: (val) => setDialogState(() => includeItems = val ?? false),
                              title: const Text('Include items from template'),
                              subtitle: const Text('Copy all items with their values'),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            );
                          }
                          return const SizedBox.shrink();
                        }),
                      ],
                    ],
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
                  if (controller.text.trim().isNotEmpty) {
                    Navigator.pop(ctx, {
                      'name': controller.text.trim(),
                      'description': descController.text.trim(),
                      'template': selectedTemplate,
                      'is_saved_template': isSavedTemplate,
                      'include_items': includeItems,
                      'folder_id': selectedFolderId,
                    });
                  }
                },
                style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      final workspaceId = _selectedWorkspace?.id ?? _workspaces.first.id;
      final resultFolderId = result['folder_id'] as int?;

      int? boardId;
      if (result['template'] != null) {
        if (result['is_saved_template'] == true) {
          // Create from saved template (uses board_templates.php)
          boardId = await SundayService.createBoardFromSavedTemplate(
            templateId: result['template'],
            workspaceId: workspaceId,
            name: result['name'],
            username: widget.username,
            folderId: resultFolderId,
            includeItems: result['include_items'] ?? false,
          );
        } else {
          // Create from built-in template (uses boards.php)
          boardId = await SundayService.createBoardFromSavedTemplate(
            templateId: result['template'],
            workspaceId: workspaceId,
            name: result['name'],
            username: widget.username,
            folderId: resultFolderId,
          );
        }
      } else {
        // Create blank board
        boardId = await SundayService.createBoard(
          workspaceId: workspaceId,
          name: result['name'],
          description: result['description'],
          folderId: resultFolderId,
          username: widget.username,
        );
      }

      if (boardId != null && mounted) {
        // First, refresh the boards list to show the new board in sidebar
        if (_selectedWorkspace != null) {
          await _selectWorkspace(_selectedWorkspace!, closeBoard: false);
        }

        // Then try to open the newly created board
        final board = await SundayService.getBoard(boardId, widget.username);
        if (board != null && mounted) {
          _openBoard(board);
        } else if (mounted) {
          // Board was created but couldn't be opened - still show success
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Board "${result['name']}" created successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create board'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showTemplatesDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Board Templates'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: SundayService.boardTemplates.map((template) {
              return ListTile(
                leading: Icon(
                  _getTemplateIcon(template.icon),
                  color: AppColors.accent,
                ),
                title: Text(template.name),
                subtitle: Text(template.description),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(ctx);
                  _createBoardFromTemplate(template);
                },
              );
            }).toList(),
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

  void _showMondayImportDialog() {
    if (_selectedWorkspace == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a workspace first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => MondayImportDialog(
        workspaceId: _selectedWorkspace!.id,
        username: widget.username,
        onImportComplete: (boardId) {
          // Reload workspaces and boards list without closing current board
          _loadWorkspaces();
          if (_selectedWorkspace != null) {
            _selectWorkspace(_selectedWorkspace!, closeBoard: false);
          }
        },
      ),
    );
  }

  IconData _getTemplateIcon(String icon) {
    switch (icon) {
      case 'leaderboard':
        return Icons.leaderboard;
      case 'work':
        return Icons.work;
      case 'task_alt':
        return Icons.task_alt;
      case 'folder_special':
        return Icons.folder_special;
      case 'dashboard':
        return Icons.dashboard;
      case 'trending_up':
        return Icons.trending_up;
      case 'check_circle':
        return Icons.check_circle;
      case 'folder':
        return Icons.folder;
      case 'people':
        return Icons.people;
      case 'settings':
        return Icons.settings;
      case 'build':
        return Icons.build;
      case 'assignment':
        return Icons.assignment;
      case 'event':
        return Icons.event;
      default:
        return Icons.dashboard;
    }
  }

  void _createBoardFromTemplate(BoardTemplate template) async {
    if (_selectedWorkspace == null && _workspaces.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a workspace first')),
      );
      _showCreateWorkspaceDialog();
      return;
    }

    final workspaceId = _selectedWorkspace?.id ?? _workspaces.first.id;

    final boardId = await SundayService.createBoardFromTemplate(
      workspaceId: workspaceId,
      name: template.name,
      templateId: template.id,
      username: widget.username,
    );

    if (boardId != null) {
      if (_selectedWorkspace != null) {
        _selectWorkspace(_selectedWorkspace!);
      }
      final board = await SundayService.getBoard(boardId, widget.username);
      if (board != null) {
        _openBoard(board);
      }
    }
  }

  void _showRenameWorkspaceDialog(SundayWorkspace workspace) {
    final nameController = TextEditingController(text: workspace.name);
    final descController = TextEditingController(text: workspace.description ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Workspace'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Workspace Name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
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
                  const SnackBar(content: Text('Workspace name cannot be empty')),
                );
                return;
              }

              Navigator.pop(ctx);

              final success = await SundayService.updateWorkspace(
                workspaceId: workspace.id,
                username: widget.username,
                name: newName,
                description: descController.text.trim(),
              );

              if (success) {
                _loadWorkspaces();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Workspace renamed to "$newName"')),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to rename workspace'),
                      backgroundColor: Colors.red,
                    ),
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

  void _confirmDeleteWorkspace(SundayWorkspace workspace) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Workspace'),
        content: Text(
          'Are you sure you want to delete "${workspace.name}"?\n\n'
          'This will permanently delete all boards, items, and data in this workspace. This action cannot be undone.',
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
      final success = await SundayService.deleteWorkspace(workspace.id, widget.username);

      if (success) {
        // If we deleted the currently selected workspace, clear selection
        if (_selectedWorkspace?.id == workspace.id) {
          setState(() {
            _selectedWorkspace = null;
            _boards = [];
          });
        }
        _loadWorkspaces();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Workspace "${workspace.name}" deleted')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete workspace. You may not have permission.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _openBoard(SundayBoard board) {
    final isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = !isDesktop || screenWidth < 600;

    if (isMobile) {
      // On mobile, navigate to a new screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SundayBoardScreen(
            boardId: board.id,
            username: widget.username,
            role: widget.role,
          ),
        ),
      );
    } else {
      // On desktop, show inline
      setState(() => _selectedBoard = board);
    }
  }

  void _closeBoard() {
    setState(() => _selectedBoard = null);
  }
}
