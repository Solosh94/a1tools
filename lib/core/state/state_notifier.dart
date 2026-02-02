// State Notifier
//
// Base class for state management with ChangeNotifier.
// Provides common patterns for loading data, error handling, and state updates.

import 'package:flutter/foundation.dart';

import '../models/app_error.dart';
import '../services/api_client.dart';
import 'async_state.dart';

/// Base class for managing async state with ChangeNotifier
abstract class AsyncStateNotifier<T> extends ChangeNotifier {
  AsyncState<T> _state = const AsyncState.initial();

  /// Current state
  AsyncState<T> get state => _state;

  // Convenience getters
  bool get isLoading => _state.isLoading;
  bool get isSuccess => _state.isSuccess;
  bool get isError => _state.isError;
  bool get isRefreshing => _state.isRefreshing;
  bool get hasData => _state.hasData;
  T? get data => _state.data;
  AppError? get error => _state.error;

  /// Update state and notify listeners
  @protected
  void setState(AsyncState<T> newState) {
    _state = newState;
    notifyListeners();
  }

  /// Load data with automatic state management
  @protected
  Future<void> loadData(Future<T> Function() loader) async {
    setState(_state.toLoading());

    try {
      final result = await loader();
      setState(AsyncState.success(result));
    } catch (e, stack) {
      final error = _createError(e, stack);
      setState(_state.toError(error));
    }
  }

  /// Load data from API response
  @protected
  Future<void> loadFromApi<R>(
    Future<ApiResponse<R>> Function() apiCall,
    T Function(R data) transform,
  ) async {
    setState(_state.toLoading());

    try {
      final response = await apiCall();

      if (response.success && response.data != null) {
        setState(AsyncState.success(transform(response.data as R)));
      } else {
        final error = response.error ?? AppError.unknown(message: response.message ?? 'Unknown error');
        setState(_state.toError(error));
      }
    } catch (e, stack) {
      final error = _createError(e, stack);
      setState(_state.toError(error));
    }
  }

  /// Refresh data (shows refreshing state while loading)
  Future<void> refresh(Future<T> Function() loader) async {
    if (_state.hasData) {
      setState(AsyncState.refreshing(_state.data as T));
    } else {
      setState(const AsyncState.loading());
    }

    try {
      final result = await loader();
      setState(AsyncState.success(result));
    } catch (e, stack) {
      final error = _createError(e, stack);
      setState(_state.toError(error));
    }
  }

  /// Reset to initial state
  void reset() {
    setState(const AsyncState.initial());
  }

  /// Clear error and keep existing data
  void clearError() {
    if (_state.hasData) {
      setState(AsyncState.success(_state.data as T));
    } else {
      setState(const AsyncState.initial());
    }
  }

  AppError _createError(dynamic e, StackTrace stack) {
    if (e is AppError) return e;
    return AppError.unknown(
      message: e.toString(),
      originalException: e,
      stackTrace: stack,
    );
  }
}

/// Base class for paginated data
abstract class PaginatedStateNotifier<T> extends ChangeNotifier {
  PaginatedState<T> _state = const PaginatedState.initial();

  /// Current state
  PaginatedState<T> get state => _state;

  // Convenience getters
  bool get isLoading => _state.isLoading;
  bool get isRefreshing => _state.isRefreshing;
  bool get hasMore => _state.hasMore;
  List<T> get items => _state.items;
  bool get isEmpty => _state.isEmpty;

  /// Update state and notify listeners
  @protected
  void setState(PaginatedState<T> newState) {
    _state = newState;
    notifyListeners();
  }

  /// Load first page
  @protected
  Future<void> loadFirstPage(
    Future<PaginatedResult<T>> Function(int page) loader,
  ) async {
    setState(_state.copyWith(status: AsyncStatus.loading, items: []));

    try {
      final result = await loader(1);
      setState(PaginatedState.success(
        items: result.items,
        currentPage: 1,
        totalPages: result.totalPages,
        totalItems: result.totalItems,
        hasMore: result.hasMore,
      ));
    } catch (e, stack) {
      setState(_state.copyWith(
        status: AsyncStatus.error,
        error: _createError(e, stack),
      ));
    }
  }

