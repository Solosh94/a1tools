import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import '../../app_theme.dart';
import '../../config/api_config.dart';

/// Admin screen to manage minimum app version requirements
/// Users with versions below the minimum will be blocked from using the app
class MinimumVersionScreen extends StatefulWidget {
  final String currentUsername;

  const MinimumVersionScreen({
    super.key,
    required this.currentUsername,
  });

  @override
  State<MinimumVersionScreen> createState() => _MinimumVersionScreenState();
}

class _MinimumVersionScreenState extends State<MinimumVersionScreen> {
  static const Color _accent = AppColors.accent;

  final _minimumVersionController = TextEditingController();
  final _messageController = TextEditingController();
  final _downloadUrlController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String _currentAppVersion = '...';
  String? _lastUpdatedAt;
  String? _lastUpdatedBy;
  Map<String, dynamic>? _latestUpdate;

  @override
  void initState() {
    super.initState();
    _loadCurrentVersion();
    _loadSettings();
  }

  @override
  void dispose() {
    _minimumVersionController.dispose();
    _messageController.dispose();
    _downloadUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _currentAppVersion = packageInfo.version;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentAppVersion = 'Unknown';
        });
      }
    }
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse('${ApiConfig.appUpdate}?action=get_version_settings&_t=$timestamp'),
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final settings = data['settings'] as Map<String, dynamic>? ?? {};

          setState(() {
            _minimumVersionController.text =
                settings['minimum_version']?['value'] ?? '0.0.0';
            _messageController.text =
                settings['minimum_version_message']?['value'] ??
                    'Your app is outdated. Please update to continue using A1 Tools.';
            _downloadUrlController.text =
                settings['latest_download_url']?['value'] ?? '';

            _lastUpdatedAt = settings['minimum_version']?['updated_at'];
            _lastUpdatedBy = settings['minimum_version']?['updated_by'];
            _latestUpdate = data['latest_update'];
          });
        }
      }
    } catch (e) {
      _showError('Failed to load settings: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveSettings() async {
    final minimumVersion = _minimumVersionController.text.trim();
    final message = _messageController.text.trim();
    final downloadUrl = _downloadUrlController.text.trim();

    // Validate version format
    if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(minimumVersion)) {
      _showError('Invalid version format. Use X.Y.Z format (e.g., 3.8.50)');
      return;
    }

    // Confirm if setting a high minimum version
    if (_isVersionNewer(minimumVersion, _currentAppVersion)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange),
              SizedBox(width: 8),
              Text('Warning'),
            ],
          ),
          content: Text(
            'The minimum version ($minimumVersion) is newer than your current version ($_currentAppVersion). '
            'This means YOUR app will also be blocked!\n\n'
            'Are you sure you want to continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Continue Anyway', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    setState(() => _saving = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.appUpdate),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'set_version_settings',
          'minimum_version': minimumVersion,
          'message': message,
          'download_url': downloadUrl,
          'updated_by': widget.currentUsername,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _showSuccess('Settings saved successfully!');
          _loadSettings(); // Reload to get updated timestamps
        } else {
          _showError(data['error'] ?? 'Failed to save settings');
        }
      } else {
        _showError('Server error: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Failed to save settings: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  void _useLatestUpdateUrl() {
    if (_latestUpdate != null && _latestUpdate!['download_url'] != null) {
      _downloadUrlController.text = _latestUpdate!['download_url'];
    }
  }

  void _setToCurrentVersion() {
    if (_currentAppVersion != 'Unknown' && _currentAppVersion != '...') {
      _minimumVersionController.text = _currentAppVersion;
    }
  }

  bool _isVersionNewer(String version1, String version2) {
    final v1Parts = version1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final v2Parts = version2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      final v1 = i < v1Parts.length ? v1Parts[i] : 0;
      final v2 = i < v2Parts.length ? v2Parts[i] : 0;
      if (v1 > v2) return true;
      if (v1 < v2) return false;
    }
    return false;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minimum Version Settings'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadSettings,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info card
                  Card(
                    color: Colors.blue.withValues(alpha: 0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.blue),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'About Minimum Version',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Users with app versions below the minimum will see a blocking screen '
                                  'and must update to continue using the app. Set to 0.0.0 to disable.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Current version info
                  Row(
                    children: [
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your App Version',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white60 : Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _currentAppVersion,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (_latestUpdate != null)
                        Expanded(
                          child: Card(
                            color: Colors.green.withValues(alpha: 0.1),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Latest Push Update',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white60 : Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _latestUpdate!['version'] ?? 'N/A',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Minimum version field
                  const Text(
                    'Minimum Required Version',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minimumVersionController,
                          decoration: InputDecoration(
                            hintText: 'e.g., 3.8.50',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: const Icon(Icons.security),
                          ),
                          keyboardType: TextInputType.text,
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _setToCurrentVersion,
                        child: const Text('Use Current'),
                      ),
                    ],
                  ),
                  if (_lastUpdatedAt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Last updated: $_lastUpdatedAt by ${_lastUpdatedBy ?? 'unknown'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Message field
                  const Text(
                    'Blocking Message',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _messageController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Message shown to users with outdated apps...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 48),
                        child: Icon(Icons.message),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Download URL field
                  const Text(
                    'Update Download URL',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _downloadUrlController,
                          decoration: InputDecoration(
                            hintText: '${ApiConfig.downloadsBase}/...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: const Icon(Icons.link),
                          ),
                        ),
                      ),
                      if (_latestUpdate != null) ...[
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _useLatestUpdateUrl,
                          child: const Text('Use Latest'),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This URL will be shown on the blocking screen so users can download the update.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _saveSettings,
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save, color: Colors.white),
                      label: Text(
                        _saving ? 'Saving...' : 'Save Settings',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Warning card
                  Card(
                    color: Colors.orange.withValues(alpha: 0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber, color: Colors.orange),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Important',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Version checking happens on app startup and periodically. '
                                  'Users already logged in will be blocked on their next session or heartbeat.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
