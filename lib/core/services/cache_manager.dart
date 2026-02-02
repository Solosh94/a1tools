// Cache Manager
//
// Unified caching layer for the application.
// Provides memory caching with configurable TTL and optional disk persistence.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Configuration for cache behavior
class CacheConfig {
  /// Time-to-live for cached entries
  final Duration ttl;

  /// Whether to persist cache to disk
  final bool persist;

  /// Maximum number of entries (0 = unlimited)
  final int maxEntries;

  /// Whether to refresh in background when cache is stale
  final bool staleWhileRevalidate;

  const CacheConfig({
    this.ttl = const Duration(minutes: 5),
    this.persist = false,
    this.maxEntries = 0,
    this.staleWhileRevalidate = false,
  });

  // =========================================================================
  // DURATION-BASED PRESETS
  // =========================================================================

  /// No caching - always fetch fresh data
  static const none = CacheConfig(ttl: Duration.zero);

  /// Very short-lived cache (30 seconds) - for frequently changing data
  static const veryShort = CacheConfig(ttl: Duration(seconds: 30));

  /// Short-lived cache (1 minute)
  static const short = CacheConfig(ttl: Duration(minutes: 1));

  /// Standard cache (5 minutes)
  static const standard = CacheConfig(ttl: Duration(minutes: 5));

  /// Medium cache (15 minutes)
  static const medium = CacheConfig(ttl: Duration(minutes: 15));

  /// Long-lived cache (30 minutes)
  static const long = CacheConfig(ttl: Duration(minutes: 30));

  /// Very long-lived cache (1 hour)
  static const veryLong = CacheConfig(ttl: Duration(hours: 1));

  /// Persistent cache (1 hour, saved to disk)
  static const persistent = CacheConfig(
    ttl: Duration(hours: 1),
    persist: true,
  );

  // =========================================================================
  // ENDPOINT-TYPE PRESETS
  // These presets are optimized for common API endpoint patterns
  // =========================================================================

  /// For alerts, notifications, messages - data that changes frequently
  /// Short TTL, no persistence
  static const alerts = CacheConfig(
    ttl: Duration(seconds: 30),
    staleWhileRevalidate: true,
  );

  /// For real-time data like status checks, heartbeats
  /// Very short TTL or no caching
  static const realtime = CacheConfig(ttl: Duration(seconds: 10));

  /// For user profile data - changes rarely but should be fresh
  /// Medium TTL with stale-while-revalidate
  static const userProfile = CacheConfig(
    ttl: Duration(minutes: 10),
    staleWhileRevalidate: true,
  );

  /// For configuration/settings - changes rarely
  /// Long TTL with persistence
  static const settings = CacheConfig(
    ttl: Duration(minutes: 30),
    persist: true,
    staleWhileRevalidate: true,
  );

  /// For lists that don't change often (inventory categories, roles)
  /// Long TTL with stale-while-revalidate
  static const staticLists = CacheConfig(
    ttl: Duration(hours: 1),
    staleWhileRevalidate: true,
  );

  /// For frequently accessed reference data (customers, locations)
  /// Medium TTL, good for reducing repeated lookups
  static const referenceData = CacheConfig(
    ttl: Duration(minutes: 15),
    staleWhileRevalidate: true,
  );

  /// For search results - short-lived, no persistence
  static const searchResults = CacheConfig(
    ttl: Duration(minutes: 2),
  );

  /// For paginated lists - medium TTL
  static const paginatedList = CacheConfig(
    ttl: Duration(minutes: 5),
    staleWhileRevalidate: true,
  );

  /// For dashboard/analytics data - medium TTL
  static const analytics = CacheConfig(
    ttl: Duration(minutes: 10),
    staleWhileRevalidate: true,
  );

  /// For image/media URLs - very long TTL
  static const media = CacheConfig(
    ttl: Duration(hours: 24),
    persist: true,
  );

  // =========================================================================
  // FACTORY METHODS
  // =========================================================================

  /// Create a custom configuration with specific TTL
  factory CacheConfig.withTtl(Duration ttl, {
    bool persist = false,
    bool staleWhileRevalidate = false,
    int maxEntries = 0,
  }) {
    return CacheConfig(
      ttl: ttl,
      persist: persist,
      staleWhileRevalidate: staleWhileRevalidate,
      maxEntries: maxEntries,
    );
  }

