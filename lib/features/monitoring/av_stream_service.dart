// File: lib/av_stream_service.dart
// 
// OPTIMIZED VERSION - Removed PowerShell-based audio capture which was 
// spawning processes every 200ms. Video streaming now uses proper rate
// limiting to prevent PowerShell accumulation.
// 
// CHANGES:
// - Removed audio capture entirely (was experimental and caused severe performance issues)
// - Reduced default FPS from 10 to 2 FPS for streaming
// - Added proper rate limiting to prevent capture backlog
// - Uses shared ScreenCaptureManager lock to prevent concurrent captures

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Video-only streaming server for A1 Tools remote monitoring
/// Audio capture has been disabled due to performance issues (spawned PowerShell every 200ms)
/// 
/// For audio monitoring, consider using external tools or a persistent FFmpeg process
/// in a future update.
class AVStreamServer {
  static const int defaultPort = 5902;
  static const String authPassword = 'a1stream';
  static const int idleTimeoutMinutes = 5;
  
  ServerSocket? _server;
  final List<Socket> _clients = [];
  Timer? _captureTimer;
  Timer? _idleTimer;
  bool _isRunning = false;
  
  // Callback to capture screen (provided by app)
  final Future<Uint8List?> Function()? onCaptureScreen;
  final void Function(String message)? onLog;
  final void Function(int clientCount)? onClientCountChanged;
  final void Function()? onIdleStop;
  
  // Settings - REDUCED from 100ms (10 FPS) to 500ms (2 FPS) to prevent PowerShell accumulation
  int _captureIntervalMs = 500; // 2 FPS default - much more sustainable
  static const int _minIntervalMs = 250; // Max 4 FPS to prevent overload
  
  // Rate limiting - skip capture if previous one hasn't finished
  bool _captureInProgress = false;
  int _skippedFrames = 0;
  
  AVStreamServer({
    this.onCaptureScreen,
    this.onLog,
    this.onClientCountChanged,
    this.onIdleStop,
  });
  
  bool get isRunning => _isRunning;
  int get clientCount => _clients.length;
  
  // Audio is disabled in this version
  bool get audioEnabled => false;
  
