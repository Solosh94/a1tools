/// Unified API Client
///
/// Centralized HTTP client for all API communication.
/// Provides consistent error handling, timeouts, logging, and response parsing.
///
/// ## Usage
///
/// ```dart
/// // GET request
/// final response = await ApiClient.instance.get('https://api.example.com/data');
/// if (response.success) {
///   final data = response.rawJson;
/// }
///
/// // POST request with body
/// final response = await ApiClient.instance.post(
///   'https://api.example.com/data',
///   body: {'key': 'value'},
/// );
/// ```
///
/// ## Features
///
/// - Automatic JSON parsing and error extraction
/// - Configurable timeouts (default 30s, uploads 120s)
/// - Request/response logging in debug mode
/// - Sensitive data sanitization in logs
/// - Header interceptors for auth tokens
/// - Unified [AppError] integration
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/app_error.dart';

/// Response wrapper for all API calls.
///
/// Contains the parsed response data, status code, and any error information.
/// Use [success] to check if the request was successful before accessing [data].
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final int statusCode;
  final Map<String, dynamic>? rawJson;
  final AppError? error;

  const ApiResponse({
    required this.success,
    this.data,
    this.message,
    required this.statusCode,
    this.rawJson,
    this.error,
  });

  /// Create a success response
  factory ApiResponse.success(T data, {int statusCode = 200, Map<String, dynamic>? rawJson}) {
    return ApiResponse(
      success: true,
      data: data,
      statusCode: statusCode,
      rawJson: rawJson,
    );
  }

  /// Create an error response
  factory ApiResponse.error(String message, {int statusCode = 0, AppError? appError}) {
    return ApiResponse(
      success: false,
      message: message,
      statusCode: statusCode,
      error: appError,
    );
  }

  /// Create an error response from AppError
  factory ApiResponse.fromError(AppError error) {
    return ApiResponse(
      success: false,
      message: error.message,
      statusCode: error.statusCode ?? 0,
      error: error,
    );
  }
}

/// Exception for API-related errors.
///
/// Thrown when an API request fails due to network issues, server errors,
/// or invalid responses. Contains the original error for debugging.
class ApiException implements Exception {
  /// Human-readable error message.
  final String message;

  /// HTTP status code if available, null for network errors.
  final int? statusCode;

  /// The original exception that caused this error.
  final dynamic originalError;

  const ApiException(this.message, {this.statusCode, this.originalError});

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}

/// Unified API Client - singleton for all HTTP communication.
///
/// Access via [ApiClient.instance]. Provides methods for all HTTP verbs
/// with automatic JSON parsing, error handling, and logging.
///
/// ## Configuration
///
/// ```dart
/// ApiClient.instance.defaultTimeout = Duration(seconds: 60);
/// ApiClient.instance.enableLogging = false;
/// ApiClient.instance.onGetHeaders = () async => {'Authorization': 'Bearer $token'};
/// ```
/// Configuration for retry behavior
class RetryConfig {
  /// Maximum number of retry attempts (0 = no retry)
  final int maxAttempts;

  /// Initial delay between retries
  final Duration initialDelay;

  /// Maximum delay between retries (for exponential backoff)
  final Duration maxDelay;

  /// Multiplier for exponential backoff
  final double backoffMultiplier;

  /// HTTP status codes that should trigger a retry
  final Set<int> retryStatusCodes;

  const RetryConfig({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 10),
    this.backoffMultiplier = 2.0,
    this.retryStatusCodes = const {502, 503, 504, 429},
  });

  /// No retry configuration
  static const none = RetryConfig(maxAttempts: 0);

  /// Default retry configuration
  static const standard = RetryConfig();

  /// Aggressive retry for critical operations
  static const aggressive = RetryConfig(
    maxAttempts: 5,
    initialDelay: Duration(milliseconds: 200),
    maxDelay: Duration(seconds: 30),
  );
}

// ===========================================================================
// CIRCUIT BREAKER PATTERN
// ===========================================================================