  /// Create a copy with modified TTL
  CacheConfig copyWithTtl(Duration newTtl) {
    return CacheConfig(
      ttl: newTtl,
      persist: persist,
      maxEntries: maxEntries,
      staleWhileRevalidate: staleWhileRevalidate,
    );
  }
}

/// A single cache entry with metadata
class CacheEntry<T> {
  final T data;
  final DateTime createdAt;
  final DateTime expiresAt;

  CacheEntry({
    required this.data,
    required this.createdAt,
    required this.expiresAt,
  });

  /// Check if entry has expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Check if entry is still valid
  bool get isValid => !isExpired;

  /// Time remaining until expiry
  Duration get timeRemaining {
    final remaining = expiresAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Age of the entry
  Duration get age => DateTime.now().difference(createdAt);

  /// Create from JSON (for disk persistence)
  factory CacheEntry.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fromJson,
  ) {
    return CacheEntry<T>(
      data: fromJson(json['data']),
      createdAt: DateTime.parse(json['createdAt']),
      expiresAt: DateTime.parse(json['expiresAt']),
    );
  }

  /// Convert to JSON (for disk persistence)
  Map<String, dynamic> toJson(dynamic Function(T) toJson) {
    return {
      'data': toJson(data),
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
    };
  }
}

/// Result of a cache operation
class CacheResult<T> {
  final T? data;
  final bool fromCache;
  final bool isStale;
  final String? error;

  const CacheResult({
    this.data,
    this.fromCache = false,
    this.isStale = false,
    this.error,
  });

  bool get success => data != null && error == null;

  factory CacheResult.hit(T data, {bool isStale = false}) {
    return CacheResult(data: data, fromCache: true, isStale: isStale);
  }

  factory CacheResult.miss(T data) {
    return CacheResult(data: data, fromCache: false);
  }

  factory CacheResult.failure(String error) {
    return CacheResult(error: error);
  }
}

/// Generic cache manager for a specific data type
class CacheManager<T> {
  final String key;
  final CacheConfig config;
  final T Function(dynamic json)? fromJson;
  final dynamic Function(T data)? toJson;

  CacheEntry<T>? _entry;
  DateTime? _lastAccessTime;
  bool _isLoading = false;
  Completer<T?>? _loadingCompleter;

  /// Last time this cache was accessed (for LRU eviction)
  DateTime? get lastAccessTime => _lastAccessTime;

  CacheManager({
    required this.key,
    this.config = const CacheConfig(),
    this.fromJson,
    this.toJson,
  });

  /// Get cached data if valid
  T? get() {
    if (_entry != null && _entry!.isValid) {
      _lastAccessTime = DateTime.now();
      return _entry!.data;
    }
    return null;
  }

  /// Get cached data even if expired (for stale-while-revalidate)
  T? getStale() {
    if (_entry != null) {
      _lastAccessTime = DateTime.now();
    }
    return _entry?.data;
  }

  /// Check if cache has valid data
  bool get hasValidData => _entry != null && _entry!.isValid;

  /// Check if cache has any data (including stale)
  bool get hasData => _entry != null;

  /// Check if data is stale (expired but available)
  bool get isStale => _entry != null && _entry!.isExpired;

  /// Get time remaining until expiry
  Duration? get timeRemaining => _entry?.timeRemaining;

  /// Set data in cache
  void set(T data) {
    final now = DateTime.now();
    _entry = CacheEntry<T>(
      data: data,
      createdAt: now,
      expiresAt: now.add(config.ttl),
    );
    _lastAccessTime = now;

    if (config.persist) {
      _saveToDisk();
    }

    if (kDebugMode) {
      debugPrint('[CacheManager] Cached "$key" (expires in ${config.ttl.inMinutes}m)');
    }
  }

