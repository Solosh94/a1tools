// Base Repository
//
// Ready-to-use base repository with common functionality.
// Extend this class for feature-specific repositories.

import '../models/app_error.dart';
import '../services/api_client.dart';
import '../services/cache_manager.dart';
import 'repository.dart';

export 'repository.dart';

/// Base repository with API, caching, and common patterns
abstract class BaseRepository<T, ID> implements CrudRepository<T, ID> {
  final ApiClient _api;
  final String _endpoint;
  final Map<ID, CacheManager<T>> _itemCaches = {};
  CacheManager<List<T>>? _listCache;
  final CacheConfig? _itemCacheConfig;

  BaseRepository({
    required ApiClient api,
    required String endpoint,
    CacheConfig? itemCacheConfig,
    CacheConfig? listCacheConfig,
  })  : _api = api,
        _endpoint = endpoint,
        _itemCacheConfig = itemCacheConfig {
    if (listCacheConfig != null) {
      _listCache = CacheManager<List<T>>(
        key: '${endpoint}_list',
        config: listCacheConfig,
      );
    }
  }

  /// Get or create a cache for a specific item ID
  CacheManager<T>? _getItemCache(ID id) {
    if (_itemCacheConfig == null) return null;

    return _itemCaches.putIfAbsent(
      id,
      () => CacheManager<T>(
        key: '${_endpoint}_item_$id',
        config: _itemCacheConfig,
      ),
    );
  }

  /// Remove item cache for a specific ID
  void _removeItemCache(ID id) {
    final cache = _itemCaches.remove(id);
    cache?.invalidate();
  }

  /// Convert JSON to model - must be implemented
  T fromJson(Map<String, dynamic> json);

  /// Convert model to JSON - must be implemented
  Map<String, dynamic> toJson(T item);

  /// Get ID from model - must be implemented
  ID getId(T item);

  /// Key for list data in API response (default: 'data')
  String get listKey => 'data';

  /// Key for single item in API response (default: 'item')
  String get itemKey => 'item';

  /// Access to API client for custom methods
  ApiClient get api => _api;

  /// Base endpoint
  String get endpoint => _endpoint;

  @override
  Future<Result<T>> getById(ID id, {bool forceRefresh = false}) async {
    final itemCache = _getItemCache(id);

    // Check cache first if not forcing refresh
    if (itemCache != null && !forceRefresh) {
      final cached = itemCache.getStale();
      if (cached != null) {
        return Result.success(cached);
      }
    }

    final response = await _api.get('$_endpoint/$id');
    final result = _handleSingleResponse(response);

    // Cache the result on success
    if (result.isSuccess && itemCache != null) {
      itemCache.set(result.data as T);
    }

    return result;
  }

  @override
  Future<Result<List<T>>> getAll({bool forceRefresh = false}) async {
    if (_listCache != null && !forceRefresh) {
      final cacheResult = await _listCache!.getOrFetch(
        () => _fetchAll(),
        forceRefresh: forceRefresh,
      );

      if (cacheResult.success && cacheResult.data != null) {
        return Result.success(cacheResult.data!);
      }
      if (cacheResult.error != null) {
        return Result.failure(AppError.unknown(message: cacheResult.error!));
      }
    }

    return _fetchAllResult();
  }

  Future<List<T>> _fetchAll() async {
    final result = await _fetchAllResult();
    if (result.isSuccess) return result.data!;
    throw result.error!;
  }

  Future<Result<List<T>>> _fetchAllResult() async {
    final response = await _api.get(_endpoint);
    return _handleListResponse(response);
  }

  @override
  Future<Result<bool>> exists(ID id) async {
    final result = await getById(id);
    return Result.success(result.isSuccess);
  }

  @override
  Future<Result<T>> create(T item) async {
    final response = await _api.post(_endpoint, body: toJson(item));
    final result = _handleSingleResponse(response);

    if (result.isSuccess) {
      _invalidateCaches();
    }

    return result;
  }

  @override
  Future<Result<T>> update(T item) async {
    final id = getId(item);
    final response = await _api.put('$_endpoint/$id', body: toJson(item));
    final result = _handleSingleResponse(response);

    if (result.isSuccess) {
      _invalidateCaches();
    }

    return result;
  }

  @override
  Future<Result<void>> delete(ID id) async {
    final response = await _api.delete('$_endpoint/$id');

    if (response.success) {
      _invalidateCaches();
      return Result.success(null);
    }

    return Result.failure(
      response.error ?? AppError.unknown(message: response.message ?? 'Delete failed'),
    );
  }

  /// Search items by query
  Future<Result<List<T>>> search(String query, {int limit = 20}) async {
    final response = await _api.get(
      '$_endpoint?search=${Uri.encodeComponent(query)}&limit=$limit',
    );
    return _handleListResponse(response);
  }