  /// Start the streaming server
  Future<bool> start({int port = defaultPort}) async {
    if (_isRunning) {
      _log('Server already running');
      return true;
    }
    
    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      _isRunning = true;
      _log('AV stream server started on port $port (video only, audio disabled)');
      
      _server!.listen(
        _handleClient,
        onError: (e) => _log('Server error: $e'),
        onDone: () {
          _log('Server stopped');
          _isRunning = false;
        },
      );
      
      // Note: Audio capture has been disabled due to performance issues
      // It was spawning PowerShell processes every 200ms, causing CPU overload
      _log('Audio capture: DISABLED (performance optimization)');
      
      _startIdleTimer();
      
      return true;
    } catch (e) {
      _log('Failed to start server: $e');
      return false;
    }
  }
  
  /// Stop the streaming server
  Future<void> stop() async {
    _isRunning = false;
    _captureTimer?.cancel();
    _captureTimer = null;
    _idleTimer?.cancel();
    _idleTimer = null;
    _captureInProgress = false;
    
    for (final client in _clients.toList()) {
      try {
        await client.close();
      } catch (e) {
  debugPrint('[AvStreamService] Error: $e');
}
    }
    _clients.clear();
    
    await _server?.close();
    _server = null;
    
    _log('Server stopped');
  }
  
  /// Handle new client connection
  void _handleClient(Socket client) {
    final clientAddress = '${client.remoteAddress.address}:${client.remotePort}';
    _log('New connection from $clientAddress');
    
    bool authenticated = false;
    List<int> buffer = [];
    
    client.listen(
      (Uint8List data) {
        buffer.addAll(data);
        
        while (true) {
          final newlineIndex = buffer.indexOf(10);
          if (newlineIndex == -1) break;
          
          final message = utf8.decode(buffer.sublist(0, newlineIndex)).trim();
          buffer = buffer.sublist(newlineIndex + 1);
          
          if (!authenticated) {
            if (message.startsWith('AUTH ')) {
              final pwd = message.substring(5);
              if (pwd == authPassword) {
                authenticated = true;
                _clients.add(client);
                _cancelIdleTimer();
                // Audio is always disabled in this version
                client.write('OK AUDIO=0\n');
                _log('Client $clientAddress authenticated (audio disabled)');
                onClientCountChanged?.call(_clients.length);
                _ensureStreamingStarted();
              } else {
                client.write('FAIL\n');
                _log('Client $clientAddress failed auth');
                client.close();
              }
            } else {
              client.write('FAIL\n');
              client.close();
            }
          } else {
            _handleCommand(client, message);
          }
        }
      },
      onError: (e) {
        _log('Client error: $e');
        _removeClient(client);
      },
      onDone: () {
        _log('Client $clientAddress disconnected');
        _removeClient(client);
      },
    );
  }
  
  void _handleCommand(Socket client, String command) {
    if (command.startsWith('SET_FPS ')) {
      final fps = int.tryParse(command.substring(8)) ?? 2;
      // Clamp FPS to prevent overload - max 4 FPS
      final clampedFps = fps.clamp(1, 4);
      _captureIntervalMs = (1000 / clampedFps).round().clamp(_minIntervalMs, 2000);
      _log('FPS set to $clampedFps (interval: ${_captureIntervalMs}ms)');
      
      // Restart timer with new interval
      if (_captureTimer != null) {
        _captureTimer?.cancel();
        _captureTimer = Timer.periodic(
          Duration(milliseconds: _captureIntervalMs),
          (_) => _captureAndSendVideo(),
        );
      }
    }
  }
  
  void _removeClient(Socket client) {
    _clients.remove(client);
    onClientCountChanged?.call(_clients.length);
    
    if (_clients.isEmpty) {
      _captureTimer?.cancel();
      _captureTimer = null;
      _log('No clients, streaming paused');
      _startIdleTimer();
    }
    
    try { client.close(); } catch (e) {
  debugPrint('[AvStreamService] Error: $e');
}
  }
  
  void _startIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(minutes: idleTimeoutMinutes), () {
      if (_clients.isEmpty && _isRunning) {
        _log('Idle timeout - auto-stopping server to save resources');
        stop();
        onIdleStop?.call();
      }
    });
    _log('Idle timer started - will auto-stop in $idleTimeoutMinutes minutes if no clients');
  }
  
  void _cancelIdleTimer() {
    if (_idleTimer != null) {
      _idleTimer?.cancel();
      _idleTimer = null;
      _log('Idle timer cancelled - client connected');
    }
  }
  
  void _ensureStreamingStarted() {
    if (_clients.isEmpty) return;
    
    if (_captureTimer == null) {
      _log('Starting video stream at ${1000 ~/ _captureIntervalMs} FPS');
      _captureAndSendVideo();
      _captureTimer = Timer.periodic(
        Duration(milliseconds: _captureIntervalMs),
        (_) => _captureAndSendVideo(),
      );
    }
  }
  
  Future<void> _captureAndSendVideo() async {
    if (_clients.isEmpty || onCaptureScreen == null) return;
    
    // Rate limiting - skip if previous capture hasn't finished
    if (_captureInProgress) {
      _skippedFrames++;
      if (_skippedFrames % 10 == 0) {
        _log('Warning: Skipped $_skippedFrames frames due to capture backlog');
      }
      return;
    }
    
    _captureInProgress = true;
    
    try {
      final imageData = await onCaptureScreen!();
      if (imageData == null || imageData.isEmpty) {
        return;
      }
      
      final header = 'FRAME ${imageData.length}\n';
      final headerBytes = utf8.encode(header);
      
      for (final client in _clients.toList()) {
        try {
          client.add(headerBytes);
          client.add(imageData);
        } catch (e) {
          _removeClient(client);
        }
      }
    } catch (e) {
      _log('Video capture error: $e');
    } finally {
      _captureInProgress = false;
    }
  }
  
  void _log(String message) {
    debugPrint('[AVStreamServer] $message');
    onLog?.call(message);
  }
}


/// AV stream client - connects to a remote A1 Tools instance
/// Note: Audio support has been disabled on the server side
class AVStreamClient {
  Socket? _socket;
  bool _isConnected = false;
  bool _authenticated = false;
  bool _audioAvailable = false;
  
  final void Function(Uint8List frameData)? onFrame;
  final void Function(Uint8List audioData)? onAudio;
  final void Function(String status)? onStatusChanged;
  final void Function(String error)? onError;
  final void Function(bool available)? onAudioAvailable;
  
