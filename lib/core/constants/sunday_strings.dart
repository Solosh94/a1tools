// Sunday Feature UI Strings
//
// Centralized string constants for the Sunday feature.
// This improves maintainability and enables easier localization.

/// UI strings for the Sunday board feature
class SundayStrings {
  SundayStrings._();

  // Screen titles
  static const String screenTitle = 'Sunday';
  static const String workspacesTitle = 'Workspaces';
  static const String boardsTitle = 'Boards';

  // Labels
  static const String workspaceLabel = 'Workspace';
  static const String boardLabel = 'Board';
  static const String folderLabel = 'Folder';

  // Empty states
  static const String welcomeTitle = 'Welcome to Sunday';
  static const String welcomeSubtitle =
      'Create your first workspace and board to start managing\nyour leads, jobs, and projects.';
  static const String noBoardsYet = 'No boards yet';
  static const String noBoardsSubtitle = 'Create your first board to start tracking work';
  static const String noBoardsInFolder = 'No boards in this folder';
  static const String contactAdminForSetup = 'Contact your administrator to set up workspaces.';

  // Actions
  static const String newBoard = 'New Board';
  static const String createBoard = 'Create Board';
  static const String createWorkspace = 'Create Workspace';
  static const String createFolder = 'Create Folder';
  static const String startWithTemplate = 'Start with Template';
  static const String addBoard = 'Add Board';
  static const String newFolder = 'New Folder';

  // Dialog titles
  static const String createBoardDialogTitle = 'Create Board';
  static const String createWorkspaceDialogTitle = 'Create Workspace';
  static const String createFolderDialogTitle = 'Create Folder';
  static const String renameFolderDialogTitle = 'Rename Folder';
  static const String renameWorkspaceDialogTitle = 'Rename Workspace';
  static const String deleteFolderDialogTitle = 'Delete Folder';
  static const String deleteWorkspaceDialogTitle = 'Delete Workspace';
  static const String searchBoardsDialogTitle = 'Search Boards';
  static const String boardTemplatesDialogTitle = 'Board Templates';
  static const String moveToBoardDialogTitle = 'Move to folder';

  // Form labels
  static const String boardNameLabel = 'Board name';
  static const String boardNameHint = 'e.g., Lead Pipeline, Job Tracker';
  static const String workspaceNameLabel = 'Workspace name';
  static const String workspaceNameHint = 'e.g., Sales, Operations';
  static const String folderNameLabel = 'Folder name';
  static const String folderNameHint = 'e.g., Marketing';
  static const String descriptionLabel = 'Description (optional)';
  static const String searchHint = 'Search by name...';

  // Template section
  static const String startFromTemplate = 'Start from template (optional)';
  static const String builtInTemplates = 'Built-in Templates';
  static const String savedTemplates = 'Saved Templates';
  static const String includeItemsFromTemplate = 'Include items from template';
  static const String includeItemsSubtitle = 'Copy all items with their values';
  static const String greenDotIndicator = 'Green dot indicates template includes items';

  // Buttons
  static const String cancel = 'Cancel';
  static const String create = 'Create';
  static const String save = 'Save';
  static const String delete = 'Delete';
  static const String rename = 'Rename';
  static const String retry = 'Retry';
  static const String close = 'Close';

  // Context menu items
  static const String moveToFolder = 'Move to folder...';
  static const String removeFromFolder = 'Remove from folder';

  // Confirmation messages
  static String deleteFolderConfirmation(String folderName) =>
      'Delete "$folderName"? Boards in this folder will be moved to the root level.';
  static String deleteWorkspaceConfirmation(String workspaceName) =>
      'Are you sure you want to delete "$workspaceName"?\n\n'
      'This will permanently delete all boards, items, and data in this workspace. This action cannot be undone.';

  // Success messages
  static String boardCreatedSuccess(String boardName) =>
      'Board "$boardName" created successfully';
  static String workspaceRenamedSuccess(String newName) =>
      'Workspace renamed to "$newName"';
  static String workspaceDeletedSuccess(String workspaceName) =>
      'Workspace "$workspaceName" deleted';

  // Error messages
  static const String createBoardFailed = 'Failed to create board';
  static const String renameFolderFailed = 'Failed to rename folder';
  static const String deleteFolderFailed = 'Failed to delete folder';
  static const String renameWorkspaceFailed = 'Failed to rename workspace';
  static const String deleteWorkspaceFailed =
      'Failed to delete workspace. You may not have permission.';
  static const String workspaceNameEmpty = 'Workspace name cannot be empty';
  static const String createWorkspaceFirst = 'Create a workspace first';
  static const String selectWorkspaceFirst = 'Please select a workspace first';
  static const String noFoldersYet = 'No folders yet. Create a folder first.';
  static String noResultsFound(String query) => 'No results found for "$query"';

  // Stats labels
  static const String itemsLabel = 'items';
  static const String groupsLabel = 'groups';

  // Search results
  static String searchResultsTitle(String query) => 'Results for "$query"';
  static String boardInWorkspace(String? workspaceName) =>
      'Board in ${workspaceName ?? "workspace"}';
  static String itemInBoard(String boardName) => 'Item in $boardName';

  // Tooltips
  static const String newWorkspaceTooltip = 'New workspace';
  static const String selectWorkspaceTooltip = 'Select workspace';
}