  /// Get paginated results
  Future<Result<PagedResult<T>>> getPage({
    int page = 1,
    int pageSize = 20,
    Map<String, dynamic>? filters,
    String? sortBy,
    bool ascending = true,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': pageSize.toString(),
    };

    if (sortBy != null) {
      queryParams['sort'] = sortBy;
      queryParams['order'] = ascending ? 'asc' : 'desc';
    }

    if (filters != null) {
      filters.forEach((key, value) {
        queryParams[key] = value.toString();
      });
    }

    final queryString = queryParams.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');

    final response = await _api.get('$_endpoint?$queryString');

    if (response.success && response.data != null) {
      final data = response.data;
      List<T> items;
      int? totalItems;
      int? totalPages;

      if (data is List) {
        final listData = data as List;
        items = listData.map((e) => fromJson(e as Map<String, dynamic>)).toList();
      } else if (data is Map<String, dynamic>) {
        final listData = data[listKey] ?? data['items'] ?? data['results'];
        if (listData is List) {
          items = listData.map((e) => fromJson(e as Map<String, dynamic>)).toList();
        } else {
          return Result.failure(AppError.parse(details: 'Invalid list format'));
        }
        totalItems = data['total'] as int?;
        totalPages = data['total_pages'] as int?;
      } else {
        return Result.failure(AppError.parse(details: 'Invalid response format'));
      }

      return Result.success(PagedResult(
        items: items,
        page: page,
        pageSize: pageSize,
        totalItems: totalItems,
        totalPages: totalPages,
      ));
    }

    return Result.failure(
      response.error ?? AppError.unknown(message: response.message ?? 'Failed to get page'),
    );
  }

  /// Handle single item API response
  Result<T> _handleSingleResponse(ApiResponse response) {
    if (response.success && response.data != null) {
      final data = response.data;

      if (data is Map<String, dynamic>) {
        // Check if item is nested
        if (data.containsKey(itemKey)) {
          return Result.success(fromJson(data[itemKey] as Map<String, dynamic>));
        }
        return Result.success(fromJson(data));
      }
    }

    return Result.failure(
      response.error ?? AppError.unknown(message: response.message ?? 'Request failed'),
    );
  }

  /// Handle list API response
  Result<List<T>> _handleListResponse(ApiResponse response) {
    if (response.success && response.data != null) {
      final data = response.data;
      List<dynamic> items;

      if (data is List) {
        items = data;
      } else if (data is Map) {
        final listData = data[listKey] ?? data['items'] ?? data['results'];
        if (listData is List) {
          items = listData;
        } else {
          return Result.failure(AppError.parse(details: 'Invalid list format'));
        }
      } else {
        return Result.failure(AppError.parse(details: 'Invalid response format'));
      }

      return Result.success(
        items.map((e) => fromJson(e as Map<String, dynamic>)).toList(),
      );
    }

    return Result.failure(
      response.error ?? AppError.unknown(message: response.message ?? 'Request failed'),
    );
  }

  /// Invalidate all caches
  void _invalidateCaches() {
    for (final cache in _itemCaches.values) {
      cache.invalidate();
    }
    _itemCaches.clear();
    _listCache?.invalidate();
  }

  /// Manually invalidate caches
  void invalidate() => _invalidateCaches();

  /// Invalidate cache for a specific item
  void invalidateItem(ID id) => _removeItemCache(id);

  /// Get stale list data if available
  List<T>? getStaleList() => _listCache?.getStale();
}

/// Example: Simple in-memory repository for testing/mocking
class InMemoryRepository<T, ID> implements CrudRepository<T, ID> {
  final Map<ID, T> _store = {};
  final ID Function(T item) _getId;

  InMemoryRepository({required ID Function(T item) getId}) : _getId = getId;

  @override
  Future<Result<T>> getById(ID id) async {
    final item = _store[id];
    if (item != null) {
      return Result.success(item);
    }
    return Result.failure(AppError.notFound(details: 'Item not found'));
  }

  @override
  Future<Result<List<T>>> getAll() async {
    return Result.success(_store.values.toList());
  }

  @override
  Future<Result<bool>> exists(ID id) async {
    return Result.success(_store.containsKey(id));
  }

  @override
  Future<Result<T>> create(T item) async {
    final id = _getId(item);
    _store[id] = item;
    return Result.success(item);
  }

  @override
  Future<Result<T>> update(T item) async {
    final id = _getId(item);
    if (!_store.containsKey(id)) {
      return Result.failure(AppError.notFound(details: 'Item not found'));
    }
    _store[id] = item;
    return Result.success(item);
  }

  @override
  Future<Result<void>> delete(ID id) async {
    if (!_store.containsKey(id)) {
      return Result.failure(AppError.notFound(details: 'Item not found'));
    }
    _store.remove(id);
    return Result.success(null);
  }

  /// Clear all items
  void clear() => _store.clear();

  /// Seed with initial data
  void seed(List<T> items) {
    for (final item in items) {
      _store[_getId(item)] = item;
    }
  }
}
