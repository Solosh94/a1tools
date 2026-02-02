import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import '../../app_theme.dart';
import '../../config/api_config.dart';

/// Admin screen to push updates to all clients
class PushUpdateScreen extends StatefulWidget {
  const PushUpdateScreen({super.key});

  @override
  State<PushUpdateScreen> createState() => _PushUpdateScreenState();
}

class _PushUpdateScreenState extends State<PushUpdateScreen> {
  static const Color _accent = AppColors.accent;

  final _versionController = TextEditingController();
  final _downloadUrlController = TextEditingController();
  final _releaseNotesController = TextEditingController();

  bool _forceUpdate = true;
  bool _loading = false;
  bool _pushing = false;
  List<dynamic> _recentUpdates = [];
  Map<String, dynamic>? _activeUpdate;
  String _currentVersion = '...';

  @override
  void initState() {
    super.initState();
    _loadStatus();
    _loadVersion();
    
    // Auto-update download URL when version changes
    _versionController.addListener(_updateDownloadUrl);
  }
  
  Future<void> _loadVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _currentVersion = packageInfo.version;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentVersion = 'Unknown';
        });
      }
    }
  }

  void _updateDownloadUrl() {
    final version = _versionController.text.trim();
    if (version.isNotEmpty) {
      _downloadUrlController.text = ApiConfig.installerDownload(version);
    }
  }

  @override
  void dispose() {
    _versionController.removeListener(_updateDownloadUrl);
    _versionController.dispose();
    _downloadUrlController.dispose();
    _releaseNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    setState(() => _loading = true);

    try {
      // Add timestamp to bust cache
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse('${ApiConfig.appUpdate}?action=status&_t=$timestamp'),
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _recentUpdates = data['updates'] ?? [];
            _activeUpdate = _recentUpdates.isNotEmpty &&
                    _recentUpdates[0]['is_active'] == 1
                ? _recentUpdates[0]
                : null;
          });
        }
      }
    } catch (e) {
      _showError('Failed to load status: $e');
    } finally {
      setState(() => _loading = false);
    }
  }


  Future<void> _pushUpdate() async {
    final version = _versionController.text.trim();
    final downloadUrl = _downloadUrlController.text.trim();

    if (version.isEmpty || downloadUrl.isEmpty) {
      _showError('Version and Download URL are required');
      return;
    }

    // Confirm push
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Push Update?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: $version'),
            Text('URL: $downloadUrl'),
            const SizedBox(height: 16),
            const Text(
              'This will push the update to ALL connected clients. '
              'They will download and install it automatically.',
              style: TextStyle(color: Colors.orange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _accent),
            child: const Text('Push Update', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _pushing = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.appUpdate),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'push',
          'version': version,
          'download_url': downloadUrl,
          'force_update': _forceUpdate ? 1 : 0,
          'release_notes': _releaseNotesController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _showSuccess('Update $version pushed to all clients!');
          _versionController.clear();
          _releaseNotesController.clear();
          _loadStatus();
        } else {
          _showError(data['error'] ?? 'Failed to push update');
        }
      } else {
        _showError('Server error: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Failed to push update: $e');
    } finally {
      setState(() => _pushing = false);
    }
  }

  Future<void> _cancelUpdate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Update?'),
        content: const Text(
          'This will stop the current update from being pushed to clients '
          'that haven\'t updated yet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Update', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.appUpdate),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'cancel'}),
      );

      if (response.statusCode == 200) {
        _showSuccess('Update cancelled');
        _loadStatus();
      }
    } catch (e) {
      _showError('Failed to cancel: $e');
    }
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Push App Update'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current version info
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: _accent),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Your App Version',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              Text(
                                _currentVersion,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Active update status
                  if (_activeUpdate != null) ...[
                    Card(
                      color: Colors.green.withValues(alpha: 0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.cloud_upload, color: Colors.green),
                                const SizedBox(width: 8),
                                const Text(
                                  'Active Update',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: _cancelUpdate,
                                  icon: const Icon(Icons.cancel, color: Colors.red, size: 18),
                                  label: const Text('Cancel', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Version: ${_activeUpdate!['version']}'),
                            Text(
                              'Pushed: ${_activeUpdate!['pushed_at']}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Push new update form
                  const Text(
                    'Push New Update',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _versionController,
                    decoration: InputDecoration(
                      labelText: 'Version',
                      hintText: 'e.g., 2.0.2',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.tag),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _downloadUrlController,
                    decoration: InputDecoration(
                      labelText: 'Download URL',
                      hintText: '${ApiConfig.downloadsBase}/...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.link),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _releaseNotesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Release Notes (optional)',
                      hintText: 'What\'s new in this version...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.notes),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SwitchListTile(
                    title: const Text('Force Update'),
                    subtitle: const Text(
                      'If enabled, clients will auto-install immediately',
                    ),
                    value: _forceUpdate,
                    activeTrackColor: _accent.withValues(alpha: 0.5),
                    activeThumbColor: _accent,
                    onChanged: (v) => setState(() => _forceUpdate = v),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _pushing ? null : _pushUpdate,
                      icon: _pushing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.rocket_launch, color: Colors.white),
                      label: Text(
                        _pushing ? 'Pushing...' : 'Push Update to All Clients',
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

                  // Recent updates history
                  if (_recentUpdates.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    const Text(
                      'Recent Updates',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ...(_recentUpdates.take(5).map((update) => Card(
                          child: ListTile(
                            leading: Icon(
                              update['is_active'] == 1
                                  ? Icons.cloud_done
                                  : Icons.cloud_off,
                              color: update['is_active'] == 1
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                            title: Text('Version ${update['version']}'),
                            subtitle: Text(
                              'Pushed: ${update['pushed_at'] ?? update['created_at']}',
                            ),
                            trailing: update['is_active'] == 1
                                ? const Chip(
                                    label: Text('Active'),
                                    backgroundColor: Colors.green,
                                    labelStyle: TextStyle(color: Colors.white),
                                  )
                                : null,
                          ),
                        ))),
                  ],
                ],
              ),
            ),
    );
  }
}
