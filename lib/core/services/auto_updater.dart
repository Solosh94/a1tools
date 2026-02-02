import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../config/api_config.dart';

/// Auto-updater service for Windows
/// Checks for updates periodically and installs them silently
class AutoUpdater {
  static String get _updateApiUrl => ApiConfig.appUpdate;
  static const Duration _checkInterval = Duration(minutes: 1);
  
  static AutoUpdater? _instance;
  static AutoUpdater get instance => _instance ??= AutoUpdater._();
  
  AutoUpdater._();
  
  Timer? _checkTimer;
  bool _isUpdating = false;
  bool _initialized = false;
  String _currentVersion = '0.0.0';
  VoidCallback? _onUpdateStarted;
  void Function(double progress)? _onDownloadProgress;
  void Function(String error)? _onUpdateError;
  
  /// Current app version (read from pubspec.yaml)
  String get currentVersion => _currentVersion;
  
  /// Initialize and get version from package info
  Future<void> _initVersion() async {
    if (_initialized) return;
    
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _currentVersion = packageInfo.version;
      _initialized = true;
      debugPrint('[AutoUpdater] Version from pubspec: $_currentVersion');
    } catch (e) {
      debugPrint('[AutoUpdater] Failed to get package info: $e');
      _currentVersion = '0.0.0';
    }
  }
  
  /// Start the auto-updater (call this on app startup)
  Future<void> start({
    VoidCallback? onUpdateStarted,
    void Function(double progress)? onDownloadProgress,
    void Function(String error)? onUpdateError,
  }) async {
    _onUpdateStarted = onUpdateStarted;
    _onDownloadProgress = onDownloadProgress;
    _onUpdateError = onUpdateError;
    
    // Get version from pubspec.yaml
    await _initVersion();
    
    // Check immediately on start
    debugPrint('[AutoUpdater] Starting update check (current version: $_currentVersion)');
    checkForUpdate();
    
    // Then check periodically
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(_checkInterval, (_) {
      debugPrint('[AutoUpdater] Periodic check triggered');
      checkForUpdate();
    });
    
    debugPrint('[AutoUpdater] Started - checking every ${_checkInterval.inMinutes} minute(s)');
  }
  
  /// Stop the auto-updater
  void stop() {
    _checkTimer?.cancel();
    _checkTimer = null;
    debugPrint('[AutoUpdater] Stopped');
  }
  
  /// Check for updates
  Future<UpdateInfo?> checkForUpdate() async {
    if (_isUpdating) {
      debugPrint('[AutoUpdater] Already updating, skipping check');
      return null;
    }
    
    // Make sure we have the version
    if (!_initialized) {
      await _initVersion();
    }
    
    try {
      // Add timestamp to bust cache
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = '$_updateApiUrl?action=check&version=$_currentVersion&_t=$timestamp';
      
      debugPrint('[AutoUpdater] Checking: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      ).timeout(const Duration(seconds: 30));
      
      debugPrint('[AutoUpdater] Response status: ${response.statusCode}');
      debugPrint('[AutoUpdater] Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['update_available'] == true) {
          final updateInfo = UpdateInfo(
            version: data['version'],
            downloadUrl: data['download_url'],
            forceUpdate: data['force_update'] ?? true,
            releaseNotes: data['release_notes'],
          );
          
          debugPrint('[AutoUpdater] âœ“ Update available: ${updateInfo.version} (force: ${updateInfo.forceUpdate})');
          debugPrint('[AutoUpdater] Download URL: ${updateInfo.downloadUrl}');
          
          // Auto-install if forced
          if (updateInfo.forceUpdate) {
            debugPrint('[AutoUpdater] Force update enabled, starting download...');
            _performUpdate(updateInfo);
          }
          
          return updateInfo;
        } else {
          debugPrint('[AutoUpdater] No update available (current: $_currentVersion)');
        }
      } else {
        debugPrint('[AutoUpdater] HTTP Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e, stackTrace) {
      debugPrint('[AutoUpdater] Check failed: $e');
      debugPrint('[AutoUpdater] Stack: $stackTrace');
    }
    
    return null;
  }
  
  /// Manually trigger update
  Future<void> triggerUpdate(UpdateInfo updateInfo) async {
    await _performUpdate(updateInfo);
  }
  
  /// Perform the update
  Future<void> _performUpdate(UpdateInfo updateInfo) async {
    if (_isUpdating) return;
    _isUpdating = true;

    _onUpdateStarted?.call();
    debugPrint('[AutoUpdater] Starting update to ${updateInfo.version}');

    try {
      // Use AppData\Local\A1Tools\Updates instead of Temp to avoid Windows Defender flags
      // The Temp folder triggers DefenseEvasion detection due to suspicious download+execute pattern
      final appDataDir = await getApplicationSupportDirectory();
      final updateDir = Directory('${appDataDir.path}\\Updates');
      if (!await updateDir.exists()) {
        await updateDir.create(recursive: true);
      }
      final installerPath = '${updateDir.path}\\a1tools_update_${updateInfo.version}.exe';

      // Download the installer
      debugPrint('[AutoUpdater] Downloading from ${updateInfo.downloadUrl}');
      await _downloadFile(updateInfo.downloadUrl, installerPath);

      debugPrint('[AutoUpdater] Running installer directly...');

      // Create update lock file BEFORE starting installer
      // This signals to the watchdog and crash recovery that an update is in progress
      await _createUpdateLockFile(updateInfo.version);

      // Run the Inno Setup installer directly with flags that handle everything:
      // /VERYSILENT - No UI at all
      // /SUPPRESSMSGBOXES - Suppress message boxes
      // /NORESTART - Don't restart computer
      // /CLOSEAPPLICATIONS - Let Inno Setup close this app gracefully
      // /RESTARTAPPLICATIONS - Restart the app after install
      // /SP- - Disable "This will install..." prompt
      await Process.start(
        installerPath,
        ['/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/CLOSEAPPLICATIONS', '/RESTARTAPPLICATIONS', '/SP-'],
        mode: ProcessStartMode.detached,
      );

      // Give the installer a moment to start, then exit
      debugPrint('[AutoUpdater] Exiting app for update...');
      await Future.delayed(const Duration(seconds: 1));
      exit(0);

    } catch (e) {
      _isUpdating = false;
      // Remove lock file on failure
      await _removeUpdateLockFile();
      final error = 'Update failed: $e';
      debugPrint('[AutoUpdater] $error');
      _onUpdateError?.call(error);
    }
  }

  /// Create update lock file to signal update in progress
  /// This prevents the watchdog and crash recovery from restarting the app during updates
  Future<void> _createUpdateLockFile(String version) async {
    try {
      final appDataDir = await getApplicationSupportDirectory();
      final lockFile = File('${appDataDir.path}\\.update_in_progress');

      final lockData = jsonEncode({
        'started_at': DateTime.now().toIso8601String(),
        'version': version,
        'pid': pid,
      });

      await lockFile.writeAsString(lockData);
      debugPrint('[AutoUpdater] Created update lock file');
    } catch (e) {
      debugPrint('[AutoUpdater] Failed to create update lock file: $e');
      // Continue anyway - better to risk a restart than fail the update
    }
  }

  /// Remove the update lock file
  Future<void> _removeUpdateLockFile() async {
    try {
      final appDataDir = await getApplicationSupportDirectory();
      final lockFile = File('${appDataDir.path}\\.update_in_progress');

      if (await lockFile.exists()) {
        await lockFile.delete();
        debugPrint('[AutoUpdater] Removed update lock file');
      }
    } catch (e) {
      debugPrint('[AutoUpdater] Failed to remove update lock file: $e');
    }
  }
  
  /// Download file with progress
  Future<void> _downloadFile(String url, String savePath) async {
    final request = http.Request('GET', Uri.parse(url));
    final response = await http.Client().send(request);
    
    final contentLength = response.contentLength ?? 0;
    int downloadedBytes = 0;
    
    final file = File(savePath);
    final sink = file.openWrite();
    
    await for (final chunk in response.stream) {
      sink.add(chunk);
      downloadedBytes += chunk.length;
      
      if (contentLength > 0) {
        final progress = downloadedBytes / contentLength;
        _onDownloadProgress?.call(progress);
      }
    }
    
    await sink.close();
    debugPrint('[AutoUpdater] Download complete: $savePath');
  }
}

/// Update information
class UpdateInfo {
  final String version;
  final String downloadUrl;
  final bool forceUpdate;
  final String? releaseNotes;
  
  UpdateInfo({
    required this.version,
    required this.downloadUrl,
    this.forceUpdate = true,
    this.releaseNotes,
  });
}

/// Widget to show update progress overlay
class UpdateOverlay extends StatefulWidget {
  final Widget child;
  
  const UpdateOverlay({super.key, required this.child});
  
  @override
  State<UpdateOverlay> createState() => _UpdateOverlayState();
}

class _UpdateOverlayState extends State<UpdateOverlay> {
  bool _showOverlay = false;
  double _progress = 0;
  String _status = 'Checking for updates...';
  
  @override
  void initState() {
    super.initState();
    _initAutoUpdater();
  }
  
  Future<void> _initAutoUpdater() async {
    // Start auto-updater with callbacks
    await AutoUpdater.instance.start(
      onUpdateStarted: () {
        if (mounted) {
          setState(() {
            _showOverlay = true;
            _status = 'Update found! Downloading...';
          });
        }
      },
      onDownloadProgress: (progress) {
        if (mounted) {
          setState(() {
            _progress = progress;
            _status = 'Downloading update... ${(progress * 100).toInt()}%';
          });
        }
      },
      onUpdateError: (error) {
        if (mounted) {
          setState(() {
            _showOverlay = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red),
          );
        }
      },
    );
  }
  
  @override
  void dispose() {
    AutoUpdater.instance.stop();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showOverlay)
          Container(
            color: Colors.black87,
            child: Center(
              child: Card(
                margin: const EdgeInsets.all(32),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.system_update,
                        size: 64,
                        color: Color(0xFFF49320),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Installing Update',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _status,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 300,
                        child: LinearProgressIndicator(
                          value: _progress > 0 ? _progress : null,
                          backgroundColor: Colors.grey[300],
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFF49320),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Please wait, the app will restart automatically.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
