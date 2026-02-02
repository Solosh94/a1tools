// Repository Pattern
//
// Base repository interfaces and implementations for data access abstraction.
// Repositories provide a clean separation between data sources and business logic.

import '../models/app_error.dart';
import '../services/api_client.dart';
import '../services/cache_manager.dart';

/// Result type for repository operations
class Result<T> {
  final T? data;
  final AppError? error;
  final bool isSuccess;

  const Result._({this.data, this.error, required this.isSuccess});

  /// Success result with data
  factory Result.success(T data) => Result._(data: data, isSuccess: true);

  /// Failure result with error
  factory Result.failure(AppError error) => Result._(error: error, isSuccess: false);

  /// Create from API response
  factory Result.fromApiResponse(ApiResponse<T> response) {
    if (response.success && response.data != null) {
      return Result.success(response.data as T);
    }
    return Result.failure(
      response.error ?? AppError.unknown(message: response.message ?? 'Unknown error'),
    );
  }

  bool get isFailure => !isSuccess;

  /// Get data or throw if error
  T get dataOrThrow {
    if (isSuccess && data != null) return data as T;
    throw error ?? AppError.unknown(message: 'No data available');
  }

  /// Get data or default value
  T dataOr(T defaultValue) => data ?? defaultValue;

  /// Transform data if success
  Result<R> map<R>(R Function(T data) transform) {
    if (isSuccess && data != null) {
      return Result.success(transform(data as T));
    }
    return Result.failure(error!);
  }

  /// Transform data async if success
  Future<Result<R>> mapAsync<R>(Future<R> Function(T data) transform) async {
    if (isSuccess && data != null) {
      return Result.success(await transform(data as T));
    }
    return Result.failure(error!);
  }

  /// Execute callback based on result
  R when<R>({
    required R Function(T data) success,
    required R Function(AppError error) failure,
  }) {
    if (isSuccess && data != null) {
      return success(data as T);
    }
    return failure(error!);
  }

  @override
  String toString() => isSuccess ? 'Result.success($data)' : 'Result.failure($error)';
}

/// Base interface for read-only repositories
abstract class ReadRepository<T, ID> {
  /// Get a single item by ID
  Future<Result<T>> getById(ID id);

  /// Get all items
  Future<Result<List<T>>> getAll();

  /// Check if an item exists
  Future<Result<bool>> exists(ID id);
}

/// Base interface for full CRUD repositories
abstract class CrudRepository<T, ID> extends ReadRepository<T, ID> {
  /// Create a new item
  Future<Result<T>> create(T item);

  /// Update an existing item
  Future<Result<T>> update(T item);

  /// Delete an item by ID
  Future<Result<void>> delete(ID id);
}

/// Base interface for paginated repositories
abstract class PaginatedRepository<T, ID> extends ReadRepository<T, ID> {
  /// Get a page of items
  Future<Result<PagedResult<T>>> getPage({
    int page = 1,
    int pageSize = 20,
    Map<String, dynamic>? filters,
    String? sortBy,
    bool ascending = true,
  });

  /// Search items
  Future<Result<List<T>>> search(String query, {int limit = 20});
}

/// Paged result for pagination
class PagedResult<T> {
  final List<T> items;
  final int page;
  final int pageSize;
  final int? totalItems;
  final int? totalPages;

  const PagedResult({
    required this.items,
    required this.page,
    required this.pageSize,
    this.totalItems,
    this.totalPages,
  });

  bool get hasMore {
    if (totalPages != null) return page < totalPages!;
    return items.length >= pageSize;
  }

  bool get isEmpty => items.isEmpty;
  int get count => items.length;
}

/// Base implementation for API-backed repositories
abstract class ApiRepository<T, ID> implements CrudRepository<T, ID> {
  final ApiClient api;
  final String baseEndpoint;

  ApiRepository({
    required this.api,
    required this.baseEndpoint,
  });

  /// Convert JSON to model
  T fromJson(Map<String, dynamic> json);

  /// Convert model to JSON
  Map<String, dynamic> toJson(T item);

  /// Get ID from model
  ID getId(T item);

  /// Get the key for list responses (default: 'data')
  String get listKey => 'data';

  @override
  Future<Result<T>> getById(ID id) async {
    final response = await api.get('$baseEndpoint/$id');
    if (response.success && response.data != null) {
      return Result.success(fromJson(response.data as Map<String, dynamic>));
    }
    return Result.failure(
      response.error ?? AppError.unknown(message: response.message ?? 'Failed to get item'),
    );
  }

