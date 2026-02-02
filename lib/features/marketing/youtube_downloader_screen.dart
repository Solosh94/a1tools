// YouTube Video Downloader Screen
//
// Allows downloading YouTube videos in various formats and resolutions.
// Uses local yt-dlp binary for Windows desktop.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../../app_theme.dart';
import '../../core/services/dependencies_manager.dart';
import '../../config/api_config.dart';

class YouTubeDownloaderScreen extends StatefulWidget {
  final String username;
  final String role;

  const YouTubeDownloaderScreen({
    required this.username,
    required this.role,
    super.key,
  });

  @override
  State<YouTubeDownloaderScreen> createState() => _YouTubeDownloaderScreenState();
}

/// Download type options
enum _DownloadType {
  regular('Regular', Icons.high_quality, true, 'Video with audio, best quality'),
  videoOnly('Video Only', Icons.videocam, true, 'Video without audio'),
  audioOnly('Audio Only (MP3)', Icons.audiotrack, true, 'Extract audio as MP3');

  final String label;
  final IconData icon;
  final bool requiresFfmpeg; // All options require ffmpeg now
  final String hint;
  const _DownloadType(this.label, this.icon, this.requiresFfmpeg, this.hint);
}

class _YouTubeDownloaderScreenState extends State<YouTubeDownloaderScreen> {
  final _urlController = TextEditingController();
  final _urlFocusNode = FocusNode();

  String _outputFolder = '';
  bool _isLoading = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _statusMessage = '';
  String? _ytDlpPath;
  String? _ffmpegPath;

  // Video info
  String? _videoId;
  String? _videoTitle;
  String? _videoThumbnail;
  String? _videoDuration;
  String? _videoAuthor;
  List<_VideoFormat> _availableFormats = [];
  _VideoFormat? _selectedFormat;

  // Download options - default to regular (video + audio)
  _DownloadType _downloadType = _DownloadType.regular;

  // Process for cancellation
  Process? _currentProcess;

  @override
  void initState() {
    super.initState();
    _initDependencies();
    _setDefaultOutputFolder();
  }

