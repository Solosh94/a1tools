// WebSocket Client
//
// Unified WebSocket client for real-time communication.
// Provides auto-reconnection, connection state management, and event handling.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

/// Connection state for WebSocket
enum WebSocketState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

/// Configuration for WebSocket connection
class WebSocketConfig {
  /// Whether to automatically reconnect on disconnect
  final bool autoReconnect;

  /// Maximum number of reconnection attempts (0 = unlimited)
  final int maxReconnectAttempts;

  /// Initial delay between reconnection attempts
  final Duration reconnectDelay;

  /// Maximum delay between reconnection attempts
  final Duration maxReconnectDelay;

  /// Ping interval to keep connection alive
  final Duration? pingInterval;

  /// Connection timeout
  final Duration connectionTimeout;

  /// Backoff multiplier for exponential backoff (default 2.0)
  final double backoffMultiplier;

  /// Maximum jitter percentage (0.0 - 1.0) added to delays to prevent thundering herd
  final double jitterFactor;

  /// Whether to reset backoff on successful connection
  final bool resetBackoffOnConnect;

  const WebSocketConfig({
    this.autoReconnect = true,
    this.maxReconnectAttempts = 10,  // Default to 10 attempts to prevent infinite loops
    this.reconnectDelay = const Duration(seconds: 1),
    this.maxReconnectDelay = const Duration(seconds: 30),
    this.pingInterval,
    this.connectionTimeout = const Duration(seconds: 10),
    this.backoffMultiplier = 2.0,
    this.jitterFactor = 0.3, // 30% jitter by default
    this.resetBackoffOnConnect = true,
  });

  /// Default configuration with sensible reconnection limits
  static const standard = WebSocketConfig(
    maxReconnectAttempts: 10,  // Prevent infinite reconnection loops
  );

  /// Configuration for monitoring (longer timeouts, more reconnect attempts)
  static const monitoring = WebSocketConfig(
    autoReconnect: true,
    maxReconnectAttempts: 20,  // More attempts for critical monitoring, but not infinite
    reconnectDelay: Duration(seconds: 2),
    maxReconnectDelay: Duration(minutes: 1),
    pingInterval: Duration(seconds: 30),
    connectionTimeout: Duration(seconds: 15),
    backoffMultiplier: 1.5, // Gentler backoff for monitoring
    jitterFactor: 0.25,
  );

  /// Configuration for notifications (quick reconnect)
  static const notifications = WebSocketConfig(
    autoReconnect: true,
    maxReconnectAttempts: 10,
    reconnectDelay: Duration(milliseconds: 500),
    maxReconnectDelay: Duration(seconds: 10),
    connectionTimeout: Duration(seconds: 5),
    backoffMultiplier: 2.0,
    jitterFactor: 0.2,
  );

  /// Configuration for real-time features (aggressive reconnect)
  static const realtime = WebSocketConfig(
    autoReconnect: true,
    maxReconnectAttempts: 15,
    reconnectDelay: Duration(milliseconds: 250),
    maxReconnectDelay: Duration(seconds: 15),
    connectionTimeout: Duration(seconds: 5),
    pingInterval: Duration(seconds: 15),
    backoffMultiplier: 1.5,
    jitterFactor: 0.4, // Higher jitter for real-time to spread reconnects
  );
}

/// Event types for WebSocket messages
class WebSocketEvent {
  final String type;
  final dynamic data;
  final DateTime timestamp;