  @override
  Future<Result<List<T>>> getAll() async {
    final response = await api.get(baseEndpoint);
    if (response.success && response.data != null) {
      final data = response.data!;
      final listData = data[listKey];

      if (listData is List) {
        return Result.success(
          listData.map((e) => fromJson(e as Map<String, dynamic>)).toList(),
        );
      }
      return Result.failure(AppError.parse(details: 'Invalid response format'));
    }
    return Result.failure(
      response.error ?? AppError.unknown(message: response.message ?? 'Failed to get items'),
    );
  }

  @override
  Future<Result<bool>> exists(ID id) async {
    final result = await getById(id);
    return Result.success(result.isSuccess);
  }

  @override
  Future<Result<T>> create(T item) async {
    final response = await api.post(baseEndpoint, body: toJson(item));
    if (response.success && response.data != null) {
      return Result.success(fromJson(response.data as Map<String, dynamic>));
    }
    return Result.failure(
      response.error ?? AppError.unknown(message: response.message ?? 'Failed to create item'),
    );
  }

  @override
  Future<Result<T>> update(T item) async {
    final id = getId(item);
    final response = await api.put('$baseEndpoint/$id', body: toJson(item));
    if (response.success && response.data != null) {
      return Result.success(fromJson(response.data as Map<String, dynamic>));
    }
    return Result.failure(
      response.error ?? AppError.unknown(message: response.message ?? 'Failed to update item'),
    );
  }

  @override
  Future<Result<void>> delete(ID id) async {
    final response = await api.delete('$baseEndpoint/$id');
    if (response.success) {
      return Result.success(null);
    }
    return Result.failure(
      response.error ?? AppError.unknown(message: response.message ?? 'Failed to delete item'),
    );
  }
}

/// Mixin for adding caching to repositories
mixin CachedRepository<T, ID> on ReadRepository<T, ID> {
  CacheManager<T>? get itemCache => null;
  CacheManager<List<T>>? get listCache => null;

  /// Get item with caching
  Future<Result<T>> getCached(
    ID id,
    Future<Result<T>> Function() fetch, {
    bool forceRefresh = false,
  }) async {
    if (itemCache == null) return fetch();

    final cacheResult = await itemCache!.getOrFetch(
      () async {
        final result = await fetch();
        if (result.isSuccess) return result.data as T;
        throw result.error!;
      },
      forceRefresh: forceRefresh,
    );

    if (cacheResult.success && cacheResult.data != null) {
      return Result.success(cacheResult.data as T);
    }
    return Result.failure(AppError.unknown(message: cacheResult.error ?? 'Cache error'));
  }

  /// Get list with caching
  Future<Result<List<T>>> getAllCached(
    Future<Result<List<T>>> Function() fetch, {
    bool forceRefresh = false,
  }) async {
    if (listCache == null) return fetch();

    final cacheResult = await listCache!.getOrFetch(
      () async {
        final result = await fetch();
        if (result.isSuccess) return result.data!;
        throw result.error!;
      },
      forceRefresh: forceRefresh,
    );

    if (cacheResult.success && cacheResult.data != null) {
      return Result.success(cacheResult.data!);
    }
    return Result.failure(AppError.unknown(message: cacheResult.error ?? 'Cache error'));
  }

  /// Invalidate all caches
  void invalidateCaches() {
    itemCache?.invalidate();
    listCache?.invalidate();
  }
}

/// Mixin for offline support
mixin OfflineRepository<T, ID> on CrudRepository<T, ID> {
  /// Local storage for offline data
  Future<List<T>> getLocalItems();
  Future<void> saveLocalItems(List<T> items);
  Future<void> saveLocalItem(T item);
  Future<void> deleteLocalItem(ID id);

  /// Sync local changes with remote
  Future<Result<void>> sync();

  /// Get items with offline fallback
  Future<Result<List<T>>> getAllWithOfflineFallback() async {
    final result = await getAll();
    if (result.isSuccess) {
      await saveLocalItems(result.data!);
      return result;
    }

    // Fallback to local data
    final localItems = await getLocalItems();
    if (localItems.isNotEmpty) {
      return Result.success(localItems);
    }

    return result; // Return original error
  }
}
