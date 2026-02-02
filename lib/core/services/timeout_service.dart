// Timeout Service
//
// Provides unified timeout handling for async operations across the app.
// Centralizes timeout configuration and provides utilities for common patterns.

import 'dart:async';
import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';

/// Configuration for operation timeouts
class TimeoutConfig {
  /// Network request timeout
  final Duration network;

  /// Short operation timeout (quick API calls)
  final Duration short;

  /// Standard operation timeout
  final Duration standard;

  /// Long operation timeout (uploads, heavy processing)
  final Duration long;

  /// Extra long timeout (bulk operations)
  final Duration extraLong;

  /// UI debounce timeout
  final Duration debounce;

  const TimeoutConfig({
    this.network = const Duration(seconds: NetworkConstants.defaultTimeoutSeconds),
    this.short = const Duration(seconds: NetworkConstants.shortTimeoutSeconds),
    this.standard = const Duration(seconds: NetworkConstants.defaultTimeoutSeconds),
    this.long = const Duration(seconds: NetworkConstants.longTimeoutSeconds),
    this.extraLong = const Duration(seconds: NetworkConstants.uploadTimeoutSeconds),
    this.debounce = const Duration(milliseconds: DebounceConstants.searchDebounceMs),
  });

  /// Default production configuration
  static const production = TimeoutConfig();

  /// Development configuration with longer timeouts
  static const development = TimeoutConfig(
    network: Duration(seconds: 60),
    short: Duration(seconds: 30),
    standard: Duration(seconds: 60),
    long: Duration(seconds: 120),
    extraLong: Duration(seconds: 300),
    debounce: Duration(milliseconds: 500),
  );

  /// Strict configuration for performance testing
  static const strict = TimeoutConfig(
    network: Duration(seconds: 10),
    short: Duration(seconds: 5),
    standard: Duration(seconds: 15),
    long: Duration(seconds: 30),
    extraLong: Duration(seconds: 60),
    debounce: Duration(milliseconds: 200),
  );
}

/// Result of a timed operation
class TimedResult<T> {
  final T? value;
  final Duration elapsed;
  final bool timedOut;
  final Object? error;

  const TimedResult._({
    this.value,
    required this.elapsed,
    this.timedOut = false,
    this.error,
  });

  factory TimedResult.success(T value, Duration elapsed) {
    return TimedResult._(value: value, elapsed: elapsed);
  }

  factory TimedResult.timeout(Duration elapsed) {
    return TimedResult._(elapsed: elapsed, timedOut: true);
  }

  factory TimedResult.failure(Object error, Duration elapsed) {
    return TimedResult._(elapsed: elapsed, error: error);
  }

  bool get isSuccess => value != null && error == null && !timedOut;

  @override
  String toString() {
    if (isSuccess) return 'TimedResult.success(${elapsed.inMilliseconds}ms)';
    if (timedOut) return 'TimedResult.timeout(${elapsed.inMilliseconds}ms)';
    return 'TimedResult.failure($error, ${elapsed.inMilliseconds}ms)';
  }
}

/// Service for managing timeouts and timed operations
class TimeoutService {
  static final TimeoutService _instance = TimeoutService._();
  static TimeoutService get instance => _instance;
  TimeoutService._();

  /// Current timeout configuration
  TimeoutConfig config = kDebugMode ? TimeoutConfig.development : TimeoutConfig.production;

  /// Execute an operation with timeout
  ///
  /// Returns the result or throws TimeoutException if the operation times out.
  Future<T> withTimeout<T>(
    Future<T> Function() operation, {
    Duration? timeout,
    String? operationName,
  }) async {
    final effectiveTimeout = timeout ?? config.standard;
    try {
      return await operation().timeout(
        effectiveTimeout,
        onTimeout: () {
          final message = operationName != null
              ? 'Operation "$operationName" timed out after ${effectiveTimeout.inSeconds}s'
              : 'Operation timed out after ${effectiveTimeout.inSeconds}s';
          throw TimeoutException(message, effectiveTimeout);
        },
      );
    } on TimeoutException {
      rethrow;
    }
  }

  /// Execute an operation with timeout and return detailed result
  Future<TimedResult<T>> timedOperation<T>(
    Future<T> Function() operation, {
    Duration? timeout,
    String? operationName,
  }) async {
    final effectiveTimeout = timeout ?? config.standard;
    final stopwatch = Stopwatch()..start();

    try {
      final result = await operation().timeout(effectiveTimeout);
      stopwatch.stop();
      return TimedResult.success(result, stopwatch.elapsed);
    } on TimeoutException {
      stopwatch.stop();
      if (kDebugMode && operationName != null) {
        debugPrint('[Timeout] "$operationName" timed out after ${stopwatch.elapsedMilliseconds}ms');
      }
      return TimedResult.timeout(stopwatch.elapsed);
    } catch (e) {
      stopwatch.stop();
      if (kDebugMode && operationName != null) {
        debugPrint('[Timeout] "$operationName" failed after ${stopwatch.elapsedMilliseconds}ms: $e');
      }
      return TimedResult.failure(e, stopwatch.elapsed);
    }
  }

