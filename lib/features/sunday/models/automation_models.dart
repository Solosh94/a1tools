/// Sunday Automation Models
/// Provides Monday.com-like automation capabilities with enhanced features
library;

import 'dart:convert';

// Helper to safely parse JSON strings
Map<String, dynamic>? _parseJsonSafe(String jsonStr) {
  try {
    final decoded = jsonDecode(jsonStr);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return null;
  } catch (_) {
    return null;
  }
}

// ============================================
// AUTOMATION TRIGGER TYPES
// ============================================

/// Types of events that can trigger an automation
enum AutomationTrigger {
  // Status triggers
  statusChanges, // When status changes to any value
  statusChangesTo, // When status changes to specific value
  statusChangesFrom, // When status changes from specific value

  // Item triggers
  itemCreated, // When item is created
  itemUpdated, // When any column is updated
  itemMoved, // When item moves to another group
  itemDeleted, // When item is deleted

  // Date triggers
  dateArrives, // When date arrives (deadline)
  datePassedBy, // When date has passed by X days
  dateApproaching, // X days before date

  // Person triggers
  personAssigned, // When person is assigned
  personUnassigned, // When person is unassigned

  // Column triggers
  columnChanges, // When specific column changes
  columnBecomes, // When column becomes specific value
  columnIsEmpty, // When column becomes empty
  columnIsNotEmpty, // When column is filled

  // Subitem triggers
  subitemCreated, // When subitem is created
  allSubitemsCompleted, // When all subitems are done

  // Time triggers
  recurring, // Recurring schedule (daily, weekly, monthly)
  everyTimePeriod, // Every X hours/days

  // Integration triggers
  workizJobCreated, // A1: When Workiz job is created
  workizJobUpdated, // A1: When Workiz job is updated
  workizJobCompleted, // A1: When Workiz job is completed
  webhookReceived, // External webhook received

  // Button trigger
  buttonClicked, // Manual button click
}

// ============================================
// AUTOMATION ACTION TYPES
// ============================================

/// Types of actions an automation can perform
enum AutomationAction {
  // Status actions
  changeStatus, // Change status to value
  clearStatus, // Clear status value

  // Column actions
  setColumnValue, // Set column to value
  clearColumnValue, // Clear column value
  copyColumnValue, // Copy from another column
  calculateFormula, // Calculate and set formula result

  // Assignment actions
  assignPerson, // Assign person(s)
  unassignPerson, // Remove person assignment
  assignCreator, // Assign to item creator
  assignRoundRobin, // Round-robin assignment

  // Item actions
  createItem, // Create new item
  duplicateItem, // Duplicate item
  moveItem, // Move to group
  moveToBoard, // Move to another board
  archiveItem, // Archive item
  deleteItem, // Delete item

  // Subitem actions
  createSubitem, // Create subitem
  deleteAllSubitems, // Delete all subitems

  // Notification actions
  sendNotification, // Send in-app notification
  sendEmail, // Send email
  sendSms, // Send SMS (via Twilio)
  sendAlert, // Send alert via A1 Tools alert system
  sendChatMessage, // Send chat message

  // Date actions
  setDate, // Set date value
  setDateRelative, // Set date relative to another date
  clearDate, // Clear date

  // Integration actions
  syncToWorkiz, // Sync to Workiz
  createWorkizJob, // Create Workiz job
  updateWorkizJob, // Update Workiz job
  callWebhook, // Call external webhook
  callN8nWorkflow, // Call N8N workflow

  // Group actions
  changeGroup, // Move item to different group

  // Update actions
  postUpdate, // Post update/comment on item

  // Dependency actions
  notifyDependents, // Notify dependent items
  updateDependents, // Update dependent item status
}

// ============================================
// AUTOMATION MODEL
// ============================================

/// Complete automation rule
class SundayAutomation {
  final int id;
  final int boardId;
  final String name;
  final String? description;
  final bool isActive;
  final AutomationTrigger trigger;
  final Map<String, dynamic> triggerConfig; // Trigger-specific settings
  final List<AutomationActionConfig> actions;
  final List<AutomationCondition> conditions; // Additional conditions
  final String createdBy;
  final DateTime createdAt;
  final DateTime? lastTriggeredAt;
  final int triggerCount;

