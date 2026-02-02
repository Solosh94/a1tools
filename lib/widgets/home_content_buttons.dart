import 'dart:io';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../features/admin/management_screen.dart';
import '../guidelines.dart';
import '../features/alerts/alert_admin_screen.dart';
import '../features/training/training_screen.dart';
import '../features/inspection/inspection_list_screen.dart';
import '../features/suggestions/suggestion_screen.dart';
import '../features/marketing/marketing_tools_screen.dart';
import '../features/timeclock/schedule_screen.dart';
import '../features/sunday/sunday_screen.dart';

class HomeContentButtons extends StatelessWidget {
  final bool canSendAlerts;
  final String? username;
  final String? firstName;
  final String? lastName;
  final String? role;
  final VoidCallback? onLoginPressed;
  final int unreadMessageCount;
  final int sundayNotificationCount;

  const HomeContentButtons({
    required this.canSendAlerts,
    required this.username,
    this.firstName,
    this.lastName,
    required this.role,
    this.onLoginPressed,
    this.unreadMessageCount = 0,
    this.sundayNotificationCount = 0,
    super.key,
  });

  static const Color _accent = AppColors.accent;

  bool get _isLoggedIn => username != null && username!.isNotEmpty;

  /// Admin roles: developer, administrator, management
  bool get _isAdminRole =>
      _role == 'developer' || _role == 'administrator' || _role == 'management';

  /// Inspection access: technician + admin roles
  bool get _canViewInspection =>
      _role == 'technician' || _isAdminRole;

  /// Training access: all logged in users
  bool get _canViewTraining => _isLoggedIn;

  /// Check if user is technician only (not admin)
  bool get _isTechnicianOnly => _role == 'technician';

  String? get _role => role;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;

