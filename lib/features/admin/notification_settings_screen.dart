// Notification Settings Screen
//
// Allows users to configure their push notification preferences.

import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../core/services/push_notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  static const Color _accent = AppColors.accent;

  final PushNotificationService _service = PushNotificationService();
  late NotificationSettings _settings;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      _settings = _service.settings;
      _loading = false;
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    await _service.saveSettings(_settings);
    setState(() => _saving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification settings saved'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[100],
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveSettings,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Master toggle
                _buildSettingsCard(
                  isDark: isDark,
                  child: SwitchListTile(
                    title: const Text(
                      'Enable Notifications',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Turn off to disable all push notifications',
                    ),
                    value: _settings.enabled,
                    activeTrackColor: _accent.withValues(alpha: 0.5),
                    activeThumbColor: _accent,
                    onChanged: (value) {
                      setState(() {
                        _settings = _settings.copyWith(enabled: value);
                      });
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // Notification types
                Text(
                  'Notification Types',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),

                _buildSettingsCard(
                  isDark: isDark,
                  child: Column(
                    children: [
                      _buildNotificationToggle(
                        icon: Icons.warning_amber,
                        title: 'Alerts',
                        subtitle: 'Important alerts from administrators',
                        value: _settings.alerts,
                        onChanged: _settings.enabled
                            ? (value) {
                                setState(() {
                                  _settings = _settings.copyWith(alerts: value);
                                });
                              }
                            : null,
                      ),
                      const Divider(),
                      _buildNotificationToggle(
                        icon: Icons.chat_bubble_outline,
                        title: 'Chat Messages',
                        subtitle: 'Direct messages and group chats',
                        value: _settings.chats,
                        onChanged: _settings.enabled
                            ? (value) {
                                setState(() {
                                  _settings = _settings.copyWith(chats: value);
                                });
                              }
                            : null,
                      ),
                      const Divider(),
                      _buildNotificationToggle(
                        icon: Icons.assignment,
                        title: 'Job Assignments',
                        subtitle: 'New job assignments and schedule changes',
                        value: _settings.jobAssignments,
                        onChanged: _settings.enabled
                            ? (value) {
                                setState(() {
                                  _settings = _settings.copyWith(jobAssignments: value);
                                });
                              }
                            : null,
                      ),
                      const Divider(),
                      _buildNotificationToggle(
                        icon: Icons.update,
                        title: 'Job Updates',
                        subtitle: 'Updates on assigned jobs',
                        value: _settings.jobUpdates,
                        onChanged: _settings.enabled
                            ? (value) {
                                setState(() {
                                  _settings = _settings.copyWith(jobUpdates: value);
                                });
                              }
                            : null,
                      ),
                      const Divider(),
                      _buildNotificationToggle(
                        icon: Icons.alarm,
                        title: 'Reminders',
                        subtitle: 'Scheduled reminders and deadlines',
                        value: _settings.reminders,
                        onChanged: _settings.enabled
                            ? (value) {
                                setState(() {
                                  _settings = _settings.copyWith(reminders: value);
                                });
                              }
                            : null,
                      ),
                      const Divider(),
                      _buildNotificationToggle(
                        icon: Icons.school,
                        title: 'Training',
                        subtitle: 'Training assignments and deadlines',
                        value: _settings.training,
                        onChanged: _settings.enabled
                            ? (value) {
                                setState(() {
                                  _settings = _settings.copyWith(training: value);
                                });
                              }
                            : null,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Sound & Vibration
                Text(
                  'Sound & Vibration',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),

                _buildSettingsCard(
                  isDark: isDark,
                  child: Column(
                    children: [
                      _buildNotificationToggle(
                        icon: Icons.volume_up,
                        title: 'Sound',
                        subtitle: 'Play sound for notifications',
                        value: _settings.soundEnabled,
                        onChanged: _settings.enabled
                            ? (value) {
                                setState(() {
                                  _settings = _settings.copyWith(soundEnabled: value);
                                });
                              }
                            : null,
                      ),
                      const Divider(),
                      _buildNotificationToggle(
                        icon: Icons.vibration,
                        title: 'Vibration',
                        subtitle: 'Vibrate for notifications',
                        value: _settings.vibrationEnabled,
                        onChanged: _settings.enabled
                            ? (value) {
                                setState(() {
                                  _settings = _settings.copyWith(vibrationEnabled: value);
                                });
                              }
                            : null,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Test notification button
                Center(
                  child: OutlinedButton.icon(
                    onPressed: _settings.enabled ? _sendTestNotification : null,
                    icon: const Icon(Icons.send),
                    label: const Text('Send Test Notification'),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildSettingsCard({
    required bool isDark,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: child,
    );
  }

  Widget _buildNotificationToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    ValueChanged<bool>? onChanged,
  }) {
    final enabled = onChanged != null;

    return SwitchListTile(
      secondary: Icon(
        icon,
        color: enabled ? _accent : Colors.grey,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: enabled ? null : Colors.grey,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: enabled ? Colors.grey : Colors.grey.shade400,
        ),
      ),
      value: value,
      activeTrackColor: _accent.withValues(alpha: 0.5),
      activeThumbColor: _accent,
      onChanged: onChanged,
    );
  }

  Future<void> _sendTestNotification() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Test notification sent!'),
        backgroundColor: Colors.green,
      ),
    );

    // In a real implementation, this would trigger a local notification
    // or send a push notification to the current device
  }
}
