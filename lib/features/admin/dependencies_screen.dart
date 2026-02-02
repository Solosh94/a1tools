// Dependencies Screen
//
// Allows users to view and install optional dependencies like ffmpeg.

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../core/services/dependencies_manager.dart';

class DependenciesScreen extends StatefulWidget {
  const DependenciesScreen({super.key});

  @override
  State<DependenciesScreen> createState() => _DependenciesScreenState();
}

class _DependenciesScreenState extends State<DependenciesScreen> {
  final _manager = DependenciesManager.instance;
  StreamSubscription? _subscription;
  Map<String, DependencyInfo> _dependencies = {};
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _manager.initialize();

    _subscription = _manager.statusStream.listen((deps) {
      if (mounted) {
        setState(() => _dependencies = deps);
      }
    });

    setState(() {
      _dependencies = _manager.dependencies;
      _isInitialized = true;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _installFfmpeg() async {
    final success = await _manager.installFfmpeg();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'FFmpeg installed successfully!'
                : 'Failed to install FFmpeg. Please try again.',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _refreshStatus() async {
    await _manager.checkAllDependencies();
  }

  Future<void> _updateYtDlp() async {
    final success = await _manager.updateYtDlp();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'yt-dlp updated successfully!'
                : 'Failed to update yt-dlp. Please try again.',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;

    if (!Platform.isWindows) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dependencies')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.desktop_windows, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Dependencies management is only available on Windows',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dependencies'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshStatus,
            tooltip: 'Refresh Status',
          ),
        ],
      ),
      body: !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Some features require additional tools. '
                            'Install them here to unlock all functionality.',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Dependencies list
                  _buildDependencyCard(
                    'ffmpeg',
                    cardColor,
                    isDark,
                    icon: Icons.video_settings,
                    features: [
                      'High quality video downloads (1080p+)',
                      'Audio extraction (MP3)',
                      'Video format conversion',
                    ],
                    downloadSize: '~80 MB',
                    onInstall: _installFfmpeg,
                  ),
                  const SizedBox(height: 12),
                  _buildDependencyCard(
                    'yt-dlp',
                    cardColor,
                    isDark,
                    icon: Icons.download,
                    features: [
                      'YouTube video downloading',
                      'Video information fetching',
                    ],
                    isBundled: true,
                    onUpdate: _updateYtDlp,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDependencyCard(
    String id,
    Color cardColor,
    bool isDark, {
    required IconData icon,
    required List<String> features,
    String? downloadSize,
    bool isBundled = false,
    VoidCallback? onInstall,
    VoidCallback? onUpdate,
  }) {
    final dep = _dependencies[id];
    if (dep == null) return const SizedBox.shrink();

    final isInstalled = dep.status == DependencyStatus.installed;
    final isWorking = dep.isWorking;
    final isError = dep.status == DependencyStatus.error;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (dep.status) {
      case DependencyStatus.installed:
        statusColor = Colors.green;
        statusText = 'Installed';
        statusIcon = Icons.check_circle;
        break;
      case DependencyStatus.notInstalled:
        statusColor = Colors.orange;
        statusText = 'Not Installed';
        statusIcon = Icons.warning_amber;
        break;
      case DependencyStatus.checking:
        statusColor = Colors.blue;
        statusText = 'Checking...';
        statusIcon = Icons.hourglass_empty;
        break;
      case DependencyStatus.downloading:
        statusColor = Colors.blue;
        statusText = 'Downloading...';
        statusIcon = Icons.cloud_download;
        break;
      case DependencyStatus.extracting:
        statusColor = Colors.blue;
        statusText = 'Extracting...';
        statusIcon = Icons.folder_zip;
        break;
      case DependencyStatus.error:
        statusColor = Colors.red;
        statusText = 'Error';
        statusIcon = Icons.error;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isInstalled
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (isInstalled ? Colors.green : AppColors.accent)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: isInstalled ? Colors.green : AppColors.accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            dep.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isBundled) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Bundled',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dep.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isWorking)
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(statusColor),
                          ),
                        )
                      else
                        Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Version info
          if (dep.version != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Version: ${dep.version}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ),

          // Path info
          if (dep.installedPath != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Path: ${dep.installedPath}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontFamily: 'monospace',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // Download progress
          if (dep.status == DependencyStatus.downloading &&
              dep.downloadProgress != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: dep.downloadProgress,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(dep.downloadProgress! * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

          // Error message
          if (isError && dep.errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                dep.errorMessage!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.red,
                ),
              ),
            ),

          const Divider(height: 24),

          // Features list
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Enables:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...features.map((feature) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Row(
                  children: [
                    Icon(
                      isInstalled ? Icons.check : Icons.circle,
                      size: isInstalled ? 16 : 6,
                      color: isInstalled ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feature,
                        style: TextStyle(
                          fontSize: 13,
                          color: isInstalled
                              ? (isDark ? Colors.white70 : Colors.black87)
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              )),

          // Install button (for not installed dependencies)
          if (!isInstalled && !isBundled && onInstall != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isWorking ? null : onInstall,
                  icon: isWorking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download),
                  label: Text(
                    isWorking
                        ? 'Installing...'
                        : 'Install${downloadSize != null ? ' ($downloadSize)' : ''}',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(14),
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            )
          // Update button (for installed dependencies that support updates)
          else if (isInstalled && onUpdate != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isWorking ? null : onUpdate,
                  icon: isWorking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.update),
                  label: Text(
                    isWorking ? 'Updating...' : 'Update to Latest Version',
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(14),
                    foregroundColor: AppColors.accent,
                    side: const BorderSide(color: AppColors.accent),
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 16),
        ],
      ),
    );
  }
}