    // If not logged in, show only Login button
    if (!_isLoggedIn) {
      return Center(
        child: SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Please log in to continue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _buildMenuButton(
                context: context,
                icon: Icons.login,
                title: 'Login',
                subtitle: 'Sign in to your account',
                cardColor: cardColor,
                onTap: () => onLoginPressed?.call(),
              ),
            ],
          ),
        ),
      );
    }

    // Logged in - show all available features (alphabetized)
    // Build the list of active menu items
    final List<Widget> activeItems = [];
    final List<Widget> comingSoonItems = [];

    // For technicians: only show Inspection, Training, and Suggestions
    if (_isTechnicianOnly) {
      // Inspection
      activeItems.add(
        _buildMenuButton(
          context: context,
          icon: Icons.assignment_outlined,
          title: 'Inspection',
          subtitle: 'Submit inspection reports',
          cardColor: cardColor,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => InspectionListScreen(
                  username: username!,
                  firstName: firstName ?? '',
                  lastName: lastName ?? '',
                  role: role!,
                ),
              ),
            );
          },
        ),
      );

      // Training
      activeItems.add(
        _buildMenuButton(
          context: context,
          icon: Icons.school_outlined,
          title: 'Training',
          subtitle: 'Courses & certification tests',
          cardColor: cardColor,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TrainingScreen(
                  username: username!,
                  role: role!,
                ),
              ),
            );
          },
        ),
      );

      // Suggestions
      activeItems.add(
        _buildMenuButton(
          context: context,
          icon: Icons.lightbulb_outline,
          title: 'Suggestions',
          subtitle: 'Share ideas for app improvements',
          cardColor: cardColor,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SuggestionScreen(
                  username: username!,
                ),
              ),
            );
          },
        ),
      );
    } else {
      // For all other roles: show full menu

      // Guidelines - all users
      activeItems.add(
        _buildMenuButton(
          context: context,
          icon: Icons.menu_book_outlined,
          title: 'Guidelines',
          subtitle: 'Company policies & procedures',
          cardColor: cardColor,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const GuidelinesScreen(),
              ),
            );
          },
        ),
      );

      // Inspection: admin roles only (technicians handled above)
      if (_canViewInspection) {
        activeItems.add(
          _buildMenuButton(
            context: context,
            icon: Icons.assignment_outlined,
            title: 'Inspection',
            subtitle: 'Submit inspection reports',
            cardColor: cardColor,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => InspectionListScreen(
                    username: username!,
                    firstName: firstName ?? '',
                    lastName: lastName ?? '',
                    role: role!,
                  ),
                ),
              );
            },
          ),
        );
      }

      // Sunday: all logged in users
      if (_isLoggedIn) {
        activeItems.add(
          _buildMenuButton(
            context: context,
            icon: Icons.dashboard_customize,
            title: 'Sunday',
            subtitle: 'Boards, leads & job tracking',
            cardColor: cardColor,
            badgeCount: sundayNotificationCount,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SundayScreen(
                    username: username!,
                    role: role!,
                  ),
                ),
              );
            },
          ),
        );
      }

      // Management: admin roles only
      if (_isAdminRole) {
        activeItems.add(
          _buildMenuButton(
            context: context,
            icon: Icons.admin_panel_settings_outlined,
            title: 'Management',
            subtitle: 'Admin tools & analytics',
            cardColor: cardColor,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ManagementScreen(
                    currentUsername: username ?? '',
                    currentRole: role ?? '',
                  ),
                ),
              );
            },
          ),
        );
      }

      // Marketing Tools: admin roles + marketing (Windows desktop only)
      if ((_isAdminRole || _role == 'marketing') && Platform.isWindows) {
        activeItems.add(
          _buildMenuButton(
            context: context,
            icon: Icons.campaign_outlined,
            title: 'Marketing Tools',
            subtitle: 'Image editing, blog creator & more',
            cardColor: cardColor,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MarketingToolsScreen(
                    username: username!,
                    role: role!,
                  ),
                ),
              );
            },
          ),
        );
      }

      // Messages: roles that can send alerts
      if (canSendAlerts) {
        activeItems.add(
          _buildMenuButton(
            context: context,
            icon: Icons.message_outlined,
            title: 'Messages',
            subtitle: 'Send & receive alerts',
            cardColor: cardColor,
            badgeCount: unreadMessageCount,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AlertAdminScreen(
                    currentUsername: username ?? '',
                    currentRole: role ?? '',
                  ),
                ),
              );
            },
          ),
        );
      }

      // Schedule: all logged in users
      activeItems.add(
        _buildMenuButton(
          context: context,
          icon: Icons.schedule,
          title: 'Schedule',
          subtitle: 'Calendar, hours & time tracking',
          cardColor: cardColor,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ScheduleScreen(
                  username: username!,
                  role: role!,
                ),
              ),
            );
          },
        ),
      );

      // Training: all logged in users
      if (_isLoggedIn && _canViewTraining) {
        activeItems.add(
          _buildMenuButton(
            context: context,
            icon: Icons.school_outlined,
            title: 'Training',
            subtitle: 'Courses & certification tests',
            cardColor: cardColor,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TrainingScreen(
                    username: username!,
                    role: role!,
                  ),
                ),
              );
            },
          ),
        );
      } else if (!_isLoggedIn) {
        activeItems.add(
          _buildMenuButton(
            context: context,
            icon: Icons.school_outlined,
            title: 'Training',
            subtitle: 'Login to access training',
            cardColor: cardColor,
            onTap: () => onLoginPressed?.call(),
          ),
        );
      }

      // Suggestions: all logged in users
      activeItems.add(
        _buildMenuButton(
          context: context,
          icon: Icons.lightbulb_outline,
          title: 'Suggestions',
          subtitle: 'Share ideas for app improvements',
          cardColor: cardColor,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SuggestionScreen(
                  username: username!,
                ),
              ),
            );
          },
        ),
      );

      // Coming Soon section - File Transfer (admin roles only)
      if (_isAdminRole) {
        comingSoonItems.add(
          _buildComingSoonButton(
            context: context,
            icon: Icons.folder_outlined,
            title: 'File Transfer',
            subtitle: 'Transfer & share files',
            cardColor: cardColor,
          ),
        );
      }
    }

    // Check if we should use 2-column layout (desktop only, Windows)
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    final useWideLayout = isDesktop && screenWidth > 600;

    // Use LayoutBuilder to center content when there's extra space,
    // but allow scrolling when content exceeds available height
    return LayoutBuilder(
      builder: (context, constraints) {
        if (useWideLayout) {
          // 2-column layout for desktop
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 32,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Active items in 2-column grid
                      _buildTwoColumnGrid(activeItems),
                      // Coming Soon section
                      if (comingSoonItems.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        // Coming Soon header
                        Row(
                          children: [
                            Icon(
                              Icons.upcoming,
                              size: 16,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Coming Soon',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Divider(
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Coming soon items in 2-column grid
                        _buildTwoColumnGrid(comingSoonItems),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        } else {
          // Single column layout for mobile
          final content = SizedBox(
            width: 280,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Active items with spacing
                for (int i = 0; i < activeItems.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  activeItems[i],
                ],
                // Coming Soon section
                if (comingSoonItems.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  // Coming Soon header
                  Row(
                    children: [
                      Icon(
                        Icons.upcoming,
                        size: 16,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Coming Soon',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Divider(
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Coming soon items
                  for (int i = 0; i < comingSoonItems.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    comingSoonItems[i],
                  ],
                ],
              ],
            ),
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 32, // Account for padding
              ),
              child: Center(child: content),
            ),
          );
        }
      },
    );
  }

  /// Builds a 2-column grid from a list of widgets
  Widget _buildTwoColumnGrid(List<Widget> items) {
    final List<Widget> rows = [];

    for (int i = 0; i < items.length; i += 2) {
      final hasSecond = i + 1 < items.length;

      rows.add(
        Padding(
          padding: EdgeInsets.only(top: i > 0 ? 12 : 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: items[i]),
              const SizedBox(width: 12),
              Expanded(
                child: hasSecond ? items[i + 1] : const SizedBox(),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }

  Widget _buildMenuButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color cardColor,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _accent.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      color: _accent,
                      size: 24,
                    ),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          badgeCount > 99 ? '99+' : badgeCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Coming soon button (disabled with "Coming Soon" badge)
  Widget _buildComingSoonButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color cardColor,
  }) {
    return Opacity(
      opacity: 0.5,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: Colors.grey,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Soon',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