  /// Get data from cache or fetch using the provided function
  Future<CacheResult<T>> getOrFetch(
    Future<T> Function() fetch, {
    bool forceRefresh = false,
  }) async {
    // Return valid cached data if not forcing refresh
    if (!forceRefresh && hasValidData) {
      return CacheResult.hit(_entry!.data);
    }

    // If stale-while-revalidate is enabled and we have stale data,
    // return it immediately and refresh in background
    if (config.staleWhileRevalidate && isStale && !forceRefresh) {
      final staleData = _entry!.data;
      _refreshInBackground(fetch);
      return CacheResult.hit(staleData, isStale: true);
    }

    // Avoid duplicate fetches - capture completer reference to avoid race condition
    if (_isLoading) {
      final currentCompleter = _loadingCompleter;
      if (currentCompleter != null) {
        try {
          final data = await currentCompleter.future;
          if (data != null) {
            return CacheResult.hit(data);
          }
        } catch (_) {
          // Completer was completed with error or cancelled
        }
      }
      return CacheResult.failure('Failed to load data');
    }

    // Fetch fresh data
    _isLoading = true;
    final completer = Completer<T?>();
    _loadingCompleter = completer;

    try {
      final data = await fetch();
      set(data);
      if (!completer.isCompleted) {
        completer.complete(data);
      }
      return CacheResult.miss(data);
    } catch (e) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }

      // Return stale data if available
      if (_entry != null) {
        return CacheResult.hit(_entry!.data, isStale: true);
      }

      return CacheResult.failure(e.toString());
    } finally {
      _isLoading = false;
      // Only clear if this is still our completer (avoid clearing a newer one)
      if (_loadingCompleter == completer) {
        _loadingCompleter = null;
      }
    }
  }

  /// Refresh cache in background
  void _refreshInBackground(Future<T> Function() fetch) {
    if (_isLoading) return;

    fetch().then((data) {
      set(data);
      if (kDebugMode) {
        debugPrint('[CacheManager] Background refresh completed for "$key"');
      }
    }).catchError((e) {
      if (kDebugMode) {
        debugPrint('[CacheManager] Background refresh failed for "$key": $e');
      }
    });
  }

  /// Invalidate the cache
  void invalidate() {
    _entry = null;
    if (config.persist) {
      _deleteFromDisk();
    }
    if (kDebugMode) {
      debugPrint('[CacheManager] Invalidated "$key"');
    }
  }

  /// Clear cache (alias for invalidate)
  void clear() => invalidate();

  /// Load cache from disk (call during initialization if using persistence)
  Future<void> loadFromDisk() async {
    if (!config.persist || fromJson == null) return;

    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/cache/$key.json');

      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content);
        _entry = CacheEntry.fromJson(json, fromJson!);

        if (_entry!.isExpired) {
          _entry = null;
          await file.delete();
          if (kDebugMode) {
            debugPrint('[CacheManager] Expired disk cache deleted for "$key"');
          }
        } else {
          if (kDebugMode) {
            debugPrint('[CacheManager] Loaded "$key" from disk');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CacheManager] Failed to load "$key" from disk: $e');
      }
    }
  }

  /// Save cache to disk
  Future<void> _saveToDisk() async {
    if (!config.persist || toJson == null || _entry == null) return;

    try {
      final dir = await getApplicationSupportDirectory();
      final cacheDir = Directory('${dir.path}/cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      final file = File('${cacheDir.path}/$key.json');
      final content = jsonEncode(_entry!.toJson(toJson!));
      await file.writeAsString(content);

      if (kDebugMode) {
        debugPrint('[CacheManager] Saved "$key" to disk');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CacheManager] Failed to save "$key" to disk: $e');
      }
    }
  }

  /// Delete cache from disk
  Future<void> _deleteFromDisk() async {
    if (!config.persist) return;

    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/cache/$key.json');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CacheManager] Failed to delete "$key" from disk: $e');
      }
    }
  }
}

/// Global cache registry for managing multiple caches
class CacheRegistry {
  static final CacheRegistry _instance = CacheRegistry._internal();
  factory CacheRegistry() => _instance;
  CacheRegistry._internal();

  static CacheRegistry get instance => _instance;

  final Map<String, CacheManager> _caches = {};

  /// Maximum number of caches allowed (0 = unlimited)
  /// Prevents memory exhaustion from unbounded cache creation
  int maxCaches = 100;

