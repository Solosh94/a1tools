// FCM Configuration Screen
//
// Allows administrators to configure Firebase Cloud Messaging settings
// for push notifications.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../app_theme.dart';
import '../../config/api_config.dart';

class FcmConfigScreen extends StatefulWidget {
  final String username;
  final String role;

  const FcmConfigScreen({
    super.key,
    required this.username,
    required this.role,
  });

  @override
  State<FcmConfigScreen> createState() => _FcmConfigScreenState();
}

class _FcmConfigScreenState extends State<FcmConfigScreen> {
  static const Color _accent = AppColors.accent;

  final _formKey = GlobalKey<FormState>();
  final _serverKeyController = TextEditingController();
  final _senderIdController = TextEditingController();

  bool _enabled = false;
  bool _loading = true;
  bool _saving = false;
  bool _obscureServerKey = true;

  // Stats
  int _registeredUsers = 0;
  int _totalTokens = 0;
  int _sentToday = 0;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _loadStats();
  }

  @override
  void dispose() {
    _serverKeyController.dispose();
    _senderIdController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.pushNotifications}?action=get_config'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _serverKeyController.text = data['config']['server_key'] ?? '';
            _senderIdController.text = data['config']['sender_id'] ?? '';
            _enabled = data['config']['enabled'] ?? false;
            _loading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading FCM config: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _loadStats() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.pushNotifications}?action=get_stats'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _registeredUsers = data['stats']['registered_users'] ?? 0;
            _totalTokens = data['stats']['total_tokens'] ?? 0;
            _sentToday = data['stats']['sent_today'] ?? 0;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading FCM stats: $e');
    }
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.pushNotifications),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'save_config',
          'server_key': _serverKeyController.text.trim(),
          'sender_id': _senderIdController.text.trim(),
          'enabled': _enabled,
          'updated_by': widget.username,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('FCM configuration saved successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception(data['error'] ?? 'Failed to save');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving configuration: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _sendTestNotification() async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.pushNotifications),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'send_notification',
          'usernames': [widget.username],
          'title': 'Test Notification',
          'body': 'This is a test push notification from A1 Tools.',
          'type': 'test',
          'sent_by': widget.username,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['success'] == true
                  ? 'Test notification sent (${data['sent_count']} delivered)'
                  : 'Failed: ${data['error']}'),
              backgroundColor: data['success'] == true ? Colors.green : Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending test: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[100],
      appBar: AppBar(
        title: const Text('Push Notification Settings'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveConfig,
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Card
                    _buildStatsCard(isDark),
                    const SizedBox(height: 24),

                    // Enable Switch
                    _buildSettingsCard(
                      isDark: isDark,
                      child: SwitchListTile(
                        title: const Text(
                          'Enable Push Notifications',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text(
                          'Turn on to allow sending push notifications',
                        ),
                        value: _enabled,
                        activeTrackColor: _accent.withValues(alpha: 0.5),
                        activeThumbColor: _accent,
                        onChanged: (value) {
                          setState(() => _enabled = value);
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Firebase Configuration Section
                    Text(
                      'Firebase Configuration',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildSettingsCard(
                      isDark: isDark,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // Server Key
                            TextFormField(
                              controller: _serverKeyController,
                              obscureText: _obscureServerKey,
                              decoration: InputDecoration(
                                labelText: 'FCM Server Key',
                                hintText: 'Enter your Firebase Cloud Messaging server key',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureServerKey
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureServerKey = !_obscureServerKey;
                                    });
                                  },
                                ),
                              ),
                              validator: (value) {
                                if (_enabled && (value == null || value.isEmpty)) {
                                  return 'Server key is required when enabled';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Sender ID
                            TextFormField(
                              controller: _senderIdController,
                              decoration: const InputDecoration(
                                labelText: 'Sender ID (optional)',
                                hintText: 'Your Firebase project sender ID',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Instructions
                    _buildSettingsCard(
                      isDark: isDark,
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: _accent, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'How to get your FCM Server Key',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Text(
                              '1. Go to Firebase Console (console.firebase.google.com)\n'
                              '2. Select your project or create a new one\n'
                              '3. Go to Project Settings > Cloud Messaging\n'
                              '4. Copy the "Server key" from Cloud Messaging API (Legacy)\n'
                              '5. Paste it in the field above',
                              style: TextStyle(fontSize: 13, height: 1.6),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Test Button
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: _enabled ? _sendTestNotification : null,
                        icon: const Icon(Icons.send),
                        label: const Text('Send Test Notification'),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.people,
            label: 'Registered Users',
            value: _registeredUsers.toString(),
          ),
          _buildStatItem(
            icon: Icons.devices,
            label: 'Total Devices',
            value: _totalTokens.toString(),
          ),
          _buildStatItem(
            icon: Icons.send,
            label: 'Sent Today',
            value: _sentToday.toString(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: _accent, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
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
}