  /// Execute operation with timeout and fallback value
  Future<T> withFallback<T>(
    Future<T> Function() operation, {
    required T fallback,
    Duration? timeout,
    String? operationName,
  }) async {
    try {
      return await withTimeout(
        operation,
        timeout: timeout,
        operationName: operationName,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Timeout] Using fallback for "${operationName ?? 'operation'}": $e');
      }
      return fallback;
    }
  }

  /// Execute multiple operations with individual timeouts
  Future<List<TimedResult<T>>> parallel<T>(
    List<Future<T> Function()> operations, {
    Duration? timeout,
    bool stopOnFirstError = false,
  }) async {
    final futures = operations.map((op) => timedOperation(op, timeout: timeout));
    if (stopOnFirstError) {
      return Future.wait(futures);
    } else {
      final results = await Future.wait(
        futures.map((f) => f.catchError(
              (e) => TimedResult<T>.failure(e, Duration.zero),
            )),
      );
      return results;
    }
  }

  /// Race multiple operations, return first to complete
  Future<T> race<T>(
    List<Future<T> Function()> operations, {
    Duration? timeout,
  }) async {
    final effectiveTimeout = timeout ?? config.standard;
    return Future.any(operations.map((op) => op())).timeout(effectiveTimeout);
  }

  /// Create a debounced function
  Function debounce(
    Function callback, {
    Duration? delay,
  }) {
    Timer? timer;
    final effectiveDelay = delay ?? config.debounce;

    return () {
      timer?.cancel();
      timer = Timer(effectiveDelay, () => callback());
    };
  }

  /// Create a throttled function (executes at most once per interval)
  Function throttle(
    Function callback, {
    Duration? interval,
  }) {
    DateTime? lastExecution;
    final effectiveInterval = interval ?? config.debounce;

    return () {
      final now = DateTime.now();
      if (lastExecution == null ||
          now.difference(lastExecution!) >= effectiveInterval) {
        lastExecution = now;
        callback();
      }
    };
  }
}

/// Extension for adding timeout to any Future
extension TimeoutExtension<T> on Future<T> {
  /// Execute with default timeout
  Future<T> withDefaultTimeout() {
    return timeout(TimeoutService.instance.config.standard);
  }

  /// Execute with short timeout
  Future<T> withShortTimeout() {
    return timeout(TimeoutService.instance.config.short);
  }

  /// Execute with long timeout
  Future<T> withLongTimeout() {
    return timeout(TimeoutService.instance.config.long);
  }

  /// Execute with custom timeout and optional operation name for logging
  Future<T> withNamedTimeout(Duration timeout, {String? name}) {
    return TimeoutService.instance.withTimeout(
      () => this,
      timeout: timeout,
      operationName: name,
    );
  }

  /// Execute with timeout and fallback
  Future<T> withFallback(T fallback, {Duration? timeout}) {
    return TimeoutService.instance.withFallback(
      () => this,
      fallback: fallback,
      timeout: timeout,
    );
  }
}

/// Helper for cancellable operations with timeout
class CancellableOperation<T> {
  final Future<T> Function() operation;
  final Duration timeout;
  final String? name;

  bool _isCancelled = false;
  Completer<T>? _completer;

  CancellableOperation({
    required this.operation,
    Duration? timeout,
    this.name,
  }) : timeout = timeout ?? TimeoutService.instance.config.standard;

  bool get isCancelled => _isCancelled;

  Future<T> execute() async {
    if (_isCancelled) {
      throw StateError('Operation was cancelled');
    }

    _completer = Completer<T>();

    try {
      final result = await operation().timeout(timeout);
      if (!_isCancelled && !_completer!.isCompleted) {
        _completer!.complete(result);
      }
      return _completer!.future;
    } on TimeoutException {
      if (!_completer!.isCompleted) {
        _completer!.completeError(
          TimeoutException('${name ?? "Operation"} timed out', timeout),
        );
      }
      rethrow;
    } catch (e) {
      if (!_completer!.isCompleted) {
        _completer!.completeError(e);
      }
      rethrow;
    }
  }

  void cancel() {
    _isCancelled = true;
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.completeError(
        StateError('${name ?? "Operation"} was cancelled'),
      );
    }
  }
}