  /// Register a cache manager
  ///
  /// If [maxCaches] is set and the limit is reached, the least recently used
  /// cache will be evicted to make room.
  void register<T>(CacheManager<T> cache) {
    // Enforce max caches limit using LRU eviction
    if (maxCaches > 0 && _caches.length >= maxCaches && !_caches.containsKey(cache.key)) {
      _evictLeastRecentlyUsed();
    }
    _caches[cache.key] = cache;
  }

  /// Evict the least recently used cache
  void _evictLeastRecentlyUsed() {
    if (_caches.isEmpty) return;

    String? lruKey;
    DateTime? lruTime;

    for (final entry in _caches.entries) {
      final lastAccess = entry.value.lastAccessTime;
      // If no access time recorded, consider it very old (should be evicted first)
      final accessTime = lastAccess ?? DateTime.fromMillisecondsSinceEpoch(0);

      if (lruTime == null || accessTime.isBefore(lruTime)) {
        lruKey = entry.key;
        lruTime = accessTime;
      }
    }

    if (lruKey != null) {
      _caches[lruKey]?.invalidate();
      _caches.remove(lruKey);
      if (kDebugMode) {
        debugPrint('[CacheRegistry] Evicted LRU cache "$lruKey" to make room (limit: $maxCaches)');
      }
    }
  }

  /// Unregister a cache manager
  void unregister(String key) {
    _caches[key]?.invalidate();
    _caches.remove(key);
  }

  /// Get current number of registered caches
  int get count => _caches.length;

  /// Get a registered cache by key
  CacheManager<T>? get<T>(String key) {
    return _caches[key] as CacheManager<T>?;
  }

  /// Invalidate all caches
  void invalidateAll() {
    for (final cache in _caches.values) {
      cache.invalidate();
    }
    if (kDebugMode) {
      debugPrint('[CacheRegistry] Invalidated all caches');
    }
  }

  /// Invalidate caches matching a pattern
  void invalidatePattern(String pattern) {
    final regex = RegExp(pattern);
    for (final entry in _caches.entries) {
      if (regex.hasMatch(entry.key)) {
        entry.value.invalidate();
      }
    }
  }

  /// Load all persistent caches from disk
  Future<void> loadAllFromDisk() async {
    for (final cache in _caches.values) {
      await cache.loadFromDisk();
    }
  }

  /// Get cache statistics
  Map<String, CacheStats> getStats() {
    return _caches.map((key, cache) => MapEntry(
          key,
          CacheStats(
            hasData: cache.hasData,
            isValid: cache.hasValidData,
            isStale: cache.isStale,
            timeRemaining: cache.timeRemaining,
          ),
        ));
  }
}

/// Statistics for a single cache
class CacheStats {
  final bool hasData;
  final bool isValid;
  final bool isStale;
  final Duration? timeRemaining;

  const CacheStats({
    required this.hasData,
    required this.isValid,
    required this.isStale,
    this.timeRemaining,
  });
}

/// Simple key-value cache for quick lookups
class SimpleCache<K, V> {
  final Duration ttl;
  final int maxEntries;
  final Map<K, CacheEntry<V>> _cache = {};

  SimpleCache({
    this.ttl = const Duration(minutes: 5),
    this.maxEntries = 100,
  });

  /// Get value from cache
  V? get(K key) {
    final entry = _cache[key];
    if (entry != null && entry.isValid) {
      return entry.data;
    }
    if (entry != null && entry.isExpired) {
      _cache.remove(key);
    }
    return null;
  }

  /// Set value in cache
  void set(K key, V value) {
    // Enforce max entries
    if (maxEntries > 0 && _cache.length >= maxEntries) {
      _evictOldest();
    }

    final now = DateTime.now();
    _cache[key] = CacheEntry<V>(
      data: value,
      createdAt: now,
      expiresAt: now.add(ttl),
    );
  }

  /// Get or compute value
  Future<V> getOrCompute(K key, Future<V> Function() compute) async {
    final cached = get(key);
    if (cached != null) return cached;

    final value = await compute();
    set(key, value);
    return value;
  }

