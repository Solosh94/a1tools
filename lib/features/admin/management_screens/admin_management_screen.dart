import 'package:flutter/material.dart';
import 'management_base.dart';
import '../../../hr/hr_screen.dart';
import '../../auth/authenticator_screen.dart';
import '../../audit/audit_log_screen.dart';
import '../../timeclock/time_records_screen.dart';
import '../../timeclock/office_map_screen.dart';
import '../../training/training_dashboard_screen.dart';

/// Administration management screen
/// Contains: Human Resources, Authenticator, Time Records, Office Map, Training Dashboard
class AdminManagementScreen extends StatelessWidget {
  final String currentUsername;
  final String currentRole;

  const AdminManagementScreen({
    super.key,
    required this.currentUsername,
    required this.currentRole,
  });

  @override
  Widget build(BuildContext context) {
    return ManagementCategoryScreen(
      title: 'Administration',
      icon: Icons.admin_panel_settings,
      children: [
        ManagementButton(
          icon: Icons.badge_outlined,
          title: 'Human Resources',
          subtitle: 'Employee database & documents',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HRScreen(
                username: currentUsername,
                role: currentRole,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ManagementButton(
          icon: Icons.security,
          title: 'Authenticator',
          subtitle: 'Security codes for sensitive operations',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AuthenticatorScreen(
                username: currentUsername,
                role: currentRole,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ManagementButton(
          icon: Icons.access_time,
          title: 'Time Records',
          subtitle: 'View clock in/out records',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TimeRecordsScreen()),
          ),
        ),
        const SizedBox(height: 12),
        ManagementButton(
          icon: Icons.map_outlined,
          title: 'Office Map',
          subtitle: 'View staff locations & status',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OfficeMapScreen(
                currentUsername: currentUsername,
                currentRole: currentRole,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ManagementButton(
          icon: Icons.dashboard,
          title: 'Training Dashboard',
          subtitle: 'View user progress & results',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TrainingDashboardScreen(
                currentUsername: currentUsername,
                currentRole: currentRole,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ManagementButton(
          icon: Icons.history,
          title: 'Audit Logs',
          subtitle: 'View system activity & security events',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AuditLogScreen(
                currentUsername: currentUsername,
                currentRole: currentRole,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
