// Remote Monitoring Viewer Screen
// 
// Admin interface for:
// - Viewing screenshot history from monitored computers
// - Live screen streaming
// - Remote control (mouse/keyboard)
// 
// All communication goes through the server via HTTPS.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../app_theme.dart';
import '../../config/api_config.dart';

class RemoteMonitoringViewer extends StatefulWidget {
  final String computerName;
  final String username;
  final String viewerUsername; // The admin viewing
  
  const RemoteMonitoringViewer({
    super.key,
    required this.computerName,
    required this.username,
    required this.viewerUsername,
  });

  @override
  State<RemoteMonitoringViewer> createState() => _RemoteMonitoringViewerState();
}

class _RemoteMonitoringViewerState extends State<RemoteMonitoringViewer> with SingleTickerProviderStateMixin {
  static const Color _accent = AppColors.accent;
  
  late TabController _tabController;
  
  // Screenshot history
  List<_ScreenshotInfo> _screenshots = [];
  bool _loadingScreenshots = true;
  String? _screenshotError;
  Timer? _screenshotRefreshTimer;
  
  // Selected screenshot for preview
  _ScreenshotInfo? _selectedScreenshot;
  Uint8List? _selectedImageData;
  bool _loadingSelectedImage = false;
  
  // Live streaming
  bool _isStreaming = false;
  bool _streamRequested = false;
  Uint8List? _streamFrame;
  int _lastFrameTimestamp = 0;
  Timer? _streamPollTimer;
  int _streamFps = 2;
  int _streamQuality = 50;
  double _actualFps = 0;
  DateTime? _lastFrameTime;
  DateTime? _streamStartTime; // Track when stream was requested
  // ignore: unused_field
  int _connectionRetries = 0;
  static const int _maxConnectionWaitSeconds = 30; // Wait up to 30 seconds for first frame
  String? _streamStatus; // Status message to show user
  
  // Remote control
  bool _controlEnabled = false;
  final FocusNode _keyboardFocusNode = FocusNode();
  int? _targetScreenWidth;
  int? _targetScreenHeight;

  // For tracking actual displayed image size
  final GlobalKey _imageKey = GlobalKey();
  Offset? _localCursorPosition; // Track cursor position for overlay

  // Mouse move throttling
  DateTime? _lastMouseMoveTime;
  static const Duration _mouseMoveThrottle = Duration(milliseconds: 50);
  
  // Computer status
  bool _isOnline = false;
  String? _lastHeartbeat;

  // Audio streaming
  bool _audioEnabled = false;
  bool _audioRequested = false;
  Timer? _audioPollTimer;
  int _lastAudioTimestamp = 0;
  bool _isPlayingAudio = false;
  AudioPlayer? _audioPlayer;
  String? _tempAudioPath;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    
    _loadScreenshots();
    _loadComputerStatus();
    
