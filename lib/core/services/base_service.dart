// Base Service Class
//
// Provides common functionality for all feature services:
// - API client access (with dependency injection support)
// - Error handling
// - Caching support
// - Logging

import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'cache_manager.dart';
import 'error_handler.dart';
import '../models/app_error.dart';

/// Base class for all feature services
///
/// Supports two patterns:
///
/// 1. SINGLETON PATTERN (legacy, for backwards compatibility):
/// ```dart
/// class MyService extends BaseService {
///   static final MyService _instance = MyService._();
///   static MyService get instance => _instance;
///   MyService._();
/// }
/// ```
///
/// 2. DEPENDENCY INJECTION PATTERN (recommended):
/// ```dart
/// class MyService extends BaseService {
///   MyService({ApiClient? api, CacheRegistry? cacheRegistry})
///       : super(api: api, cacheRegistry: cacheRegistry);
/// }
///
/// // Register in service_locator.dart:
/// sl.registerLazySingleton<MyService>(
///   () => MyService(api: sl<ApiClient>()),
/// );
///
/// // Use anywhere:
/// final service = getIt<MyService>();
/// ```
abstract class BaseService {
  final ApiClient? _injectedApi;
  final CacheRegistry? _injectedCacheRegistry;

  /// Create a BaseService with optional dependency injection
  ///
  /// If dependencies are not provided, falls back to singleton instances.
  BaseService({
    ApiClient? api,
    CacheRegistry? cacheRegistry,
  })  : _injectedApi = api,
        _injectedCacheRegistry = cacheRegistry;

  /// API client for making HTTP requests
  /// Uses injected instance if provided, otherwise falls back to singleton
  @protected
  ApiClient get api => _injectedApi ?? ApiClient.instance;

  /// Error handler for user-friendly error display
  @protected
  ErrorHandler get errorHandler => ErrorHandler.instance;

  /// Cache registry for caching support
  /// Uses injected instance if provided, otherwise falls back to singleton
  @protected
  CacheRegistry get cacheRegistry => _injectedCacheRegistry ?? CacheRegistry.instance;

  /// Service name for logging (override in subclasses)
  @protected
  String get serviceName => runtimeType.toString();

  /// Log a debug message
  @protected
  void log(String message) {
    debugPrint('[$serviceName] $message');
  }

  /// Log an error message
  @protected
  void logError(String message, [Object? error, StackTrace? stackTrace]) {
    debugPrint('[$serviceName] ERROR: $message');
    if (error != null) {
      debugPrint('[$serviceName] Exception: $error');
    }
    if (stackTrace != null && kDebugMode) {
      debugPrint('[$serviceName] Stack: $stackTrace');
    }
  }

  /// Handle an API call with standardized error handling
  ///
  /// [apiCall] - The async function that makes the API request
  /// [parser] - Function to parse successful response data
  /// [errorMessage] - User-friendly error message for failures
  /// [defaultValue] - Value to return on error (if not throwing)
  /// [throwOnError] - Whether to throw exception on error (default: false)
  @protected
  Future<T> handleApiCall<T>({
    required Future<ApiResponse> Function() apiCall,
    required T Function(Map<String, dynamic> data) parser,
    String errorMessage = 'Operation failed',
    T? defaultValue,
    bool throwOnError = false,
  }) async {
    try {
      final response = await apiCall();

      if (response.success && response.rawJson != null) {
        return parser(response.rawJson!);
      }

      // Handle error
      final error = response.error ?? AppError.unknown(message: response.message ?? errorMessage);
      logError(errorMessage, error);

      if (throwOnError) {
        throw error;
      }

      if (defaultValue != null) {
        return defaultValue;
      }

      throw error;
    } catch (e, stackTrace) {
      if (e is AppError) rethrow;

      final appError = ErrorHandler.toAppError(e, stackTrace);
      logError(errorMessage, e, stackTrace);

      if (throwOnError) {
        throw appError;
      }

      if (defaultValue != null) {
        return defaultValue;
      }

      throw appError;
    }
  }

  /// Handle a simple API call that returns success/failure
  @protected
  Future<bool> handleSimpleApiCall({
    required Future<ApiResponse> Function() apiCall,
    String errorMessage = 'Operation failed',
  }) async {
    try {
      final response = await apiCall();
      if (!response.success) {
        logError(errorMessage, response.error);
      }
      return response.success;
    } catch (e, stackTrace) {
      logError(errorMessage, e, stackTrace);
      return false;
    }
  }

  /// Create and register a cache for this service
  ///
  /// If a cache with the same name already exists, returns the existing one.
  @protected
  CacheManager<T> createCache<T>({
    required String name,
    CacheConfig config = const CacheConfig(),
    T Function(dynamic json)? fromJson,
    dynamic Function(T data)? toJson,
  }) {
    final cacheKey = '${serviceName}_$name';
    // Check if cache already exists
    final existing = cacheRegistry.get<T>(cacheKey);
    if (existing != null) {
      return existing;
    }
    // Create and register new cache
    final cache = CacheManager<T>(
      key: cacheKey,
      config: config,
      fromJson: fromJson,
      toJson: toJson,
    );
    cacheRegistry.register<T>(cache);
    return cache;
  }
}

/// Mixin for services that need local caching of items
mixin CachedItemsMixin<T> on BaseService {
  final List<T> _cachedItems = [];
  DateTime? _lastFetch;
  Duration get cacheValidDuration => const Duration(minutes: 5);

  /// Get cached items
  List<T> get cachedItems => List.unmodifiable(_cachedItems);

  /// Check if cache is valid
  bool get isCacheValid =>
      _lastFetch != null &&
      DateTime.now().difference(_lastFetch!) < cacheValidDuration;

  /// Update cached items
  @protected
  void updateCache(List<T> items) {
    _cachedItems
      ..clear()
      ..addAll(items);
    _lastFetch = DateTime.now();
  }

  /// Clear cached items
  @protected
  void clearCache() {
    _cachedItems.clear();
    _lastFetch = null;
  }

  /// Get items from cache or fetch
  @protected
  Future<List<T>> getItemsWithCache({
    required Future<List<T>> Function() fetchItems,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && isCacheValid) {
      return cachedItems;
    }

    final items = await fetchItems();
    updateCache(items);
    return items;
  }
}
