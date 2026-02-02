// File: lib/remote_view_screen.dart
//
// Grid view of screenshots for a specific computer with full-screen preview.

import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../config/api_config.dart';
import '../../app_theme.dart';

class RemoteViewScreen extends StatefulWidget {
  final String computerName;
  final String username;

  const RemoteViewScreen({
    super.key,
    required this.computerName,
    required this.username,
  });

  @override
  State<RemoteViewScreen> createState() => _RemoteViewScreenState();
}

class _ScreenshotInfo {
  final String filename;
  final int timestamp;
  final DateTime datetime;
  final int sizeBytes;
  final int ageSeconds;

  _ScreenshotInfo({
    required this.filename,
    required this.timestamp,
    required this.datetime,
    required this.sizeBytes,
    required this.ageSeconds,
  });

  factory _ScreenshotInfo.fromJson(Map<String, dynamic> json) {
    return _ScreenshotInfo(
      filename: json['filename'] ?? '',
      timestamp: json['timestamp'] ?? 0,
      datetime: DateTime.tryParse(json['datetime'] ?? '') ?? DateTime.now(),
      sizeBytes: json['size_bytes'] ?? 0,
      ageSeconds: json['age_seconds'] ?? 0,
    );
  }
}

class _RemoteViewScreenState extends State<RemoteViewScreen> {
  static const Color _accent = AppColors.accent;

  List<_ScreenshotInfo> _screenshots = [];
  final Map<String, Uint8List> _thumbnailCache = {};
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  // For full-screen preview
  String? _selectedFilename;
  Uint8List? _selectedImage;
  bool _loadingFullImage = false;

  @override
  void initState() {
    super.initState();
    _loadScreenshotList();
    
    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadScreenshotList();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadScreenshotList() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.screenshotGet}?computer=${Uri.encodeComponent(widget.computerName)}&list=1'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List<dynamic> screenshotList = data['screenshots'] ?? [];
          
          setState(() {
            _screenshots = screenshotList
                .map((s) => _ScreenshotInfo.fromJson(s))
                .toList();
            _loading = false;
            _error = null;
          });