    // Auto-refresh screenshots every 30 seconds
    _screenshotRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadScreenshots(),
    );
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _screenshotRefreshTimer?.cancel();
    _streamPollTimer?.cancel();
    _audioPollTimer?.cancel();
    _stopStream();
    _stopAudio();
    _audioPlayer?.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }
  
  void _onTabChanged() {
    // Stop streaming when leaving live tab
    if (_tabController.index != 1 && _isStreaming) {
      _stopStream();
    }
  }
  
  Future<void> _loadComputerStatus() async {
    debugPrint('[RemoteViewer] Loading status for ${widget.computerName}...');
    try {
      final url = '${ApiConfig.remoteMonitoring}?action=get_status&computer=${Uri.encodeComponent(widget.computerName)}';
      debugPrint('[RemoteViewer] Status URL: $url');
      
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      
      debugPrint('[RemoteViewer] Status response: ${response.statusCode}');
      debugPrint('[RemoteViewer] Status body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && mounted) {
          final status = data['status'];
          debugPrint('[RemoteViewer] Status parsed - online: ${status['is_online']}, screen: ${status['screen_width']}x${status['screen_height']}');
          setState(() {
            _isOnline = status['is_online'] == true || status['is_online'] == 1;
            _lastHeartbeat = status['last_heartbeat'];
            _targetScreenWidth = status['screen_width'];
            _targetScreenHeight = status['screen_height'];
          });
        } else {
          debugPrint('[RemoteViewer] Status error: ${data['error']}');
        }
      }
    } catch (e, stack) {
      debugPrint('[RemoteViewer] Status load error: $e');
      debugPrint('[RemoteViewer] Stack: $stack');
    }
  }
  
  Future<void> _loadScreenshots() async {
    debugPrint('[RemoteViewer] Loading screenshots for ${widget.computerName}...');
    try {
      final url = '${ApiConfig.remoteMonitoring}?action=list_screenshots&computer=${Uri.encodeComponent(widget.computerName)}&limit=100';
      debugPrint('[RemoteViewer] Screenshots URL: $url');
      
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      
      debugPrint('[RemoteViewer] Screenshots response: ${response.statusCode}');
      debugPrint('[RemoteViewer] Screenshots body: ${response.body.substring(0, response.body.length.clamp(0, 500))}...');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && mounted) {
          final List<dynamic> list = data['screenshots'] ?? [];
          debugPrint('[RemoteViewer] Found ${list.length} screenshots');
          setState(() {
            _screenshots = list.map((s) => _ScreenshotInfo.fromJson(s)).toList();
            _loadingScreenshots = false;
            _screenshotError = null;
          });
        } else {
          debugPrint('[RemoteViewer] Screenshots error: ${data['error']}');
          setState(() {
            _loadingScreenshots = false;
            _screenshotError = data['error'] ?? 'Unknown error';
          });
        }
      } else {
        debugPrint('[RemoteViewer] HTTP error: ${response.statusCode}');
        setState(() {
          _loadingScreenshots = false;
          _screenshotError = 'HTTP ${response.statusCode}';
        });
      }
    } catch (e, stack) {
      debugPrint('[RemoteViewer] Screenshots error: $e');
      debugPrint('[RemoteViewer] Stack: $stack');
      if (mounted) {
        setState(() {
          _loadingScreenshots = false;
          _screenshotError = 'Failed to load screenshots: $e';
        });
      }
    }
  }
  
  Future<void> _loadScreenshotImage(_ScreenshotInfo screenshot) async {
    debugPrint('[RemoteViewer] Loading screenshot image: ${screenshot.url}');
    setState(() {
      _selectedScreenshot = screenshot;
      _loadingSelectedImage = true;
    });
    
    try {
      final response = await http.get(Uri.parse(screenshot.url)).timeout(const Duration(seconds: 30));
      
      debugPrint('[RemoteViewer] Image response status: ${response.statusCode}');
      debugPrint('[RemoteViewer] Image content-type: ${response.headers['content-type']}');
      debugPrint('[RemoteViewer] Image size: ${response.bodyBytes.length} bytes');
      
      if (response.statusCode == 200 && mounted) {
        // Check if response is actually an image (not JSON error)
        final contentType = response.headers['content-type'] ?? '';
        if (contentType.contains('image')) {
          setState(() {
            _selectedImageData = response.bodyBytes;
            _loadingSelectedImage = false;
          });
        } else {
          debugPrint('[RemoteViewer] Image error - got non-image response: ${response.body.substring(0, (response.body.length).clamp(0, 500))}');
          setState(() => _loadingSelectedImage = false);
          _showError('Failed to load image: server returned $contentType');
        }
      } else {
        debugPrint('[RemoteViewer] Image error response: ${response.body}');
        setState(() => _loadingSelectedImage = false);
        _showError('Failed to load image: HTTP ${response.statusCode}');
      }
    } catch (e, stack) {
      debugPrint('[RemoteViewer] Image load exception: $e');
      debugPrint('[RemoteViewer] Stack: $stack');
      if (mounted) {
        setState(() {
          _loadingSelectedImage = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  // ===========================================================================
  // LIVE STREAMING
  // ===========================================================================
  
  Future<void> _startStream() async {
    if (_streamRequested) return;

    debugPrint('[RemoteViewer] Starting stream for ${widget.computerName}...');
    setState(() {
      _streamRequested = true;
      _streamStartTime = DateTime.now();
      _connectionRetries = 0;
      _streamStatus = 'Requesting stream...';
      _streamFrame = null;
      _lastFrameTimestamp = 0;
    });

    try {
      const url = '${ApiConfig.remoteMonitoring}?action=start_stream';
      debugPrint('[RemoteViewer] Start stream URL: $url');

      final response = await http.post(
        Uri.parse(url),
        body: {
          'computer_name': widget.computerName,
          'requested_by': widget.viewerUsername,
          'fps': _streamFps.toString(),
          'quality': _streamQuality.toString(),
        },
      ).timeout(const Duration(seconds: 10));

      debugPrint('[RemoteViewer] Start stream response: ${response.statusCode}');
      debugPrint('[RemoteViewer] Start stream body: ${response.body}');

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('[RemoteViewer] Stream started successfully');
          setState(() {
            _isStreaming = true;
            _streamStatus = 'Waiting for ${widget.computerName} to respond...';
          });
          _startStreamPolling();
        } else {
          debugPrint('[RemoteViewer] Stream start failed: ${data['error']}');
          setState(() {
            _streamRequested = false;
            _streamStatus = null;
          });
          _showError('Failed to start stream: ${data['error']}');
        }
      }
    } catch (e, stack) {
      debugPrint('[RemoteViewer] Stream start exception: $e');
      debugPrint('[RemoteViewer] Stack: $stack');
      if (mounted) {
        setState(() {
          _streamRequested = false;
          _streamStatus = null;
        });
        _showError('Stream request failed: $e');
      }
    }
  }
  
  Future<void> _stopStream() async {
    _streamPollTimer?.cancel();
    _streamPollTimer = null;

    if (!_streamRequested) return;

    try {
      await http.post(
        Uri.parse('${ApiConfig.remoteMonitoring}?action=stop_stream'),
        body: {'computer_name': widget.computerName},
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[RemoteMonitoringViewer] Error stopping stream: $e');
    }

    if (mounted) {
      setState(() {
        _isStreaming = false;
        _streamRequested = false;
        _streamFrame = null;
        _streamStatus = null;
        _streamStartTime = null;
        _connectionRetries = 0;
      });
    }
  }

  // ===========================================================================
  // AUDIO STREAMING
  // ===========================================================================

  Future<void> _startAudio() async {
    if (_audioRequested) return;

    debugPrint('[RemoteViewer] Starting audio for ${widget.computerName}...');

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.remoteMonitoring}?action=start_audio'),
        body: {
          'computer_name': widget.computerName,
          'requested_by': widget.viewerUsername,
        },
      ).timeout(const Duration(seconds: 10));

      debugPrint('[RemoteViewer] Start audio response: ${response.statusCode}');
      debugPrint('[RemoteViewer] Start audio body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && mounted) {
          setState(() {
            _audioRequested = true;
            _audioEnabled = true;
          });
          _startAudioPolling();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Audio streaming requested - waiting for client...'), backgroundColor: Colors.green),
          );
        } else if (mounted) {
          final error = data['error'] ?? 'Unknown error';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to start audio: $error'), backgroundColor: Colors.red),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start audio: HTTP ${response.statusCode}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      debugPrint('[RemoteViewer] Start audio error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Audio error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _stopAudio() async {
    _audioPollTimer?.cancel();
    _audioPollTimer = null;

    // Stop audio playback
    try {
      await _audioPlayer?.stop();
    } catch (e) {
  debugPrint('[RemoteMonitoringViewer] Error: $e');
}

    if (!_audioRequested) return;

    try {
      await http.post(
        Uri.parse('${ApiConfig.remoteMonitoring}?action=stop_audio'),
        body: {'computer_name': widget.computerName},
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
  debugPrint('[RemoteMonitoringViewer] Error: $e');
}

    if (mounted) {
      setState(() {
        _audioEnabled = false;
        _audioRequested = false;
        _isPlayingAudio = false;
      });
    }
  }

  void _startAudioPolling() {
    _audioPollTimer?.cancel();

    // Poll for audio every 500ms
    _audioPollTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _pollAudioFrame(),
    );
  }

  Future<void> _pollAudioFrame() async {
    if (!_audioEnabled) return;

    try {
      final url = '${ApiConfig.remoteMonitoring}?action=get_audio&computer=${Uri.encodeComponent(widget.computerName)}&since=$_lastAudioTimestamp';

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);

        if (data['success'] == true && data['new_audio'] == true) {
          final audioBase64 = data['audio'] as String;
          final timestamp = data['timestamp'] as int;

          if (timestamp > _lastAudioTimestamp) {
            final audioData = base64Decode(audioBase64);

            setState(() {
              _lastAudioTimestamp = timestamp;
              _isPlayingAudio = true;
            });

            // Play the audio chunk
            await _playAudioChunk(audioData);
            debugPrint('[RemoteViewer] Playing audio chunk: ${audioData.length} bytes');
          }
        } else if (data['stale'] == true) {
          debugPrint('[RemoteViewer] Audio stream is stale');
          if (mounted) {
            setState(() {
              _isPlayingAudio = false;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('[RemoteViewer] Audio poll error: $e');
    }
  }

  /// Play an audio chunk (WAV data)
  Future<void> _playAudioChunk(Uint8List audioData) async {
    try {
      // Initialize audio player if needed
      _audioPlayer ??= AudioPlayer();

      // Get temp directory and save the audio file
      final tempDir = await getTemporaryDirectory();
      _tempAudioPath = '${tempDir.path}/remote_audio_${DateTime.now().millisecondsSinceEpoch}.wav';

      final audioFile = File(_tempAudioPath!);
      await audioFile.writeAsBytes(audioData);

      // Play the audio file
      await _audioPlayer!.play(DeviceFileSource(_tempAudioPath!));

      // Clean up old temp file after a delay
      Future.delayed(const Duration(seconds: 3), () {
        try {
          if (_tempAudioPath != null) {
            final oldFile = File(_tempAudioPath!);
            if (oldFile.existsSync()) {
              oldFile.deleteSync();
            }
          }
        } catch (e) {
  debugPrint('[RemoteMonitoringViewer] Error: $e');
}
      });
    } catch (e) {
      debugPrint('[RemoteViewer] Audio playback error: $e');
    }
  }

  void _toggleAudio() {
    if (_audioEnabled) {
      _stopAudio();
    } else {
      _startAudio();
    }
  }
  
  void _startStreamPolling() {
    _streamPollTimer?.cancel();
    
    // Poll at 2x the requested FPS to ensure we don't miss frames
    final pollInterval = (500 / _streamFps).round().clamp(50, 500);
    
    debugPrint('[RemoteViewer] Starting stream polling every ${pollInterval}ms');
    
    _streamPollTimer = Timer.periodic(
      Duration(milliseconds: pollInterval),
      (_) => _pollStreamFrame(),
    );
  }
  
  Future<void> _pollStreamFrame() async {
    if (!_isStreaming) return;

    try {
      final url = '${ApiConfig.remoteMonitoring}?action=get_stream&computer=${Uri.encodeComponent(widget.computerName)}&since=$_lastFrameTimestamp';

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);

        if (data['success'] == true && data['new_frame'] == true) {
          debugPrint('[RemoteViewer] Got new frame, size: ${data['size']} bytes');
          final frameBase64 = data['frame'] as String;
          final timestamp = data['timestamp'] as int;

          if (timestamp > _lastFrameTimestamp) {
            final frameData = base64Decode(frameBase64);

            // Calculate actual FPS
            final now = DateTime.now();
            if (_lastFrameTime != null) {
              final elapsed = now.difference(_lastFrameTime!).inMilliseconds;
              if (elapsed > 0) {
                _actualFps = 1000 / elapsed;
              }
            }
            _lastFrameTime = now;

            setState(() {
              _streamFrame = frameData;
              _lastFrameTimestamp = timestamp;
              _streamStatus = null; // Clear status once we have frames
              _connectionRetries = 0;
            });
          }
        } else if (data['stale'] == true) {
          // Stream appears stopped - check if we should retry or give up
          debugPrint('[RemoteViewer] Stream is stale (no frames for 10+ seconds)');

          // If we never received a frame and haven't exceeded timeout, retry
          if (_streamFrame == null && _streamStartTime != null) {
            final waitTime = DateTime.now().difference(_streamStartTime!).inSeconds;

            if (waitTime < _maxConnectionWaitSeconds) {
              _connectionRetries++;
              if (mounted) {
                setState(() {
                  _streamStatus = 'Waiting for ${widget.computerName}... (${waitTime}s)';
                });
              }
              // Re-request stream to keep it alive
              _updateStreamSettings();
              return; // Don't stop, keep trying
            } else {
              // Exceeded timeout, show error
              if (mounted) {
                setState(() {
                  _isStreaming = false;
                  _streamRequested = false;
                  _streamStatus = null;
                });
                _streamPollTimer?.cancel();
                _showError('Connection timeout - ${widget.computerName} did not respond');
              }
            }
          } else if (_streamFrame != null) {
            // We had frames before, stream died - stop cleanly
            if (mounted) {
              setState(() {
                _isStreaming = false;
                _streamRequested = false;
                _streamStatus = null;
              });
              _streamPollTimer?.cancel();
            }
          }
        } else if (data['new_frame'] == false) {
          // No new frame yet - this is normal, just waiting
          // Update status message with wait time
          if (_streamFrame == null && _streamStartTime != null && mounted) {
            final waitTime = DateTime.now().difference(_streamStartTime!).inSeconds;
            setState(() {
              _streamStatus = 'Waiting for ${widget.computerName}... (${waitTime}s)';
            });
          }
          // Only log occasionally to avoid spam
          if (DateTime.now().second % 5 == 0) {
            debugPrint('[RemoteViewer] Waiting for frames... (server has no new data)');
          }
        } else {
          debugPrint('[RemoteViewer] Unexpected response: ${response.body}');
        }
      } else {
        debugPrint('[RemoteViewer] Stream poll HTTP error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('[RemoteViewer] Stream poll error: $e');
    }
  }
  
  void _updateStreamSettings() {
    // Send updated settings to server
    http.post(
      Uri.parse('${ApiConfig.remoteMonitoring}?action=start_stream'),
      body: {
        'computer_name': widget.computerName,
        'requested_by': widget.viewerUsername,
        'fps': _streamFps.toString(),
        'quality': _streamQuality.toString(),
      },
    ).timeout(const Duration(seconds: 5));
  }
  
  // ===========================================================================
  // REMOTE CONTROL
  // ===========================================================================
  
  Future<void> _sendCommand(String commandType, Map<String, dynamic> data) async {
    if (!_controlEnabled) return;
    
    try {
      await http.post(
        Uri.parse('${ApiConfig.remoteMonitoring}?action=send_command'),
        body: {
          'computer_name': widget.computerName,
          'command_type': commandType,
          'command_data': jsonEncode(data),
          'sent_by': widget.viewerUsername,
        },
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[RemoteViewer] Command send error: $e');
    }
  }
  
  void _handleMouseEvent(PointerEvent event, Size imageSize) {
    if (!_controlEnabled || _targetScreenWidth == null || _targetScreenHeight == null) return;

    // Update local cursor position for overlay
    setState(() {
      _localCursorPosition = event.localPosition;
    });

    // Calculate position on target screen
    final scaleX = _targetScreenWidth! / imageSize.width;
    final scaleY = _targetScreenHeight! / imageSize.height;

    final targetX = (event.localPosition.dx * scaleX).round().clamp(0, _targetScreenWidth!);
    final targetY = (event.localPosition.dy * scaleY).round().clamp(0, _targetScreenHeight!);

    if (event is PointerDownEvent) {
      final button = event.buttons == 2 ? 'right' : (event.buttons == 4 ? 'middle' : 'left');
      _sendCommand('mouse_click', {'x': targetX, 'y': targetY, 'button': button});
    } else if (event is PointerMoveEvent) {
      // Throttle mouse moves to avoid flooding the server
      final now = DateTime.now();
      if (_lastMouseMoveTime == null ||
          now.difference(_lastMouseMoveTime!) >= _mouseMoveThrottle) {
        _lastMouseMoveTime = now;
        _sendCommand('mouse_move', {'x': targetX, 'y': targetY});
      }
    } else if (event is PointerScrollEvent) {
      final delta = event.scrollDelta.dy > 0 ? -120 : 120; // Windows uses 120 per notch
      _sendCommand('mouse_scroll', {'delta': delta, 'x': targetX, 'y': targetY});
    }
  }
  
  void _handleKeyEvent(KeyEvent event) {
    if (!_controlEnabled) return;
    
    String? keyName;
    
    // Map logical key to our command format
    final keyMap = {
      LogicalKeyboardKey.enter: 'enter',
      LogicalKeyboardKey.backspace: 'backspace',
      LogicalKeyboardKey.tab: 'tab',
      LogicalKeyboardKey.escape: 'escape',
      LogicalKeyboardKey.delete: 'delete',
      LogicalKeyboardKey.arrowUp: 'up',
      LogicalKeyboardKey.arrowDown: 'down',
      LogicalKeyboardKey.arrowLeft: 'left',
      LogicalKeyboardKey.arrowRight: 'right',
      LogicalKeyboardKey.home: 'home',
      LogicalKeyboardKey.end: 'end',
      LogicalKeyboardKey.pageUp: 'pageup',
      LogicalKeyboardKey.pageDown: 'pagedown',
      LogicalKeyboardKey.f1: 'f1',
      LogicalKeyboardKey.f2: 'f2',
      LogicalKeyboardKey.f3: 'f3',
      LogicalKeyboardKey.f4: 'f4',
      LogicalKeyboardKey.f5: 'f5',
      LogicalKeyboardKey.f6: 'f6',
      LogicalKeyboardKey.f7: 'f7',
      LogicalKeyboardKey.f8: 'f8',
      LogicalKeyboardKey.f9: 'f9',
      LogicalKeyboardKey.f10: 'f10',
      LogicalKeyboardKey.f11: 'f11',
      LogicalKeyboardKey.f12: 'f12',
    };
    keyName = keyMap[event.logicalKey];
    
    if (keyName != null) {
      if (event is KeyDownEvent) {
        _sendCommand('key_down', {'key': keyName});
      } else if (event is KeyUpEvent) {
        _sendCommand('key_up', {'key': keyName});
      }
    } else if (event is KeyDownEvent && event.character != null && event.character!.isNotEmpty) {
      // Type the character
      _sendCommand('type_text', {'text': event.character});
    }
  }
  
  void _sendSpecialAction(String action) {
    switch (action) {
      case 'ctrl_alt_del':
        // Can't send actual Ctrl+Alt+Del, but can suggest
        _showError('Ctrl+Alt+Del cannot be sent remotely for security reasons');
        break;
      case 'lock':
        _sendCommand('lock_screen', {});
        break;
      case 'screenshot':
        _sendCommand('screenshot_now', {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Screenshot requested'), backgroundColor: Colors.green),
        );
        break;
      case 'message':
        _showMessageDialog();
        break;
    }
  }
  
  void _showMessageDialog() {
    final titleController = TextEditingController(text: 'A1 Tools');
    final messageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Message'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(labelText: 'Message'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _sendCommand('message_box', {
                'title': titleController.text,
                'message': messageController.text,
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _accent),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.username, style: const TextStyle(fontSize: 16)),
            Text(
              widget.computerName,
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
            ),
          ],
        ),
        actions: [
          // Online status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: _isOnline ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isOnline ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    color: _isOnline ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadScreenshots();
              _loadComputerStatus();
            },
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _accent,
          labelColor: _accent,
          tabs: const [
            Tab(icon: Icon(Icons.photo_library), text: 'Screenshots'),
            Tab(icon: Icon(Icons.live_tv), text: 'Live'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildScreenshotsTab(isDark),
          _buildLiveStreamTab(isDark),
        ],
      ),
    );
  }
  
  // ===========================================================================
  // SCREENSHOTS TAB
  // ===========================================================================
  
  Widget _buildScreenshotsTab(bool isDark) {
    if (_loadingScreenshots) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_screenshotError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_screenshotError!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadScreenshots,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    if (_screenshots.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No screenshots available', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    
    return Row(
      children: [
        // Screenshot grid
        Expanded(
          flex: 2,
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 16 / 9,
            ),
            itemCount: _screenshots.length,
            itemBuilder: (context, index) {
              final ss = _screenshots[index];
              final isSelected = _selectedScreenshot?.filename == ss.filename;
              
              return InkWell(
                onTap: () => _loadScreenshotImage(ss),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected ? _accent : Colors.transparent,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Actual thumbnail image
                        Image.network(
                          ss.url,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                              child: const Icon(Icons.broken_image, size: 32, color: Colors.grey),
                            );
                          },
                        ),
                        // Time label
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            color: Colors.black54,
                            child: Text(
                              DateFormat('MMM d, h:mm a').format(ss.capturedAt),
                              style: const TextStyle(color: Colors.white, fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        
        // Preview panel
        Expanded(
          flex: 3,
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _selectedScreenshot == null
                ? const Center(child: Text('Select a screenshot to preview'))
                : _loadingSelectedImage
                    ? const Center(child: CircularProgressIndicator())
                    : _selectedImageData != null
                        ? Column(
                            children: [
                              Expanded(
                                child: InteractiveViewer(
                                  child: Image.memory(
                                    _selectedImageData!,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      DateFormat('MMMM d, yyyy h:mm:ss a').format(_selectedScreenshot!.capturedAt),
                                      style: TextStyle(
                                        color: isDark ? Colors.white70 : Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      '${_selectedScreenshot!.width}x${_selectedScreenshot!.height}',
                                      style: TextStyle(
                                        color: isDark ? Colors.white70 : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : const Center(child: Text('Failed to load image')),
          ),
        ),
      ],
    );
  }
  
  // ===========================================================================
  // LIVE TAB
  // ===========================================================================
  
  /// Combined Live Stream and Control tab
  /// Shows live stream with optional remote control toggle
  Widget _buildLiveStreamTab(bool isDark) {
    if (!_isOnline) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('Computer is offline', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              'Last seen: ${_lastHeartbeat ?? 'Unknown'}',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Stream controls toolbar
        Container(
          padding: const EdgeInsets.all(12),
          color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
          child: Row(
            children: [
              // Start/Stop button
              ElevatedButton.icon(
                onPressed: _isStreaming ? _stopStream : _startStream,
                icon: Icon(_isStreaming ? Icons.stop : Icons.play_arrow),
                label: Text(_isStreaming ? 'Stop Stream' : 'Start Stream'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isStreaming ? Colors.red : _accent,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 16),

              // Control toggle (only show when streaming)
              if (_isStreaming) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _controlEnabled ? _accent.withValues(alpha: 0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _controlEnabled ? _accent : Colors.grey.shade400,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _controlEnabled ? Icons.mouse : Icons.visibility,
                        size: 18,
                        color: _controlEnabled ? _accent : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Switch(
                        value: _controlEnabled,
                        onChanged: (value) {
                          setState(() => _controlEnabled = value);
                          if (value) {
                            _keyboardFocusNode.requestFocus();
                          }
                        },
                        activeTrackColor: _accent.withValues(alpha: 0.5),
                        thumbColor: WidgetStateProperty.resolveWith((states) =>
                            states.contains(WidgetState.selected) ? _accent : null),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      Text(
                        _controlEnabled ? 'Control' : 'View Only',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _controlEnabled ? _accent : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
              ],

              // FPS selector
              const Text('FPS: '),
              DropdownButton<int>(
                value: _streamFps,
                items: [1, 2, 3, 5, 10].map((fps) => DropdownMenuItem(
                  value: fps,
                  child: Text('$fps'),
                )).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _streamFps = value);
                    if (_isStreaming) _updateStreamSettings();
                  }
                },
              ),
              const SizedBox(width: 16),

              // Quality selector
              const Text('Quality: '),
              DropdownButton<int>(
                value: _streamQuality,
                items: [30, 50, 70, 90].map((q) => DropdownMenuItem(
                  value: q,
                  child: Text('$q%'),
                )).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _streamQuality = value);
                    if (_isStreaming) _updateStreamSettings();
                  }
                },
              ),
              const SizedBox(width: 16),

              // Audio toggle button
              ElevatedButton.icon(
                onPressed: _toggleAudio,
                icon: Icon(_audioEnabled ? Icons.volume_up : Icons.volume_off, size: 18),
                label: Text(_audioEnabled ? 'Audio On' : 'Audio Off'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _audioEnabled ? Colors.green : Colors.grey.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),

              const Spacer(),

              // Quick actions (only when control is enabled)
              if (_controlEnabled && _isStreaming) ...[
                _buildQuickAction(Icons.screenshot, 'Screenshot', () => _sendSpecialAction('screenshot')),
                const SizedBox(width: 8),
                _buildQuickAction(Icons.lock, 'Lock', () => _sendSpecialAction('lock')),
                const SizedBox(width: 8),
                _buildQuickAction(Icons.message, 'Message', () => _sendSpecialAction('message')),
                const SizedBox(width: 16),
              ],

              // Status indicators
              if (_audioEnabled)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: _isPlayingAudio ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isPlayingAudio ? Icons.hearing : Icons.hearing_disabled,
                        size: 14,
                        color: _isPlayingAudio ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isPlayingAudio ? 'Audio' : 'Wait',
                        style: TextStyle(
                          fontSize: 11,
                          color: _isPlayingAudio ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

              // Actual FPS display
              if (_isStreaming)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_actualFps.toStringAsFixed(1)} FPS',
                    style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w500),
                  ),
                ),
            ],
          ),
        ),

        // Stream view with optional control
        Expanded(
          child: KeyboardListener(
            focusNode: _keyboardFocusNode,
            onKeyEvent: _controlEnabled ? _handleKeyEvent : null,
            child: _streamFrame != null
                ? Center(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Calculate the actual displayed image size maintaining aspect ratio
                        final targetAspect = (_targetScreenWidth ?? 1920) / (_targetScreenHeight ?? 1080);
                        final containerAspect = constraints.maxWidth / constraints.maxHeight;

                        double displayWidth, displayHeight;
                        if (containerAspect > targetAspect) {
                          displayHeight = constraints.maxHeight;
                          displayWidth = displayHeight * targetAspect;
                        } else {
                          displayWidth = constraints.maxWidth;
                          displayHeight = displayWidth / targetAspect;
                        }

                        final displaySize = Size(displayWidth, displayHeight);

                        return Listener(
                          onPointerDown: _controlEnabled ? (e) => _handleMouseEvent(e, displaySize) : null,
                          onPointerMove: _controlEnabled ? (e) => _handleMouseEvent(e, displaySize) : null,
                          onPointerHover: _controlEnabled ? (e) {
                            // Update cursor position on hover for smooth tracking
                            if (mounted) {
                              setState(() => _localCursorPosition = e.localPosition);
                            }
                          } : null,
                          onPointerSignal: _controlEnabled ? (e) {
                            if (e is PointerScrollEvent) {
                              _handleMouseEvent(e, displaySize);
                            }
                          } : null,
                          child: MouseRegion(
                            cursor: _controlEnabled ? SystemMouseCursors.none : SystemMouseCursors.basic,
                            onEnter: _controlEnabled ? (e) {
                              if (mounted) {
                                setState(() => _localCursorPosition = e.localPosition);
                              }
                            } : null,
                            onExit: (_) {
                              if (mounted) {
                                setState(() => _localCursorPosition = null);
                              }
                            },
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // The screen image
                                Image.memory(
                                  _streamFrame!,
                                  key: _imageKey,
                                  fit: BoxFit.contain,
                                  gaplessPlayback: true,
                                  width: displayWidth,
                                  height: displayHeight,
                                ),
                                // Cursor overlay when control is enabled
                                if (_controlEnabled && _localCursorPosition != null)
                                  Positioned(
                                    left: _localCursorPosition!.dx - 8,
                                    top: _localCursorPosition!.dy - 8,
                                    child: IgnorePointer(
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _accent.withValues(alpha: 0.5),
                                          border: Border.all(color: _accent, width: 2),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_streamRequested) ...[
                          // Connecting spinner
                          const SizedBox(
                            width: 64,
                            height: 64,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: _accent,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _streamStatus ?? 'Connecting...',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          if (_streamStartTime != null)
                            Text(
                              'Timeout in ${_maxConnectionWaitSeconds - DateTime.now().difference(_streamStartTime!).inSeconds}s',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            ),
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: _stopStream,
                            icon: const Icon(Icons.cancel, size: 18),
                            label: const Text('Cancel'),
                            style: TextButton.styleFrom(foregroundColor: Colors.grey),
                          ),
                        ] else ...[
                          // Not started yet
                          Icon(
                            Icons.live_tv,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Click "Start Stream" to begin',
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Toggle "Control" to send mouse/keyboard input',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ),

        // Control instructions bar (only when control is enabled)
        if (_controlEnabled && _streamFrame != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: _accent.withValues(alpha: 0.1),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, size: 16, color: _accent),
                SizedBox(width: 8),
                Text(
                  'Click to interact • Type to send keys • ESC to unfocus • Toggle off to disable control',
                  style: TextStyle(color: _accent, fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }
  
  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// DATA MODELS
// =============================================================================

class _ScreenshotInfo {
  final int id;
  final String filename;
  final int fileSize;
  final int width;
  final int height;
  final DateTime capturedAt;
  final String url;
  
  _ScreenshotInfo({
    required this.id,
    required this.filename,
    required this.fileSize,
    required this.width,
    required this.height,
    required this.capturedAt,
    required this.url,
  });
  
  factory _ScreenshotInfo.fromJson(Map<String, dynamic> json) {
    // Parse server time as UTC and convert to local time
    DateTime capturedAt = DateTime.now();
    final capturedAtStr = json['captured_at'] ?? '';
    if (capturedAtStr.isNotEmpty) {
      // Server returns datetime in format "2024-01-08 20:13:00" (server local time, which is UTC)
      // Parse it as UTC and convert to device local time
      final parsed = DateTime.tryParse(capturedAtStr);
      if (parsed != null) {
        // If the datetime doesn't have timezone info, treat it as UTC
        final utcTime = DateTime.utc(
          parsed.year, parsed.month, parsed.day,
          parsed.hour, parsed.minute, parsed.second,
        );
        capturedAt = utcTime.toLocal();
      }
    }

    return _ScreenshotInfo(
      id: json['id'] ?? 0,
      filename: json['filename'] ?? '',
      fileSize: json['file_size'] ?? 0,
      width: json['width'] ?? 0,
      height: json['height'] ?? 0,
      capturedAt: capturedAt,
      url: json['url'] ?? '',
    );
  }
}