  List<int> _buffer = [];
  int _expectedSize = 0;
  bool _waitingForData = false;
  String _dataType = '';
  
  // Stats
  int _framesReceived = 0;
  int _audioChunksReceived = 0;
  DateTime? _lastFrameTime;
  double _fps = 0;
  
  AVStreamClient({
    this.onFrame,
    this.onAudio,
    this.onStatusChanged,
    this.onError,
    this.onAudioAvailable,
  });
  
  bool get isConnected => _isConnected && _authenticated;
  bool get audioAvailable => _audioAvailable;
  int get framesReceived => _framesReceived;
  int get audioChunksReceived => _audioChunksReceived;
  double get fps => _fps;
  
  Future<bool> connect(String host, {int port = AVStreamServer.defaultPort}) async {
    try {
      onStatusChanged?.call('Connecting to $host:$port...');
      
      _socket = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
      _isConnected = true;
      
      onStatusChanged?.call('Connected, authenticating...');
      _socket!.write('AUTH ${AVStreamServer.authPassword}\n');
      
      _socket!.listen(
        _handleData,
        onError: (e) {
          onError?.call('Connection error: $e');
          disconnect();
        },
        onDone: () {
          onStatusChanged?.call('Disconnected');
          _isConnected = false;
          _authenticated = false;
        },
      );
      
      return true;
    } catch (e) {
      onError?.call('Failed to connect: $e');
      return false;
    }
  }
  
  Future<void> disconnect() async {
    _isConnected = false;
    _authenticated = false;
    _buffer.clear();
    
    try { await _socket?.close(); } catch (e) {
  debugPrint('[AvStreamService] Error: $e');
}
    _socket = null;
    
    onStatusChanged?.call('Disconnected');
  }
  
  void _handleData(Uint8List data) {
    _buffer.addAll(data);
    
    while (_buffer.isNotEmpty) {
      if (!_authenticated) {
        final newlineIndex = _buffer.indexOf(10);
        if (newlineIndex == -1) break;
        
        final response = utf8.decode(_buffer.sublist(0, newlineIndex)).trim();
        _buffer = _buffer.sublist(newlineIndex + 1);
        
        if (response.startsWith('OK')) {
          _authenticated = true;
          _audioAvailable = response.contains('AUDIO=1');
          onAudioAvailable?.call(_audioAvailable);
          onStatusChanged?.call(_audioAvailable ? 'Streaming (with audio)...' : 'Streaming (video only)...');
        } else {
          onError?.call('Authentication failed');
          disconnect();
          return;
        }
      } else if (!_waitingForData) {
        final newlineIndex = _buffer.indexOf(10);
        if (newlineIndex == -1) break;
        
        final header = utf8.decode(_buffer.sublist(0, newlineIndex)).trim();
        _buffer = _buffer.sublist(newlineIndex + 1);
        
        if (header.startsWith('FRAME ')) {
          _expectedSize = int.tryParse(header.substring(6)) ?? 0;
          _dataType = 'FRAME';
          _waitingForData = _expectedSize > 0;
        } else if (header.startsWith('AUDIO ')) {
          _expectedSize = int.tryParse(header.substring(6)) ?? 0;
          _dataType = 'AUDIO';
          _waitingForData = _expectedSize > 0;
        }
      } else {
        if (_buffer.length >= _expectedSize) {
          final binaryData = Uint8List.fromList(_buffer.sublist(0, _expectedSize));
          _buffer = _buffer.sublist(_expectedSize);
          _waitingForData = false;
          _expectedSize = 0;
          
          if (_dataType == 'FRAME') {
            _framesReceived++;
            final now = DateTime.now();
            if (_lastFrameTime != null) {
              final elapsed = now.difference(_lastFrameTime!).inMilliseconds;
              if (elapsed > 0) _fps = 1000 / elapsed;
            }
            _lastFrameTime = now;
            onFrame?.call(binaryData);
          } else if (_dataType == 'AUDIO') {
            _audioChunksReceived++;
            onAudio?.call(binaryData);
          }
          
          _dataType = '';
        } else {
          break;
        }
      }
    }
  }
  
  void setFps(int fps) {
    if (_authenticated && _socket != null) {
      // Server will clamp this to max 4 FPS
      _socket!.write('SET_FPS $fps\n');
    }
  }
}
