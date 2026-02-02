// Dependencies Manager
//
// Manages optional dependencies like ffmpeg that can be downloaded on-demand
// instead of bundling them with the app installer.

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:archive/archive.dart';

/// Status of a dependency
enum DependencyStatus {
  notInstalled,
  checking,
  downloading,
  extracting,
  installed,
  error,
}

/// Information about a dependency
class DependencyInfo {
  final String name;
  final String description;
  final String? version;
  final String? installedPath;
  final DependencyStatus status;
  final double? downloadProgress;
  final String? errorMessage;

  const DependencyInfo({
    required this.name,
    required this.description,
    this.version,
    this.installedPath,
    this.status = DependencyStatus.notInstalled,
    this.downloadProgress,
    this.errorMessage,
  });

  DependencyInfo copyWith({
    String? name,
    String? description,
    String? version,
    String? installedPath,
    DependencyStatus? status,
    double? downloadProgress,
    String? errorMessage,
  }) {
    return DependencyInfo(
      name: name ?? this.name,
      description: description ?? this.description,
      version: version ?? this.version,
      installedPath: installedPath ?? this.installedPath,
      status: status ?? this.status,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get isInstalled => status == DependencyStatus.installed;
  bool get isWorking => status == DependencyStatus.downloading ||
                        status == DependencyStatus.extracting ||
                        status == DependencyStatus.checking;
}

/// Manages optional dependencies
class DependenciesManager {
  static DependenciesManager? _instance;
  static DependenciesManager get instance => _instance ??= DependenciesManager._();

  DependenciesManager._();

  // Stream controller for status updates
  final _statusController = StreamController<Map<String, DependencyInfo>>.broadcast();
  Stream<Map<String, DependencyInfo>> get statusStream => _statusController.stream;

  // Current status of all dependencies
  final Map<String, DependencyInfo> _dependencies = {};
  Map<String, DependencyInfo> get dependencies => Map.unmodifiable(_dependencies);

  // App's data directory for storing dependencies
  String? _depsDir;

  /// Initialize the manager and check for existing installations
  Future<void> initialize() async {
    if (!Platform.isWindows) return;

    // Get the app's installation directory
    final exePath = Platform.resolvedExecutable;
    final appDir = path.dirname(exePath);
    _depsDir = path.join(appDir, 'deps');

    // Ensure deps directory exists
    final depsDirectory = Directory(_depsDir!);
    if (!await depsDirectory.exists()) {
      await depsDirectory.create(recursive: true);
    }

    // Initialize dependency info
    _dependencies['ffmpeg'] = const DependencyInfo(
      name: 'FFmpeg',
      description: 'Required for high-quality video downloads and MP3 extraction',
      status: DependencyStatus.checking,
    );

    _dependencies['yt-dlp'] = const DependencyInfo(
      name: 'yt-dlp',
      description: 'YouTube video downloader (bundled with app)',
      status: DependencyStatus.checking,
    );

    _notifyListeners();

    // Check for existing installations
    await checkAllDependencies();
  }

  /// Check status of all dependencies
  Future<void> checkAllDependencies() async {
    await _checkFfmpeg();
    await _checkYtDlp();
  }

  /// Check if ffmpeg is installed
  Future<void> _checkFfmpeg() async {
    _updateDependency('ffmpeg', status: DependencyStatus.checking);

    String? installedPath;
    String? version;

    // Check in deps folder first
    if (_depsDir != null) {
      final depsPath = path.join(_depsDir!, 'ffmpeg.exe');
      if (await File(depsPath).exists()) {
        installedPath = depsPath;
      }
    }

    // Check in app directory
    if (installedPath == null) {
      final exePath = Platform.resolvedExecutable;
      final appDir = path.dirname(exePath);
      final appPath = path.join(appDir, 'ffmpeg.exe');
      if (await File(appPath).exists()) {
        installedPath = appPath;
      }
    }

    // Check in PATH
    if (installedPath == null) {
      try {
        final result = await Process.run('where', ['ffmpeg'], runInShell: true);
        if (result.exitCode == 0) {
          installedPath = result.stdout.toString().trim().split('\n').first;
        }
      } catch (e) {
        debugPrint('Error checking ffmpeg in PATH: $e');
      }
    }

    // Get version if installed
    if (installedPath != null) {
      try {
        // Don't use runInShell to avoid issues with paths containing spaces
        final result = await Process.run(
          installedPath,
          ['-version'],
        );
        if (result.exitCode == 0) {
          final versionMatch = RegExp(r'ffmpeg version (\S+)').firstMatch(result.stdout.toString());
          version = versionMatch?.group(1);
        }
      } catch (e) {
        debugPrint('Error getting ffmpeg version: $e');
      }
    }

    _updateDependency(
      'ffmpeg',
      status: installedPath != null ? DependencyStatus.installed : DependencyStatus.notInstalled,
      installedPath: installedPath,
      version: version,
    );
  }

  /// Check if yt-dlp is installed
  Future<void> _checkYtDlp() async {
    _updateDependency('yt-dlp', status: DependencyStatus.checking);

    String? installedPath;
    String? version;

    // Check in app directory first
    final exePath = Platform.resolvedExecutable;
    final appDir = path.dirname(exePath);
    final appPath = path.join(appDir, 'yt-dlp.exe');
    if (await File(appPath).exists()) {
      installedPath = appPath;
    }

    // Check in deps folder
    if (installedPath == null && _depsDir != null) {
      final depsPath = path.join(_depsDir!, 'yt-dlp.exe');
      if (await File(depsPath).exists()) {
        installedPath = depsPath;
      }
    }

    // Check in PATH
    if (installedPath == null) {
      try {
        final result = await Process.run('where', ['yt-dlp'], runInShell: true);
        if (result.exitCode == 0) {
          installedPath = result.stdout.toString().trim().split('\n').first;
        }
      } catch (e) {
        debugPrint('Error checking yt-dlp in PATH: $e');
      }
    }

    // Get version if installed
    if (installedPath != null) {
      try {
        // Don't use runInShell to avoid issues with paths containing spaces
        final result = await Process.run(
          installedPath,
          ['--version'],
        );
        if (result.exitCode == 0) {
          version = result.stdout.toString().trim();
        }
      } catch (e) {
        debugPrint('Error getting yt-dlp version: $e');
      }
    }

    _updateDependency(
      'yt-dlp',
      status: installedPath != null ? DependencyStatus.installed : DependencyStatus.notInstalled,
      installedPath: installedPath,
      version: version,
    );
  }

  /// Download and install ffmpeg
  Future<bool> installFfmpeg({void Function(double progress)? onProgress}) async {
    if (!Platform.isWindows || _depsDir == null) return false;

    _updateDependency('ffmpeg', status: DependencyStatus.downloading, downloadProgress: 0);

    try {
      // FFmpeg download URL (using gyan.dev builds which are well-maintained)
      // Using essentials build which is smaller (~80MB) but has all common codecs
      const downloadUrl = 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip';

      final response = await http.Client().send(
        http.Request('GET', Uri.parse(downloadUrl)),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to download ffmpeg: HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      final bytes = <int>[];
      var downloadedBytes = 0;

      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        downloadedBytes += chunk.length;

        final progress = contentLength > 0 ? downloadedBytes / contentLength : 0.0;
        _updateDependency('ffmpeg', downloadProgress: progress);
        onProgress?.call(progress);
      }

      _updateDependency('ffmpeg', status: DependencyStatus.extracting);

      // Extract the zip file
      final archive = ZipDecoder().decodeBytes(bytes);

      // Find ffmpeg.exe in the archive
      String? ffmpegEntryPath;
      for (final file in archive) {
        if (file.name.endsWith('ffmpeg.exe') && !file.isFile == false) {
          ffmpegEntryPath = file.name;
          break;
        }
      }

      if (ffmpegEntryPath == null) {
        throw Exception('ffmpeg.exe not found in archive');
      }

      // Extract ffmpeg.exe to deps folder
      final ffmpegEntry = archive.findFile(ffmpegEntryPath);
      if (ffmpegEntry != null) {
        final outputPath = path.join(_depsDir!, 'ffmpeg.exe');
        final outputFile = File(outputPath);
        await outputFile.writeAsBytes(ffmpegEntry.content as List<int>);
        debugPrint('FFmpeg extracted to: $outputPath');
      }

      // Also extract ffprobe.exe if present (useful for some operations)
      for (final file in archive) {
        if (file.name.endsWith('ffprobe.exe') && file.isFile) {
          final outputPath = path.join(_depsDir!, 'ffprobe.exe');
          final outputFile = File(outputPath);
          await outputFile.writeAsBytes(file.content as List<int>);
          debugPrint('FFprobe extracted to: $outputPath');
          break;
        }
      }

      // Verify installation
      await _checkFfmpeg();

      return _dependencies['ffmpeg']?.isInstalled ?? false;
    } catch (e) {
      debugPrint('Error installing ffmpeg: $e');
      _updateDependency(
        'ffmpeg',
        status: DependencyStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// Get the path to ffmpeg (if installed)
  String? get ffmpegPath => _dependencies['ffmpeg']?.installedPath;

  /// Get the path to yt-dlp (if installed)
  String? get ytDlpPath => _dependencies['yt-dlp']?.installedPath;

  /// Check if ffmpeg is available
  bool get isFfmpegInstalled => _dependencies['ffmpeg']?.isInstalled ?? false;

  /// Check if yt-dlp is available
  bool get isYtDlpInstalled => _dependencies['yt-dlp']?.isInstalled ?? false;

  /// Update yt-dlp to the latest version
  Future<bool> updateYtDlp() async {
    if (!Platform.isWindows) return false;

    final currentPath = ytDlpPath;
    if (currentPath == null) return false;

    _updateDependency('yt-dlp', status: DependencyStatus.downloading, downloadProgress: 0);

    try {
      // Download latest yt-dlp from GitHub releases
      const downloadUrl = 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe';

      final response = await http.Client().send(
        http.Request('GET', Uri.parse(downloadUrl)),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to download yt-dlp: HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      final bytes = <int>[];
      var downloadedBytes = 0;

      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        downloadedBytes += chunk.length;

        final progress = contentLength > 0 ? downloadedBytes / contentLength : 0.0;
        _updateDependency('yt-dlp', downloadProgress: progress);
      }

      // Determine where to save (prefer deps folder, fall back to app folder)
      String outputPath;
      if (_depsDir != null) {
        outputPath = path.join(_depsDir!, 'yt-dlp.exe');
      } else {
        final exePath = Platform.resolvedExecutable;
        final appDir = path.dirname(exePath);
        outputPath = path.join(appDir, 'yt-dlp.exe');
      }

      // Write the new executable
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(bytes);
      debugPrint('yt-dlp updated at: $outputPath');

      // Verify installation
      await _checkYtDlp();

      return _dependencies['yt-dlp']?.isInstalled ?? false;
    } catch (e) {
      debugPrint('Error updating yt-dlp: $e');
      _updateDependency(
        'yt-dlp',
        status: DependencyStatus.error,
        errorMessage: e.toString(),
      );
      // Revert to checking current status
      await _checkYtDlp();
      return false;
    }
  }

  void _updateDependency(
    String name, {
    DependencyStatus? status,
    String? installedPath,
    String? version,
    double? downloadProgress,
    String? errorMessage,
  }) {
    final current = _dependencies[name];
    if (current == null) return;

    _dependencies[name] = current.copyWith(
      status: status,
      installedPath: installedPath,
      version: version,
      downloadProgress: downloadProgress,
      errorMessage: errorMessage,
    );
    _notifyListeners();
  }

  void _notifyListeners() {
    _statusController.add(Map.unmodifiable(_dependencies));
  }

  void dispose() {
    _statusController.close();
  }
}