/// State of a circuit breaker
enum CircuitState {
  /// Normal operation - requests allowed
  closed,

  /// Circuit tripped - requests blocked
  open,

  /// Testing if service recovered - limited requests allowed
  halfOpen,
}

/// Configuration for circuit breaker behavior
class CircuitBreakerConfig {
  /// Number of failures before opening circuit
  final int failureThreshold;

  /// Time to wait before testing recovery (half-open state)
  final Duration resetTimeout;

  /// Number of successful requests in half-open to close circuit
  final int successThreshold;

  /// HTTP status codes that count as failures
  final Set<int> failureStatusCodes;

  /// Whether to count timeouts as failures
  final bool countTimeoutsAsFailures;

  /// Whether to count network errors as failures
  final bool countNetworkErrorsAsFailures;

  const CircuitBreakerConfig({
    this.failureThreshold = 5,
    this.resetTimeout = const Duration(seconds: 30),
    this.successThreshold = 2,
    this.failureStatusCodes = const {500, 502, 503, 504},
    this.countTimeoutsAsFailures = true,
    this.countNetworkErrorsAsFailures = true,
  });

  /// Default configuration
  static const standard = CircuitBreakerConfig();

  /// Aggressive - trips faster, recovers slower
  static const aggressive = CircuitBreakerConfig(
    failureThreshold: 3,
    resetTimeout: Duration(seconds: 60),
    successThreshold: 3,
  );

  /// Lenient - more tolerant of failures
  static const lenient = CircuitBreakerConfig(
    failureThreshold: 10,
    resetTimeout: Duration(seconds: 15),
    successThreshold: 1,
  );
}

/// Circuit breaker for a specific endpoint/service
class CircuitBreaker {
  final String name;
  final CircuitBreakerConfig config;

  CircuitState _state = CircuitState.closed;
  int _failureCount = 0;
  int _successCount = 0;
  DateTime? _lastFailureTime;
  DateTime? _stateChangedAt;

  CircuitBreaker({
    required this.name,
    this.config = const CircuitBreakerConfig(),
  }) {
    _stateChangedAt = DateTime.now();
  }

  /// Current state of the circuit
  CircuitState get state => _state;

  /// Number of consecutive failures
  int get failureCount => _failureCount;

  /// Number of consecutive successes (in half-open state)
  int get successCount => _successCount;

  /// Time when state last changed
  DateTime? get stateChangedAt => _stateChangedAt;

  /// Check if requests are allowed
  bool get allowRequest {
    switch (_state) {
      case CircuitState.closed:
        return true;

      case CircuitState.open:
        // Check if enough time has passed to try again
        if (_lastFailureTime != null) {
          final elapsed = DateTime.now().difference(_lastFailureTime!);
          if (elapsed >= config.resetTimeout) {
            _transitionTo(CircuitState.halfOpen);
            return true;
          }
        }
        return false;

      case CircuitState.halfOpen:
        return true;
    }
  }

