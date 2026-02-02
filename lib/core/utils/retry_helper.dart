// Retry Helper
//
// Utility for retrying failed operations with exponential backoff.

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/app_error.dart';
import '../services/error_handler.dart';

/// Configuration for retry behavior
class RetryConfig {
  final int maxAttempts;
  final Duration initialDelay;
  final double backoffMultiplier;
  final Duration maxDelay;
  final bool useJitter;

  const RetryConfig({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(seconds: 30),
    this.useJitter = true,
  });

  /// Quick retry for UI actions (2 attempts, short delays)
  static const quick = RetryConfig(
    maxAttempts: 2,
    initialDelay: Duration(milliseconds: 500),
    backoffMultiplier: 1.5,
    maxDelay: Duration(seconds: 2),
  );

  /// Standard retry for API calls
  static const standard = RetryConfig(
    maxAttempts: 3,
    initialDelay: Duration(seconds: 1),
    backoffMultiplier: 2.0,
    maxDelay: Duration(seconds: 10),
  );

  /// Aggressive retry for critical operations
  static const aggressive = RetryConfig(
    maxAttempts: 5,
    initialDelay: Duration(seconds: 2),
    backoffMultiplier: 2.0,
    maxDelay: Duration(seconds: 30),
  );
}

/// Result of a retry operation
class RetryResult<T> {
  final T? data;
  final AppError? error;
  final int attemptsMade;
  final bool success;

  const RetryResult._({
    this.data,
    this.error,
    required this.attemptsMade,
    required this.success,
  });

  factory RetryResult.success(T data, int attempts) {
    return RetryResult._(
      data: data,
      attemptsMade: attempts,
      success: true,
    );
  }

  factory RetryResult.failure(AppError error, int attempts) {
    return RetryResult._(
      error: error,
      attemptsMade: attempts,
      success: false,
    );
  }
}

/// Retry helper for handling transient failures
class RetryHelper {
  static final _random = Random();

  /// Retry an async operation with exponential backoff
  ///
  /// Example:
  /// ```dart
  /// final result = await RetryHelper.retry(
  ///   () => api.fetchData(),
  ///   config: RetryConfig.standard,
  ///   onRetry: (attempt, error) => print('Retrying... attempt $attempt'),
  /// );
  /// ```
  static Future<RetryResult<T>> retry<T>(
    Future<T> Function() operation, {
    RetryConfig config = const RetryConfig(),
    bool Function(dynamic error)? shouldRetry,
    void Function(int attempt, dynamic error)? onRetry,
  }) async {
    int attempt = 0;
    dynamic lastError;
    StackTrace? lastStackTrace;

    while (attempt < config.maxAttempts) {
      attempt++;
      try {
        final result = await operation();
        return RetryResult.success(result, attempt);
      } catch (e, st) {
        lastError = e;
        lastStackTrace = st;

        // Check if we should retry this error
        final canRetry = shouldRetry?.call(e) ?? _isRetryable(e);

        if (!canRetry || attempt >= config.maxAttempts) {
          break;
        }

        // Calculate delay with exponential backoff
        final delay = _calculateDelay(attempt, config);

        if (kDebugMode) {
          debugPrint(
            '[RetryHelper] Attempt $attempt failed, retrying in ${delay.inMilliseconds}ms: $e',
          );
        }

        onRetry?.call(attempt, e);

        await Future.delayed(delay);
      }
    }

    // All retries exhausted
    final appError = ErrorHandler.toAppError(lastError, lastStackTrace);
    return RetryResult.failure(appError, attempt);
  }

  /// Retry and return the result directly, throwing on failure
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   final data = await RetryHelper.retryOrThrow(() => api.fetchData());
  /// } catch (e) {
  ///   // Handle error
  /// }
  /// ```
  static Future<T> retryOrThrow<T>(
    Future<T> Function() operation, {
    RetryConfig config = const RetryConfig(),
    bool Function(dynamic error)? shouldRetry,
    void Function(int attempt, dynamic error)? onRetry,
  }) async {
    final result = await retry<T>(
      operation,
      config: config,
      shouldRetry: shouldRetry,
      onRetry: onRetry,
    );

    if (result.success) {
      return result.data as T;
    }

    throw result.error!;
  }

  /// Retry with a simple callback pattern
  ///
  /// Example:
  /// ```dart
  /// await RetryHelper.retryAsync(
  ///   operation: () => api.fetchData(),
  ///   onSuccess: (data) => setState(() => _data = data),
  ///   onError: (error) => showError(error.message),
  /// );
  /// ```
  static Future<void> retryAsync<T>({
    required Future<T> Function() operation,
    required void Function(T data) onSuccess,
    required void Function(AppError error) onError,
    RetryConfig config = const RetryConfig(),
    void Function(int attempt)? onRetrying,
  }) async {
    final result = await retry<T>(
      operation,
      config: config,
      onRetry: (attempt, _) => onRetrying?.call(attempt),
    );

    if (result.success) {
      onSuccess(result.data as T);
    } else {
      onError(result.error!);
    }
  }

  /// Check if an error is typically retryable
  static bool _isRetryable(dynamic error) {
    // Network errors are retryable
    if (error is SocketException) return true;
    if (error is TimeoutException) return true;

    // AppError has its own retryable flag
    if (error is AppError) return error.isRetryable;

    // HTTP errors - retry 5xx, don't retry 4xx
    if (error is Exception) {
      final message = error.toString().toLowerCase();
      if (message.contains('5')) return true; // 500, 502, 503, etc.
      if (message.contains('timeout')) return true;
      if (message.contains('connection')) return true;
    }

    return false;
  }

  /// Calculate delay with exponential backoff and optional jitter
  static Duration _calculateDelay(int attempt, RetryConfig config) {
    // Exponential backoff: delay = initialDelay * (multiplier ^ (attempt - 1))
    final exponentialDelay = config.initialDelay.inMilliseconds *
        pow(config.backoffMultiplier, attempt - 1);

    // Cap at max delay
    var delayMs = min(exponentialDelay.toInt(), config.maxDelay.inMilliseconds);

    // Add jitter (±25%) to prevent thundering herd
    if (config.useJitter) {
      final jitter = (delayMs * 0.25 * (2 * _random.nextDouble() - 1)).toInt();
      delayMs = max(0, delayMs + jitter);
    }

    return Duration(milliseconds: delayMs);
  }
}

/// Extension to add retry capability to Futures
extension RetryExtension<T> on Future<T> Function() {
  /// Retry this future with the given config
  Future<RetryResult<T>> withRetry({
    RetryConfig config = const RetryConfig(),
    bool Function(dynamic error)? shouldRetry,
    void Function(int attempt, dynamic error)? onRetry,
  }) {
    return RetryHelper.retry(
      this,
      config: config,
      shouldRetry: shouldRetry,
      onRetry: onRetry,
    );
  }
}