  /// Load next page
  @protected
  Future<void> loadNextPage(
    Future<PaginatedResult<T>> Function(int page) loader,
  ) async {
    if (!_state.hasMore || _state.isLoading || _state.isRefreshing) return;

    setState(_state.copyWith(status: AsyncStatus.refreshing));

    try {
      final nextPage = _state.currentPage + 1;
      final result = await loader(nextPage);
      setState(_state.addPage(
        result.items,
        totalPages: result.totalPages,
        totalItems: result.totalItems,
        hasMore: result.hasMore,
      ));
    } catch (e, stack) {
      setState(_state.copyWith(
        status: AsyncStatus.success, // Keep success to show existing items
        error: _createError(e, stack),
      ));
    }
  }

  /// Refresh (reload from first page)
  Future<void> refresh(
    Future<PaginatedResult<T>> Function(int page) loader,
  ) async {
    setState(_state.copyWith(status: AsyncStatus.refreshing));
    await loadFirstPage(loader);
  }

  /// Reset to initial state
  void reset() {
    setState(const PaginatedState.initial());
  }

  AppError _createError(dynamic e, StackTrace stack) {
    if (e is AppError) return e;
    return AppError.unknown(
      message: e.toString(),
      originalException: e,
      stackTrace: stack,
    );
  }
}

/// Result for paginated API calls
class PaginatedResult<T> {
  final List<T> items;
  final int? totalPages;
  final int? totalItems;
  final bool hasMore;

  PaginatedResult({
    required this.items,
    this.totalPages,
    this.totalItems,
    bool? hasMore,
  }) : hasMore = hasMore ?? items.isNotEmpty;

  factory PaginatedResult.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fromJson,
    String itemsKey,
  ) {
    final items = (json[itemsKey] as List?)?.map(fromJson).toList() ?? [];
    return PaginatedResult(
      items: items,
      totalPages: json['total_pages'] as int?,
      totalItems: json['total_items'] as int? ?? json['total'] as int?,
      hasMore: json['has_more'] as bool? ?? items.isNotEmpty,
    );
  }
}

/// Mixin for managing multiple async states
mixin MultiStateNotifier on ChangeNotifier {
  final Map<String, AsyncState> _states = {};

  /// Get state for a key
  AsyncState<T> getState<T>(String key) {
    return _states[key] as AsyncState<T>? ?? const AsyncState.initial();
  }

  /// Set state for a key
  void setStateFor<T>(String key, AsyncState<T> state) {
    _states[key] = state;
    notifyListeners();
  }

  /// Load data for a specific key
  Future<void> loadFor<T>(
    String key,
    Future<T> Function() loader,
  ) async {
    setStateFor<T>(key, getState<T>(key).toLoading());

    try {
      final result = await loader();
      setStateFor<T>(key, AsyncState.success(result));
    } catch (e, stack) {
      final error = e is AppError
          ? e
          : AppError.unknown(
              message: e.toString(),
              originalException: e,
              stackTrace: stack,
            );
      setStateFor<T>(key, getState<T>(key).toError(error));
    }
  }

  /// Check if any state is loading
  bool get isAnyLoading => _states.values.any((s) => s.isBusy);

  /// Check if any state has error
  bool get hasAnyError => _states.values.any((s) => s.isError);
}

/// Simple value notifier with persistence support
class PersistentValueNotifier<T> extends ValueNotifier<T> {
  final String key;
  final Future<void> Function(String key, T value)? onSave;
  final Future<T?> Function(String key)? onLoad;

  PersistentValueNotifier({
    required T initialValue,
    required this.key,
    this.onSave,
    this.onLoad,
  }) : super(initialValue) {
    _loadValue();
  }

  Future<void> _loadValue() async {
    if (onLoad != null) {
      final loadedValue = await onLoad!(key);
      if (loadedValue != null) {
        value = loadedValue;
      }
    }
  }

  @override
  set value(T newValue) {
    super.value = newValue;
    onSave?.call(key, newValue);
  }
}