  /// Time remaining until circuit attempts recovery (when open)
  Duration? get timeUntilRetry {
    if (_state != CircuitState.open || _lastFailureTime == null) return null;
    final elapsed = DateTime.now().difference(_lastFailureTime!);
    final remaining = config.resetTimeout - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Record a successful request
  void recordSuccess() {
    switch (_state) {
      case CircuitState.closed:
        // Reset failure count on success
        _failureCount = 0;
        break;

      case CircuitState.halfOpen:
        _successCount++;
        if (_successCount >= config.successThreshold) {
          _transitionTo(CircuitState.closed);
        }
        break;

      case CircuitState.open:
        // Shouldn't happen, but handle gracefully
        break;
    }
  }

  /// Record a failed request
  void recordFailure() {
    _lastFailureTime = DateTime.now();

    switch (_state) {
      case CircuitState.closed:
        _failureCount++;
        if (_failureCount >= config.failureThreshold) {
          _transitionTo(CircuitState.open);
        }
        break;

      case CircuitState.halfOpen:
        // Any failure in half-open returns to open
        _transitionTo(CircuitState.open);
        break;

      case CircuitState.open:
        // Already open, just update timestamp
        break;
    }
  }

  /// Check if a status code should be counted as failure
  bool isFailureStatus(int statusCode) {
    return config.failureStatusCodes.contains(statusCode);
  }

  /// Reset the circuit breaker to closed state
  void reset() {
    _transitionTo(CircuitState.closed);
    _failureCount = 0;
    _successCount = 0;
    _lastFailureTime = null;
  }

  void _transitionTo(CircuitState newState) {
    if (_state != newState) {
      debugPrint('[CircuitBreaker] $name: $_state -> $newState');
      _state = newState;
      _stateChangedAt = DateTime.now();

      if (newState == CircuitState.closed) {
        _failureCount = 0;
        _successCount = 0;
      } else if (newState == CircuitState.halfOpen) {
        _successCount = 0;
      }
    }
  }

  @override
  String toString() {
    return 'CircuitBreaker($name: $_state, failures: $_failureCount)';
  }
}

/// Manager for multiple circuit breakers
class CircuitBreakerRegistry {
  final Map<String, CircuitBreaker> _breakers = {};
  final CircuitBreakerConfig defaultConfig;

  /// Maximum number of circuit breakers to track (prevents unbounded growth)
  final int maxBreakers;

  /// Threshold for automatic cleanup
  final Duration cleanupThreshold;

  /// Timer for periodic cleanup
  Timer? _cleanupTimer;

  CircuitBreakerRegistry({
    this.defaultConfig = const CircuitBreakerConfig(),
    this.maxBreakers = 100,
    this.cleanupThreshold = const Duration(hours: 1),
  }) {
    // Start periodic cleanup every 10 minutes
    _cleanupTimer = Timer.periodic(
      const Duration(minutes: 10),
      (_) => cleanup(inactiveThreshold: cleanupThreshold),
    );
  }

  /// Current number of tracked circuit breakers
  int get count => _breakers.length;

  /// Get or create a circuit breaker for an endpoint
  CircuitBreaker getBreaker(String endpoint, {CircuitBreakerConfig? config}) {
    // Normalize endpoint to domain/path pattern
    final key = _normalizeEndpoint(endpoint);

    // Check if we need to evict before adding new breaker
    if (!_breakers.containsKey(key) && _breakers.length >= maxBreakers) {
      _evictOldestClosed();
    }

    return _breakers.putIfAbsent(
      key,
      () => CircuitBreaker(name: key, config: config ?? defaultConfig),
    );
  }

  /// Evict the oldest closed circuit breaker to make room
  void _evictOldestClosed() {
    String? oldestKey;
    DateTime? oldestTime;

    for (final entry in _breakers.entries) {
      // Only evict closed breakers
      if (entry.value.state != CircuitState.closed) continue;

      final changedAt = entry.value.stateChangedAt;
      if (changedAt != null && (oldestTime == null || changedAt.isBefore(oldestTime))) {
        oldestKey = entry.key;
        oldestTime = changedAt;
      }
    }

    if (oldestKey != null) {
      _breakers.remove(oldestKey);
      debugPrint('[CircuitBreakerRegistry] Evicted oldest breaker: $oldestKey (limit: $maxBreakers)');
    }
  }

  /// Check if a request to an endpoint is allowed
  bool allowRequest(String endpoint) {
    final breaker = _breakers[_normalizeEndpoint(endpoint)];
    return breaker?.allowRequest ?? true;
  }

  /// Record success for an endpoint
  void recordSuccess(String endpoint) {
    final breaker = _breakers[_normalizeEndpoint(endpoint)];
    breaker?.recordSuccess();
  }

  /// Record failure for an endpoint
  void recordFailure(String endpoint) {
    final breaker = _breakers[_normalizeEndpoint(endpoint)];
    breaker?.recordFailure();
  }

