// Request Pool Service
//
// Provides request pooling and backpressure for API requests.
// Prevents overwhelming the server with too many concurrent requests,
// especially useful for screenshot uploads during live streaming.

import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';

/// Priority levels for queued requests
enum RequestPriority {
  /// Critical requests (e.g., commands, auth) - processed first
  critical,

  /// High priority (e.g., heartbeats) - processed before normal
  high,

  /// Normal priority (e.g., periodic screenshots)
  normal,

  /// Low priority (e.g., analytics, telemetry) - can be dropped
  low,
}

/// Status of the request pool
enum PoolStatus {
  /// Pool is running normally
  healthy,

  /// Pool is experiencing backpressure
  backpressure,

  /// Pool is overloaded, dropping low priority requests
  overloaded,

  /// Pool is paused
  paused,
}

/// Statistics about the request pool
class PoolStatistics {
  final int activeRequests;
  final int queuedRequests;
  final int completedRequests;
  final int failedRequests;
  final int droppedRequests;
  final int totalProcessed;
  final Duration averageLatency;
  final PoolStatus status;

  const PoolStatistics({
    required this.activeRequests,
    required this.queuedRequests,
    required this.completedRequests,
    required this.failedRequests,
    required this.droppedRequests,
    required this.totalProcessed,
    required this.averageLatency,
    required this.status,
  });

  @override
  String toString() {
    return 'PoolStats(active: $activeRequests, queued: $queuedRequests, '
        'completed: $completedRequests, failed: $failedRequests, '
        'dropped: $droppedRequests, status: $status)';
  }
}

/// A queued request waiting to be processed
class _QueuedRequest<T> {
  final String id;
  final Future<T> Function() requestFn;
  final RequestPriority priority;
  final Duration timeout;
  final DateTime queuedAt;
  final Completer<T> completer;

  _QueuedRequest({
    required this.id,
    required this.requestFn,
    required this.priority,
    required this.timeout,
  })  : queuedAt = DateTime.now(),
        completer = Completer<T>();

  /// Time spent waiting in queue
  Duration get waitTime => DateTime.now().difference(queuedAt);

  /// Whether request has exceeded its timeout while queued
  bool get isExpired => waitTime > timeout;
}

/// Configuration for a request pool
class RequestPoolConfig {
  /// Maximum concurrent requests
  final int maxConcurrent;

  /// Maximum requests in queue before dropping low priority
  final int maxQueueSize;

  /// Default timeout for queued requests
  final Duration defaultTimeout;

  /// Whether to drop low priority requests when overloaded
  final bool dropLowPriorityOnOverload;

  /// Interval for processing queue
  final Duration processInterval;

  const RequestPoolConfig({
    this.maxConcurrent = RequestPoolConstants.maxConcurrentScreenshots,
    this.maxQueueSize = RequestPoolConstants.maxPendingScreenshots,
    this.defaultTimeout = const Duration(
      milliseconds: RequestPoolConstants.requestQueueTimeoutMs,
    ),
    this.dropLowPriorityOnOverload = true,
    this.processInterval = const Duration(milliseconds: 50),
  });

  /// Default configuration for screenshot uploads
  static const screenshots = RequestPoolConfig(
    maxConcurrent: RequestPoolConstants.maxConcurrentScreenshots,
    maxQueueSize: RequestPoolConstants.maxPendingScreenshots,
    defaultTimeout: Duration(
      seconds: RequestPoolConstants.screenshotUploadTimeoutSeconds,
    ),
    dropLowPriorityOnOverload: true,
  );

  /// Configuration for general API requests
  static const api = RequestPoolConfig(
    maxConcurrent: RequestPoolConstants.maxConcurrentRequestsPerEndpoint,
    maxQueueSize: 50,
    defaultTimeout: Duration(seconds: 30),
    dropLowPriorityOnOverload: false,
  );
}

/// Request pool for managing concurrent requests with backpressure
class RequestPool {
  final String name;
  final RequestPoolConfig config;

  final Queue<_QueuedRequest> _queue = Queue();
  final Set<String> _activeRequests = {};

  int _completedCount = 0;
  int _failedCount = 0;
  int _droppedCount = 0;
  int _totalLatencyMs = 0;
  int _latencyCount = 0;

  Timer? _processTimer;
  bool _isPaused = false;

  /// Callback when pool status changes
  void Function(PoolStatus status)? onStatusChange;

  /// Callback when a request is dropped
  void Function(String requestId, RequestPriority priority)? onRequestDropped;

  RequestPool({
    required this.name,
    this.config = const RequestPoolConfig(),
  }) {
    _startProcessing();
  }

  /// Current pool status
  PoolStatus get status {
    if (_isPaused) return PoolStatus.paused;
    if (_queue.length >= config.maxQueueSize) return PoolStatus.overloaded;
    if (_queue.length >= config.maxQueueSize * 0.7) return PoolStatus.backpressure;
    return PoolStatus.healthy;
  }

  /// Pool statistics
  PoolStatistics get statistics => PoolStatistics(
        activeRequests: _activeRequests.length,
        queuedRequests: _queue.length,
        completedRequests: _completedCount,
        failedRequests: _failedCount,
        droppedRequests: _droppedCount,
        totalProcessed: _completedCount + _failedCount,
        averageLatency: _latencyCount > 0
            ? Duration(milliseconds: _totalLatencyMs ~/ _latencyCount)
            : Duration.zero,
        status: status,
      );

