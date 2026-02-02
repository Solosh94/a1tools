// app_download_service.dart
// Handles checking latest.json and downloading updates for Windows and Android

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/api_config.dart';

/// Platform-specific update info
class PlatformUpdateInfo {
  final String version;
  final String downloadUrl;
  final String filename;
  final int? sizeBytes;
  final int? versionCode; // Android only

  PlatformUpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.filename,
    this.sizeBytes,
    this.versionCode,
  });

  factory PlatformUpdateInfo.fromJson(Map<String, dynamic> json) {
    return PlatformUpdateInfo(
      version: json['version']?.toString() ?? '',
      downloadUrl: json['download_url']?.toString() ?? '',
      filename: json['filename']?.toString() ?? '',
      sizeBytes: json['size_bytes'] is int ? json['size_bytes'] : null,
      versionCode: json['version_code'] is int ? json['version_code'] : null,
    );
  }

  String get formattedSize {
    if (sizeBytes == null) return '';
    final mb = sizeBytes! / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

/// Result of checking for updates
class UpdateCheckResult {
  final bool updateAvailable;
  final String currentVersion;
  final PlatformUpdateInfo? updateInfo;
  final String? error;

  UpdateCheckResult({
    required this.updateAvailable,
    required this.currentVersion,
    this.updateInfo,
    this.error,
  });
}

/// Service to check and download app updates
class AppDownloadService {
  static String get _latestJsonUrl => ApiConfig.latestVersion;

  /// Check for updates for the specified platform
  static Future<UpdateCheckResult> checkForUpdate(String platform) async {
    try {
      // Get current version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // Fetch latest.json with cache busting
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse('$_latestJsonUrl?_t=$timestamp'),
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return UpdateCheckResult(
          updateAvailable: false,
          currentVersion: currentVersion,
          error: 'Server returned ${response.statusCode}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // Get platform-specific info
      final platformData = data[platform.toLowerCase()];
      if (platformData == null || platformData is! Map<String, dynamic>) {
        // Try legacy format (for backward compatibility with Windows)
        if (platform.toLowerCase() == 'windows' && data['download_url'] != null) {
          final legacyInfo = PlatformUpdateInfo(
            version: data['latest_version']?.toString() ?? '',
            downloadUrl: data['download_url']?.toString() ?? '',
            filename: 'A1-Tools-Setup.exe',
          );

          final isNewer = _isVersionNewer(legacyInfo.version, currentVersion);
          return UpdateCheckResult(
            updateAvailable: isNewer,
            currentVersion: currentVersion,
            updateInfo: legacyInfo,
          );
        }

        return UpdateCheckResult(
          updateAvailable: false,
          currentVersion: currentVersion,
          error: 'No $platform version available',
        );
      }

      final updateInfo = PlatformUpdateInfo.fromJson(platformData);
      final isNewer = _isVersionNewer(updateInfo.version, currentVersion);

      return UpdateCheckResult(
        updateAvailable: isNewer,
        currentVersion: currentVersion,
        updateInfo: updateInfo,
      );
    } catch (e) {
      return UpdateCheckResult(
        updateAvailable: false,
        currentVersion: 'unknown',
        error: e.toString(),
      );
    }
  }

  /// Download and install update for Windows
  static Future<void> downloadAndInstallWindows(
    PlatformUpdateInfo info, {
    void Function(double progress)? onProgress,
    void Function(String status)? onStatus,
    void Function(String error)? onError,
  }) async {
    try {
      onStatus?.call('Preparing download...');

      // Get temp directory
      final tempDir = await getTemporaryDirectory();
      final installerPath = '${tempDir.path}\\${info.filename}';

      // Download the installer
      onStatus?.call('Downloading ${info.formattedSize}...');
      await _downloadFile(
        info.downloadUrl,
        installerPath,
        onProgress: onProgress,
      );

      onStatus?.call('Starting installer...');

      // Create update batch script
      final batchPath = '${tempDir.path}\\a1tools_updater.bat';
      final vbsPath = '${tempDir.path}\\a1tools_updater.vbs';
      final appPath = Platform.resolvedExecutable;

      final batchContent = '''
@echo off
:waitloop
tasklist /FI "IMAGENAME eq a1_tools.exe" 2>NUL | find /I /N "a1_tools.exe">NUL
if "%ERRORLEVEL%"=="0" (
    timeout /t 1 /nobreak >nul
    goto waitloop
)

"$installerPath" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-

timeout /t 2 /nobreak >nul

REM Start the app fully detached using a temporary VBScript
echo Set WshShell = CreateObject("WScript.Shell") > "%TEMP%\\launcher.vbs"
echo WshShell.Run chr(34) ^& "$appPath" ^& chr(34), 1, False >> "%TEMP%\\launcher.vbs"
wscript.exe "%TEMP%\\launcher.vbs"
del "%TEMP%\\launcher.vbs" 2>nul

REM Cleanup
del "$installerPath" 2>nul
(goto) 2>nul & del "%~f0"
''';

      await File(batchPath).writeAsString(batchContent);

      // VBScript to run batch hidden
      final vbsContent = '''
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run chr(34) & "$batchPath" & chr(34), 0, False
''';

      await File(vbsPath).writeAsString(vbsContent);

      // Run updater
      await Process.start(
        'wscript.exe',
        [vbsPath],
        mode: ProcessStartMode.detached,
      );

      // Exit app to allow update
      await Future.delayed(const Duration(milliseconds: 500));
      exit(0);
    } catch (e) {
      onError?.call('Download failed: $e');
    }
  }

  /// Download APK for Android and prompt to install
  static Future<void> downloadAndInstallAndroid(
    PlatformUpdateInfo info, {
    void Function(double progress)? onProgress,
    void Function(String status)? onStatus,
    void Function(String error)? onError,
  }) async {
    try {
      onStatus?.call('Preparing download...');

      // Get downloads directory
      final downloadsDir = await getExternalStorageDirectory();
      if (downloadsDir == null) {
        onError?.call('Cannot access storage');
        return;
      }

      final apkPath = '${downloadsDir.path}/${info.filename}';

      // Download the APK
      onStatus?.call('Downloading ${info.formattedSize}...');
      await _downloadFile(
        info.downloadUrl,
        apkPath,
        onProgress: onProgress,
      );

      onStatus?.call('Opening installer...');

      // Try to open the APK for installation
      // On Android, we need to use a file provider or intent
      final apkUri = Uri.file(apkPath);
      
      // Try using url_launcher to open the APK
      // This may require additional Android configuration for file provider
      if (await canLaunchUrl(apkUri)) {
        await launchUrl(apkUri);
      } else {
        // Fallback: try using shell command on Android
        await Process.run('am', [
          'start',
          '-a', 'android.intent.action.VIEW',
          '-d', 'file://$apkPath',
          '-t', 'application/vnd.android.package-archive',
        ]);
      }
    } catch (e) {
      onError?.call('Download failed: $e');
    }
  }

  /// Open download URL in browser (fallback method)
  static Future<bool> openDownloadUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (e) {
      debugPrint('[AppDownloadService] Error: $e');
      return false;
    }
  }

  /// Download file with progress reporting
  static Future<void> _downloadFile(
    String url,
    String savePath, {
    void Function(double progress)? onProgress,
  }) async {
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
        onProgress?.call(progress);
      }
    }

    await sink.close();
  }

  /// Compare version strings (e.g., "2.5.30" vs "2.5.29")
  static bool _isVersionNewer(String newVersion, String currentVersion) {
    final newParts = newVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final currentParts = currentVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final maxLength = newParts.length > currentParts.length ? newParts.length : currentParts.length;

    for (var i = 0; i < maxLength; i++) {
      final newPart = i < newParts.length ? newParts[i] : 0;
      final currentPart = i < currentParts.length ? currentParts[i] : 0;

      if (newPart > currentPart) return true;
      if (newPart < currentPart) return false;
    }

    return false; // Versions are equal
  }
}