  /// Get status of all circuit breakers
  Map<String, CircuitState> get allStates {
    return _breakers.map((key, breaker) => MapEntry(key, breaker.state));
  }

  /// Get all open circuits
  List<String> get openCircuits {
    return _breakers.entries
        .where((e) => e.value.state == CircuitState.open)
        .map((e) => e.key)
        .toList();
  }

  /// Reset all circuit breakers
  void resetAll() {
    for (final breaker in _breakers.values) {
      breaker.reset();
    }
  }

  /// Reset a specific circuit breaker
  void reset(String endpoint) {
    final breaker = _breakers[_normalizeEndpoint(endpoint)];
    breaker?.reset();
  }

  /// Normalize endpoint to a consistent key
  String _normalizeEndpoint(String endpoint) {
    try {
      final uri = Uri.parse(endpoint);
      // Group by host + first path segment (e.g., "api.example.com/users")
      final pathSegments = uri.pathSegments;
      final firstSegment = pathSegments.isNotEmpty ? '/${pathSegments.first}' : '';
      return '${uri.host}$firstSegment';
    } catch (_) {
      return endpoint;
    }
  }

  /// Remove inactive circuit breakers (cleanup)
  void cleanup({Duration inactiveThreshold = const Duration(hours: 1)}) {
    final now = DateTime.now();
    final beforeCount = _breakers.length;
    _breakers.removeWhere((key, breaker) {
      if (breaker.state != CircuitState.closed) return false;
      final lastChange = breaker.stateChangedAt;
      if (lastChange == null) return false;
      return now.difference(lastChange) > inactiveThreshold;
    });
    final removed = beforeCount - _breakers.length;
    if (removed > 0) {
      debugPrint('[CircuitBreakerRegistry] Cleaned up $removed inactive breakers');
    }
  }

  /// Dispose the registry and stop cleanup timer
  void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _breakers.clear();
  }
}

/// Exception thrown when circuit breaker is open
class CircuitBreakerOpenException implements Exception {
  final String endpoint;
  final Duration? timeUntilRetry;

  const CircuitBreakerOpenException(this.endpoint, {this.timeUntilRetry});

  @override
  String toString() {
    final retryInfo = timeUntilRetry != null
        ? ' (retry in ${timeUntilRetry!.inSeconds}s)'
        : '';
    return 'CircuitBreakerOpenException: Service temporarily unavailable$retryInfo';
  }
}

class ApiClient {
  ApiClient._();

  static final ApiClient _instance = ApiClient._();
  static ApiClient get instance => _instance;

  final http.Client _client = http.Client();

  // Configuration
  Duration defaultTimeout = const Duration(seconds: 30);
  Duration uploadTimeout = const Duration(seconds: 120);
  bool enableLogging = kDebugMode;

  /// Default retry configuration for all requests
  RetryConfig defaultRetryConfig = RetryConfig.standard;

  /// Circuit breaker registry for managing endpoint health
  final CircuitBreakerRegistry circuitBreakers = CircuitBreakerRegistry();

  /// Whether to enable circuit breaker pattern (default: true)
  bool enableCircuitBreaker = true;

  /// Default circuit breaker configuration
  CircuitBreakerConfig defaultCircuitBreakerConfig = CircuitBreakerConfig.standard;

  // Request interceptor callback (optional)
  Future<Map<String, String>> Function()? onGetHeaders;

  // Error interceptor callback (optional) - legacy
  void Function(ApiException error)? onError;

  // AppError callback (optional) - new unified error system
  void Function(AppError error)? onAppError;

  /// Callback when circuit breaker opens
  void Function(String endpoint)? onCircuitOpen;

  /// Callback when circuit breaker closes (recovered)
  void Function(String endpoint)? onCircuitClose;

