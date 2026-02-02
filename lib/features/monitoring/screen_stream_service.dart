// File: lib/screen_stream_service.dart
// 
// OPTIMIZED VERSION - Reduced default FPS and added rate limiting
// to prevent PowerShell process accumulation.
// 
// CHANGES:
// - Reduced default FPS from 10 to 2 FPS
// - Added rate limiting to prevent capture backlog
// - Max FPS clamped to 4 to prevent system overload

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Screen streaming server for A1 Tools remote monitoring
/// Runs on target PCs and streams screen captures to connected viewers
class ScreenStreamServer {
  static const int defaultPort = 5901;
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
  
  // Settings - REDUCED from 100ms (10 FPS) to 500ms (2 FPS)
  int _captureIntervalMs = 500; // 2 FPS default
  static const int _minIntervalMs = 250; // Max 4 FPS
  int _quality = 50;
  double _scale = 0.5;
  
  // Rate limiting - prevent capture backlog
  bool _captureInProgress = false;
  int _skippedFrames = 0;
  
  ScreenStreamServer({
    this.onCaptureScreen,
    this.onLog,
    this.onClientCountChanged,
    this.onIdleStop,
  });
  
  bool get isRunning => _isRunning;
  int get clientCount => _clients.length;
  
  /// Start the streaming server
  Future<bool> start({int port = defaultPort}) async {
    if (_isRunning) {
      _log('Server already running');
      return true;
    }
    
    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      _isRunning = true;
      _log('Screen stream server started on port $port (2 FPS default)');
      
      _server!.listen(
        _handleClient,
        onError: (e) => _log('Server error: $e'),
        onDone: () {
          _log('Server stopped');
          _isRunning = false;
        },
      );
      
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
        if (kDebugMode) debugPrint('[ScreenStreamService] Error closing client: $e');
      }
    }
    _clients.clear();

    try {
      await _server?.close();
    } catch (e) {
      if (kDebugMode) debugPrint('[ScreenStreamService] Error closing server: $e');
    }
    _server = null;

    _log('Server stopped');
  }

  /// Dispose the server and release all resources
  /// Call this when the server is no longer needed
  Future<void> dispose() async {
    await stop();
    _skippedFrames = 0;
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
                client.write('OK\n');
                _log('Client $clientAddress authenticated');
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
  
  /// Handle commands from authenticated clients
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
          (_) => _captureAndSend(),
        );
      }
    } else if (command.startsWith('SET_QUALITY ')) {
      _quality = (int.tryParse(command.substring(12)) ?? 50).clamp(10, 90);
      _log('Quality set to $_quality');
    } else if (command.startsWith('SET_SCALE ')) {
      _scale = (double.tryParse(command.substring(10)) ?? 0.5).clamp(0.25, 1.0);
      _log('Scale set to $_scale');
    }
  }
  
  /// Remove a client from the list
  void _removeClient(Socket client) {
    _clients.remove(client);
    onClientCountChanged?.call(_clients.length);
    
    if (_clients.isEmpty) {
      _captureTimer?.cancel();
      _captureTimer = null;
      _captureInProgress = false;
      _log('No clients connected, streaming paused');
      _startIdleTimer();
    }
    
    try {
      client.close();
    } catch (e) {
  debugPrint('[ScreenStreamService] Error: $e');
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
  
  /// Ensure streaming is started when clients are connected
  void _ensureStreamingStarted() {
    if (_captureTimer != null) return;
    if (_clients.isEmpty) return;
    
    _log('Starting screen capture stream at ${1000 ~/ _captureIntervalMs} FPS');
    _captureAndSend(); // Send first frame immediately
    
    _captureTimer = Timer.periodic(
      Duration(milliseconds: _captureIntervalMs),
      (_) => _captureAndSend(),
    );
  }
  
  /// Capture screen and send to all clients
  Future<void> _captureAndSend() async {
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
      
      // Protocol: FRAME <size>\n<binary data>
      final header = 'FRAME ${imageData.length}\n';
      final headerBytes = utf8.encode(header);
      
      // Send to all connected clients
      for (final client in _clients.toList()) {
        try {
          client.add(headerBytes);
          client.add(imageData);
        } catch (e) {
          _log('Error sending to client: $e');
          _removeClient(client);
        }
      }
    } catch (e) {
      _log('Capture error: $e');
    } finally {
      _captureInProgress = false;
    }
  }
  
  void _log(String message) {
    debugPrint('[ScreenStreamServer] $message');
    onLog?.call(message);
  }
}


