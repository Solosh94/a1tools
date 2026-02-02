// Error Display Widgets
//
// Reusable widgets for displaying errors consistently across the app.

import 'package:flutter/material.dart';

import '../models/app_error.dart';

/// A banner widget for displaying errors at the top of screens
class ErrorBanner extends StatelessWidget {
  final AppError error;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final bool showIcon;

  const ErrorBanner({
    super.key,
    required this.error,
    this.onRetry,
    this.onDismiss,
    this.showIcon = true,
  });

  /// Create from a simple message
  factory ErrorBanner.message(
    String message, {
    Key? key,
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
  }) {
    return ErrorBanner(
      key: key,
      error: AppError(type: ErrorType.unknown, message: message),
      onRetry: onRetry,
      onDismiss: onDismiss,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          if (showIcon) ...[
            Icon(_getIcon(), color: Colors.white, size: 20),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              error.message,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          if (error.isRetryable && onRetry != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('Retry'),
            ),
          ],
          if (onDismiss != null) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 18),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }

  Color _getBackgroundColor() {
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

  IconData _getIcon() {
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
}

/// A full-screen error widget with retry button
class ErrorView extends StatelessWidget {
  final AppError error;
  final VoidCallback? onRetry;
  final String? retryText;
  final IconData? icon;
  final double iconSize;

  const ErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.retryText,
    this.icon,
    this.iconSize = 64,
  });

  /// Create from a simple message
  factory ErrorView.message(
    String message, {
    Key? key,
    VoidCallback? onRetry,
    String? retryText,
    IconData? icon,
  }) {
    return ErrorView(
      key: key,
      error: AppError(type: ErrorType.unknown, message: message),
      onRetry: onRetry,
      retryText: retryText,
      icon: icon,
    );
  }

  /// Create a "no internet" error view
  factory ErrorView.noInternet({
    Key? key,
    VoidCallback? onRetry,
  }) {
    return ErrorView(
      key: key,
      error: AppError.noInternet(),
      onRetry: onRetry,
    );
  }

  /// Create an "empty data" view (not really an error, but common pattern)
  factory ErrorView.empty({
    Key? key,
    String message = 'No data found',
    VoidCallback? onRetry,
    IconData icon = Icons.inbox_outlined,
  }) {
    return ErrorView(
      key: key,
      error: AppError(type: ErrorType.notFound, message: message),
      onRetry: onRetry,
      icon: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon ?? _getIcon(),
              size: iconSize,
              color: _getColor(context),
            ),
            const SizedBox(height: 24),
            Text(
              _getTitle(),
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              error.message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
              textAlign: TextAlign.center,
            ),
            if (error.isRetryable && onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(retryText ?? 'Try Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getTitle() {
    switch (error.type) {
      case ErrorType.noInternet:
        return 'No Internet Connection';
      case ErrorType.timeout:
        return 'Request Timed Out';
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
        return 'Something Went Wrong';
    }
  }

  IconData _getIcon() {
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
        return Icons.lock_outline;
      case ErrorType.forbidden:
        return Icons.block;
      case ErrorType.notFound:
        return Icons.search_off;
      case ErrorType.badRequest:
        return Icons.error_outline;
      case ErrorType.parseError:
        return Icons.code_off;
      case ErrorType.validationError:
        return Icons.warning_amber;
      case ErrorType.cancelled:
        return Icons.cancel_outlined;
      case ErrorType.unknown:
        return Icons.error_outline;
    }
  }

  Color _getColor(BuildContext context) {
    switch (error.type) {
      case ErrorType.noInternet:
      case ErrorType.timeout:
      case ErrorType.networkError:
        return Colors.orange;
      case ErrorType.serverError:
      case ErrorType.badRequest:
      case ErrorType.parseError:
      case ErrorType.validationError:
      case ErrorType.unknown:
        return Colors.red;
      case ErrorType.unauthorized:
      case ErrorType.forbidden:
        return Colors.deepOrange;
      case ErrorType.notFound:
        return Colors.grey;
      case ErrorType.cancelled:
        return Colors.grey;
    }
  }
}

/// A small inline error text widget
class ErrorText extends StatelessWidget {
  final String message;
  final TextStyle? style;
  final IconData? icon;

  const ErrorText({
    super.key,
    required this.message,
    this.style,
    this.icon,
  });

  factory ErrorText.fromError(AppError error, {Key? key, TextStyle? style}) {
    return ErrorText(
      key: key,
      message: error.message,
      style: style,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon ?? Icons.error_outline,
          color: Colors.red,
          size: 16,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            message,
            style: style ??
                TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 13,
                ),
          ),
        ),
      ],
    );
  }
}

/// A loading overlay with optional error state
class LoadingErrorOverlay extends StatelessWidget {
  final bool isLoading;
  final AppError? error;
  final Widget child;
  final VoidCallback? onRetry;
  final String? loadingMessage;

  const LoadingErrorOverlay({
    super.key,
    required this.isLoading,
    this.error,
    required this.child,
    this.onRetry,
    this.loadingMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return ErrorView(
        error: error!,
        onRetry: onRetry,
      );
    }

    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            if (loadingMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                loadingMessage!,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      );
    }

    return child;
  }
}
