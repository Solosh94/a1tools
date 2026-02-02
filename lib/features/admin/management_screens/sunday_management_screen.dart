import 'package:flutter/material.dart';
import 'management_base.dart';
import '../../sunday/sunday_templates_screen.dart';
import '../../sunday/sunday_monday_import_screen.dart';

/// Sunday management screen
/// Contains: Board Templates, Import from Monday
/// Note: Sunday Settings is now accessible from the Sunday screen top bar (for admins)
class SundayManagementScreen extends StatelessWidget {
  final String currentUsername;

  const SundayManagementScreen({
    super.key,
    required this.currentUsername,
  });

  @override
  Widget build(BuildContext context) {
    return ManagementCategoryScreen(
      title: 'Sunday',
      icon: Icons.view_kanban,
      children: [
        ManagementButton(
          icon: Icons.folder_copy,
          title: 'Board Templates',
          subtitle: 'Manage board templates',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SundayTemplatesScreen(username: currentUsername),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ManagementButton(
          icon: Icons.cloud_upload,
          title: 'Import from Monday',
          subtitle: 'Import boards from Monday.com',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SundayMondayImportScreen(username: currentUsername),
            ),
          ),
        ),
      ],
    );
  }
}