  /// Synchronous get or compute
  V getOrComputeSync(K key, V Function() compute) {
    final cached = get(key);
    if (cached != null) return cached;

    final value = compute();
    set(key, value);
    return value;
  }

  /// Remove entry
  void remove(K key) {
    _cache.remove(key);
  }

  /// Clear all entries
  void clear() {
    _cache.clear();
  }

  /// Remove expired entries
  void cleanup() {
    _cache.removeWhere((_, entry) => entry.isExpired);
  }

  /// Evict oldest entry
  void _evictOldest() {
    if (_cache.isEmpty) return;

    K? oldestKey;
    DateTime? oldestTime;

    for (final entry in _cache.entries) {
      if (oldestTime == null || entry.value.createdAt.isBefore(oldestTime)) {
        oldestKey = entry.key;
        oldestTime = entry.value.createdAt;
      }
    }

    if (oldestKey != null) {
      _cache.remove(oldestKey);
    }
  }

  /// Get number of entries
  int get length => _cache.length;

  /// Check if cache contains key
  bool containsKey(K key) {
    final entry = _cache[key];
    return entry != null && entry.isValid;
  }
}

// =============================================================================
// MEMORY-AWARE LRU CACHE
// =============================================================================

/// Callback to estimate memory size of a cached value
typedef MemorySizeEstimator<V> = int Function(V value);

/// A cache entry with memory tracking
class _MemoryEntry<V> {
  final V data;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int memorySizeBytes;
  DateTime lastAccessTime;

  _MemoryEntry({
    required this.data,
    required this.createdAt,
    required this.expiresAt,
    required this.memorySizeBytes,
  }) : lastAccessTime = createdAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isValid => !isExpired;
}

/// Memory-aware LRU cache with configurable limits
///
/// Tracks both entry count and approximate memory usage,
/// evicting entries when either limit is exceeded.
class MemoryAwareLRUCache<K, V> {
  /// Maximum number of entries
  final int maxEntries;

  /// Maximum memory in bytes (0 = unlimited)
  final int maxMemoryBytes;

  /// Time-to-live for entries
  final Duration ttl;

  /// Function to estimate memory size of values
  final MemorySizeEstimator<V>? sizeEstimator;

  final Map<K, _MemoryEntry<V>> _cache = {};
  final List<K> _accessOrder = [];
  int _currentMemoryBytes = 0;

  MemoryAwareLRUCache({
    this.maxEntries = 1000,
    this.maxMemoryBytes = 50 * 1024 * 1024, // 50MB default
    this.ttl = const Duration(minutes: 5),
    this.sizeEstimator,
  });

  /// Current memory usage in bytes
  int get currentMemoryBytes => _currentMemoryBytes;

  /// Current number of entries
  int get length => _cache.length;

  /// Memory usage as percentage of limit
  double get memoryUsagePercent {
    if (maxMemoryBytes <= 0) return 0;
    return (_currentMemoryBytes / maxMemoryBytes) * 100;
  }

  /// Get value from cache
  V? get(K key) {
    final entry = _cache[key];
    if (entry == null) return null;

    if (entry.isExpired) {
      _remove(key);
      return null;
    }

    // Update access time and order
    entry.lastAccessTime = DateTime.now();
    _accessOrder.remove(key);
    _accessOrder.add(key);

    return entry.data;
  }

  /// Set value in cache
  void set(K key, V value) {
    // Remove existing entry if present
    if (_cache.containsKey(key)) {
      _remove(key);
    }

    final memorySize = _estimateSize(value);

    // Evict entries if needed to make room
    _evictIfNeeded(memorySize);

    final now = DateTime.now();
    _cache[key] = _MemoryEntry<V>(
      data: value,
      createdAt: now,
      expiresAt: now.add(ttl),
      memorySizeBytes: memorySize,
    );
    _accessOrder.add(key);
    _currentMemoryBytes += memorySize;
  }

  /// Get or compute value
  Future<V> getOrCompute(K key, Future<V> Function() compute) async {
    final cached = get(key);
    if (cached != null) return cached;

    final value = await compute();
    set(key, value);
    return value;
  }

  /// Remove entry by key
  void remove(K key) {
    _remove(key);
  }

