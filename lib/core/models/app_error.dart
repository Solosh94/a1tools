// App Error Model
//
// Centralized error types and error class for consistent error handling
// across the application.

/// Error categories for classification
enum ErrorType {
  // Network errors
  noInternet,
  timeout,
  networkError,

  // Server errors
  serverError, // 5xx
  unauthorized, // 401
  forbidden, // 403
  notFound, // 404
  badRequest, // 400

  // App errors
  parseError,
  validationError,
  cancelled,

  // Unknown
  unknown,
}

/// Centralized error class for the application
class AppError implements Exception {
  final ErrorType type;
  final String message;
  final String? technicalDetails;
  final int? statusCode;
  final dynamic originalException;
  final StackTrace? stackTrace;

  const AppError({
    required this.type,
    required this.message,
    this.technicalDetails,
    this.statusCode,
    this.originalException,
    this.stackTrace,
  });

  /// Whether this error type is typically retryable
  bool get isRetryable {
    switch (type) {
      case ErrorType.noInternet:
      case ErrorType.timeout:
      case ErrorType.networkError:
      case ErrorType.serverError:
        return true;
      case ErrorType.unauthorized:
      case ErrorType.forbidden:
      case ErrorType.notFound:
      case ErrorType.badRequest:
      case ErrorType.parseError:
      case ErrorType.validationError:
      case ErrorType.cancelled:
      case ErrorType.unknown:
        return false;
    }
  }

  /// Whether this is a network-related error
  bool get isNetworkError {
    return type == ErrorType.noInternet ||
        type == ErrorType.timeout ||
        type == ErrorType.networkError;
  }

  /// Whether this is an authentication error
  bool get isAuthError {
    return type == ErrorType.unauthorized || type == ErrorType.forbidden;
  }

  /// Factory for no internet connection
  factory AppError.noInternet({dynamic originalException, StackTrace? stackTrace}) {
    return AppError(
      type: ErrorType.noInternet,
      message: 'No internet connection. Please check your network.',
      originalException: originalException,
      stackTrace: stackTrace,
    );
  }

  /// Factory for timeout errors
  factory AppError.timeout({dynamic originalException, StackTrace? stackTrace}) {
    return AppError(
      type: ErrorType.timeout,
      message: 'Request timed out. Please try again.',
      originalException: originalException,
      stackTrace: stackTrace,
    );
  }

  /// Factory for generic network errors
  factory AppError.network({
    String? details,
    dynamic originalException,
    StackTrace? stackTrace,
  }) {
    return AppError(
      type: ErrorType.networkError,
      message: 'Network error. Please check your connection.',
      technicalDetails: details,
      originalException: originalException,
      stackTrace: stackTrace,
    );
  }

  /// Factory for server errors (5xx)
  factory AppError.server({
    int? statusCode,
    String? details,
    dynamic originalException,
    StackTrace? stackTrace,
  }) {
    return AppError(
      type: ErrorType.serverError,
      message: 'Server error. Please try again later.',
      statusCode: statusCode,
      technicalDetails: details,
      originalException: originalException,
      stackTrace: stackTrace,
    );
  }

  /// Factory for service unavailable (503 or circuit breaker open)
  factory AppError.serviceUnavailable({
    String? details,
    dynamic originalException,
    StackTrace? stackTrace,
  }) {
    return AppError(
      type: ErrorType.serverError,
      message: 'Service temporarily unavailable. Please try again later.',
      statusCode: 503,
      technicalDetails: details,
      originalException: originalException,
      stackTrace: stackTrace,
    );
  }

  /// Factory for unauthorized (401)
  factory AppError.unauthorized({
    String? details,
    dynamic originalException,
    StackTrace? stackTrace,
  }) {
    return AppError(
      type: ErrorType.unauthorized,
      message: 'Session expired. Please log in again.',
      statusCode: 401,
      technicalDetails: details,
      originalException: originalException,
      stackTrace: stackTrace,
    );
  }

  /// Factory for forbidden (403)
  factory AppError.forbidden({
    String? details,
    dynamic originalException,
    StackTrace? stackTrace,
  }) {
    return AppError(
      type: ErrorType.forbidden,
      message: 'You don\'t have permission to perform this action.',
      statusCode: 403,
      technicalDetails: details,
      originalException: originalException,
      stackTrace: stackTrace,
    );
  }

  /// Factory for not found (404)
  factory AppError.notFound({
    String? details,
    dynamic originalException,
    StackTrace? stackTrace,
  }) {
    return AppError(
      type: ErrorType.notFound,
      message: 'The requested resource was not found.',
      statusCode: 404,
      technicalDetails: details,
      originalException: originalException,
      stackTrace: stackTrace,
    );
  }

  /// Factory for bad request (400)
  factory AppError.badRequest({
    String? message,
    String? details,
    dynamic originalException,
    StackTrace? stackTrace,
  }) {
    return AppError(
      type: ErrorType.badRequest,
      message: message ?? 'Invalid request. Please check your input.',
      statusCode: 400,
      technicalDetails: details,
      originalException: originalException,
      stackTrace: stackTrace,
    );
  }

