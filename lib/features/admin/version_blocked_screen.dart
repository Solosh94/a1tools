import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app_theme.dart';
import '../../core/services/auto_updater.dart';
import '../../core/services/version_check_service.dart';

/// Screen shown when app version is below minimum required
/// Blocks access to the app until user updates
class VersionBlockedScreen extends StatefulWidget {
  final String currentVersion;
  final String minimumVersion;
  final String message;
  final String? downloadUrl;
  final VoidCallback? onRetry;

  const VersionBlockedScreen({
    super.key,
    required this.currentVersion,
    required this.minimumVersion,
    required this.message,
    this.downloadUrl,
    this.onRetry,
  });

  @override
  State<VersionBlockedScreen> createState() => _VersionBlockedScreenState();
}

class _VersionBlockedScreenState extends State<VersionBlockedScreen> {
  static const Color _accent = AppColors.accent;
  bool _downloading = false;
  double _downloadProgress = 0;
  bool _autoUpdateStarted = false;
  String? _latestVersion;
  String _updateStatus = '';
  bool _checkingVersion = false;

  // These can be updated when "Check Again" is clicked
  late String _minimumVersion;
  late String _message;
  String? _downloadUrl;

  @override
  void initState() {
    super.initState();
    // Initialize with widget values
    _minimumVersion = widget.minimumVersion;
    _message = widget.message;
    _downloadUrl = widget.downloadUrl;
    // Start auto-updater to check for latest version (not just minimum)
    _startAutoUpdate();
  }

  @override
  void dispose() {
    // Stop the auto-updater when leaving this screen
    AutoUpdater.instance.stop();
    super.dispose();
  }

  /// Start the auto-updater to check for and download the latest version
  Future<void> _startAutoUpdate() async {
    if (_autoUpdateStarted || !Platform.isWindows) return;
    _autoUpdateStarted = true;

    setState(() {
      _updateStatus = 'Checking for latest version...';
    });

    await AutoUpdater.instance.start(
      onUpdateStarted: () {
        if (mounted) {
          setState(() {
            _downloading = true;
            _updateStatus = 'Update found! Starting download...';
          });
        }
      },
      onDownloadProgress: (progress) {
        if (mounted) {
          setState(() {
            _downloadProgress = progress;
            _updateStatus = 'Downloading update... ${(progress * 100).toInt()}%';
          });
        }
      },
      onUpdateError: (error) {
        if (mounted) {
          setState(() {
            _downloading = false;
            _updateStatus = 'Auto-update failed. Use manual download below.';
          });
        }
      },
    );

    // Check for update - AutoUpdater will handle it automatically if found
    final updateInfo = await AutoUpdater.instance.checkForUpdate();
    if (mounted) {
      if (updateInfo != null) {
        setState(() {
          _latestVersion = updateInfo.version;
          _updateStatus = 'Found latest version: ${updateInfo.version}';
        });
      } else {
        setState(() {
          _updateStatus = 'No auto-update available. Use manual download.';
        });
      }
    }
  }

