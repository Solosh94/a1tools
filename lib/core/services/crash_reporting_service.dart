// Crash Reporting Service
//
// Integrates with Sentry for crash analytics and error monitoring.
// Provides a unified interface for error reporting across the app.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Breadcrumb categories for tracking user actions
enum BreadcrumbCategory {
  navigation('navigation'),
  userAction('user_action'),
  network('network'),
  auth('auth'),
  ui('ui'),
  lifecycle('lifecycle'),
  error('error');

  final String value;
  const BreadcrumbCategory(this.value);
}

/// Service for crash reporting and error analytics
class CrashReportingService {
  CrashReportingService._();
  static final CrashReportingService _instance = CrashReportingService._();
  factory CrashReportingService() => _instance;
  static CrashReportingService get instance => _instance;

  bool _isInitialized = false;

  /// Current username for context (can be accessed for debugging)
  String? currentUsername;

  /// Current role for context (can be accessed for debugging)
  String? currentRole;

  /// Check if crash reporting is initialized
  bool get isInitialized => _isInitialized;

  /// Initialize Sentry with the app runner
  /// Call this in main.dart before runApp
  static Future<void> initialize({
    required String dsn,
    required Future<void> Function() appRunner,
    String environment = 'production',
    double sampleRate = 1.0,
    double tracesSampleRate = 0.2,
  }) async {
    if (dsn.isEmpty) {
      debugPrint('[CrashReporting] No DSN provided, running without crash reporting');
      await appRunner();
      return;
    }

    await SentryFlutter.init(
      (options) {
        options.dsn = dsn;
        options.environment = environment;
        options.sampleRate = sampleRate;
        options.tracesSampleRate = tracesSampleRate;

        // Enable automatic session tracking
        options.enableAutoSessionTracking = true;
        options.autoSessionTrackingInterval = const Duration(milliseconds: 30000);

        // Attach stack traces to all events
        options.attachStacktrace = true;

        // Set max breadcrumbs
        options.maxBreadcrumbs = 100;

        // Don't send in debug mode unless explicitly enabled
        options.debug = kDebugMode;

        // Filter out PII from URLs
        options.beforeSend = (event, hint) async {
          // Scrub sensitive data
          return _scrubSensitiveData(event);
        };

        // Filter breadcrumbs
        options.beforeBreadcrumb = (breadcrumb, hint) {
          // Don't record breadcrumbs with sensitive data
          final data = breadcrumb?.data;
          if (data != null && data.containsKey('password')) {
            return null;
          }
          return breadcrumb;
        };
      },
      appRunner: appRunner,
    );

    instance._isInitialized = true;
    debugPrint('[CrashReporting] Initialized with environment: $environment');
  }

  /// Scrub sensitive data from events
  static SentryEvent? _scrubSensitiveData(SentryEvent event) {
    // List of keys to scrub
    const sensitiveKeys = [
      'password',
      'token',
      'api_key',
      'secret',
      'authorization',
      'cookie',
      'session',
      'credit_card',
      'ssn',
    ];

    // Scrub from tags
    final scrubbedTags = <String, String>{};
    event.tags?.forEach((key, value) {
      if (sensitiveKeys.any((k) => key.toLowerCase().contains(k))) {
        scrubbedTags[key] = '[REDACTED]';
      } else {
        scrubbedTags[key] = value;
      }
    });

    return event.copyWith(tags: scrubbedTags);
  }

  /// Set the current user for crash reports
  void setUser({
    required String? username,
    String? email,
    String? role,
  }) {
    currentUsername = username;
    currentRole = role;

    if (username != null) {
      Sentry.configureScope((scope) {
        scope.setUser(SentryUser(
          username: username,
          email: email,
        ));
        if (role != null) {
          scope.setTag('user_role', role);
        }
      });
      debugPrint('[CrashReporting] User set: $username (role: $role)');
    } else {
      Sentry.configureScope((scope) {
        scope.setUser(null);
        scope.removeTag('user_role');
      });
      debugPrint('[CrashReporting] User cleared');
    }
  }

  /// Clear user info (on logout)
  void clearUser() {
    setUser(username: null);
    currentUsername = null;
    currentRole = null;
  }

  /// Set extra context information
  void setContext(String key, Map<String, dynamic> data) {
    Sentry.configureScope((scope) {
      scope.setContexts(key, data);
    });
  }

  /// Add a tag to all future events
  void setTag(String key, String value) {
    Sentry.configureScope((scope) {
      scope.setTag(key, value);
    });
  }

