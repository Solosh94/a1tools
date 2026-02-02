import 'package:flutter/material.dart';
import '../../app_theme.dart';

// Category screen imports
import 'management_screens/admin_management_screen.dart';
import 'management_screens/sunday_management_screen.dart';
import 'management_screens/training_management_screen.dart';
import 'management_screens/metrics_management_screen.dart';
import 'management_screens/app_management_screen.dart';
import 'management_screens/general_settings_management_screen.dart';
import 'management_screens/management_base.dart';

/// Main management hub screen
///
/// Displays a list of category items that navigate to dedicated screens
/// for each management category. Uses the same design as category screens.
class ManagementScreen extends StatelessWidget {
  final String currentUsername;
  final String currentRole;

  const ManagementScreen({
    super.key,
    required this.currentUsername,
    required this.currentRole,
  });

  bool get _isAdminLevel =>
      currentRole == 'administrator' || currentRole == 'developer';
  bool get _isDeveloper => currentRole == 'developer';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.settings, size: 20, color: AppColors.accent),
            SizedBox(width: 8),
            Text('Management'),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildCategoryList(context),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCategoryList(BuildContext context) {
    final items = <Widget>[];

    // Administration (all)
    items.add(
      ManagementButton(
        icon: Icons.admin_panel_settings,
        title: 'Administration',
        subtitle: 'HR, Time Records & Training',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminManagementScreen(
              currentUsername: currentUsername,
              currentRole: currentRole,
            ),
          ),
        ),
      ),
    );

    // Sunday (administrator, developer)
    items.add(const SizedBox(height: 12));
    if (_isAdminLevel) {
      items.add(
        ManagementButton(
          icon: Icons.view_kanban,
          title: 'Sunday',
          subtitle: 'Boards & Templates',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SundayManagementScreen(
                currentUsername: currentUsername,
              ),
            ),
          ),
        ),
      );
    } else {
      items.add(
        const DisabledManagementButton(
          icon: Icons.view_kanban,
          title: 'Sunday',
          subtitle: 'Boards & Templates',
        ),
      );
    }

    // Training (all)
    items.add(const SizedBox(height: 12));
    items.add(
      ManagementButton(
        icon: Icons.school,
        title: 'Training',
        subtitle: 'Guides & Tests',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TrainingManagementScreen(
              currentUsername: currentUsername,
              currentRole: currentRole,
            ),
          ),
        ),
      ),
    );

    // Metrics (administrator, developer)
    items.add(const SizedBox(height: 12));
    if (_isAdminLevel) {
      items.add(
        ManagementButton(
          icon: Icons.bar_chart,
          title: 'Metrics',
          subtitle: 'Analytics & Reports',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MetricsManagementScreen(
                currentUsername: currentUsername,
                currentRole: currentRole,
              ),
            ),
          ),
        ),
      );
    } else {
      items.add(
        const DisabledManagementButton(
          icon: Icons.bar_chart,
          title: 'Metrics',
          subtitle: 'Analytics & Reports',
        ),
      );
    }

    // App Settings (administrator, developer)
    items.add(const SizedBox(height: 12));
    if (_isAdminLevel) {
      items.add(
        ManagementButton(
          icon: Icons.apps,
          title: 'App Settings',
          subtitle: 'Config & Updates',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AppManagementScreen(
                currentUsername: currentUsername,
                currentRole: currentRole,
              ),
            ),
          ),
        ),
      );
    } else {
      items.add(
        const DisabledManagementButton(
          icon: Icons.apps,
          title: 'App Settings',
          subtitle: 'Config & Updates',
        ),
      );
    }

    // General Settings (developer only)
    items.add(const SizedBox(height: 12));
    if (_isDeveloper) {
      items.add(
        ManagementButton(
          icon: Icons.settings_applications,
          title: 'General Settings',
          subtitle: 'System-wide configuration',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GeneralSettingsManagementScreen(
                currentUsername: currentUsername,
                currentRole: currentRole,
              ),
            ),
          ),
        ),
      );
    } else {
      items.add(
        const DisabledManagementButton(
          icon: Icons.settings_applications,
          title: 'General Settings',
          subtitle: 'System-wide configuration',
        ),
      );
    }

    return items;
  }
}