/// Screen stream client - connects to a remote A1 Tools instance
class ScreenStreamClient {
  Socket? _socket;
  bool _isConnected = false;
  bool _authenticated = false;
  
  final void Function(Uint8List frameData)? onFrame;
  final void Function(String status)? onStatusChanged;
  final void Function(String error)? onError;
  
  List<int> _buffer = [];
  int _expectedFrameSize = 0;
  bool _waitingForFrameData = false;
  
  // Stats
  int _framesReceived = 0;
  DateTime? _lastFrameTime;
  double _fps = 0;
  
  ScreenStreamClient({
    this.onFrame,
    this.onStatusChanged,
    this.onError,
  });
  
  bool get isConnected => _isConnected && _authenticated;
  int get framesReceived => _framesReceived;
  double get fps => _fps;
  
  /// Connect to a remote screen stream server
  Future<bool> connect(String host, {int port = ScreenStreamServer.defaultPort}) async {
    try {
      onStatusChanged?.call('Connecting to $host:$port...');
      
      _socket = await Socket.connect(
        host, 
        port,
        timeout: const Duration(seconds: 5),
      );
      _isConnected = true;
      
      onStatusChanged?.call('Connected, authenticating...');
      
      // Send authentication
      _socket!.write('AUTH ${ScreenStreamServer.authPassword}\n');
      
      // Listen for data
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
  
  /// Disconnect from the server
  Future<void> disconnect() async {
    _isConnected = false;
    _authenticated = false;
    _buffer.clear();

    try {
      await _socket?.close();
    } catch (e) {
      if (kDebugMode) debugPrint('[ScreenStreamService] Error closing socket: $e');
    }
    _socket = null;

    onStatusChanged?.call('Disconnected');
  }

  /// Dispose the client and release all resources
  Future<void> dispose() async {
    await disconnect();
    _framesReceived = 0;
    _fps = 0;
    _lastFrameTime = null;
  }
  
  /// Handle incoming data
  void _handleData(Uint8List data) {
    _buffer.addAll(data);
    
    while (_buffer.isNotEmpty) {
      if (!_authenticated) {
        final newlineIndex = _buffer.indexOf(10);
        if (newlineIndex == -1) break;
        
        final response = utf8.decode(_buffer.sublist(0, newlineIndex)).trim();
        _buffer = _buffer.sublist(newlineIndex + 1);
        
        if (response == 'OK') {
          _authenticated = true;
          onStatusChanged?.call('Streaming...');
        } else {
          onError?.call('Authentication failed');
          disconnect();
          return;
        }
      } else if (!_waitingForFrameData) {
        final newlineIndex = _buffer.indexOf(10);
        if (newlineIndex == -1) break;
        
        final header = utf8.decode(_buffer.sublist(0, newlineIndex)).trim();
        _buffer = _buffer.sublist(newlineIndex + 1);
        
        if (header.startsWith('FRAME ')) {
          _expectedFrameSize = int.tryParse(header.substring(6)) ?? 0;
          if (_expectedFrameSize > 0) {
            _waitingForFrameData = true;
          }
        }
      } else {
        if (_buffer.length >= _expectedFrameSize) {
          final frameData = Uint8List.fromList(_buffer.sublist(0, _expectedFrameSize));
          _buffer = _buffer.sublist(_expectedFrameSize);
          _waitingForFrameData = false;
          _expectedFrameSize = 0;
          
          // Update stats
          _framesReceived++;
          final now = DateTime.now();
          if (_lastFrameTime != null) {
            final elapsed = now.difference(_lastFrameTime!).inMilliseconds;
            if (elapsed > 0) {
              _fps = 1000 / elapsed;
            }
          }
          _lastFrameTime = now;
          
          // Deliver frame
          onFrame?.call(frameData);
        } else {
          break;
        }
      }
    }
  }
  
  /// Request FPS change (server will clamp to max 4 FPS)
  void setFps(int fps) {
    if (_authenticated && _socket != null) {
      _socket!.write('SET_FPS $fps\n');
    }
  }
  
  /// Request quality change
  void setQuality(int quality) {
    if (_authenticated && _socket != null) {
      _socket!.write('SET_QUALITY $quality\n');
    }
  }
  
  /// Request scale change
  void setScale(double scale) {
    if (_authenticated && _socket != null) {
      _socket!.write('SET_SCALE $scale\n');
    }
  }
}