  WebSocketEvent({
    required this.type,
    this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory WebSocketEvent.fromJson(Map<String, dynamic> json) {
    return WebSocketEvent(
      type: json['type'] as String? ?? 'unknown',
      data: json['data'],
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
      };

  @override
  String toString() => 'WebSocketEvent(type: $type, data: $data)';
}

/// Unified WebSocket client
class WebSocketClient {
  final String url;
  final WebSocketConfig config;
  final Map<String, String>? headers;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  WebSocketState _state = WebSocketState.disconnected;
  int _reconnectAttempts = 0;
  Duration _currentReconnectDelay;
  bool _isDisposed = false;

  // Event streams
  final _stateController = StreamController<WebSocketState>.broadcast();
  final _messageController = StreamController<dynamic>.broadcast();
  final _eventController = StreamController<WebSocketEvent>.broadcast();
  final _errorController = StreamController<dynamic>.broadcast();

  /// Stream of connection state changes
  Stream<WebSocketState> get stateStream => _stateController.stream;

  /// Stream of raw messages
  Stream<dynamic> get messageStream => _messageController.stream;

  /// Stream of parsed events (for JSON messages with type/data structure)
  Stream<WebSocketEvent> get eventStream => _eventController.stream;

  /// Stream of errors
  Stream<dynamic> get errorStream => _errorController.stream;

  /// Current connection state
  WebSocketState get state => _state;

  /// Whether currently connected
  bool get isConnected => _state == WebSocketState.connected;

  /// Whether currently connecting or reconnecting
  bool get isConnecting =>
      _state == WebSocketState.connecting ||
      _state == WebSocketState.reconnecting;

  WebSocketClient({
    required this.url,
    this.config = const WebSocketConfig(),
    this.headers,
  }) : _currentReconnectDelay = config.reconnectDelay;

  /// Connect to WebSocket server
  Future<bool> connect() async {
    if (_state == WebSocketState.connected) {
      debugPrint('[WebSocket] Already connected');
      return true;
    }

    if (_state == WebSocketState.connecting) {
      debugPrint('[WebSocket] Connection in progress');
      return false;
    }

    _setState(WebSocketState.connecting);
    debugPrint('[WebSocket] Connecting to $url...');

    try {
      final uri = Uri.parse(url);
      _channel = WebSocketChannel.connect(uri, protocols: null);

      // Wait for connection to be ready
      await _channel!.ready.timeout(
        config.connectionTimeout,
        onTimeout: () {
          throw TimeoutException('Connection timeout', config.connectionTimeout);
        },
      );

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      _setState(WebSocketState.connected);
      _reconnectAttempts = 0;
      _currentReconnectDelay = config.reconnectDelay;

      debugPrint('[WebSocket] Connected successfully');

      // Start ping timer if configured
      _startPingTimer();

      return true;
    } catch (e) {
      debugPrint('[WebSocket] Connection failed: $e');
      _setState(WebSocketState.disconnected);
      _errorController.add(e);

      if (config.autoReconnect) {
        _scheduleReconnect();
      }

      return false;
    }
  }

  /// Disconnect from WebSocket server
  Future<void> disconnect() async {
    debugPrint('[WebSocket] Disconnecting...');

    _cancelReconnect();
    _stopPingTimer();

    await _subscription?.cancel();
    _subscription = null;

    try {
      await _channel?.sink.close(status.normalClosure);
    } catch (e) {
      debugPrint('[WebSocket] Error closing channel: $e');
    }
    _channel = null;

    _setState(WebSocketState.disconnected);
    debugPrint('[WebSocket] Disconnected');
  }

  /// Send a message
  void send(dynamic message) {
    if (!isConnected) {
      debugPrint('[WebSocket] Cannot send - not connected');
      return;
    }

    try {
      if (message is String) {
        _channel!.sink.add(message);
      } else if (message is Map || message is List) {
        _channel!.sink.add(jsonEncode(message));
      } else {
        _channel!.sink.add(message.toString());
      }
    } catch (e) {
      debugPrint('[WebSocket] Send error: $e');
      _errorController.add(e);
    }
  }

  /// Send a typed event
  void sendEvent(String type, [dynamic data]) {
    send(WebSocketEvent(type: type, data: data).toJson());
  }

  /// Send raw bytes
  void sendBytes(List<int> bytes) {
    if (!isConnected) {
      debugPrint('[WebSocket] Cannot send - not connected');
      return;
    }

    try {
      _channel!.sink.add(bytes);
    } catch (e) {
      debugPrint('[WebSocket] Send bytes error: $e');
      _errorController.add(e);
    }
  }

  void _onMessage(dynamic message) {
    if (_isDisposed) return;

    _messageController.add(message);

    // Try to parse as event
    if (message is String) {
      try {
        final json = jsonDecode(message);
        if (json is Map<String, dynamic> && json.containsKey('type')) {
          _eventController.add(WebSocketEvent.fromJson(json));
        }
      } catch (e) {
        // Not JSON or not an event, that's fine
        debugPrint('[WebSocketClient] Error: $e');
      }
    }
  }

  void _onError(dynamic error) {
    if (_isDisposed) return;

    debugPrint('[WebSocket] Error: $error');
    _errorController.add(error);
  }

  void _onDone() {
    debugPrint('[WebSocket] Connection closed');

    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    _stopPingTimer();

    if (_isDisposed) return;

    if (_state != WebSocketState.disconnected) {
      _setState(WebSocketState.disconnected);

      if (config.autoReconnect && !_isDisposed) {
        _scheduleReconnect();
      }
    }
  }

  void _scheduleReconnect() {
    if (_isDisposed) return;

    if (config.maxReconnectAttempts > 0 &&
        _reconnectAttempts >= config.maxReconnectAttempts) {
      debugPrint(
          '[WebSocket] Max reconnect attempts reached ($_reconnectAttempts)');
      return;
    }

    _cancelReconnect();
    _setState(WebSocketState.reconnecting);

    debugPrint(
        '[WebSocket] Scheduling reconnect in ${_currentReconnectDelay.inSeconds}s (attempt ${_reconnectAttempts + 1})');

    _reconnectTimer = Timer(_currentReconnectDelay, () async {
      _reconnectAttempts++;

      final success = await connect();
      if (!success && config.autoReconnect) {
        // Calculate exponential backoff with configurable jitter
        _currentReconnectDelay = _calculateNextDelay();
      }
    });
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// Calculate next delay using exponential backoff with jitter
  /// Uses decorrelated jitter algorithm for better distribution
  Duration _calculateNextDelay() {
    // Base exponential backoff
    final baseDelay = (_currentReconnectDelay.inMilliseconds * config.backoffMultiplier).toInt();

    // Calculate jitter range (using decorrelated jitter)
    final jitterRange = (baseDelay * config.jitterFactor).toInt();

    // Generate random jitter using a simple PRNG seeded with current time
    // This avoids thundering herd problem when multiple clients reconnect
    final random = DateTime.now().microsecondsSinceEpoch % 1000;
    final jitter = ((random / 1000.0) * jitterRange * 2 - jitterRange).toInt();

    // Apply jitter to base delay
    final delayMs = (baseDelay + jitter).clamp(
      config.reconnectDelay.inMilliseconds,
      config.maxReconnectDelay.inMilliseconds,
    );

    debugPrint('[WebSocket] Next reconnect delay: ${delayMs}ms (base: ${baseDelay}ms, jitter: ${jitter}ms)');

    return Duration(milliseconds: delayMs);
  }

  /// Reset reconnection state (call after successful reconnect if needed)
  void resetReconnectionState() {
    _reconnectAttempts = 0;
    _currentReconnectDelay = config.reconnectDelay;
  }

  void _startPingTimer() {
    if (config.pingInterval == null) return;

    _stopPingTimer();
    _pingTimer = Timer.periodic(config.pingInterval!, (_) {
      if (isConnected) {
        sendEvent('ping');
      }
    });
  }

  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  void _setState(WebSocketState newState) {
    if (_isDisposed) return;

    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
    }
  }

  /// Whether the client has been disposed
  bool get isDisposed => _isDisposed;

  /// Dispose the client and release resources
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    _cancelReconnect();
    _stopPingTimer();

    await _subscription?.cancel();
    _subscription = null;

    try {
      await _channel?.sink.close(status.normalClosure);
    } catch (e) {
      debugPrint('[WebSocket] Error closing channel during dispose: $e');
    }
    _channel = null;

    await _stateController.close();
    await _messageController.close();
    await _eventController.close();
    await _errorController.close();
  }
}

/// Convenience mixin for widgets that use WebSocket
mixin WebSocketMixin<T extends StatefulWidget> on State<T> {
  WebSocketClient? _webSocket;
  final List<StreamSubscription> _webSocketSubscriptions = [];

  /// Initialize WebSocket connection
  void initWebSocket({
    required String url,
    WebSocketConfig config = const WebSocketConfig(),
    Map<String, String>? headers,
    void Function(WebSocketState state)? onStateChanged,
    void Function(dynamic message)? onMessage,
    void Function(WebSocketEvent event)? onEvent,
    void Function(dynamic error)? onError,
  }) {
    _webSocket = WebSocketClient(
      url: url,
      config: config,
      headers: headers,
    );

    if (onStateChanged != null) {
      _webSocketSubscriptions.add(
        _webSocket!.stateStream.listen(onStateChanged),
      );
    }

    if (onMessage != null) {
      _webSocketSubscriptions.add(
        _webSocket!.messageStream.listen(onMessage),
      );
    }

    if (onEvent != null) {
      _webSocketSubscriptions.add(
        _webSocket!.eventStream.listen(onEvent),
      );
    }

    if (onError != null) {
      _webSocketSubscriptions.add(
        _webSocket!.errorStream.listen(onError),
      );
    }

    _webSocket!.connect();
  }

  /// Get the WebSocket client
  WebSocketClient? get webSocket => _webSocket;

  /// Dispose WebSocket resources
  void disposeWebSocket() {
    for (final sub in _webSocketSubscriptions) {
      sub.cancel();
    }
    _webSocketSubscriptions.clear();
    _webSocket?.dispose();
    _webSocket = null;
  }
}

/// WebSocket manager for managing multiple connections
class WebSocketManager {
  static final WebSocketManager _instance = WebSocketManager._internal();
  factory WebSocketManager() => _instance;
  WebSocketManager._internal();

  static WebSocketManager get instance => _instance;

  final Map<String, WebSocketClient> _clients = {};

  /// Maximum number of WebSocket clients to manage (prevents unbounded growth)
  static const int maxClients = 20;

  /// Current number of managed clients
  int get clientCount => _clients.length;

  /// Get or create a WebSocket client for a URL
  /// If autoConnect is true (default), will automatically connect if not already connected
  WebSocketClient getClient(
    String url, {
    WebSocketConfig config = const WebSocketConfig(),
    Map<String, String>? headers,
    bool autoConnect = true,
  }) {
    // Check if we need to clean up before adding a new client
    if (!_clients.containsKey(url) && _clients.length >= maxClients) {
      _cleanupDisposedClients();
      // If still at limit, remove oldest disconnected client
      if (_clients.length >= maxClients) {
        _removeOldestDisconnected();
      }
    }

    final client = _clients.putIfAbsent(
      url,
      () => WebSocketClient(url: url, config: config, headers: headers),
    );

    // Auto-connect if requested and not already connected/connecting
    if (autoConnect && !client.isConnected && !client.isConnecting && !client.isDisposed) {
      client.connect();
    }

    return client;
  }

  /// Get an existing client without creating a new one
  /// Returns null if no client exists for the URL
  WebSocketClient? getExistingClient(String url) {
    return _clients[url];
  }

  /// Ensure a client is connected, creating it if necessary
  /// Returns true if connected successfully, false otherwise
  Future<bool> ensureConnected(
    String url, {
    WebSocketConfig config = const WebSocketConfig(),
    Map<String, String>? headers,
  }) async {
    final client = getClient(url, config: config, headers: headers, autoConnect: false);

    if (client.isConnected) return true;
    if (client.isDisposed) return false;

    return client.connect();
  }

  /// Check if a client exists for a URL
  bool hasClient(String url) => _clients.containsKey(url);

  /// Remove and dispose a client
  Future<void> removeClient(String url) async {
    final client = _clients.remove(url);
    await client?.dispose();
  }

  /// Dispose all clients
  Future<void> disposeAll() async {
    final futures = _clients.values.map((client) => client.dispose());
    await Future.wait(futures);
    _clients.clear();
  }

  /// Get all connected client URLs
  List<String> get connectedUrls =>
      _clients.entries
          .where((e) => e.value.isConnected)
          .map((e) => e.key)
          .toList();

  /// Remove all disposed clients from the registry
  void _cleanupDisposedClients() {
    final disposedUrls = _clients.entries
        .where((e) => e.value.isDisposed)
        .map((e) => e.key)
        .toList();

    for (final url in disposedUrls) {
      _clients.remove(url);
    }

    if (disposedUrls.isNotEmpty) {
      debugPrint('[WebSocketManager] Cleaned up ${disposedUrls.length} disposed clients');
    }
  }

  /// Remove the oldest disconnected client to make room
  void _removeOldestDisconnected() {
    // Find disconnected clients first
    final disconnected = _clients.entries
        .where((e) => !e.value.isConnected && !e.value.isConnecting)
        .toList();

    if (disconnected.isNotEmpty) {
      final url = disconnected.first.key;
      final client = _clients.remove(url);
      client?.dispose();
      debugPrint('[WebSocketManager] Removed disconnected client to make room: $url');
    }
  }

  /// Clean up disconnected and disposed clients manually
  Future<void> cleanup() async {
    _cleanupDisposedClients();

    // Also remove clients that have been disconnected for a while
    final disconnectedUrls = _clients.entries
        .where((e) => e.value.state == WebSocketState.disconnected)
        .map((e) => e.key)
        .toList();

    for (final url in disconnectedUrls) {
      await removeClient(url);
    }
  }
}