  /// Default headers for all requests (including API versioning)
  Map<String, String> get _defaultHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-API-Version': '1.0',
        'Accept-Version': '1.0',
        'X-Client-Platform': 'flutter',
      };

  /// Merge default headers with custom headers
  Future<Map<String, String>> _buildHeaders([Map<String, String>? customHeaders]) async {
    final headers = Map<String, String>.from(_defaultHeaders);

    // Add headers from interceptor if provided
    if (onGetHeaders != null) {
      final interceptorHeaders = await onGetHeaders!();
      headers.addAll(interceptorHeaders);
    }

    // Add custom headers
    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }

    return headers;
  }

  /// Log request details
  void _logRequest(String method, String url, {dynamic body}) {
    if (!enableLogging) return;
    debugPrint('[ApiClient] $method $url');
    if (body != null && body is Map && body.isNotEmpty) {
      // Don't log sensitive data
      final sanitized = Map.from(body);
      if (sanitized.containsKey('password')) sanitized['password'] = '***';
      if (sanitized.containsKey('pin')) sanitized['pin'] = '***';
      debugPrint('[ApiClient] Body: $sanitized');
    }
  }

  /// Log response details
  void _logResponse(String method, String url, int statusCode, String body) {
    if (!enableLogging) return;
    final truncated = body.length > 500 ? '${body.substring(0, 500)}...' : body;
    debugPrint('[ApiClient] $method $url -> $statusCode');
    debugPrint('[ApiClient] Response: $truncated');
  }

  /// Handle and log errors - returns both ApiException and AppError
  ({ApiException apiException, AppError appError}) _handleError(
    dynamic error,
    String url, [
    StackTrace? stackTrace,
  ]) {
    ApiException apiException;
    AppError appError;

    if (error is SocketException) {
      apiException = ApiException(
        'No internet connection',
        originalError: error,
      );
      appError = AppError.noInternet(
        originalException: error,
        stackTrace: stackTrace,
      );
    } else if (error is TimeoutException) {
      apiException = ApiException(
        'Request timed out',
        originalError: error,
      );
      appError = AppError.timeout(
        originalException: error,
        stackTrace: stackTrace,
      );
    } else if (error is http.ClientException) {
      apiException = ApiException(
        'Network error: ${error.message}',
        originalError: error,
      );
      appError = AppError.network(
        details: error.message,
        originalException: error,
        stackTrace: stackTrace,
      );
    } else if (error is FormatException) {
      apiException = ApiException(
        'Invalid response format',
        originalError: error,
      );
      appError = AppError.parse(
        details: error.message,
        originalException: error,
        stackTrace: stackTrace,
      );
    } else {
      apiException = ApiException(
        error.toString(),
        originalError: error,
      );
      appError = AppError.unknown(
        message: error.toString(),
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    if (enableLogging) {
      debugPrint('[ApiClient] Error for $url: ${apiException.message}');
    }

    // Call error interceptor if provided
    onError?.call(apiException);
    onAppError?.call(appError);

    return (apiException: apiException, appError: appError);
  }

  /// Create AppError from HTTP status code response
  AppError _createAppErrorFromStatus(int statusCode, String message) {
    return AppError.fromStatusCode(
      statusCode,
      message: message,
    );
  }

  /// Parse response body as JSON
  Map<String, dynamic>? _parseJson(String body) {
    try {
      if (body.isEmpty) return null;
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Check if response indicates success based on common patterns
  ///
  /// Precedence rules for conflicting indicators:
  /// 1. HTTP status code must be 2xx (required)
  /// 2. 'success' field takes highest priority if present
  /// 3. 'error' field with a truthy string value indicates failure
  /// 4. 'status' field checked as secondary indicator
  /// 5. If no indicators present, 2xx status code means success
  bool _isSuccessResponse(Map<String, dynamic>? json, int statusCode) {
    // HTTP status must be 2xx
    if (statusCode < 200 || statusCode >= 300) return false;

    // No JSON body - rely on HTTP status code
    if (json == null) return true;

    // Priority 1: Explicit 'success' field (highest priority)
    if (json.containsKey('success')) {
      return json['success'] == true;
    }

    // Priority 2: 'error' field with string message indicates failure
    // (takes precedence over 'status' field)
    if (json.containsKey('error')) {
      final error = json['error'];
      // String error message = failure
      if (error is String && error.isNotEmpty) return false;
      // Boolean or null error field
      if (error == true) return false;
      if (error == false || error == null) return true;
    }

    // Priority 3: 'status' field as secondary indicator
    if (json.containsKey('status')) {
      final status = json['status'];
      if (status == 'success' || status == 'ok') return true;
      if (status == 'error' || status == 'fail' || status == 'failed') return false;
    }

    // Default: 2xx status code means success
    return true;
  }

  /// Extract error message from response
  String _extractErrorMessage(Map<String, dynamic>? json, int statusCode) {
    if (json != null) {
      if (json.containsKey('message')) return json['message'].toString();
      if (json.containsKey('error') && json['error'] is String) return json['error'];
      if (json.containsKey('errors') && json['errors'] is List) {
        return (json['errors'] as List).join(', ');
      }
    }

    // Default messages based on status code
    switch (statusCode) {
      case 400: return 'Bad request';
      case 401: return 'Unauthorized';
      case 403: return 'Forbidden';
      case 404: return 'Not found';
      case 500: return 'Server error';
      default: return 'Request failed (status $statusCode)';
    }
  }

  // ===========================================================================
  // RETRY HELPER
  // ===========================================================================

  /// Determine if a response should be retried based on status code
  bool _shouldRetry(int statusCode, RetryConfig config) {
    return config.retryStatusCodes.contains(statusCode);
  }

  /// Determine if an error should trigger a retry
  bool _shouldRetryError(dynamic error) {
    return error is SocketException || error is TimeoutException;
  }

  /// Calculate delay for retry attempt with exponential backoff and jitter
  Duration _calculateRetryDelay(int attempt, RetryConfig config) {
    final baseDelay = config.initialDelay.inMilliseconds *
        (config.backoffMultiplier * attempt).toInt();
    // Add jitter (±10% of base delay)
    final jitter = (baseDelay * 0.1 * (DateTime.now().millisecond % 20 - 10) / 10).toInt();
    final delayMs = (baseDelay + jitter).clamp(
      config.initialDelay.inMilliseconds,
      config.maxDelay.inMilliseconds,
    );
    return Duration(milliseconds: delayMs);
  }

  /// Execute a request with retry logic and circuit breaker
  ///
  /// Safety: Even with misconfigured retry settings, this will never loop
  /// more than [_absoluteMaxAttempts] times to prevent infinite loops.
  static const int _absoluteMaxAttempts = 10;

  Future<ApiResponse<Map<String, dynamic>>> _executeWithRetry(
    String method,
    String url,
    Future<http.Response> Function() requestFn,
    RetryConfig? retryConfig, {
    bool useCircuitBreaker = true,
  }) async {
    final config = retryConfig ?? defaultRetryConfig;
    int attempt = 0;
    int totalIterations = 0;

    // Check circuit breaker before attempting request
    if (enableCircuitBreaker && useCircuitBreaker) {
      final breaker = circuitBreakers.getBreaker(url, config: defaultCircuitBreakerConfig);
      if (!breaker.allowRequest) {
        if (enableLogging) {
          debugPrint('[ApiClient] Circuit breaker OPEN for $url (retry in ${breaker.timeUntilRetry?.inSeconds}s)');
        }
        return ApiResponse.error(
          'Service temporarily unavailable',
          statusCode: 503,
          appError: AppError.serviceUnavailable(
            details: 'Circuit breaker open for this service',
          ),
        );
      }
    }

    while (true) {
      // Safety guard: absolute maximum iterations to prevent infinite loops
      totalIterations++;
      if (totalIterations > _absoluteMaxAttempts) {
        if (enableLogging) {
          debugPrint('[ApiClient] SAFETY: Reached absolute max attempts ($_absoluteMaxAttempts) for $url');
        }
        _recordCircuitBreakerFailure(url);
        return ApiResponse.error(
          'Request failed after maximum retry attempts',
          statusCode: 0,
          appError: AppError.network(details: 'Exceeded maximum retry attempts'),
        );
      }

      try {
        final response = await requestFn();
        _logResponse(method, url, response.statusCode, response.body);

        final json = _parseJson(response.body);
        final success = _isSuccessResponse(json, response.statusCode);

        if (success) {
          _recordCircuitBreakerSuccess(url);
          return ApiResponse.success(
            json ?? {},
            statusCode: response.statusCode,
            rawJson: json,
          );
        } else {
          // Check if this is a circuit breaker failure status
          if (enableCircuitBreaker && useCircuitBreaker) {
            final breaker = circuitBreakers.getBreaker(url);
            if (breaker.isFailureStatus(response.statusCode)) {
              _recordCircuitBreakerFailure(url);
            }
          }

          // Check if we should retry this status code
          if (config.maxAttempts > 0 &&
              attempt < config.maxAttempts &&
              _shouldRetry(response.statusCode, config)) {
            attempt++;
            final delay = _calculateRetryDelay(attempt, config);
            if (enableLogging) {
              debugPrint('[ApiClient] Retry $attempt/${config.maxAttempts} for $url after ${delay.inMilliseconds}ms (status: ${response.statusCode})');
            }
            await Future.delayed(delay);
            continue;
          }

          final message = _extractErrorMessage(json, response.statusCode);
          return ApiResponse.error(
            message,
            statusCode: response.statusCode,
            appError: _createAppErrorFromStatus(response.statusCode, message),
          );
        }
      } catch (e, st) {
        // Record circuit breaker failure for timeouts and network errors
        if (enableCircuitBreaker && useCircuitBreaker) {
          final breaker = circuitBreakers.getBreaker(url);
          if ((e is TimeoutException && breaker.config.countTimeoutsAsFailures) ||
              (e is SocketException && breaker.config.countNetworkErrorsAsFailures)) {
            _recordCircuitBreakerFailure(url);
          }
        }

        // Check if we should retry this error
        if (config.maxAttempts > 0 &&
            attempt < config.maxAttempts &&
            _shouldRetryError(e)) {
          attempt++;
          final delay = _calculateRetryDelay(attempt, config);
          if (enableLogging) {
            debugPrint('[ApiClient] Retry $attempt/${config.maxAttempts} for $url after ${delay.inMilliseconds}ms (error: $e)');
          }
          await Future.delayed(delay);
          continue;
        }

        final error = _handleError(e, url, st);
        return ApiResponse.error(
          error.apiException.message,
          statusCode: error.apiException.statusCode ?? 0,
          appError: error.appError,
        );
      }
    }
  }

  /// Record a successful request for circuit breaker
  void _recordCircuitBreakerSuccess(String url) {
    if (!enableCircuitBreaker) return;
    final breaker = circuitBreakers.getBreaker(url);
    final wasOpen = breaker.state == CircuitState.halfOpen;
    breaker.recordSuccess();
    if (wasOpen && breaker.state == CircuitState.closed) {
      onCircuitClose?.call(url);
    }
  }

  /// Record a failed request for circuit breaker
  void _recordCircuitBreakerFailure(String url) {
    if (!enableCircuitBreaker) return;
    final breaker = circuitBreakers.getBreaker(url);
    final wasClosed = breaker.state != CircuitState.open;
    breaker.recordFailure();
    if (wasClosed && breaker.state == CircuitState.open) {
      if (enableLogging) {
        debugPrint('[ApiClient] Circuit breaker OPENED for $url after ${breaker.failureCount} failures');
      }
      onCircuitOpen?.call(url);
    }
  }

  // ===========================================================================
  // HTTP METHODS
  // ===========================================================================

  /// Perform a GET request
  Future<ApiResponse<Map<String, dynamic>>> get(
    String url, {
    Map<String, String>? headers,
    Duration? timeout,
    RetryConfig? retryConfig,
  }) async {
    _logRequest('GET', url);

    return _executeWithRetry(
      'GET',
      url,
      () async => _client
          .get(Uri.parse(url), headers: await _buildHeaders(headers))
          .timeout(timeout ?? defaultTimeout),
      retryConfig,
    );
  }

  /// Perform a POST request with JSON body
  Future<ApiResponse<Map<String, dynamic>>> post(
    String url, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Duration? timeout,
    RetryConfig? retryConfig,
  }) async {
    _logRequest('POST', url, body: body);

    return _executeWithRetry(
      'POST',
      url,
      () async => _client
          .post(
            Uri.parse(url),
            headers: await _buildHeaders(headers),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout ?? defaultTimeout),
      retryConfig,
    );
  }

  /// Perform a POST request with form data (application/x-www-form-urlencoded)
  Future<ApiResponse<Map<String, dynamic>>> postForm(
    String url, {
    required Map<String, String> body,
    Map<String, String>? headers,
    Duration? timeout,
    RetryConfig? retryConfig,
  }) async {
    _logRequest('POST (form)', url, body: body);

    return _executeWithRetry(
      'POST (form)',
      url,
      () async {
        final formHeaders = await _buildHeaders(headers);
        formHeaders['Content-Type'] = 'application/x-www-form-urlencoded';
        return _client
            .post(Uri.parse(url), headers: formHeaders, body: body)
            .timeout(timeout ?? defaultTimeout);
      },
      retryConfig,
    );
  }

  /// Perform a PUT request
  Future<ApiResponse<Map<String, dynamic>>> put(
    String url, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Duration? timeout,
    RetryConfig? retryConfig,
  }) async {
    _logRequest('PUT', url, body: body);

    return _executeWithRetry(
      'PUT',
      url,
      () async => _client
          .put(
            Uri.parse(url),
            headers: await _buildHeaders(headers),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout ?? defaultTimeout),
      retryConfig,
    );
  }

  /// Perform a DELETE request
  Future<ApiResponse<Map<String, dynamic>>> delete(
    String url, {
    Map<String, String>? headers,
    Duration? timeout,
    RetryConfig? retryConfig,
  }) async {
    _logRequest('DELETE', url);

    return _executeWithRetry(
      'DELETE',
      url,
      () async => _client
          .delete(Uri.parse(url), headers: await _buildHeaders(headers))
          .timeout(timeout ?? defaultTimeout),
      retryConfig,
    );
  }

  // ===========================================================================
  // CONVENIENCE METHODS
  // ===========================================================================

  /// Perform GET and return raw response body (for non-JSON responses)
  Future<String?> getRaw(
    String url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    _logRequest('GET (raw)', url);

    try {
      final response = await _client
          .get(Uri.parse(url), headers: await _buildHeaders(headers))
          .timeout(timeout ?? defaultTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.body;
      }
      return null;
    } catch (e) {
      _handleError(e, url);
      return null;
    }
  }

  /// Perform GET and return bytes (for file downloads)
  Future<List<int>?> getBytes(
    String url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    _logRequest('GET (bytes)', url);

    try {
      final response = await _client
          .get(Uri.parse(url), headers: await _buildHeaders(headers))
          .timeout(timeout ?? uploadTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      _handleError(e, url);
      return null;
    }
  }

  /// Check if the server is reachable
  Future<bool> isServerReachable(String url) async {
    try {
      final response = await _client
          .head(Uri.parse(url))
          .timeout(const Duration(seconds: 5));
      return response.statusCode < 500;
    } catch (e) {
      return false;
    }
  }

  /// Dispose the client (call when app is closing)
  void dispose() {
    _client.close();
    circuitBreakers.dispose();
  }
}
