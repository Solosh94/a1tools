/// Automation Builder Dialog
/// Full-featured automation builder for creating custom automations
library;

import 'package:flutter/material.dart';
import '../../../app_theme.dart';
import '../models/sunday_models.dart';
import '../models/automation_models.dart';
import '../sunday_service.dart';

class AutomationBuilderDialog extends StatefulWidget {
  final int boardId;
  final String username;
  final SundayBoard board;
  final SundayAutomation? existingAutomation;

  const AutomationBuilderDialog({
    super.key,
    required this.boardId,
    required this.username,
    required this.board,
    this.existingAutomation,
  });

  @override
  State<AutomationBuilderDialog> createState() => _AutomationBuilderDialogState();
}

class _AutomationBuilderDialogState extends State<AutomationBuilderDialog> {
  final _nameController = TextEditingController();

  // Trigger configuration
  AutomationTrigger? _selectedTrigger;
  String? _triggerColumnKey;
  String? _triggerValue;
  String? _triggerFromValue;

  // Actions list
  final List<_AutomationActionConfig> _actions = [];

  // Available users for notification recipient selection
  List<Map<String, dynamic>> _availableUsers = [];
  bool _loadingUsers = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableUsers();
    if (widget.existingAutomation != null) {
      _loadExistingAutomation();
    }
  }

  Future<void> _loadAvailableUsers() async {
    setState(() => _loadingUsers = true);
    try {
      final users = await SundayService.getAppUsers(
        requestingUsername: widget.username,
      );
      if (mounted) {
        setState(() {
          _availableUsers = users;
          _loadingUsers = false;
        });
      }
    } catch (e) {
      debugPrint('[AutomationBuilder] Error loading users: $e');
      if (mounted) {
        setState(() => _loadingUsers = false);
      }
    }
  }

  void _loadExistingAutomation() {
    final auto = widget.existingAutomation!;
    _nameController.text = auto.name;
    _selectedTrigger = auto.trigger;
    _triggerColumnKey = auto.triggerConfig['column_key'];
    _triggerValue = auto.triggerConfig['value']?.toString();
    _triggerFromValue = auto.triggerConfig['from_value']?.toString();

    for (final action in auto.actions) {
      _actions.add(_AutomationActionConfig(
        actionType: action.action,
        config: Map<String, dynamic>.from(action.config),
      ));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.existingAutomation != null;

    return Dialog(
      child: Container(
        width: 600,
        height: 700,
        padding: const EdgeInsets.all(0),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEditing ? 'Edit Automation' : 'Create Automation',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Automation Name',
                        hintText: 'e.g., Move to Done when completed',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Trigger Section
                    _buildSectionHeader('WHEN', Icons.play_arrow),
                    const SizedBox(height: 12),
                    _buildTriggerSection(isDark),

                    const SizedBox(height: 24),

                    // Actions Section
                    _buildSectionHeader('THEN', Icons.arrow_forward),
                    const SizedBox(height: 12),
                    _buildActionsSection(isDark),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _canSave ? _saveAutomation : null,
                    style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                    child: Text(isEditing ? 'Update' : 'Create'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.accent),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildTriggerSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trigger type dropdown
          DropdownButtonFormField<AutomationTrigger>(
            initialValue: _selectedTrigger,
            decoration: const InputDecoration(
              labelText: 'When this happens...',
              border: OutlineInputBorder(),
            ),
            items: [
              // Status/Label triggers
              const DropdownMenuItem(
                value: AutomationTrigger.statusChangesTo,
                child: Text('Status changes to...'),
              ),
              const DropdownMenuItem(
                value: AutomationTrigger.statusChanges,
                child: Text('Any status/label change'),
              ),
              // Item lifecycle triggers
              const DropdownMenuItem(
                value: AutomationTrigger.itemCreated,
                child: Text('Item is created'),
              ),
              const DropdownMenuItem(
                value: AutomationTrigger.itemUpdated,
                child: Text('Item is updated'),
              ),
              const DropdownMenuItem(
                value: AutomationTrigger.itemMoved,
                child: Text('Item is moved to group'),
              ),
              const DropdownMenuItem(
                value: AutomationTrigger.itemDeleted,
                child: Text('Item is deleted'),
              ),
              // Person/Assignment triggers
              const DropdownMenuItem(
                value: AutomationTrigger.personAssigned,
                child: Text('Person is assigned'),
              ),
              const DropdownMenuItem(
                value: AutomationTrigger.personUnassigned,
                child: Text('Person is unassigned'),
              ),
              // Column triggers
              const DropdownMenuItem(
                value: AutomationTrigger.columnChanges,
                child: Text('Column value changes'),
              ),
              const DropdownMenuItem(
                value: AutomationTrigger.columnIsEmpty,
                child: Text('Column becomes empty'),
              ),
              const DropdownMenuItem(
                value: AutomationTrigger.columnIsNotEmpty,
                child: Text('Column is no longer empty'),
              ),
              // Date triggers
              const DropdownMenuItem(
                value: AutomationTrigger.dateArrives,
                child: Text('Date arrives'),
              ),
              const DropdownMenuItem(
                value: AutomationTrigger.dateApproaching,
                child: Text('Date is approaching'),
              ),
              // Subitem triggers
              const DropdownMenuItem(
                value: AutomationTrigger.subitemCreated,
                child: Text('Subitem is created'),
              ),
              const DropdownMenuItem(
                value: AutomationTrigger.allSubitemsCompleted,
                child: Text('All subitems completed'),
              ),
              // Scheduled triggers
              const DropdownMenuItem(
                value: AutomationTrigger.recurring,
                child: Text('On a recurring schedule'),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _selectedTrigger = value;
                _triggerColumnKey = null;
                _triggerValue = null;
              });
            },
          ),

          // Additional trigger config based on type
          if (_selectedTrigger == AutomationTrigger.statusChangesTo) ...[
            const SizedBox(height: 16),
            _buildStatusColumnSelector(isDark),
            if (_triggerColumnKey != null) ...[
              const SizedBox(height: 12),
              _buildStatusValueSelector(isDark),
            ],
          ],

          if (_selectedTrigger == AutomationTrigger.columnChanges ||
              _selectedTrigger == AutomationTrigger.columnIsEmpty ||
              _selectedTrigger == AutomationTrigger.columnIsNotEmpty) ...[
            const SizedBox(height: 16),
            _buildColumnSelector(isDark),
          ],

          if (_selectedTrigger == AutomationTrigger.dateArrives ||
              _selectedTrigger == AutomationTrigger.dateApproaching) ...[
            const SizedBox(height: 16),
            _buildDateTriggerConfig(isDark),
          ],

          if (_selectedTrigger == AutomationTrigger.recurring) ...[
            const SizedBox(height: 16),
            _buildRecurringTriggerConfig(isDark),
          ],

          if (_selectedTrigger == AutomationTrigger.personAssigned ||
              _selectedTrigger == AutomationTrigger.personUnassigned) ...[
            const SizedBox(height: 16),
            _buildPersonColumnSelector(isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildDateTriggerConfig(bool isDark) {
    final dateColumns = widget.board.columns
        .where((c) => c.type == ColumnType.date)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _triggerColumnKey,
          decoration: const InputDecoration(
            labelText: 'Date column',
            border: OutlineInputBorder(),
          ),
          items: dateColumns.map((col) {
            return DropdownMenuItem(value: col.key, child: Text(col.title));
          }).toList(),
          onChanged: (value) => setState(() => _triggerColumnKey = value),
        ),
        if (_selectedTrigger == AutomationTrigger.dateApproaching) ...[
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Days before',
              hintText: 'e.g., 3 (notify 3 days before)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) => _triggerValue = value,
          ),
        ],
      ],
    );
  }

  Widget _buildRecurringTriggerConfig(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _triggerValue,
          decoration: const InputDecoration(
            labelText: 'Frequency',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'daily', child: Text('Daily')),
            DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
            DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
          ],
          onChanged: (value) => setState(() => _triggerValue = value),
        ),
        const SizedBox(height: 8),
        Text(
          'Note: Recurring automations run automatically at the specified interval.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _buildPersonColumnSelector(bool isDark) {
    final personColumns = widget.board.columns
        .where((c) => c.type == ColumnType.person)
        .toList();

    if (personColumns.isEmpty) {
      return Text(
        'No person columns found on this board.',
        style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: _triggerColumnKey,
      decoration: const InputDecoration(
        labelText: 'Person column',
        border: OutlineInputBorder(),
      ),
      items: personColumns.map((col) {
        return DropdownMenuItem(value: col.key, child: Text(col.title));
      }).toList(),
      onChanged: (value) => setState(() => _triggerColumnKey = value),
    );
  }

  Widget _buildStatusColumnSelector(bool isDark) {
    // Include both status columns and custom label columns
    final statusColumns = widget.board.columns
        .where((c) => c.type == ColumnType.status || c.type == ColumnType.label)
        .toList();

    if (statusColumns.isEmpty) {
      return Text(
        'No status or label columns in this board',
        style: TextStyle(color: Colors.grey.shade500),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: _triggerColumnKey,
      decoration: const InputDecoration(
        labelText: 'Status',
        border: OutlineInputBorder(),
      ),
      items: statusColumns.map((col) {
        return DropdownMenuItem(
          value: col.key,
          child: Row(
            children: [
              Icon(
                col.type == ColumnType.label ? Icons.label_outline : Icons.circle_outlined,
                size: 16,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Text(col.title),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _triggerColumnKey = value;
          _triggerValue = null;
        });
      },
    );
  }

  Widget _buildStatusValueSelector(bool isDark) {
    final column = widget.board.columns.firstWhere(
      (c) => c.key == _triggerColumnKey,
      orElse: () => widget.board.columns.first,
    );

    if (column.statusLabels.isEmpty) {
      return Text(
        'No status labels defined',
        style: TextStyle(color: Colors.grey.shade500),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: _triggerValue,
      decoration: const InputDecoration(
        labelText: 'Changes to...',
        border: OutlineInputBorder(),
      ),
      items: column.statusLabels.map((label) {
        return DropdownMenuItem(
          // Use label.id (label_key) to match what status_cell.dart sends
          value: label.id,
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: label.colorValue,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(label.label),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() => _triggerValue = value);
      },
    );
  }

  Widget _buildColumnSelector(bool isDark) {
    return DropdownButtonFormField<String>(
      initialValue: _triggerColumnKey,
      decoration: const InputDecoration(
        labelText: 'Column',
        border: OutlineInputBorder(),
      ),
      items: widget.board.columns.map((col) {
        return DropdownMenuItem(
          value: col.key,
          child: Text(col.title),
        );
      }).toList(),
      onChanged: (value) {
        setState(() => _triggerColumnKey = value);
      },
    );
  }

  Widget _buildActionsSection(bool isDark) {
    return Column(
      children: [
        // Existing actions
        ..._actions.asMap().entries.map((entry) {
          return _buildActionCard(entry.key, entry.value, isDark);
        }),

        // Add action button
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _addAction,
          icon: const Icon(Icons.add),
          label: const Text('Add Action'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accent,
            side: const BorderSide(color: AppColors.accent),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(int index, _AutomationActionConfig action, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Action ${index + 1}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.delete, size: 18, color: Colors.red.shade400),
                onPressed: () {
                  setState(() => _actions.removeAt(index));
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Action type dropdown
          DropdownButtonFormField<AutomationAction>(
            initialValue: action.actionType,
            decoration: const InputDecoration(
              labelText: 'Do this...',
              border: OutlineInputBorder(),
            ),
            items: const [
              // Item movement
              DropdownMenuItem(
                value: AutomationAction.moveItem,
                child: Text('Move item to group'),
              ),
              DropdownMenuItem(
                value: AutomationAction.archiveItem,
                child: Text('Archive item'),
              ),
              DropdownMenuItem(
                value: AutomationAction.duplicateItem,
                child: Text('Duplicate item'),
              ),
              // Status changes
              DropdownMenuItem(
                value: AutomationAction.changeStatus,
                child: Text('Change status'),
              ),
              DropdownMenuItem(
                value: AutomationAction.clearStatus,
                child: Text('Clear status'),
              ),
              // Person assignment
              DropdownMenuItem(
                value: AutomationAction.assignPerson,
                child: Text('Assign person'),
              ),
              DropdownMenuItem(
                value: AutomationAction.unassignPerson,
                child: Text('Unassign person'),
              ),
              DropdownMenuItem(
                value: AutomationAction.assignCreator,
                child: Text('Assign to item creator'),
              ),
              // Notifications
              DropdownMenuItem(
                value: AutomationAction.sendNotification,
                child: Text('Send notification'),
              ),
              DropdownMenuItem(
                value: AutomationAction.sendAlert,
                child: Text('Send A1 Tools alert'),
              ),
              DropdownMenuItem(
                value: AutomationAction.sendEmail,
                child: Text('Send email'),
              ),
              // Column operations
              DropdownMenuItem(
                value: AutomationAction.setColumnValue,
                child: Text('Set column value'),
              ),
              DropdownMenuItem(
                value: AutomationAction.clearColumnValue,
                child: Text('Clear column value'),
              ),
              // Subitems
              DropdownMenuItem(
                value: AutomationAction.createSubitem,
                child: Text('Create subitem'),
              ),
              // Updates
              DropdownMenuItem(
                value: AutomationAction.postUpdate,
                child: Text('Post an update'),
              ),
            ],
            onChanged: (value) {
              setState(() {
                action.actionType = value;
                action.config.clear();
              });
            },
          ),

          // Action-specific config
          if (action.actionType != null) ...[
            const SizedBox(height: 12),
            _buildActionConfig(action, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildActionConfig(_AutomationActionConfig action, bool isDark) {
    switch (action.actionType) {
      case AutomationAction.moveItem:
        return _buildMoveItemConfig(action, isDark);
      case AutomationAction.changeStatus:
        return _buildChangeStatusConfig(action, isDark);
      case AutomationAction.assignPerson:
        return _buildAssignPersonConfig(action, isDark);
      case AutomationAction.sendNotification:
      case AutomationAction.sendAlert:
        return _buildNotificationConfig(action, isDark);
      case AutomationAction.sendEmail:
        return _buildEmailConfig(action, isDark);
      case AutomationAction.setColumnValue:
        return _buildSetColumnConfig(action, isDark);
      case AutomationAction.clearColumnValue:
        return _buildClearColumnConfig(action, isDark);
      case AutomationAction.clearStatus:
        return _buildClearStatusConfig(action, isDark);
      case AutomationAction.unassignPerson:
        return _buildUnassignPersonConfig(action, isDark);
      case AutomationAction.assignCreator:
        return _buildAssignCreatorConfig(action, isDark);
      case AutomationAction.archiveItem:
      case AutomationAction.duplicateItem:
        return _buildSimpleActionInfo(action, isDark);
      case AutomationAction.postUpdate:
        return _buildPostUpdateConfig(action, isDark);
      default:
        return const SizedBox();
    }
  }

  Widget _buildClearColumnConfig(_AutomationActionConfig action, bool isDark) {
    return DropdownButtonFormField<String>(
      initialValue: action.config['column_key'] as String?,
      decoration: const InputDecoration(
        labelText: 'Column to clear',
        border: OutlineInputBorder(),
      ),
      items: widget.board.columns.map((col) {
        return DropdownMenuItem(value: col.key, child: Text(col.title));
      }).toList(),
      onChanged: (value) => setState(() => action.config['column_key'] = value),
    );
  }

  Widget _buildClearStatusConfig(_AutomationActionConfig action, bool isDark) {
    final statusColumns = widget.board.columns
        .where((c) => c.type == ColumnType.status || c.type == ColumnType.label)
        .toList();

    return DropdownButtonFormField<String>(
      initialValue: action.config['column_key'] as String?,
      decoration: const InputDecoration(
        labelText: 'Status/Label column to clear',
        border: OutlineInputBorder(),
      ),
      items: statusColumns.map((col) {
        return DropdownMenuItem(value: col.key, child: Text(col.title));
      }).toList(),
      onChanged: (value) => setState(() => action.config['column_key'] = value),
    );
  }

  Widget _buildUnassignPersonConfig(_AutomationActionConfig action, bool isDark) {
    final personColumns = widget.board.columns
        .where((c) => c.type == ColumnType.person)
        .toList();

    return DropdownButtonFormField<String>(
      initialValue: action.config['column_key'] as String?,
      decoration: const InputDecoration(
        labelText: 'Person column to clear',
        border: OutlineInputBorder(),
      ),
      items: personColumns.map((col) {
        return DropdownMenuItem(value: col.key, child: Text(col.title));
      }).toList(),
      onChanged: (value) => setState(() => action.config['column_key'] = value),
    );
  }

  Widget _buildAssignCreatorConfig(_AutomationActionConfig action, bool isDark) {
    final personColumns = widget.board.columns
        .where((c) => c.type == ColumnType.person)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: action.config['column_key'] as String?,
          decoration: const InputDecoration(
            labelText: 'Assign to person column',
            border: OutlineInputBorder(),
          ),
          items: personColumns.map((col) {
            return DropdownMenuItem(value: col.key, child: Text(col.title));
          }).toList(),
          onChanged: (value) => setState(() => action.config['column_key'] = value),
        ),
        const SizedBox(height: 8),
        Text(
          'This will assign the person who created the item.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _buildSimpleActionInfo(_AutomationActionConfig action, bool isDark) {
    String message;
    switch (action.actionType) {
      case AutomationAction.archiveItem:
        message = 'This action will archive the item (move it out of the board).';
        break;
      case AutomationAction.duplicateItem:
        message = 'This action will create a copy of the item in the same group.';
        break;
      default:
        message = 'This action requires no additional configuration.';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostUpdateConfig(_AutomationActionConfig action, bool isDark) {
    return TextField(
      controller: TextEditingController(text: action.config['message'] as String? ?? ''),
      decoration: const InputDecoration(
        labelText: 'Update message',
        hintText: 'Use {item_name}, {status}, {assignee} for dynamic values',
        border: OutlineInputBorder(),
      ),
      maxLines: 3,
      onChanged: (value) => action.config['message'] = value,
    );
  }

  Widget _buildMoveItemConfig(_AutomationActionConfig action, bool isDark) {
    return DropdownButtonFormField<int>(
      initialValue: action.config['group_id'] as int?,
      decoration: const InputDecoration(
        labelText: 'Move to group',
        border: OutlineInputBorder(),
      ),
      items: widget.board.groups.map((group) {
        return DropdownMenuItem(
          value: group.id,
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: group.colorValue,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(group.title),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() => action.config['group_id'] = value);
      },
    );
  }

  Widget _buildChangeStatusConfig(_AutomationActionConfig action, bool isDark) {
    // Include both status columns and custom label columns
    final statusColumns = widget.board.columns
        .where((c) => c.type == ColumnType.status || c.type == ColumnType.label)
        .toList();

    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: action.config['column_key'] as String?,
          decoration: const InputDecoration(
            labelText: 'Status/Label column',
            border: OutlineInputBorder(),
          ),
          items: statusColumns.map((col) {
            return DropdownMenuItem(
              value: col.key,
              child: Row(
                children: [
                  Icon(
                    col.type == ColumnType.label ? Icons.label_outline : Icons.circle_outlined,
                    size: 16,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(col.title),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              action.config['column_key'] = value;
              action.config['value'] = null;
            });
          },
        ),
        if (action.config['column_key'] != null) ...[
          const SizedBox(height: 12),
          Builder(builder: (context) {
            final col = statusColumns.firstWhere(
              (c) => c.key == action.config['column_key'],
              orElse: () => statusColumns.first,
            );
            return DropdownButtonFormField<String>(
              initialValue: action.config['value'] as String?,
              decoration: const InputDecoration(
                labelText: 'Change to',
                border: OutlineInputBorder(),
              ),
              items: col.statusLabels.map((label) {
                return DropdownMenuItem(
                  // Use label.id (label_key) to match what status_cell.dart sends
                  value: label.id,
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: label.colorValue,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(label.label),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => action.config['value'] = value);
              },
            );
          }),
        ],
      ],
    );
  }

  Widget _buildAssignPersonConfig(_AutomationActionConfig action, bool isDark) {
    return TextField(
      decoration: const InputDecoration(
        labelText: 'Assign to (username)',
        hintText: 'Enter username to assign',
        border: OutlineInputBorder(),
      ),
      onChanged: (value) => action.config['person'] = value,
    );
  }

  Widget _buildNotificationConfig(_AutomationActionConfig action, bool isDark) {
    // Initialize selected users list if not present
    action.config['to_users'] ??= <String>[];
    final selectedUsers = List<String>.from(action.config['to_users'] as List);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // User selection section
        Text(
          'Send to',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        _buildUserSelectionField(action, selectedUsers, isDark),
        const SizedBox(height: 16),

        // Additional recipient options
        _buildRecipientOptions(action, isDark),
        const SizedBox(height: 16),

        // Notification title
        TextField(
          controller: TextEditingController(text: action.config['title'] as String? ?? ''),
          decoration: const InputDecoration(
            labelText: 'Notification title',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => action.config['title'] = value,
        ),
        const SizedBox(height: 12),

        // Message
        TextField(
          controller: TextEditingController(text: action.config['message'] as String? ?? ''),
          decoration: const InputDecoration(
            labelText: 'Message',
            hintText: 'Use {item_name}, {status}, {assignee} for dynamic values',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
          onChanged: (value) => action.config['message'] = value,
        ),
      ],
    );
  }

  Widget _buildUserSelectionField(_AutomationActionConfig action, List<String> selectedUsers, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected users chips
          if (selectedUsers.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selectedUsers.map((username) {
                final user = _availableUsers.firstWhere(
                  (u) => u['username'] == username,
                  orElse: () => {'username': username, 'name': username},
                );
                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: AppColors.accent,
                    radius: 12,
                    child: Text(
                      (user['name'] ?? user['username'] ?? '?')[0].toUpperCase(),
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                    ),
                  ),
                  label: Text(user['name'] ?? user['username'] ?? username),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () {
                    setState(() {
                      selectedUsers.remove(username);
                      action.config['to_users'] = selectedUsers;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],

          // Add user button
          InkWell(
            onTap: _loadingUsers ? null : () => _showUserSelectionDialog(action, selectedUsers),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_add,
                    size: 18,
                    color: _loadingUsers ? Colors.grey : AppColors.accent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _loadingUsers ? 'Loading users...' : 'Add recipients',
                    style: TextStyle(
                      color: _loadingUsers ? Colors.grey : AppColors.accent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_loadingUsers) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientOptions(_AutomationActionConfig action, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Also notify:',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _buildCheckboxOption(
              action,
              'notify_assignee',
              'Item assignee',
              Icons.person,
              isDark,
            ),
            _buildCheckboxOption(
              action,
              'notify_creator',
              'Item creator',
              Icons.create,
              isDark,
            ),
            _buildCheckboxOption(
              action,
              'notify_board_members',
              'All board members',
              Icons.group,
              isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCheckboxOption(
    _AutomationActionConfig action,
    String configKey,
    String label,
    IconData icon,
    bool isDark,
  ) {
    final isChecked = action.config[configKey] == true;
    return InkWell(
      onTap: () {
        setState(() {
          action.config[configKey] = !isChecked;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isChecked
              ? AppColors.accent.withValues(alpha: 0.15)
              : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isChecked ? AppColors.accent : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isChecked ? Icons.check_box : Icons.check_box_outline_blank,
              size: 18,
              color: isChecked ? AppColors.accent : Colors.grey,
            ),
            const SizedBox(width: 6),
            Icon(icon, size: 16, color: isChecked ? AppColors.accent : Colors.grey),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isChecked
                    ? AppColors.accent
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserSelectionDialog(_AutomationActionConfig action, List<String> selectedUsers) {
    showDialog(
      context: context,
      builder: (ctx) => _UserSelectionDialog(
        availableUsers: _availableUsers,
        selectedUsernames: selectedUsers,
        onSelectionChanged: (newSelection) {
          setState(() {
            action.config['to_users'] = newSelection;
          });
        },
      ),
    );
  }

  Widget _buildEmailConfig(_AutomationActionConfig action, bool isDark) {
    return Column(
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: 'To (email address or column)',
            hintText: 'email@example.com or use {assignee_email}',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => action.config['to'] = value,
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Subject',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => action.config['subject'] = value,
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Body',
            hintText: 'Use {item_name}, {status}, {link} for dynamic values',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          onChanged: (value) => action.config['body'] = value,
        ),
      ],
    );
  }

  Widget _buildSetColumnConfig(_AutomationActionConfig action, bool isDark) {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: action.config['column_key'] as String?,
          decoration: const InputDecoration(
            labelText: 'Column',
            border: OutlineInputBorder(),
          ),
          items: widget.board.columns.map((col) {
            return DropdownMenuItem(
              value: col.key,
              child: Text(col.title),
            );
          }).toList(),
          onChanged: (value) {
            setState(() => action.config['column_key'] = value);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Value',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => action.config['value'] = value,
        ),
      ],
    );
  }

  void _addAction() {
    setState(() {
      _actions.add(_AutomationActionConfig());
    });
  }

  bool get _canSave {
    if (_nameController.text.trim().isEmpty) return false;
    if (_selectedTrigger == null) return false;
    if (_actions.isEmpty) return false;

    // Check trigger config based on trigger type
    switch (_selectedTrigger) {
      case AutomationTrigger.statusChangesTo:
        if (_triggerColumnKey == null || _triggerValue == null) return false;
        break;
      case AutomationTrigger.columnChanges:
      case AutomationTrigger.columnIsEmpty:
      case AutomationTrigger.columnIsNotEmpty:
        if (_triggerColumnKey == null) return false;
        break;
      case AutomationTrigger.dateArrives:
      case AutomationTrigger.dateApproaching:
        if (_triggerColumnKey == null) return false;
        break;
      case AutomationTrigger.recurring:
        if (_triggerValue == null) return false; // frequency required
        break;
      default:
        // Other triggers don't require additional config
        break;
    }

    // Check action configs
    for (final action in _actions) {
      if (action.actionType == null) return false;

      // Validate action-specific required config
      switch (action.actionType) {
        case AutomationAction.moveItem:
          if (action.config['group_id'] == null) return false;
          break;
        case AutomationAction.changeStatus:
          if (action.config['column_key'] == null || action.config['value'] == null) return false;
          break;
        case AutomationAction.assignPerson:
          if (action.config['person'] == null || (action.config['person'] as String).isEmpty) return false;
          break;
        case AutomationAction.setColumnValue:
          if (action.config['column_key'] == null) return false;
          break;
        case AutomationAction.clearColumnValue:
        case AutomationAction.clearStatus:
        case AutomationAction.unassignPerson:
        case AutomationAction.assignCreator:
          if (action.config['column_key'] == null) return false;
          break;
        case AutomationAction.sendNotification:
        case AutomationAction.sendAlert:
          // Must have at least one recipient method selected
          final hasUsers = action.config['to_users'] != null &&
                          (action.config['to_users'] as List).isNotEmpty;
          final hasAssignee = action.config['notify_assignee'] == true;
          final hasCreator = action.config['notify_creator'] == true;
          final hasBoardMembers = action.config['notify_board_members'] == true;
          if (!hasUsers && !hasAssignee && !hasCreator && !hasBoardMembers) {
            return false; // No recipients selected
          }
          break;
        case AutomationAction.sendEmail:
          if (action.config['to'] == null || (action.config['to'] as String).isEmpty) return false;
          break;
        case AutomationAction.postUpdate:
          if (action.config['message'] == null || (action.config['message'] as String).isEmpty) return false;
          break;
        default:
          // Other actions don't have required config
          break;
      }
    }

    return true;
  }

  Future<void> _saveAutomation() async {
    final isEditing = widget.existingAutomation != null;

    final triggerConfig = <String, dynamic>{
      'column_key': _triggerColumnKey,
      'value': _triggerValue,
      'from_value': _triggerFromValue,
    };

    final actions = _actions.asMap().entries.map((entry) {
      return AutomationActionConfig(
        id: 0,
        action: entry.value.actionType!,
        config: entry.value.config,
        order: entry.key,
      );
    }).toList();

    debugPrint('[AutomationBuilder] Saving automation:');
    debugPrint('[AutomationBuilder]   isEditing: $isEditing');
    debugPrint('[AutomationBuilder]   trigger: ${_selectedTrigger?.name}');
    debugPrint('[AutomationBuilder]   triggerConfig: $triggerConfig');
    debugPrint('[AutomationBuilder]   actions count: ${actions.length}');
    for (int i = 0; i < actions.length; i++) {
      debugPrint('[AutomationBuilder]   action[$i]: ${actions[i].action.name} - ${actions[i].config}');
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    bool success;
    if (isEditing) {
      // Update existing automation - must pass trigger type too!
      success = await SundayService.updateAutomation(
        automationId: widget.existingAutomation!.id,
        username: widget.username,
        name: _nameController.text.trim(),
        trigger: _selectedTrigger,
        triggerConfig: triggerConfig,
        actions: actions,
      );
    } else {
      // Create new automation
      final result = await SundayService.createAutomation(
        boardId: widget.boardId,
        name: _nameController.text.trim(),
        trigger: _selectedTrigger!,
        triggerConfig: triggerConfig,
        actions: actions,
        username: widget.username,
      );
      success = result != null;
    }

    // Close loading dialog
    if (mounted) Navigator.pop(context);

    if (success && mounted) {
      Navigator.pop(context, true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to ${isEditing ? 'update' : 'create'} automation. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _AutomationActionConfig {
  AutomationAction? actionType;
  Map<String, dynamic> config = {};

  _AutomationActionConfig({this.actionType, Map<String, dynamic>? config})
      : config = config ?? {};
}

/// Dialog for selecting multiple users as notification recipients
class _UserSelectionDialog extends StatefulWidget {
  final List<Map<String, dynamic>> availableUsers;
  final List<String> selectedUsernames;
  final Function(List<String>) onSelectionChanged;

  const _UserSelectionDialog({
    required this.availableUsers,
    required this.selectedUsernames,
    required this.onSelectionChanged,
  });

  @override
  State<_UserSelectionDialog> createState() => _UserSelectionDialogState();
}

class _UserSelectionDialogState extends State<_UserSelectionDialog> {
  late List<String> _selectedUsernames;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedUsernames = List<String>.from(widget.selectedUsernames);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) return widget.availableUsers;

    final query = _searchQuery.toLowerCase();
    return widget.availableUsers.where((user) {
      final username = (user['username'] ?? '').toString().toLowerCase();
      final name = (user['name'] ?? '').toString().toLowerCase();
      final email = (user['email'] ?? '').toString().toLowerCase();
      return username.contains(query) || name.contains(query) || email.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      child: Container(
        width: 400,
        height: 500,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.people, color: AppColors.accent),
                const SizedBox(width: 8),
                const Text(
                  'Select Recipients',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Search field
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, username, or email...',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
            const SizedBox(height: 8),

            // Selection count
            Text(
              '${_selectedUsernames.length} user${_selectedUsernames.length == 1 ? '' : 's'} selected',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),

            // User list
            Expanded(
              child: _filteredUsers.isEmpty
                  ? Center(
                      child: Text(
                        _searchQuery.isEmpty ? 'No users available' : 'No matching users',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = _filteredUsers[index];
                        final username = user['username'] as String? ?? '';
                        final name = user['name'] as String? ?? username;
                        final email = user['email'] as String? ?? '';
                        final isSelected = _selectedUsernames.contains(username);

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isSelected ? AppColors.accent : Colors.grey.shade600,
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(name),
                          subtitle: Text(
                            email.isNotEmpty ? email : '@$username',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle, color: AppColors.accent)
                              : Icon(Icons.circle_outlined, color: Colors.grey.shade400),
                          selected: isSelected,
                          selectedTileColor: AppColors.accent.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedUsernames.remove(username);
                              } else {
                                _selectedUsernames.add(username);
                              }
                            });
                          },
                        );
                      },
                    ),
            ),

            const SizedBox(height: 12),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() => _selectedUsernames.clear());
                  },
                  child: const Text('Clear All'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    widget.onSelectionChanged(_selectedUsernames);
                    Navigator.pop(context);
                  },
                  style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                  child: Text('Done (${_selectedUsernames.length})'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
