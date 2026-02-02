import 'package:flutter/material.dart';
import 'management_base.dart';
import '../data_analysis_screen.dart';
import '../../compliance/compliance_management_screen.dart';

/// Metrics management screen (Developer only)
/// Contains: Analytics, Compliance System
class MetricsManagementScreen extends StatelessWidget {
  final String currentUsername;
  final String currentRole;

  const MetricsManagementScreen({
    super.key,
    required this.currentUsername,
    required this.currentRole,
  });

  @override
  Widget build(BuildContext context) {
    return ManagementCategoryScreen(
      title: 'Metrics',
      icon: Icons.bar_chart,
      children: [
        ManagementButton(
          icon: Icons.analytics_outlined,
          title: 'Analytics',
          subtitle: 'Reports & statistics',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DataAnalysisScreen(currentUsername: currentUsername)),
          ),
        ),
        const SizedBox(height: 12),
        ManagementButton(
          icon: Icons.monitor_heart,
          title: 'Compliance System',
          subtitle: 'Monitor heartbeats & auto clock-out',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ComplianceManagementScreen(
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
