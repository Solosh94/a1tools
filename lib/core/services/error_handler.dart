// Error Handler Service
//
// Centralized error handling utility for displaying errors consistently
// across the application.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/app_error.dart';

/// Global error handler for the application
class ErrorHandler {
  // Singleton
  static final ErrorHandler _instance = ErrorHandler._internal();
  factory ErrorHandler() => _instance;
  ErrorHandler._internal();

  static ErrorHandler get instance => _instance;

  /// Global error callback - set this to handle all errors centrally
  /// (e.g., for analytics, logging, or auth redirect)
  void Function(AppError error)? onError;

  /// Global auth error callback - called when 401/403 errors occur
  void Function(AppError error)? onAuthError;

  /// Convert any exception to AppError
  static AppError toAppError(dynamic exception, [StackTrace? stackTrace]) {
    if (exception is AppError) {
      return exception;
    }

    if (exception is SocketException) {
      return AppError.noInternet(
        originalException: exception,
        stackTrace: stackTrace,
      );
    }

    if (exception is TimeoutException) {
      return AppError.timeout(
        originalException: exception,
        stackTrace: stackTrace,
      );
    }

    if (exception is http.ClientException) {
      return AppError.network(
        details: exception.message,
        originalException: exception,
        stackTrace: stackTrace,
      );
    }

    if (exception is FormatException) {
      return AppError.parse(
        details: exception.message,
        originalException: exception,
        stackTrace: stackTrace,
      );
    }

    if (exception is Exception) {
      return AppError.unknown(
        message: exception.toString().replaceFirst('Exception: ', ''),
        originalException: exception,
        stackTrace: stackTrace,
      );
    }

    return AppError.unknown(
      message: exception?.toString() ?? 'Unknown error',
      originalException: exception,
      stackTrace: stackTrace,
    );
  }

  /// Handle an error - logs it and optionally shows UI
  void handle(
    dynamic error, {
    BuildContext? context,
    bool showSnackBar = true,
    bool showDialog = false,
    VoidCallback? onRetry,
    String? customMessage,
  }) {
    final appError = error is AppError ? error : toAppError(error);

    // Log the error
    _log(appError);

    // Call global error handler
    onError?.call(appError);

    // Handle auth errors specially
    if (appError.isAuthError) {
      onAuthError?.call(appError);
    }

    // Show UI if context provided
    if (context != null && context.mounted) {
      if (showDialog) {
        showErrorDialog(
          context,
          appError,
          customMessage: customMessage,
          onRetry: onRetry,
        );
      } else if (showSnackBar) {
        showErrorSnackBar(
          context,
          appError,
          customMessage: customMessage,
          onRetry: onRetry,
        );
      }
    }
  }

  /// Show error as a SnackBar
  static void showErrorSnackBar(
    BuildContext context,
    AppError error, {
    String? customMessage,
    VoidCallback? onRetry,
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!context.mounted) return;

    final message = customMessage ?? error.message;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _getIconForError(error),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: _getColorForError(error),
        duration: duration,
        action: error.isRetryable && onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Show error as a dialog
  static Future<void> showErrorDialog(
    BuildContext context,
    AppError error, {
    String? customMessage,
    VoidCallback? onRetry,
  }) async {
    if (!context.mounted) return;

    final message = customMessage ?? error.message;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          _getIconForError(error),
          color: _getColorForError(error),
          size: 48,
        ),
        title: Text(_getTitleForError(error)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          if (error.isRetryable && onRetry != null)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  /// Show a simple error message (shorthand)
  static void showError(
    BuildContext context,
    String message, {
    VoidCallback? onRetry,
  }) {
    showErrorSnackBar(
      context,
      AppError(type: ErrorType.unknown, message: message),
      onRetry: onRetry,
    );
  }

  /// Show a success message
  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Show an info message
  static void showInfo(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Show a warning message
  static void showWarning(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  static IconData _getIconForError(AppError error) {
    switch (error.type) {
      case ErrorType.noInternet:
        return Icons.wifi_off;
      case ErrorType.timeout:
        return Icons.timer_off;
      case ErrorType.networkError:
        return Icons.cloud_off;
      case ErrorType.serverError:
        return Icons.dns;
      case ErrorType.unauthorized:
        return Icons.lock;
      case ErrorType.forbidden:
        return Icons.block;
      case ErrorType.notFound:
        return Icons.search_off;
      case ErrorType.badRequest:
        return Icons.error_outline;
      case ErrorType.parseError:
        return Icons.code_off;
      case ErrorType.validationError:
        return Icons.warning;
      case ErrorType.cancelled:
        return Icons.cancel;
      case ErrorType.unknown:
        return Icons.error;
    }
  }

  static Color _getColorForError(AppError error) {
    switch (error.type) {
      case ErrorType.noInternet:
      case ErrorType.timeout:
      case ErrorType.networkError:
        return Colors.orange.shade700;
      case ErrorType.serverError:
        return Colors.red.shade700;
      case ErrorType.unauthorized:
      case ErrorType.forbidden:
        return Colors.deepOrange.shade700;
      case ErrorType.notFound:
      case ErrorType.badRequest:
      case ErrorType.parseError:
      case ErrorType.validationError:
        return Colors.red.shade600;
      case ErrorType.cancelled:
        return Colors.grey.shade700;
      case ErrorType.unknown:
        return Colors.red;
    }
  }

  static String _getTitleForError(AppError error) {
    switch (error.type) {
      case ErrorType.noInternet:
        return 'No Internet';
      case ErrorType.timeout:
        return 'Request Timeout';
      case ErrorType.networkError:
        return 'Network Error';
      case ErrorType.serverError:
        return 'Server Error';
      case ErrorType.unauthorized:
        return 'Session Expired';
      case ErrorType.forbidden:
        return 'Access Denied';
      case ErrorType.notFound:
        return 'Not Found';
      case ErrorType.badRequest:
        return 'Invalid Request';
      case ErrorType.parseError:
        return 'Data Error';
      case ErrorType.validationError:
        return 'Validation Error';
      case ErrorType.cancelled:
        return 'Cancelled';
      case ErrorType.unknown:
        return 'Error';
    }
  }

  void _log(AppError error) {
    if (kDebugMode) {
      debugPrint('[ErrorHandler] ${error.type}: ${error.message}');
      if (error.technicalDetails != null) {
        debugPrint('[ErrorHandler] Details: ${error.technicalDetails}');
      }
      if (error.stackTrace != null) {
        debugPrint('[ErrorHandler] Stack: ${error.stackTrace}');
      }
    }
  }
}

/// Extension for convenient error handling on BuildContext
extension ErrorHandlerExtension on BuildContext {
  /// Show an error snackbar
  void showError(String message, {VoidCallback? onRetry}) {
    ErrorHandler.showError(this, message, onRetry: onRetry);
  }

  /// Show a success snackbar
  void showSuccess(String message) {
    ErrorHandler.showSuccess(this, message);
  }

  /// Show an info snackbar
  void showInfo(String message) {
    ErrorHandler.showInfo(this, message);
  }

  /// Show a warning snackbar
  void showWarning(String message) {
    ErrorHandler.showWarning(this, message);
  }

  /// Handle an AppError with snackbar
  void handleError(AppError error, {VoidCallback? onRetry}) {
    ErrorHandler.showErrorSnackBar(this, error, onRetry: onRetry);
  }
}