  // Debug log buffer for sending to server
  final StringBuffer _debugLog = StringBuffer();

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocusNode.dispose();
    _currentProcess?.kill();
    super.dispose();
  }

  /// Add a line to the debug log
  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final line = '[$timestamp] $message';
    _debugLog.writeln(line);
    debugPrint(line);
  }

  /// Send debug log to the server for analysis
  Future<void> _sendDebugLog(String context) async {
    try {
      final logContent = _debugLog.toString();
      if (logContent.isEmpty) return;

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/debug_log.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'source': 'youtube_downloader',
          'context': context,
          'username': widget.username,
          'timestamp': DateTime.now().toIso8601String(),
          'log': logContent,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('Debug log sent successfully');
      } else {
        debugPrint('Failed to send debug log: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error sending debug log: $e');
    }
  }

  Future<void> _initDependencies() async {
    // Use DependenciesManager for centralized dependency detection
    final manager = DependenciesManager.instance;
    await manager.initialize();

    if (Platform.isWindows) {
      // Get yt-dlp path from manager
      final ytDlpPath = manager.ytDlpPath;
      if (ytDlpPath != null) {
        setState(() => _ytDlpPath = ytDlpPath);
        debugPrint('yt-dlp found at: $ytDlpPath');
      } else {
        debugPrint('yt-dlp not found');
        if (mounted) {
          setState(() => _statusMessage = 'yt-dlp not found. Please reinstall the app.');
        }
      }

      // Get ffmpeg path from manager
      final ffmpegPath = manager.ffmpegPath;
      if (ffmpegPath != null) {
        setState(() => _ffmpegPath = ffmpegPath);
        debugPrint('ffmpeg found at: $ffmpegPath');
      } else {
        debugPrint('ffmpeg not found. High Quality and MP3 downloads will be disabled.');
        debugPrint('Install ffmpeg via Settings > Dependencies to enable these features.');
      }
    } else {
      // On other platforms, assume yt-dlp and ffmpeg are in PATH
      setState(() {
        _ytDlpPath = 'yt-dlp';
        _ffmpegPath = 'ffmpeg';
      });
    }
  }

  Future<void> _setDefaultOutputFolder() async {
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null && mounted) {
        setState(() => _outputFolder = downloads.path);
      }
    } catch (e) {
      debugPrint('Could not get downloads folder: $e');
    }
  }

  /// Extract video ID from various YouTube URL formats
  String? _extractVideoId(String url) {
    url = url.trim();

    // Standard watch URL: youtube.com/watch?v=VIDEO_ID
    final watchRegex = RegExp(r'[?&]v=([a-zA-Z0-9_-]{11})');
    final watchMatch = watchRegex.firstMatch(url);
    if (watchMatch != null) return watchMatch.group(1);

    // Short URL: youtu.be/VIDEO_ID
    final shortRegex = RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})');
    final shortMatch = shortRegex.firstMatch(url);
    if (shortMatch != null) return shortMatch.group(1);

    // Embed URL: youtube.com/embed/VIDEO_ID
    final embedRegex = RegExp(r'youtube\.com/embed/([a-zA-Z0-9_-]{11})');
    final embedMatch = embedRegex.firstMatch(url);
    if (embedMatch != null) return embedMatch.group(1);

    // Shorts URL: youtube.com/shorts/VIDEO_ID
    final shortsRegex = RegExp(r'youtube\.com/shorts/([a-zA-Z0-9_-]{11})');
    final shortsMatch = shortsRegex.firstMatch(url);
    if (shortsMatch != null) return shortsMatch.group(1);

    // Just the video ID
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(url)) {
      return url;
    }

    return null;
  }

  Future<void> _fetchVideoInfo() async {
    if (_ytDlpPath == null) {
      _showError('yt-dlp not available. Please reinstall the app.');
      return;
    }

    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showError('Please enter a YouTube URL');
      return;
    }

    final videoId = _extractVideoId(url);
    if (videoId == null) {
      _showError('Invalid YouTube URL. Please enter a valid video link.');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Fetching video info...';
      _videoId = videoId;
      _videoTitle = null;
      _videoThumbnail = null;
      _videoDuration = null;
      _videoAuthor = null;
      _availableFormats = [];
      _selectedFormat = null;
    });

    try {
      final videoUrl = 'https://www.youtube.com/watch?v=$videoId';

      // Run yt-dlp to get video info as JSON
      // Note: Don't use runInShell as it has issues with paths containing spaces
      final result = await Process.run(
        _ytDlpPath!,
        ['--dump-json', '--no-download', videoUrl],
      );

      if (result.exitCode != 0) {
        final error = result.stderr.toString();
        if (error.contains('Video unavailable') || error.contains('Private video')) {
          _showError('Video is unavailable or private');
        } else if (error.contains('Sign in')) {
          _showError('This video requires sign-in');
        } else {
          _showError('Failed to fetch video info: ${error.split('\n').first}');
        }
        return;
      }

      final info = jsonDecode(result.stdout.toString());

      // Parse formats
      final formats = <_VideoFormat>[];
      final seenQualities = <String>{};

      for (final format in (info['formats'] as List? ?? [])) {
        // Skip audio-only formats
        if ((format['vcodec'] ?? 'none') == 'none') continue;

        final height = _toInt(format['height']) ?? 0;
        if (height == 0) continue;

        final fps = _toInt(format['fps']) ?? 30;
        final qualityLabel = _getQualityLabel(height, fps);

        // Avoid duplicates
        if (seenQualities.contains(qualityLabel)) continue;
        seenQualities.add(qualityLabel);

        formats.add(_VideoFormat(
          formatId: format['format_id']?.toString(),
          qualityLabel: qualityLabel,
          ext: format['ext']?.toString(),
          height: height,
          width: _toInt(format['width']),
          fps: fps,
          filesize: _toInt(format['filesize']) ?? _toInt(format['filesize_approx']),
          vcodec: _simplifyCodec(format['vcodec']?.toString() ?? ''),
          acodec: _simplifyCodec(format['acodec']?.toString() ?? ''),
          hasAudio: format['acodec'] != null && format['acodec'] != 'none',
          hasVideo: true,
        ));
      }

      // Sort by height descending
      formats.sort((a, b) => (b.height ?? 0).compareTo(a.height ?? 0));

      // Format duration
      final durationSeconds = _toInt(info['duration']) ?? 0;
      final duration = _formatDuration(durationSeconds);

      setState(() {
        _videoTitle = info['title'] ?? 'Unknown';
        _videoAuthor = info['uploader'] ?? info['channel'] ?? 'Unknown';
        _videoThumbnail = info['thumbnail'] ?? 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';
        _videoDuration = duration;
        _availableFormats = formats;
        _selectedFormat = formats.isNotEmpty ? formats.first : null;
        _statusMessage = 'Video info loaded - ${formats.length} formats available';
      });
    } catch (e) {
      _showError('Error fetching video info: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Safely convert dynamic value to int (handles int, double, and string)
  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  String _getQualityLabel(int height, int fps) {
    final fpsLabel = fps > 30 ? ' ${fps}fps' : '';
    if (height >= 2160) return '4K (2160p)$fpsLabel';
    if (height >= 1440) return '2K (1440p)$fpsLabel';
    if (height >= 1080) return '1080p$fpsLabel';
    if (height >= 720) return '720p$fpsLabel';
    if (height >= 480) return '480p';
    if (height >= 360) return '360p';
    if (height >= 240) return '240p';
    return '${height}p';
  }

  String _simplifyCodec(String codec) {
    if (codec.isEmpty || codec == 'none') return '';
    if (codec.contains('avc1')) return 'H.264';
    if (codec.contains('av01')) return 'AV1';
    if (codec.contains('vp9')) return 'VP9';
    if (codec.contains('vp8')) return 'VP8';
    if (codec.contains('mp4a')) return 'AAC';
    if (codec.contains('opus')) return 'Opus';
    return codec;
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '0:${seconds.toString().padLeft(2, '0')}';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _browseOutputFolder() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Download Folder',
    );
    if (result != null) {
      setState(() => _outputFolder = result);
    }
  }

  Future<void> _downloadVideo() async {
    if (_ytDlpPath == null) {
      _showError('yt-dlp not available');
      return;
    }

    // For video downloads, require a format selection
    if (_downloadType != _DownloadType.audioOnly && _selectedFormat == null) {
      _showError('Please select a video format');
      return;
    }

    if (_outputFolder.isEmpty) {
      _showError('Please select an output folder');
      return;
    }

    // Check if ffmpeg is available (required for all download types)
    if (_ffmpegPath == null) {
      _showError(
        'ffmpeg not found. All download types require ffmpeg for merging/conversion.\n'
        'Go to Settings > Dependencies to install ffmpeg.',
      );
      return;
    }

    // Clear debug log for new download
    _debugLog.clear();
    _log('=== Starting YouTube Download ===');
    _log('Video ID: $_videoId');
    _log('Video Title: $_videoTitle');
    _log('Download Type: ${_downloadType.label}');
    _log('yt-dlp Path: $_ytDlpPath');
    _log('ffmpeg Path: $_ffmpegPath');
    _log('Output Folder: $_outputFolder');

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _statusMessage = 'Starting download...';
    });

    try {
      final videoUrl = 'https://www.youtube.com/watch?v=$_videoId';
      final sanitizedTitle = _sanitizeFilename(_videoTitle ?? 'video');

      _log('Sanitized Title: $sanitizedTitle');
      _log('Video URL: $videoUrl');

      // Build yt-dlp arguments based on download type
      final args = <String>[
        '--no-playlist',
        '--progress',
        '--newline', // Better progress parsing
        '--no-check-certificates', // Avoid SSL issues
        '--verbose', // Enable verbose output for debugging
      ];

      // Tell yt-dlp where ffmpeg is located
      if (_ffmpegPath != null) {
        final ffmpegDir = path.dirname(_ffmpegPath!);
        args.addAll(['--ffmpeg-location', ffmpegDir]);
        _log('FFmpeg location: $ffmpegDir');
      }

      final outputTemplate = path.join(_outputFolder, '$sanitizedTitle.%(ext)s');
      args.addAll(['-o', outputTemplate]);
      _log('Output template: $outputTemplate');

      switch (_downloadType) {
        case _DownloadType.regular:
          // Download best video + best audio, merge to mp4 (requires ffmpeg)
          // This gives the highest quality with both video and audio
          args.addAll([
            '-f', 'bestvideo+bestaudio/best',
            '--merge-output-format', 'mp4',
          ]);
          _log('Format: bestvideo+bestaudio/best (merge to mp4)');
          break;

        case _DownloadType.videoOnly:
          // Download best video only (no audio)
          args.addAll([
            '-f', 'bestvideo',
            '--merge-output-format', 'mp4',
          ]);
          _log('Format: bestvideo only (no audio)');
          break;

        case _DownloadType.audioOnly:
          // Extract audio only as MP3
          args.addAll([
            '-x', // Extract audio
            '--audio-format', 'mp3',
            '--audio-quality', '0', // Best quality
          ]);
          _log('Format: audio extraction to mp3');
          break;
      }

      args.add(videoUrl);

      final fullCommand = '$_ytDlpPath ${args.join(' ')}';
      _log('Full command: $fullCommand');

      // Show the command in status for debugging
      if (mounted) {
        setState(() => _statusMessage = 'Starting download...');
      }

      // Start process
      // Note: Don't use runInShell on Windows as it has issues with paths containing spaces
      // Process.start handles paths with spaces correctly when runInShell is false
      _log('Starting yt-dlp process...');
      _currentProcess = await Process.start(
        _ytDlpPath!,
        args,
      );
      _log('Process started with PID: ${_currentProcess!.pid}');

      // Collect output for error analysis
      final stderrBuffer = StringBuffer();
      final stdoutBuffer = StringBuffer();

      // Parse progress from stderr/stdout
      final progressRegex = RegExp(r'(\d+\.?\d*)%');

      _currentProcess!.stdout.transform(utf8.decoder).listen((data) {
        _log('STDOUT: $data');
        stdoutBuffer.write(data);

        // Parse progress percentage
        final match = progressRegex.firstMatch(data);
        if (match != null && mounted) {
          final percent = double.tryParse(match.group(1)!) ?? 0;
          setState(() {
            _downloadProgress = percent / 100;
            _statusMessage = 'Downloading: ${percent.toStringAsFixed(1)}%';
          });
        }

        // Check for merging status
        if (data.contains('Merging') && mounted) {
          setState(() => _statusMessage = 'Merging video and audio...');
        }
        if (data.contains('Converting') && mounted) {
          setState(() => _statusMessage = 'Converting to MP3...');
        }
      });

      _currentProcess!.stderr.transform(utf8.decoder).listen((data) {
        _log('STDERR: $data');
        stderrBuffer.write(data);

        // yt-dlp often outputs progress to stderr
        final match = progressRegex.firstMatch(data);
        if (match != null && mounted) {
          final percent = double.tryParse(match.group(1)!) ?? 0;
          setState(() {
            _downloadProgress = percent / 100;
            _statusMessage = 'Downloading: ${percent.toStringAsFixed(1)}%';
          });
        }
      });

      final exitCode = await _currentProcess!.exitCode;
      _currentProcess = null;
      _log('Process exited with code: $exitCode');

      if (exitCode == 0) {
        _log('Download completed successfully!');
        final downloadTypeLabel = _downloadType == _DownloadType.audioOnly ? 'MP3' : 'video';
        setState(() {
          _downloadProgress = 1.0;
          _statusMessage = 'Download complete!';
        });

        // Send success log
        await _sendDebugLog('download_success');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Downloaded $downloadTypeLabel: ${_videoTitle ?? 'video'}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Open Folder',
                textColor: Colors.white,
                onPressed: () => _openFolder(_outputFolder),
              ),
            ),
          );
        }
      } else {
        // Analyze error for better feedback
        final stderr = stderrBuffer.toString();
        final stdout = stdoutBuffer.toString();
        final allOutput = '$stderr\n$stdout';
        String errorMsg = 'Download failed (exit code: $exitCode)';

        _log('=== DOWNLOAD FAILED ===');
        _log('Exit code: $exitCode');
        _log('STDERR length: ${stderr.length}');
        _log('STDOUT length: ${stdout.length}');

        if (allOutput.contains('ffmpeg') || allOutput.contains('FFmpeg')) {
          errorMsg = 'Download failed: ffmpeg error. Please ensure ffmpeg is installed correctly.';
        } else if (allOutput.contains('Requested format is not available') ||
                   allOutput.contains('requested format not available') ||
                   allOutput.contains('No video formats found')) {
          errorMsg = 'Selected format is not available for this video. Try a different quality.';
        } else if (allOutput.contains('Video unavailable')) {
          errorMsg = 'Video is unavailable or private.';
        } else if (allOutput.contains('Sign in to confirm your age') ||
                   allOutput.contains('age-restricted')) {
          errorMsg = 'This video is age-restricted and cannot be downloaded.';
        } else if (allOutput.contains('Private video') || allOutput.contains('private video')) {
          errorMsg = 'This video is private.';
        } else if (allOutput.contains('copyright') || allOutput.contains('blocked')) {
          errorMsg = 'This video is blocked or has copyright restrictions.';
        } else if (allOutput.contains('HTTP Error 403') || allOutput.contains('Forbidden')) {
          errorMsg = 'Access denied by YouTube. The video may be region-locked or require authentication.';
        } else if (allOutput.contains('Unable to extract') || allOutput.contains('extraction')) {
          errorMsg = 'Failed to extract video data. YouTube may have changed their format.';
        } else if (allOutput.contains('ERROR:')) {
          // Extract the specific error message
          final errorMatch = RegExp(r'ERROR:\s*(.+)').firstMatch(allOutput);
          if (errorMatch != null) {
            final extractedError = errorMatch.group(1)?.trim();
            if (extractedError != null && extractedError.isNotEmpty) {
              // Truncate very long error messages
              errorMsg = extractedError.length > 150
                  ? '${extractedError.substring(0, 150)}...'
                  : extractedError;
            }
          }
        } else if (stderr.isNotEmpty) {
          // Show first line of stderr if nothing else matched
          final firstLine = stderr.split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
          if (firstLine.isNotEmpty && firstLine.length < 200) {
            errorMsg = firstLine;
          }
        }

        _log('Final error message: $errorMsg');

        // Send error log to server for debugging
        await _sendDebugLog('download_error');

        _showError(errorMsg);
      }
    } catch (e) {
      _log('Exception during download: $e');
      await _sendDebugLog('download_exception');
      _showError('Error downloading: $e');
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  void _cancelDownload() {
    _currentProcess?.kill();
    _currentProcess = null;
    setState(() {
      _isDownloading = false;
      _statusMessage = 'Download cancelled';
    });
  }

  String _sanitizeFilename(String filename) {
    return filename
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _openFolder(String folderPath) {
    if (Platform.isWindows) {
      Process.run('explorer', [folderPath]);
    } else if (Platform.isMacOS) {
      Process.run('open', [folderPath]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [folderPath]);
    }
  }

  void _showError(String message) {
    setState(() => _statusMessage = message);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _urlController.text = data!.text!;
      _fetchVideoInfo();
    }
  }

  void _clearAll() {
    setState(() {
      _urlController.clear();
      _videoId = null;
      _videoTitle = null;
      _videoThumbnail = null;
      _videoDuration = null;
      _videoAuthor = null;
      _availableFormats = [];
      _selectedFormat = null;
      _statusMessage = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;

    // Show not supported message on non-Windows platforms
    if (!Platform.isWindows) {
      return Scaffold(
        appBar: AppBar(title: const Text('YouTube Downloader')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.desktop_windows, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'YouTube Downloader is only available on Windows',
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
        title: const Text('YouTube Downloader'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelp,
            tooltip: 'Help',
          ),
        ],
      ),
      body: Row(
        children: [
          // Left Panel - URL Input & Options
          SizedBox(
            width: 400,
            child: _buildOptionsPanel(cardColor),
          ),
          const VerticalDivider(width: 1),
          // Right Panel - Video Preview & Formats
          Expanded(
            child: _buildPreviewPanel(cardColor, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsPanel(Color cardColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // URL Input Section
          const Text(
            'Video URL',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _urlController,
            focusNode: _urlFocusNode,
            decoration: InputDecoration(
              hintText: 'Paste YouTube URL here...',
              prefixIcon: const Icon(Icons.link),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.content_paste),
                    onPressed: _pasteFromClipboard,
                    tooltip: 'Paste from clipboard',
                  ),
                  if (_urlController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _clearAll,
                      tooltip: 'Clear',
                    ),
                ],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onSubmitted: (_) => _fetchVideoInfo(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading || _ytDlpPath == null ? null : _fetchVideoInfo,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: Text(_isLoading ? 'Loading...' : 'Fetch Video Info'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(14),
              ),
            ),
          ),

          const Divider(height: 32),

          // Output Folder
          const Text(
            'Output Folder',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  _outputFolder.isEmpty ? 'Not selected' : _outputFolder,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _outputFolder.isEmpty ? Colors.grey : null,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isDownloading ? null : _browseOutputFolder,
                child: const Text('Browse'),
              ),
            ],
          ),

          const Divider(height: 32),

          // Download Type Selection
          const Text(
            'Download Type',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...List.generate(_DownloadType.values.length, (index) {
            final type = _DownloadType.values[index];
            final isSelected = _downloadType == type;
            // Disable ffmpeg-dependent options if ffmpeg is not available
            final isDisabled = type.requiresFfmpeg && _ffmpegPath == null;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Material(
                color: isSelected
                    ? AppColors.accent.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _isDownloading || isDisabled
                      ? null
                      : () => setState(() => _downloadType = type),
                  child: Opacity(
                    opacity: isDisabled ? 0.5 : 1.0,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                            size: 20,
                            color: isSelected ? AppColors.accent : Colors.grey,
                          ),
                          const SizedBox(width: 10),
                          Icon(type.icon, size: 18, color: isSelected ? AppColors.accent : Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  type.label,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    color: isSelected ? AppColors.accent : null,
                                  ),
                                ),
                                Text(
                                  isDisabled ? 'Install ffmpeg in Settings > Dependencies' : type.hint,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDisabled ? Colors.red.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),

          const Divider(height: 32),

          // Format Selection (only for video downloads)
          if (_availableFormats.isNotEmpty && _downloadType != _DownloadType.audioOnly) ...[
            const Text(
              'Quality',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<_VideoFormat>(
                  value: _selectedFormat,
                  isExpanded: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  items: _availableFormats.map((format) {
                    return DropdownMenuItem(
                      value: format,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(format.qualityLabel ?? 'Unknown'),
                          Text(
                            format.filesize != null
                                ? _formatFileSize(format.filesize!)
                                : '',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: _isDownloading
                      ? null
                      : (v) => setState(() => _selectedFormat = v),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Download Button
          // Show if video loaded
          if (_videoId != null && _availableFormats.isNotEmpty) ...[
            SizedBox(
              width: double.infinity,
              child: _isDownloading
                  ? ElevatedButton.icon(
                      onPressed: _cancelDownload,
                      icon: const Icon(Icons.cancel),
                      label: const Text('Cancel Download'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: _downloadVideo,
                      icon: Icon(_downloadType == _DownloadType.audioOnly
                          ? Icons.audiotrack
                          : Icons.download),
                      label: Text(_downloadType == _DownloadType.audioOnly
                          ? 'Download MP3'
                          : 'Download'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                      ),
                    ),
            ),
          ],

          // Status
          if (_statusMessage.isNotEmpty) ...[
            const SizedBox(height: 16),
            if (_isDownloading) ...[
              LinearProgressIndicator(
                value: _downloadProgress > 0 ? _downloadProgress : null,
              ),
              const SizedBox(height: 8),
            ],
            Text(
              _statusMessage,
              style: TextStyle(
                color: _statusMessage.contains('Error') ||
                        _statusMessage.contains('Invalid') ||
                        _statusMessage.contains('not found') ||
                        _statusMessage.contains('failed')
                    ? Colors.red
                    : _statusMessage.contains('complete')
                        ? Colors.green
                        : Colors.grey.shade600,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewPanel(Color cardColor, bool isDark) {
    if (_videoId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Enter a YouTube URL to preview',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Supported formats: youtube.com/watch, youtu.be, shorts',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          if (_videoThumbnail != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  _videoThumbnail!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.broken_image, size: 48),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Video Title
          if (_videoTitle != null)
            Text(
              _videoTitle!,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          const SizedBox(height: 8),

          // Video Info Row
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (_videoAuthor != null)
                _buildInfoChip(Icons.person, _videoAuthor!),
              if (_videoDuration != null)
                _buildInfoChip(Icons.timer, _videoDuration!),
              _buildInfoChip(Icons.link, _videoId!),
            ],
          ),

          const Divider(height: 32),

          // Available Formats
          const Text(
            'Available Formats',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          if (_availableFormats.isEmpty && !_isLoading)
            Text(
              'No formats available',
              style: TextStyle(color: Colors.grey.shade600),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _availableFormats.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final format = _availableFormats[index];
                final isSelected = format == _selectedFormat;

                return ListTile(
                  selected: isSelected,
                  selectedTileColor: AppColors.accent.withValues(alpha: 0.1),
                  leading: Icon(
                    _getFormatIcon(format),
                    color: isSelected ? AppColors.accent : Colors.grey,
                  ),
                  title: Text(format.qualityLabel ?? 'Unknown'),
                  subtitle: Text(
                    [
                      if (format.ext != null) format.ext!.toUpperCase(),
                      if (format.fps != null) '${format.fps}fps',
                      if (format.vcodec != null && format.vcodec!.isNotEmpty) format.vcodec,
                    ].join(' • '),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  trailing: Text(
                    format.filesize != null
                        ? _formatFileSize(format.filesize!)
                        : '~',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppColors.accent : null,
                    ),
                  ),
                  onTap: () => setState(() => _selectedFormat = format),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  IconData _getFormatIcon(_VideoFormat format) {
    final height = format.height ?? 0;
    if (height >= 2160) return Icons.four_k;
    if (height >= 1440) return Icons.hd;
    if (height >= 1080) return Icons.high_quality;
    if (height >= 720) return Icons.hd;
    return Icons.sd;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('YouTube Downloader Help'),
        content: const SingleChildScrollView(
          child: Text(
            'Download YouTube videos in various formats.\n\n'
            'How to use:\n'
            '1. Paste a YouTube video URL\n'
            '2. Click "Fetch Video Info" to load video details\n'
            '3. Select your download type:\n'
            '   • Best Available: Works instantly (up to 720p)\n'
            '   • High Quality: Up to 4K resolution*\n'
            '   • Audio Only (MP3): Extract audio*\n'
            '4. Select video quality\n'
            '5. Select an output folder\n'
            '6. Click "Download" to save\n\n'
            'Supported URL formats:\n'
            '• youtube.com/watch?v=...\n'
            '• youtu.be/...\n'
            '• youtube.com/shorts/...\n'
            '• youtube.com/embed/...\n\n'
            '*ffmpeg required:\n'
            'High Quality and MP3 require ffmpeg.\n'
            'Download from: ffmpeg.org/download.html\n'
            'Add to your system PATH after installing.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// Video format information
class _VideoFormat {
  final String? formatId;
  final String? qualityLabel;
  final String? ext;
  final int? height;
  final int? width;
  final int? fps;
  final int? filesize;
  final String? vcodec;
  final String? acodec;
  final bool hasAudio;
  final bool hasVideo;

  _VideoFormat({
    this.formatId,
    this.qualityLabel,
    this.ext,
    this.height,
    this.width,
    this.fps,
    this.filesize,
    this.vcodec,
    this.acodec,
    this.hasAudio = false,
    this.hasVideo = true,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _VideoFormat &&
          runtimeType == other.runtimeType &&
          formatId == other.formatId;

  @override
  int get hashCode => formatId.hashCode;
}