  const SundayAutomation({
    required this.id,
    required this.boardId,
    required this.name,
    this.description,
    this.isActive = true,
    required this.trigger,
    this.triggerConfig = const {},
    this.actions = const [],
    this.conditions = const [],
    required this.createdBy,
    required this.createdAt,
    this.lastTriggeredAt,
    this.triggerCount = 0,
  });

  factory SundayAutomation.fromJson(Map<String, dynamic> json) {
    // Map PHP snake_case trigger types to Dart enum
    final triggerTypeStr = json['trigger_type'] as String? ?? 'item_created';
    final trigger = _parseTriggerType(triggerTypeStr);

    return SundayAutomation(
      id: json['id'] as int,
      boardId: json['board_id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      trigger: trigger,
      triggerConfig: _parseTriggerConfig(json['trigger_config']),
      actions: (json['actions'] as List<dynamic>?)
              ?.map((a) =>
                  AutomationActionConfig.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      conditions: (json['conditions'] as List<dynamic>?)
              ?.map(
                  (c) => AutomationCondition.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastTriggeredAt: json['last_triggered_at'] != null
          ? DateTime.parse(json['last_triggered_at'] as String)
          : null,
      triggerCount: json['trigger_count'] as int? ?? 0,
    );
  }

  /// Parse trigger type from PHP snake_case to Dart enum
  static AutomationTrigger _parseTriggerType(String type) {
    final result = switch (type) {
      // Status triggers
      'status_changed' || 'status_changes_to' => AutomationTrigger.statusChangesTo,
      'status_changes' => AutomationTrigger.statusChanges,
      'status_changes_from' => AutomationTrigger.statusChangesFrom,
      // Item lifecycle triggers
      'item_created' => AutomationTrigger.itemCreated,
      'item_updated' || 'column_changed' => AutomationTrigger.itemUpdated,
      'item_moved' => AutomationTrigger.itemMoved,
      'item_deleted' => AutomationTrigger.itemDeleted,
      // Date triggers
      'date_arrives' => AutomationTrigger.dateArrives,
      'date_passed' || 'date_passed_by' => AutomationTrigger.datePassedBy,
      'date_approaching' => AutomationTrigger.dateApproaching,
      // Person triggers
      'person_assigned' => AutomationTrigger.personAssigned,
      'person_unassigned' => AutomationTrigger.personUnassigned,
      // Column triggers
      'column_changes' => AutomationTrigger.columnChanges,
      'column_becomes' => AutomationTrigger.columnBecomes,
      'column_is_empty' => AutomationTrigger.columnIsEmpty,
      'column_is_not_empty' => AutomationTrigger.columnIsNotEmpty,
      // Subitem triggers
      'subitem_created' => AutomationTrigger.subitemCreated,
      'all_subitems_completed' => AutomationTrigger.allSubitemsCompleted,
      // Scheduled triggers
      'recurring' => AutomationTrigger.recurring,
      'every_time_period' => AutomationTrigger.everyTimePeriod,
      // External triggers
      'workiz_job_created' => AutomationTrigger.workizJobCreated,
      'workiz_job_updated' => AutomationTrigger.workizJobUpdated,
      'workiz_job_completed' => AutomationTrigger.workizJobCompleted,
      'webhook_received' => AutomationTrigger.webhookReceived,
      'manual' || 'button_clicked' => AutomationTrigger.buttonClicked,
      // Also handle camelCase in case it comes through
      'statusChanges' => AutomationTrigger.statusChanges,
      'statusChangesTo' => AutomationTrigger.statusChangesTo,
      'statusChangesFrom' => AutomationTrigger.statusChangesFrom,
      'itemCreated' => AutomationTrigger.itemCreated,
      'itemUpdated' => AutomationTrigger.itemUpdated,
      'itemMoved' => AutomationTrigger.itemMoved,
      'itemDeleted' => AutomationTrigger.itemDeleted,
      'personAssigned' => AutomationTrigger.personAssigned,
      'personUnassigned' => AutomationTrigger.personUnassigned,
      'columnChanges' => AutomationTrigger.columnChanges,
      'columnIsEmpty' => AutomationTrigger.columnIsEmpty,
      'columnIsNotEmpty' => AutomationTrigger.columnIsNotEmpty,
      'dateArrives' => AutomationTrigger.dateArrives,
      'dateApproaching' => AutomationTrigger.dateApproaching,
      'subitemCreated' => AutomationTrigger.subitemCreated,
      'allSubitemsCompleted' => AutomationTrigger.allSubitemsCompleted,
      _ => null,
    };
    if (result == null) {
      // Log unknown trigger type for debugging - helps identify misconfigured automations
      assert(() {
        // ignore: avoid_print
        print('[AutomationModels] WARNING: Unknown trigger type "$type", defaulting to itemCreated');
        return true;
      }());
      return AutomationTrigger.itemCreated;
    }
    return result;
  }

  /// Parse trigger config which may come as JSON string from PHP
  static Map<String, dynamic> _parseTriggerConfig(dynamic config) {
    if (config == null) return {};
    if (config is Map) {
      return Map<String, dynamic>.from(config);
    }
    if (config is String && config.isNotEmpty) {
      return _parseJsonSafe(config) ?? {};
    }
    return {};
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'board_id': boardId,
        'name': name,
        'description': description,
        'is_active': isActive,
        'trigger_type': trigger.name,
        'trigger_config': triggerConfig,
        'actions': actions.map((a) => a.toJson()).toList(),
        'conditions': conditions.map((c) => c.toJson()).toList(),
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
        'last_triggered_at': lastTriggeredAt?.toIso8601String(),
        'trigger_count': triggerCount,
      };

  /// Get human-readable description of the automation
  String get readableDescription {
    final triggerText = _getTriggerDescription();
    final actionTexts =
        actions.map((a) => a.readableDescription).join(', then ');
    return 'When $triggerText, $actionTexts';
  }

  String _getTriggerDescription() {
    switch (trigger) {
      case AutomationTrigger.statusChanges:
        return 'status changes';
      case AutomationTrigger.statusChangesTo:
        // Check both 'value' (stored) and 'target_status' (legacy)
        final value = triggerConfig['value'] ?? triggerConfig['target_status'] ?? 'value';
        return 'status changes to "$value"';
      case AutomationTrigger.itemCreated:
        return 'item is created';
      case AutomationTrigger.itemUpdated:
        return 'item is updated';
      case AutomationTrigger.itemMoved:
        return 'item is moved';
      case AutomationTrigger.columnChanges:
        final column = triggerConfig['column_key'] ?? 'column';
        return '$column changes';
      case AutomationTrigger.dateArrives:
        final column = triggerConfig['column_key'] ?? 'date';
        return '$column arrives';
      case AutomationTrigger.personAssigned:
        return 'person is assigned';
      case AutomationTrigger.recurring:
        final schedule = triggerConfig['schedule'] ?? 'daily';
        return 'every $schedule';
      case AutomationTrigger.workizJobCreated:
        return 'Workiz job is created';
      case AutomationTrigger.workizJobCompleted:
        return 'Workiz job is completed';
      case AutomationTrigger.buttonClicked:
        return 'button is clicked';
      default:
        return trigger.name;
    }
  }
}

/// Configuration for a single action
class AutomationActionConfig {
  final int id;
  final AutomationAction action;
  final Map<String, dynamic> config;
  final int order;

  const AutomationActionConfig({
    required this.id,
    required this.action,
    this.config = const {},
    this.order = 0,
  });

  factory AutomationActionConfig.fromJson(Map<String, dynamic> json) {
    // Parse action type from PHP snake_case
    final actionTypeStr = json['action_type'] as String? ?? 'send_notification';
    final action = _parseActionType(actionTypeStr);

    // Get config from either 'action_config' (PHP) or 'config' (Dart)
    // Note: PHP may return action_config as a JSON string from the database
    Map<String, dynamic> configData = {};
    if (json['action_config'] != null) {
      if (json['action_config'] is String) {
        // Parse JSON string from database
        try {
          final parsed = json['action_config'].toString();
          if (parsed.isNotEmpty) {
            configData = Map<String, dynamic>.from(
              (parsed.startsWith('{') ? _parseJsonSafe(parsed) : null) ?? {}
            );
          }
        } catch (_) {
          configData = {};
        }
      } else {
        configData = Map<String, dynamic>.from(json['action_config'] as Map);
      }
    } else if (json['config'] != null) {
      if (json['config'] is String) {
        try {
          final parsed = json['config'].toString();
          if (parsed.isNotEmpty && parsed.startsWith('{')) {
            configData = Map<String, dynamic>.from(_parseJsonSafe(parsed) ?? {});
          }
        } catch (_) {
          configData = {};
        }
      } else {
        configData = Map<String, dynamic>.from(json['config'] as Map);
      }
    }

    return AutomationActionConfig(
      id: json['id'] as int? ?? 0,
      action: action,
      config: configData,
      order: json['order'] as int? ?? json['position'] as int? ?? 0,
    );
  }

  /// Parse action type from PHP snake_case to Dart enum
  static AutomationAction _parseActionType(String type) {
    final result = switch (type) {
      // Status actions
      'change_status' => AutomationAction.changeStatus,
      'clear_status' => AutomationAction.clearStatus,
      // Column actions
      'set_column_value' => AutomationAction.setColumnValue,
      'clear_column_value' => AutomationAction.clearColumnValue,
      'copy_column_value' => AutomationAction.copyColumnValue,
      'calculate_formula' => AutomationAction.calculateFormula,
      // Person actions
      'assign_person' => AutomationAction.assignPerson,
      'unassign_person' => AutomationAction.unassignPerson,
      'assign_creator' => AutomationAction.assignCreator,
      'assign_round_robin' => AutomationAction.assignRoundRobin,
      // Item actions
      'create_item' => AutomationAction.createItem,
      'duplicate_item' => AutomationAction.duplicateItem,
      'move_item' || 'move_to_group' => AutomationAction.moveItem,
      'move_to_board' => AutomationAction.moveToBoard,
      'archive_item' => AutomationAction.archiveItem,
      'delete_item' => AutomationAction.deleteItem,
      'change_group' => AutomationAction.changeGroup,
      // Subitem actions
      'create_subitem' => AutomationAction.createSubitem,
      'delete_all_subitems' => AutomationAction.deleteAllSubitems,
      // Notification actions
      'send_notification' || 'notify_assignee' || 'notify_board_members' =>
        AutomationAction.sendNotification,
      'send_email' => AutomationAction.sendEmail,
      'send_sms' => AutomationAction.sendSms,
      'send_alert' => AutomationAction.sendAlert,
      'send_chat_message' => AutomationAction.sendChatMessage,
      // Date actions
      'set_date' => AutomationAction.setDate,
      'set_date_relative' => AutomationAction.setDateRelative,
      'clear_date' => AutomationAction.clearDate,
      // Update actions
      'create_update' || 'post_update' => AutomationAction.postUpdate,
      // External integrations
      'sync_to_workiz' => AutomationAction.syncToWorkiz,
      'create_workiz_job' => AutomationAction.createWorkizJob,
      'update_workiz_job' => AutomationAction.updateWorkizJob,
      'call_webhook' => AutomationAction.callWebhook,
      'call_n8n_workflow' => AutomationAction.callN8nWorkflow,
      // Dependency actions
      'notify_dependents' => AutomationAction.notifyDependents,
      'update_dependents' => AutomationAction.updateDependents,
      // Also handle camelCase
      'changeStatus' => AutomationAction.changeStatus,
      'clearStatus' => AutomationAction.clearStatus,
      'moveItem' => AutomationAction.moveItem,
      'archiveItem' => AutomationAction.archiveItem,
      'duplicateItem' => AutomationAction.duplicateItem,
      'assignPerson' => AutomationAction.assignPerson,
      'unassignPerson' => AutomationAction.unassignPerson,
      'assignCreator' => AutomationAction.assignCreator,
      'sendNotification' => AutomationAction.sendNotification,
      'sendAlert' => AutomationAction.sendAlert,
      'sendEmail' => AutomationAction.sendEmail,
      'setColumnValue' => AutomationAction.setColumnValue,
      'clearColumnValue' => AutomationAction.clearColumnValue,
      'createSubitem' => AutomationAction.createSubitem,
      'postUpdate' => AutomationAction.postUpdate,
      _ => null,
    };
    if (result == null) {
      // Log unknown action type for debugging - helps identify misconfigured automations
      assert(() {
        // ignore: avoid_print
        print('[AutomationModels] WARNING: Unknown action type "$type", defaulting to sendNotification');
        return true;
      }());
      return AutomationAction.sendNotification;
    }
    return result;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'action_type': action.name,
        'action_config': config,
        'config': config, // Include both for compatibility
        'order': order,
      };

  String get readableDescription {
    switch (action) {
      case AutomationAction.changeStatus:
        // Check both 'value' (stored) and 'target_status' (legacy)
        final status = config['value'] ?? config['target_status'] ?? 'value';
        return 'change status to "$status"';
      case AutomationAction.assignPerson:
        final person = config['person'] ?? 'someone';
        return 'assign $person';
      case AutomationAction.sendNotification:
        final message = config['message'] ?? '';
        return message.isNotEmpty ? 'send notification' : 'notify user';
      case AutomationAction.sendEmail:
        return 'send email';
      case AutomationAction.sendAlert:
        return 'send alert';
      case AutomationAction.createItem:
        return 'create item';
      case AutomationAction.moveItem:
        // Check both 'group_id' (stored) and 'target_group' (legacy)
        final groupId = config['group_id'] ?? config['target_group'];
        return groupId != null ? 'move to group' : 'move item';
      case AutomationAction.setColumnValue:
        final col = config['column_key'] ?? 'column';
        return 'set $col value';
      case AutomationAction.createSubitem:
        return 'create subitem';
      case AutomationAction.syncToWorkiz:
        return 'sync to Workiz';
      case AutomationAction.createWorkizJob:
        return 'create Workiz job';
      case AutomationAction.postUpdate:
        return 'post update';
      default:
        return action.name;
    }
  }
}

/// Additional condition for automation (AND logic)
class AutomationCondition {
  final String columnKey;
  final ConditionOperator operator;
  final dynamic value;

  const AutomationCondition({
    required this.columnKey,
    required this.operator,
    this.value,
  });

  factory AutomationCondition.fromJson(Map<String, dynamic> json) {
    return AutomationCondition(
      columnKey: json['column_key'] as String,
      operator: ConditionOperator.values.firstWhere(
        (e) => e.name == json['operator'],
        orElse: () => ConditionOperator.equals,
      ),
      value: json['value'],
    );
  }

  Map<String, dynamic> toJson() => {
        'column_key': columnKey,
        'operator': operator.name,
        'value': value,
      };

  /// Evaluate if condition is met
  bool evaluate(dynamic actualValue) {
    switch (operator) {
      case ConditionOperator.equals:
        return actualValue == value;
      case ConditionOperator.notEquals:
        return actualValue != value;
      case ConditionOperator.contains:
        return actualValue?.toString().contains(value.toString()) ?? false;
      case ConditionOperator.notContains:
        return !(actualValue?.toString().contains(value.toString()) ?? true);
      case ConditionOperator.isEmpty:
        return actualValue == null ||
            actualValue.toString().isEmpty ||
            actualValue == '';
      case ConditionOperator.isNotEmpty:
        return actualValue != null &&
            actualValue.toString().isNotEmpty &&
            actualValue != '';
      case ConditionOperator.greaterThan:
        if (actualValue is num && value is num) {
          return actualValue > value;
        }
        return false;
      case ConditionOperator.lessThan:
        if (actualValue is num && value is num) {
          return actualValue < value;
        }
        return false;
      case ConditionOperator.isAnyOf:
        if (value is List) {
          return value.contains(actualValue);
        }
        // If value isn't a List, condition is misconfigured - fail safely
        return false;
      case ConditionOperator.isNoneOf:
        if (value is List) {
          return !value.contains(actualValue);
        }
        // If value isn't a List, condition is misconfigured - fail safely (don't execute)
        return false;
    }
  }
}

/// Condition operators
enum ConditionOperator {
  equals,
  notEquals,
  contains,
  notContains,
  isEmpty,
  isNotEmpty,
  greaterThan,
  lessThan,
  isAnyOf,
  isNoneOf,
}

// ============================================
// AUTOMATION LOG MODEL
// ============================================

/// Log entry for automation execution
class AutomationLog {
  final int id;
  final int automationId;
  final int? itemId;
  final String status; // 'success', 'failed', 'skipped'
  final String? errorMessage;
  final Map<String, dynamic>? triggerData;
  final Map<String, dynamic>? actionResults;
  final DateTime executedAt;

  const AutomationLog({
    required this.id,
    required this.automationId,
    this.itemId,
    required this.status,
    this.errorMessage,
    this.triggerData,
    this.actionResults,
    required this.executedAt,
  });

  factory AutomationLog.fromJson(Map<String, dynamic> json) {
    return AutomationLog(
      id: json['id'] as int,
      automationId: json['automation_id'] as int,
      itemId: json['item_id'] as int?,
      status: json['status'] as String,
      errorMessage: json['error_message'] as String?,
      triggerData: json['trigger_data'] != null
          ? Map<String, dynamic>.from(json['trigger_data'] as Map)
          : null,
      actionResults: json['action_results'] != null
          ? Map<String, dynamic>.from(json['action_results'] as Map)
          : null,
      executedAt: DateTime.parse(json['executed_at'] as String),
    );
  }
}

// ============================================
// AUTOMATION TEMPLATES
// ============================================

/// Pre-built automation templates for quick setup
class AutomationTemplate {
  final String id;
  final String name;
  final String description;
  final String category;
  final AutomationTrigger trigger;
  final Map<String, dynamic> triggerConfig;
  final List<AutomationActionConfig> actions;

  const AutomationTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.trigger,
    this.triggerConfig = const {},
    required this.actions,
  });

  /// Standard automation templates for A1 Tools
  /// IDs must match PHP template IDs in automations.php
  static List<AutomationTemplate> get standardTemplates => [
        // Notify when Done - matches PHP 'notify_status_done'
        const AutomationTemplate(
          id: 'notify_status_done',
          name: 'Notify when Done',
          description: 'Notify assignee when status changes to Done',
          category: 'Status',
          trigger: AutomationTrigger.statusChangesTo,
          triggerConfig: {'target_status': 'Done'},
          actions: [
            AutomationActionConfig(
              id: 0,
              action: AutomationAction.sendNotification,
              config: {
                'message': 'Item {item_name} has been marked as Done'
              },
            ),
          ],
        ),

        // Notify on Assignment - matches PHP 'notify_assignee_on_create'
        const AutomationTemplate(
          id: 'notify_assignee_on_create',
          name: 'Notify on Assignment',
          description: 'Send notification when someone is assigned',
          category: 'Assignment',
          trigger: AutomationTrigger.personAssigned,
          actions: [
            AutomationActionConfig(
              id: 0,
              action: AutomationAction.sendNotification,
              config: {
                'message': 'You have been assigned to "{item_name}" in {board_name}.',
                'notify_assignee': true,
                'assignee_column': 'person'
              },
            ),
          ],
        ),

        // Due Date Reminder - matches PHP 'notify_overdue' (similar concept)
        const AutomationTemplate(
          id: 'notify_overdue',
          name: 'Due Date Reminder',
          description: 'Send reminder 1 day before due date',
          category: 'Dates',
          trigger: AutomationTrigger.dateApproaching,
          triggerConfig: {'days_before': 1, 'column_key': 'due_date'},
          actions: [
            AutomationActionConfig(
              id: 0,
              action: AutomationAction.sendNotification,
              config: {
                'message': 'Reminder: {item_name} is due tomorrow'
              },
            ),
          ],
        ),

        // Move on status - matches PHP 'move_when_done'
        const AutomationTemplate(
          id: 'move_when_done',
          name: 'Move Item on Status Change',
          description: 'Move item to another group when status changes',
          category: 'Status',
          trigger: AutomationTrigger.statusChangesTo,
          triggerConfig: {'target_status': 'Done'},
          actions: [
            AutomationActionConfig(
              id: 0,
              action: AutomationAction.moveItem,
              config: {},
            ),
          ],
        ),

        // Workiz integration - matches PHP 'workiz_sync'
        const AutomationTemplate(
          id: 'workiz_sync',
          name: 'Sync Workiz Job Status',
          description: 'Update status when Workiz job is completed',
          category: 'Workiz',
          trigger: AutomationTrigger.workizJobCompleted,
          actions: [
            AutomationActionConfig(
              id: 0,
              action: AutomationAction.changeStatus,
              config: {'column_key': 'status', 'value': 'Done'},
            ),
            AutomationActionConfig(
              id: 1,
              action: AutomationAction.postUpdate,
              config: {'message': 'Workiz job completed'},
            ),
          ],
        ),
      ];
}