  /// Re-check version requirements and update the displayed info
  Future<void> _checkAgain() async {
    if (_checkingVersion) return;

    setState(() {
      _checkingVersion = true;
      _updateStatus = 'Checking version requirements...';
    });

    try {
      // Re-fetch the minimum version requirements from server
      final result = await VersionCheckService.instance.checkVersion();

      if (mounted) {
        setState(() {
          _minimumVersion = result.minimumVersion;
          _message = result.message;
          _downloadUrl = result.downloadUrl;
          _checkingVersion = false;
        });

        // If no longer blocked, call the original onRetry to launch main app
        if (!result.blocked) {
          _updateStatus = 'Version check passed! Launching app...';
          widget.onRetry?.call();
        } else {
          _updateStatus = 'Still blocked. Minimum version: ${result.minimumVersion}';
          // Also trigger auto-update check for latest version
          final updateInfo = await AutoUpdater.instance.checkForUpdate();
          if (mounted && updateInfo != null) {
            setState(() {
              _latestVersion = updateInfo.version;
              _updateStatus = 'Found latest version: ${updateInfo.version}';
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _checkingVersion = false;
          _updateStatus = 'Check failed: $e';
        });
      }
    }
  }

  Future<void> _openDownloadUrl() async {
    if (_downloadUrl == null || _downloadUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No download URL available. Please contact support.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final uri = Uri.parse(_downloadUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open URL: $_downloadUrl'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadAndInstall() async {
    if (_downloadUrl == null || _downloadUrl!.isEmpty) {
      _openDownloadUrl();
      return;
    }

    if (!Platform.isWindows) {
      _openDownloadUrl();
      return;
    }

    setState(() {
      _downloading = true;
      _downloadProgress = 0;
    });

    try {
      // Use the AutoUpdater to download and install
      final updateInfo = UpdateInfo(
        version: _minimumVersion,
        downloadUrl: _downloadUrl!,
        forceUpdate: true,
      );

      // Start the auto-updater with progress callback
      await AutoUpdater.instance.start(
        onDownloadProgress: (progress) {
          if (mounted) {
            setState(() => _downloadProgress = progress);
          }
        },
        onUpdateError: (error) {
          if (mounted) {
            setState(() => _downloading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error), backgroundColor: Colors.red),
            );
          }
        },
      );

      await AutoUpdater.instance.triggerUpdate(updateInfo);
    } catch (e) {
      if (mounted) {
        setState(() => _downloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _copyUrl() {
    if (_downloadUrl != null && _downloadUrl!.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _downloadUrl!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Download URL copied to clipboard'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasDownloadUrl = _downloadUrl != null && _downloadUrl!.isNotEmpty;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.grey.shade100,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Warning icon
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.system_update,
                        size: 64,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    const Text(
                      'Update Required',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Message
                    Text(
                      _message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Version info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                'Your Version',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white60 : Colors.black45,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.currentVersion,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const Icon(
                            Icons.arrow_forward,
                            color: Colors.grey,
                          ),
                          Column(
                            children: [
                              Text(
                                _latestVersion != null ? 'Latest' : 'Required',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white60 : Colors.black45,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _latestVersion ?? _minimumVersion,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              if (_latestVersion != null && _latestVersion != _minimumVersion)
                                Text(
                                  '(min: $_minimumVersion)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark ? Colors.white38 : Colors.black38,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Auto-update status
                    if (Platform.isWindows && _updateStatus.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _downloading
                              ? Colors.blue.withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_downloading && _downloadProgress == 0)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else if (_downloading)
                              Icon(Icons.downloading, size: 16, color: Colors.blue.shade700)
                            else
                              Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _updateStatus,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _downloading ? Colors.blue.shade700 : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),

                    // Download progress
                    if (_downloading) ...[
                      Column(
                        children: [
                          Text(
                            _latestVersion != null
                                ? 'Downloading v$_latestVersion... ${(_downloadProgress * 100).toInt()}%'
                                : 'Downloading update... ${(_downloadProgress * 100).toInt()}%',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: _downloadProgress > 0 ? _downloadProgress : null,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: const AlwaysStoppedAnimation<Color>(_accent),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'The app will restart automatically after installation.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Update button
                      if (hasDownloadUrl && Platform.isWindows)
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _downloadAndInstall,
                            icon: const Icon(Icons.download, color: Colors.white),
                            label: const Text(
                              'Download & Install Update',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),

                      if (hasDownloadUrl && Platform.isWindows)
                        const SizedBox(height: 12),

                      // Open in browser button (primary on non-Windows)
                      if (hasDownloadUrl)
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: _openDownloadUrl,
                            icon: const Icon(Icons.open_in_new),
                            label: Text(
                              Platform.isWindows
                                  ? 'Open Download Page'
                                  : 'Download Update',
                              style: const TextStyle(fontSize: 16),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _accent,
                              side: const BorderSide(color: _accent),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),

                      if (hasDownloadUrl) ...[
                        const SizedBox(height: 12),
                        // Copy URL button
                        TextButton.icon(
                          onPressed: _copyUrl,
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('Copy Download URL'),
                        ),
                      ],

                      if (!hasDownloadUrl) ...[
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'No download URL available.\nPlease contact your administrator.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ],

                    const SizedBox(height: 24),

                    // Retry button
                    if (widget.onRetry != null)
                      TextButton.icon(
                        onPressed: _checkingVersion ? null : _checkAgain,
                        icon: _checkingVersion
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh, size: 18),
                        label: Text(_checkingVersion ? 'Checking...' : 'Check Again'),
                      ),

                    // Support info
                    const SizedBox(height: 16),
                    Text(
                      'If you continue to experience issues, please contact support.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