          // Load thumbnails for visible items
          _loadThumbnails();
        } else {
          setState(() {
            _error = data['error'] ?? 'Failed to load screenshots';
            _loading = false;
          });
        }
      } else {
        setState(() {
          _error = 'Server error: ${response.statusCode}';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Connection error: $e';
        _loading = false;
      });
    }
  }

  Future<void> _loadThumbnails() async {
    // Load first 12 thumbnails
    for (int i = 0; i < _screenshots.length && i < 12; i++) {
      final screenshot = _screenshots[i];
      if (!_thumbnailCache.containsKey(screenshot.filename)) {
        await _loadThumbnail(screenshot.filename);
      }
    }
  }

  Future<void> _loadThumbnail(String filename) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.screenshotGet}?computer=${Uri.encodeComponent(widget.computerName)}&file=$filename'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['screenshot'] != null) {
          final bytes = base64Decode(data['screenshot']);
          if (mounted) {
            setState(() {
              _thumbnailCache[filename] = bytes;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('[RemoteViewScreen] Thumbnail load error: \$e');
    }
  }

  Future<void> _openFullImage(String filename) async {
    setState(() {
      _selectedFilename = filename;
      _loadingFullImage = true;
    });

    // Check cache first
    if (_thumbnailCache.containsKey(filename)) {
      setState(() {
        _selectedImage = _thumbnailCache[filename];
        _loadingFullImage = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.screenshotGet}?computer=${Uri.encodeComponent(widget.computerName)}&file=$filename'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['screenshot'] != null) {
          final bytes = base64Decode(data['screenshot']);
          if (mounted) {
            setState(() {
              _selectedImage = bytes;
              _thumbnailCache[filename] = bytes;
              _loadingFullImage = false;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingFullImage = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load image: $e')),
        );
      }
    }
  }

  void _closeFullImage() {
    setState(() {
      _selectedFilename = null;
      _selectedImage = null;
    });
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return DateFormat('MMM d, h:mm a').format(dt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.white60 : Colors.black54;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.computerName, style: const TextStyle(fontSize: 16)),
            Text(
              widget.username,
              style: TextStyle(fontSize: 12, color: subtitleColor),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              setState(() => _loading = true);
              _loadScreenshotList();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main grid view
          _buildMainContent(isDark, cardColor, textColor, subtitleColor),
          
          // Full-screen overlay
          if (_selectedFilename != null)
            _buildFullScreenOverlay(isDark),
        ],
      ),
    );
  }

  Widget _buildMainContent(bool isDark, Color cardColor, Color textColor, Color subtitleColor) {
    if (_loading && _screenshots.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _screenshots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: subtitleColor)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => _loading = true);
                _loadScreenshotList();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_screenshots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.screenshot_monitor, size: 64, color: subtitleColor),
            const SizedBox(height: 16),
            Text(
              'No screenshots yet',
              style: TextStyle(fontSize: 18, color: subtitleColor),
            ),
            const SizedBox(height: 8),
            Text(
              'Screenshots will appear here when captured',
              style: TextStyle(color: subtitleColor),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Info bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[100],
          child: Row(
            children: [
              Icon(Icons.photo_library, size: 16, color: subtitleColor),
              const SizedBox(width: 8),
              Text(
                '${_screenshots.length} screenshots',
                style: TextStyle(color: subtitleColor, fontSize: 13),
              ),
              const Spacer(),
              if (_screenshots.isNotEmpty)
                Text(
                  'Latest: ${_formatTimestamp(_screenshots.first.datetime)}',
                  style: TextStyle(color: subtitleColor, fontSize: 13),
                ),
            ],
          ),
        ),

        // Grid
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 16 / 10,
              ),
              itemCount: _screenshots.length,
              itemBuilder: (context, index) {
                final screenshot = _screenshots[index];
                return _buildThumbnailCard(screenshot, isDark, cardColor, subtitleColor, index == 0);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThumbnailCard(
    _ScreenshotInfo screenshot,
    bool isDark,
    Color cardColor,
    Color subtitleColor,
    bool isLatest,
  ) {
    final hasImage = _thumbnailCache.containsKey(screenshot.filename);

    return GestureDetector(
      onTap: () => _openFullImage(screenshot.filename),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isLatest ? _accent : (isDark ? const Color(0xFF3A3A3A) : Colors.grey[300]!),
            width: isLatest ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image or placeholder
              if (hasImage)
                Image.memory(
                  _thumbnailCache[screenshot.filename]!,
                  fit: BoxFit.cover,
                )
              else
                Container(
                  color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[200],
                  child: Center(
                    child: Icon(
                      Icons.image,
                      size: 32,
                      color: subtitleColor,
                    ),
                  ),
                ),

              // Gradient overlay at bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                  child: Text(
                    _formatTimestamp(screenshot.datetime),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              // "LATEST" badge for latest
              if (isLatest)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'LATEST',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // Load thumbnail if not loaded
              if (!hasImage)
                FutureBuilder(
                  future: _loadThumbnail(screenshot.filename),
                  builder: (context, snapshot) => const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullScreenOverlay(bool isDark) {
    final info = _screenshots.firstWhere(
      (s) => s.filename == _selectedFilename,
      orElse: () => _ScreenshotInfo(
        filename: '',
        timestamp: 0,
        datetime: DateTime.now(),
        sizeBytes: 0,
        ageSeconds: 0,
      ),
    );

    return Container(
      color: Colors.black.withValues(alpha: 0.95),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _closeFullImage,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE, MMM d, yyyy').format(info.datetime),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          DateFormat('h:mm:ss a').format(info.datetime),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${(info.sizeBytes / 1024).toStringAsFixed(0)} KB',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Image
            Expanded(
              child: _loadingFullImage
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : _selectedImage != null
                      ? InteractiveViewer(
                          minScale: 0.5,
                          maxScale: 4.0,
                          child: Center(
                            child: Image.memory(
                              _selectedImage!,
                              fit: BoxFit.contain,
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            'Failed to load image',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                          ),
                        ),
            ),

            // Navigation arrows
            if (_screenshots.length > 1)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: Colors.white, size: 32),
                      onPressed: _goToPreviousImage,
                    ),
                    const SizedBox(width: 24),
                    Text(
                      '${_screenshots.indexWhere((s) => s.filename == _selectedFilename) + 1} / ${_screenshots.length}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(width: 24),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, color: Colors.white, size: 32),
                      onPressed: _goToNextImage,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _goToPreviousImage() {
    final currentIndex = _screenshots.indexWhere((s) => s.filename == _selectedFilename);
    if (currentIndex > 0) {
      _openFullImage(_screenshots[currentIndex - 1].filename);
    }
  }

  void _goToNextImage() {
    final currentIndex = _screenshots.indexWhere((s) => s.filename == _selectedFilename);
    if (currentIndex < _screenshots.length - 1) {
      _openFullImage(_screenshots[currentIndex + 1].filename);
    }
  }
}
