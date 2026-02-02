-- ============================================================================
-- SQL Script to Rename CRM Tables to Sunday Tables
-- ============================================================================
-- This script renames all 26 crm_* tables to sunday_* tables.
-- Data is preserved - this only changes the table names.
--
-- IMPORTANT: Run this script on your database server BEFORE deploying the
-- updated PHP files. The new PHP code expects sunday_* table names.
--
-- Tables being renamed:
-- 1. crm_activity_log -> sunday_activity_log
-- 2. crm_automations -> sunday_automations
-- 3. crm_automation_actions -> sunday_automation_actions
-- 4. crm_automation_conditions -> sunday_automation_conditions
-- 5. crm_automation_logs -> sunday_automation_logs
-- 6. crm_boards -> sunday_boards
-- 7. crm_board_folders -> sunday_board_folders
-- 8. crm_board_members -> sunday_board_members
-- 9. crm_board_templates -> sunday_board_templates
-- 10. crm_columns -> sunday_columns
-- 11. crm_default_labels -> sunday_default_labels
-- 12. crm_groups -> sunday_groups
-- 13. crm_items -> sunday_items
-- 14. crm_item_dependencies -> sunday_item_dependencies (if exists)
-- 15. crm_item_templates -> sunday_item_templates (if exists)
-- 16. crm_item_updates -> sunday_item_updates
-- 17. crm_item_values -> sunday_item_values
-- 18. crm_label_categories -> sunday_label_categories
-- 19. crm_saved_filters -> sunday_saved_filters (if exists)
-- 20. crm_settings -> sunday_settings
-- 21. crm_status_labels -> sunday_status_labels
-- 22. crm_subitems -> sunday_subitems
-- 23. crm_subitem_values -> sunday_subitem_values
-- 24. crm_update_attachments -> sunday_update_attachments
-- 25. crm_update_replies -> sunday_update_replies
-- 26. crm_views -> sunday_views
-- 27. crm_workspaces -> sunday_workspaces
-- 28. crm_workspace_members -> sunday_workspace_members
--
-- NOTE: Some tables (like crm_item_dependencies, crm_item_templates,
-- crm_saved_filters) might not exist in your database if those features
-- haven't been used. The script handles this gracefully.
-- ============================================================================

-- Disable foreign key checks during rename to avoid constraint issues
SET FOREIGN_KEY_CHECKS = 0;

-- ============================================================================
-- RENAME TABLES (order matters due to foreign key dependencies)
-- ============================================================================

-- First, rename tables that other tables depend on (parent tables)
RENAME TABLE crm_workspaces TO sunday_workspaces;
RENAME TABLE crm_boards TO sunday_boards;
RENAME TABLE crm_groups TO sunday_groups;
RENAME TABLE crm_columns TO sunday_columns;
RENAME TABLE crm_items TO sunday_items;
RENAME TABLE crm_automations TO sunday_automations;
RENAME TABLE crm_item_updates TO sunday_item_updates;
RENAME TABLE crm_subitems TO sunday_subitems;

-- Then rename dependent tables (child tables)
RENAME TABLE crm_workspace_members TO sunday_workspace_members;
RENAME TABLE crm_board_folders TO sunday_board_folders;
RENAME TABLE crm_board_members TO sunday_board_members;
RENAME TABLE crm_status_labels TO sunday_status_labels;
RENAME TABLE crm_item_values TO sunday_item_values;
RENAME TABLE crm_subitem_values TO sunday_subitem_values;
RENAME TABLE crm_update_replies TO sunday_update_replies;
RENAME TABLE crm_update_attachments TO sunday_update_attachments;
RENAME TABLE crm_automation_actions TO sunday_automation_actions;
RENAME TABLE crm_automation_conditions TO sunday_automation_conditions;
RENAME TABLE crm_automation_logs TO sunday_automation_logs;
RENAME TABLE crm_views TO sunday_views;
RENAME TABLE crm_activity_log TO sunday_activity_log;

-- Settings and labels tables (no dependencies)
RENAME TABLE crm_settings TO sunday_settings;
RENAME TABLE crm_default_labels TO sunday_default_labels;
RENAME TABLE crm_label_categories TO sunday_label_categories;

-- Board templates
RENAME TABLE crm_board_templates TO sunday_board_templates;

-- Re-enable foreign key checks
SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================================
-- OPTIONAL: Rename tables that may not exist in all installations
-- Run these separately if needed
-- ============================================================================

-- If you have the features tables:
-- RENAME TABLE crm_saved_filters TO sunday_saved_filters;
-- RENAME TABLE crm_item_dependencies TO sunday_item_dependencies;
-- RENAME TABLE crm_item_templates TO sunday_item_templates;

-- ============================================================================
-- VERIFY RENAMES
-- ============================================================================
-- Run this query after the renames to verify:
-- SHOW TABLES LIKE 'sunday_%';
--
-- Expected result: 26+ tables with sunday_ prefix
-- If any crm_* tables remain, re-run the appropriate RENAME statement

SELECT 'Sunday table rename complete!' AS status;