  /// Record a breadcrumb (for debugging crash context)
  void addBreadcrumb({
    required String message,
    BreadcrumbCategory category = BreadcrumbCategory.userAction,
    Map<String, dynamic>? data,
    SentryLevel level = SentryLevel.info,
  }) {
    Sentry.addBreadcrumb(Breadcrumb(
      message: message,
      category: category.value,
      level: level,
      data: data,
      timestamp: DateTime.now().toUtc(),
    ));
  }

  /// Record a navigation breadcrumb
  void addNavigationBreadcrumb({
    required String from,
    required String to,
  }) {
    addBreadcrumb(
      message: 'Navigation: $from -> $to',
      category: BreadcrumbCategory.navigation,
      data: {'from': from, 'to': to},
    );
  }

  /// Record a user action breadcrumb
  void addUserActionBreadcrumb({
    required String action,
    Map<String, dynamic>? data,
  }) {
    addBreadcrumb(
      message: action,
      category: BreadcrumbCategory.userAction,
      data: data,
    );
  }

  /// Record a network request breadcrumb
  void addNetworkBreadcrumb({
    required String method,
    required String url,
    int? statusCode,
    String? error,
  }) {
    addBreadcrumb(
      message: '$method $url',
      category: BreadcrumbCategory.network,
      level: error != null ? SentryLevel.error : SentryLevel.info,
      data: {
        'method': method,
        'url': _scrubUrl(url),
        if (statusCode != null) 'status_code': statusCode,
        if (error != null) 'error': error,
      },
    );
  }

  /// Scrub sensitive data from URLs
  String _scrubUrl(String url) {
    // Remove query parameters that might contain sensitive data
    final uri = Uri.tryParse(url);
    if (uri == null) return url;

    final scrubbed = <String, String>{};
    uri.queryParameters.forEach((key, value) {
      if (['token', 'api_key', 'password', 'secret'].any(
        (k) => key.toLowerCase().contains(k),
      )) {
        scrubbed[key] = '[REDACTED]';
      } else {
        scrubbed[key] = value;
      }
    });

    return uri.replace(queryParameters: scrubbed.isEmpty ? null : scrubbed).toString();
  }

  /// Capture an exception with optional stack trace
  Future<void> captureException(
    dynamic exception, {
    dynamic stackTrace,
    String? message,
    Map<String, dynamic>? extras,
    SentryLevel level = SentryLevel.error,
  }) async {
    if (!_isInitialized) {
      debugPrint('[CrashReporting] Not initialized, logging locally: $exception');
      return;
    }

    await Sentry.captureException(
      exception,
      stackTrace: stackTrace,
      withScope: (scope) {
        if (message != null) {
          scope.setTag('error_message', message);
        }
        if (extras != null) {
          scope.setContexts('extras', extras);
        }
        scope.level = level;
      },
    );

    debugPrint('[CrashReporting] Exception captured: $exception');
  }

  /// Capture a message/event
  Future<void> captureMessage(
    String message, {
    SentryLevel level = SentryLevel.info,
    Map<String, dynamic>? extras,
  }) async {
    if (!_isInitialized) {
      debugPrint('[CrashReporting] Not initialized, logging locally: $message');
      return;
    }

    await Sentry.captureMessage(
      message,
      level: level,
      withScope: (scope) {
        if (extras != null) {
          scope.setContexts('extras', extras);
        }
      },
    );

    debugPrint('[CrashReporting] Message captured: $message');
  }

  /// Start a transaction for performance monitoring
  ISentrySpan startTransaction({
    required String name,
    required String operation,
  }) {
    return Sentry.startTransaction(name, operation);
  }

  /// Wrap an async operation with error capture
  Future<T> wrapAsync<T>(
    Future<T> Function() operation, {
    required String operationName,
    T? fallbackValue,
  }) async {
    try {
      return await operation();
    } catch (e, st) {
      await captureException(
        e,
        stackTrace: st,
        message: 'Error in $operationName',
      );
      if (fallbackValue != null) {
        return fallbackValue;
      }
      rethrow;
    }
  }

  /// Flush pending events (call before app termination)
  Future<void> flush() async {
    if (_isInitialized) {
      await Sentry.close();
      debugPrint('[CrashReporting] Flushed and closed');
    }
  }
}

/// Extension for easy error reporting
extension CrashReportingExtension on Object {
  /// Report this exception to crash reporting
  Future<void> reportToCrashReporting({
    dynamic stackTrace,
    String? message,
  }) async {
    await CrashReportingService.instance.captureException(
      this,
      stackTrace: stackTrace,
      message: message,
    );
  }
}
