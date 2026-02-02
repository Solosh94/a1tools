import 'package:flutter/material.dart';
import '../../app_theme.dart';
import 'work_hours_screen.dart';
import 'time_clock_service.dart';

class ScheduleScreen extends StatelessWidget {
  final String username;
  final String role;

  const ScheduleScreen({
    required this.username,
    required this.role,
    super.key,
  });

  static const Color _accent = AppColors.accent;

  /// Roles that require clock-in (can modify their schedule)
  bool get _requiresClockIn => TimeClockService.requiresClockIn(role);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Image.asset(
          isDark ? 'assets/images/logo-white.png' : 'assets/images/logo.png',
          height: 40,
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
          child: _buildLayout(context, cardColor),
        ),
      ),
    );
  }

  Widget _buildLayout(BuildContext context, Color cardColor) {
    return Column(
      children: [
        _buildSection(
          context: context,
          title: 'Schedule & Time',
          icon: Icons.schedule,
          cardColor: cardColor,
          items: _scheduleItems(context, cardColor),
        ),
      ],
    );
  }

  /// Schedule tools
  List<Widget> _scheduleItems(BuildContext context, Color cardColor) {
    final items = <Widget>[];


    // My Schedule Today - only for roles that require clock-in
    if (_requiresClockIn) {
      items.add(const SizedBox(height: 12));
      items.add(
        _buildToolButton(
          context: context,
          icon: Icons.today,
          title: 'My Schedule Today',
          subtitle: 'Change your hours for today',
          cardColor: cardColor,
          onTap: () => _showTodayScheduleDialog(context),
        ),
      );
    }

    // Work Hours - only for roles that require clock-in
    if (_requiresClockIn) {
      items.add(const SizedBox(height: 12));
      items.add(
        _buildToolButton(
          context: context,
          icon: Icons.access_time,
          title: 'Work Hours',
          subtitle: 'View your clock in/out history',
          cardColor: cardColor,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => WorkHoursScreen(
                  username: username,
                ),
              ),
            );
          },
        ),
      );
    }

    return items;
  }

  /// Section with header
  Widget _buildSection({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color cardColor,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: _accent),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...items,
      ],
    );
  }

  Widget _buildToolButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color cardColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _accent.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
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
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
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
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTodayScheduleDialog(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Load existing override
    final existingOverride = await TimeClockService.getTodaySchedule(username);

    // Load default schedule for today
    final schedule = await TimeClockService.getSchedule(username);
    final dayNames = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    final todayIndex = DateTime.now().weekday - 1; // 0 = Monday
    final daySchedule = schedule?.getDay(dayNames[todayIndex]);

    // Initialize controllers with existing override or default schedule
    final startController = TextEditingController(
      text: existingOverride?.startTime ?? daySchedule?.start ?? '09:00',
    );
    final endController = TextEditingController(
      text: existingOverride?.endTime ?? daySchedule?.end ?? '17:00',
    );
    final reasonController = TextEditingController(
      text: existingOverride?.reason ?? '',
    );

    if (!context.mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.schedule, color: _accent),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('My Schedule Today'),
                Text(
                  _formatTodayDate(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Adjust your working hours for today. This will prevent early clock-out warnings.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 16),
              // Start Time
              TextField(
                controller: startController,
                decoration: InputDecoration(
                  labelText: 'Start Time',
                  border: const OutlineInputBorder(),
                  hintText: 'HH:MM',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.access_time),
                    onPressed: () async {
                      final parts = startController.text.split(':');
                      final initial = TimeOfDay(
                        hour: int.tryParse(parts[0]) ?? 9,
                        minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
                      );
                      final time = await showTimePicker(
                        context: ctx,
                        initialTime: initial,
                      );
                      if (time != null) {
                        startController.text =
                            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // End Time
              TextField(
                controller: endController,
                decoration: InputDecoration(
                  labelText: 'End Time',
                  border: const OutlineInputBorder(),
                  hintText: 'HH:MM',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.access_time),
                    onPressed: () async {
                      final parts = endController.text.split(':');
                      final initial = TimeOfDay(
                        hour: int.tryParse(parts[0]) ?? 17,
                        minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
                      );
                      final time = await showTimePicker(
                        context: ctx,
                        initialTime: initial,
                      );
                      if (time != null) {
                        endController.text =
                            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Reason
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Doctor appointment',
                ),
                maxLines: 2,
              ),
              if (existingOverride != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: _accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You already set a schedule for today',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      final success = await TimeClockService.setTodaySchedule(
        username: username,
        startTime: startController.text.trim(),
        endTime: endController.text.trim(),
        reason: reasonController.text.trim().isNotEmpty ? reasonController.text.trim() : null,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Schedule updated for today (${startController.text} - ${endController.text})'
                : 'Failed to update schedule'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  String _formatTodayDate() {
    final now = DateTime.now();
    final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dayNames[now.weekday - 1]}, ${monthNames[now.month - 1]} ${now.day}';
  }
}
