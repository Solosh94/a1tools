import 'package:flutter/material.dart';
import 'management_base.dart';
import '../../training/training_kb_management_screen.dart';
import '../../training/training_test_management_screen.dart';

/// Training management screen
/// Contains: Study Guide Editor, Test Editor
class TrainingManagementScreen extends StatelessWidget {
  final String currentUsername;
  final String currentRole;

  const TrainingManagementScreen({
    super.key,
    required this.currentUsername,
    required this.currentRole,
  });

  @override
  Widget build(BuildContext context) {
    return ManagementCategoryScreen(
      title: 'Training',
      icon: Icons.school,
      children: [
        ManagementButton(
          icon: Icons.menu_book,
          title: 'Study Guide Editor',
          subtitle: 'Create & manage training content',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TrainingKBManagementScreen(currentUserRole: currentRole),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ManagementButton(
          icon: Icons.edit_note,
          title: 'Test Editor',
          subtitle: 'Create & manage training tests',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TrainingTestManagementScreen(currentUserRole: currentRole),
            ),
          ),
        ),
      ],
    );
  }
}