  /// Factory for validation errors
  factory AppError.validation({
    required String message,
    String? details,
  }) {
    return AppError(
      type: ErrorType.validationError,
      message: message,
      technicalDetails: details,
    );
  }

  /// Factory for parse/format errors
  factory AppError.parse({
    String? details,
    dynamic originalException,
    StackTrace? stackTrace,
  }) {
    return AppError(
      type: ErrorType.parseError,
      message: 'Invalid response from server.',
      technicalDetails: details,
      originalException: originalException,
      stackTrace: stackTrace,
    );
  }

  /// Factory for cancelled operations
  factory AppError.cancelled({String? message}) {
    return AppError(
      type: ErrorType.cancelled,
      message: message ?? 'Operation cancelled.',
    );
  }

  /// Factory for unknown errors
  factory AppError.unknown({
    String? message,
    String? details,
    dynamic originalException,
    StackTrace? stackTrace,
  }) {
    return AppError(
      type: ErrorType.unknown,
      message: message ?? 'An unexpected error occurred.',
      technicalDetails: details,
      originalException: originalException,
      stackTrace: stackTrace,
    );
  }

  /// Create AppError from HTTP status code
  ///
  /// Handles all HTTP status code ranges:
  /// - 2xx: Success (returns null via [fromStatusCodeOrNull])
  /// - 3xx: Redirects (treated as unknown errors if not handled)
  /// - 4xx: Client errors (specific handling for common codes)
  /// - 5xx: Server errors
  factory AppError.fromStatusCode(
    int statusCode, {
    String? message,
    String? details,
    dynamic originalException,
    StackTrace? stackTrace,
  }) {
    // 2xx success codes - shouldn't create errors, but handle gracefully
    if (statusCode >= 200 && statusCode < 300) {
      return AppError(
        type: ErrorType.unknown,
        message: message ?? 'Unexpected success status treated as error: $statusCode',
        statusCode: statusCode,
        technicalDetails: details,
        originalException: originalException,
        stackTrace: stackTrace,
      );
    }

    // 3xx redirect codes
    if (statusCode >= 300 && statusCode < 400) {
      return AppError(
        type: ErrorType.networkError,
        message: message ?? 'Redirect not followed: $statusCode',
        statusCode: statusCode,
        technicalDetails: details ?? 'HTTP redirect status codes should be handled by the HTTP client',
        originalException: originalException,
        stackTrace: stackTrace,
      );
    }

    // 4xx client errors
    switch (statusCode) {
      case 400:
        return AppError.badRequest(
          message: message,
          details: details,
          originalException: originalException,
          stackTrace: stackTrace,
        );
      case 401:
        return AppError.unauthorized(
          details: details,
          originalException: originalException,
          stackTrace: stackTrace,
        );
      case 403:
        return AppError.forbidden(
          details: details,
          originalException: originalException,
          stackTrace: stackTrace,
        );
      case 404:
        return AppError.notFound(
          details: details,
          originalException: originalException,
          stackTrace: stackTrace,
        );
      case 408:
        return AppError.timeout(
          originalException: originalException,
          stackTrace: stackTrace,
        );
      case 429:
        return AppError(
          type: ErrorType.serverError,
          message: message ?? 'Too many requests. Please try again later.',
          statusCode: statusCode,
          technicalDetails: details,
          originalException: originalException,
          stackTrace: stackTrace,
        );
    }

    // 5xx server errors
    if (statusCode >= 500) {
      return AppError.server(
        statusCode: statusCode,
        details: details,
        originalException: originalException,
        stackTrace: stackTrace,
      );
    }

    // Other 4xx codes
    if (statusCode >= 400 && statusCode < 500) {
      return AppError(
        type: ErrorType.badRequest,
        message: message ?? 'Client error: $statusCode',
        statusCode: statusCode,
        technicalDetails: details,
        originalException: originalException,
        stackTrace: stackTrace,
      );
    }

    // Fallback for any other codes (1xx informational, etc.)
    return AppError.unknown(
      message: message ?? 'Request failed with status $statusCode',
      details: details,
      originalException: originalException,
      stackTrace: stackTrace,
    );
  }

  /// Create AppError from status code, returning null for success codes
  ///
  /// Use this when you only want an error for non-2xx status codes.
  static AppError? fromStatusCodeOrNull(
    int statusCode, {
    String? message,
    String? details,
    dynamic originalException,
    StackTrace? stackTrace,
  }) {
    if (statusCode >= 200 && statusCode < 300) {
      return null;
    }
    return AppError.fromStatusCode(
      statusCode,
      message: message,
      details: details,
      originalException: originalException,
      stackTrace: stackTrace,
    );
  }

  @override
  String toString() {
    final buffer = StringBuffer('AppError(');
    buffer.write('type: $type, ');
    buffer.write('message: $message');
    if (statusCode != null) buffer.write(', statusCode: $statusCode');
    if (technicalDetails != null) buffer.write(', details: $technicalDetails');
    buffer.write(')');
    return buffer.toString();
  }
}