  /// Clear all entries
  void clear() {
    _cache.clear();
    _accessOrder.clear();
    _currentMemoryBytes = 0;
  }

  /// Remove expired entries
  void cleanup() {
    final expiredKeys = _cache.entries
        .where((e) => e.value.isExpired)
        .map((e) => e.key)
        .toList();

    for (final key in expiredKeys) {
      _remove(key);
    }
  }

  /// Get cache statistics
  Map<String, dynamic> get statistics => {
        'entries': _cache.length,
        'maxEntries': maxEntries,
        'memoryBytes': _currentMemoryBytes,
        'maxMemoryBytes': maxMemoryBytes,
        'memoryUsagePercent': memoryUsagePercent.toStringAsFixed(1),
      };

  void _remove(K key) {
    final entry = _cache.remove(key);
    if (entry != null) {
      _accessOrder.remove(key);
      _currentMemoryBytes -= entry.memorySizeBytes;
    }
  }

  void _evictIfNeeded(int newItemSize) {
    // Evict by entry count
    while (maxEntries > 0 && _cache.length >= maxEntries && _accessOrder.isNotEmpty) {
      _evictLRU();
    }

    // Evict by memory limit
    while (maxMemoryBytes > 0 &&
        _currentMemoryBytes + newItemSize > maxMemoryBytes &&
        _accessOrder.isNotEmpty) {
      _evictLRU();
    }
  }

  void _evictLRU() {
    if (_accessOrder.isEmpty) return;
    final lruKey = _accessOrder.removeAt(0);
    final entry = _cache.remove(lruKey);
    if (entry != null) {
      _currentMemoryBytes -= entry.memorySizeBytes;
      if (kDebugMode) {
        debugPrint('[MemoryLRUCache] Evicted LRU entry (memory: ${entry.memorySizeBytes} bytes)');
      }
    }
  }

  int _estimateSize(V value) {
    if (sizeEstimator != null) {
      return sizeEstimator!(value);
    }

    // Default estimation based on value type
    if (value is String) {
      return value.length * 2; // UTF-16
    } else if (value is List) {
      // Rough estimate for lists
      return 16 + value.length * 8;
    } else if (value is Map) {
      // Rough estimate for maps
      return 32 + value.length * 24;
    } else {
      // Default fallback - assume 1KB per object
      return 1024;
    }
  }
}

/// Pre-configured memory cache for images/screenshots
class ImageMemoryCache extends MemoryAwareLRUCache<String, List<int>> {
  static final ImageMemoryCache _instance = ImageMemoryCache._();
  static ImageMemoryCache get instance => _instance;

  ImageMemoryCache._()
      : super(
          maxEntries: 50,
          maxMemoryBytes: 100 * 1024 * 1024, // 100MB for images
          ttl: const Duration(minutes: 10),
          sizeEstimator: (bytes) => bytes.length,
        );
}

/// Pre-configured memory cache for JSON data
class JsonMemoryCache extends MemoryAwareLRUCache<String, Map<String, dynamic>> {
  static final JsonMemoryCache _instance = JsonMemoryCache._();
  static JsonMemoryCache get instance => _instance;

  JsonMemoryCache._()
      : super(
          maxEntries: 500,
          maxMemoryBytes: 20 * 1024 * 1024, // 20MB for JSON
          ttl: const Duration(minutes: 5),
          sizeEstimator: (json) => _estimateJsonSize(json),
        );

  static int _estimateJsonSize(Map<String, dynamic> json) {
    // Rough estimate based on key/value counts
    var size = 32; // Base object overhead
    for (final entry in json.entries) {
      size += entry.key.length * 2; // Key as string
      size += _estimateValueSize(entry.value);
    }
    return size;
  }

  static int _estimateValueSize(dynamic value) {
    if (value == null) return 0;
    if (value is String) return value.length * 2;
    if (value is num) return 8;
    if (value is bool) return 1;
    if (value is List) {
      return 16 + value.fold<int>(0, (sum, v) => sum + _estimateValueSize(v));
    }
    if (value is Map) {
      return _estimateJsonSize(Map<String, dynamic>.from(value));
    }
    return 8; // Default
  }
}