  /// Submit a request to the pool
  ///
  /// Returns a Future that completes when the request is processed.
  /// May throw if the request times out or is dropped.
  Future<T> submit<T>(
    String id,
    Future<T> Function() requestFn, {
    RequestPriority priority = RequestPriority.normal,
    Duration? timeout,
  }) async {
    // Check if we should drop this request
    if (status == PoolStatus.overloaded && config.dropLowPriorityOnOverload) {
      if (priority == RequestPriority.low) {
        _droppedCount++;
        onRequestDropped?.call(id, priority);
        throw RequestDroppedException('Request dropped due to overload: $id');
      }
    }

    final request = _QueuedRequest<T>(
      id: id,
      requestFn: requestFn,
      priority: priority,
      timeout: timeout ?? config.defaultTimeout,
    );

    _enqueue(request);
    _processQueue();

    return request.completer.future;
  }

  /// Check if a request can be submitted without queuing
  bool canSubmitImmediately() {
    return _activeRequests.length < config.maxConcurrent;
  }

  /// Pause the pool (stops processing new requests)
  void pause() {
    _isPaused = true;
    onStatusChange?.call(status);
    debugPrint('[RequestPool:$name] Paused');
  }

  /// Resume the pool
  void resume() {
    _isPaused = false;
    onStatusChange?.call(status);
    _processQueue();
    debugPrint('[RequestPool:$name] Resumed');
  }

  /// Clear all queued requests
  void clearQueue() {
    final count = _queue.length;
    while (_queue.isNotEmpty) {
      final request = _queue.removeFirst();
      request.completer.completeError(
        const RequestDroppedException('Queue cleared'),
      );
      _droppedCount++;
    }
    debugPrint('[RequestPool:$name] Cleared $count queued requests');
  }

  /// Dispose the pool
  void dispose() {
    _processTimer?.cancel();
    _processTimer = null;
    clearQueue();
    debugPrint('[RequestPool:$name] Disposed');
  }

  void _enqueue(_QueuedRequest request) {
    // Insert based on priority
    if (request.priority == RequestPriority.critical) {
      // Critical goes to front
      final list = _queue.toList();
      list.insert(0, request);
      _queue.clear();
      _queue.addAll(list);
    } else if (request.priority == RequestPriority.high) {
      // High goes after critical but before others
      final criticalCount =
          _queue.where((r) => r.priority == RequestPriority.critical).length;
      final list = _queue.toList();
      list.insert(criticalCount, request);
      _queue.clear();
      _queue.addAll(list);
    } else {
      // Normal and low go to back
      _queue.add(request);
    }
  }

  void _startProcessing() {
    _processTimer = Timer.periodic(config.processInterval, (_) {
      _processQueue();
      _cleanupExpired();
    });
  }

  void _processQueue() {
    if (_isPaused) return;

    while (_activeRequests.length < config.maxConcurrent && _queue.isNotEmpty) {
      final request = _queue.removeFirst();

      // Skip expired requests
      if (request.isExpired) {
        request.completer.completeError(
          TimeoutException('Request timed out in queue', request.timeout),
        );
        _failedCount++;
        continue;
      }

      _executeRequest(request);
    }

    // Update status if changed
    final currentStatus = status;
    onStatusChange?.call(currentStatus);
  }

  Future<void> _executeRequest(_QueuedRequest request) async {
    _activeRequests.add(request.id);
    final startTime = DateTime.now();

    try {
      final result = await request.requestFn();
      if (!request.completer.isCompleted) {
        request.completer.complete(result);
      }
      _completedCount++;

      // Track latency
      final latency = DateTime.now().difference(startTime);
      _totalLatencyMs += latency.inMilliseconds;
      _latencyCount++;
    } catch (e) {
      if (!request.completer.isCompleted) {
        request.completer.completeError(e);
      }
      _failedCount++;
    } finally {
      _activeRequests.remove(request.id);
    }
  }

  void _cleanupExpired() {
    final expired = _queue.where((r) => r.isExpired).toList();
    for (final request in expired) {
      _queue.remove(request);
      request.completer.completeError(
        TimeoutException('Request timed out in queue'),
      );
      _failedCount++;
    }
  }
}

/// Exception thrown when a request is dropped due to backpressure
class RequestDroppedException implements Exception {
  final String message;
  const RequestDroppedException(this.message);

  @override
  String toString() => 'RequestDroppedException: $message';
}

/// Global request pool registry
class RequestPoolRegistry {
  static final RequestPoolRegistry _instance = RequestPoolRegistry._();
  static RequestPoolRegistry get instance => _instance;
  RequestPoolRegistry._();

  final Map<String, RequestPool> _pools = {};

  /// Get or create a request pool
  RequestPool getPool(String name, {RequestPoolConfig? config}) {
    return _pools.putIfAbsent(
      name,
      () => RequestPool(
        name: name,
        config: config ?? const RequestPoolConfig(),
      ),
    );
  }

  /// Get screenshot upload pool (pre-configured)
  RequestPool get screenshots => getPool(
        'screenshots',
        config: RequestPoolConfig.screenshots,
      );

  /// Get general API pool (pre-configured)
  RequestPool get api => getPool(
        'api',
        config: RequestPoolConfig.api,
      );

  /// Get statistics for all pools
  Map<String, PoolStatistics> get allStatistics {
    return _pools.map((name, pool) => MapEntry(name, pool.statistics));
  }

  /// Dispose all pools
  void disposeAll() {
    for (final pool in _pools.values) {
      pool.dispose();
    }
    _pools.clear();
  }
}
