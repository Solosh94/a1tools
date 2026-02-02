// Async State
//
// Generic state classes for handling async operations with loading, data, and error states.
// Provides a clean, type-safe way to represent the state of async data in the UI.

import '../models/app_error.dart';

/// Represents the status of an async operation
enum AsyncStatus {
  /// Initial state, no operation started
  initial,

  /// Operation in progress
  loading,

  /// Operation completed successfully
  success,

  /// Operation failed with error
  error,

  /// Refreshing data (has existing data, loading new)
  refreshing,
}

/// Generic async state that can hold data of type T
class AsyncState<T> {
  final AsyncStatus status;
  final T? data;
  final AppError? error;
  final DateTime? lastUpdated;

  const AsyncState._({
    required this.status,
    this.data,
    this.error,
    this.lastUpdated,
  });

  /// Initial state - no data loaded yet
  const AsyncState.initial()
      : status = AsyncStatus.initial,
        data = null,
        error = null,
        lastUpdated = null;

  /// Loading state - operation in progress
  const AsyncState.loading()
      : status = AsyncStatus.loading,
        data = null,
        error = null,
        lastUpdated = null;

  /// Success state with data
  AsyncState.success(T this.data)
      : status = AsyncStatus.success,
        error = null,
        lastUpdated = DateTime.now();

  /// Error state
  const AsyncState.error(AppError this.error)
      : status = AsyncStatus.error,
        data = null,
        lastUpdated = null;

  /// Refreshing state - has data but loading new
  AsyncState.refreshing(T this.data)
      : status = AsyncStatus.refreshing,
        error = null,
        lastUpdated = DateTime.now();

  // Convenience getters
  bool get isInitial => status == AsyncStatus.initial;
  bool get isLoading => status == AsyncStatus.loading;
  bool get isSuccess => status == AsyncStatus.success;
  bool get isError => status == AsyncStatus.error;
  bool get isRefreshing => status == AsyncStatus.refreshing;

  /// Has data (success or refreshing)
  bool get hasData => data != null;

  /// Is currently loading (initial load or refresh)
  bool get isBusy => isLoading || isRefreshing;

  /// Can show data (has data, regardless of refresh state)
  bool get canShowData => hasData && !isError;

  /// Copy with new values
  AsyncState<T> copyWith({
    AsyncStatus? status,
    T? data,
    AppError? error,
    DateTime? lastUpdated,
  }) {
    return AsyncState._(
      status: status ?? this.status,
      data: data ?? this.data,
      error: error ?? this.error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Transform to loading state, preserving existing data
  AsyncState<T> toLoading() {
    final currentData = data;
    if (currentData != null) {
      return AsyncState.refreshing(currentData);
    }
    return const AsyncState.loading();
  }

  /// Transform to success state with new data
  AsyncState<T> toSuccess(T newData) {
    return AsyncState.success(newData);
  }

  /// Transform to error state
  AsyncState<T> toError(AppError newError) {
    return AsyncState._(
      status: AsyncStatus.error,
      data: data, // Preserve existing data on error
      error: newError,
      lastUpdated: lastUpdated,
    );
  }

  /// Pattern matching for state handling
  R when<R>({
    required R Function() initial,
    required R Function() loading,
    required R Function(T data) success,
    required R Function(AppError error) error,
    R Function(T data)? refreshing,
  }) {
    switch (status) {
      case AsyncStatus.initial:
        return initial();
      case AsyncStatus.loading:
        return loading();
      case AsyncStatus.success:
        return success(data as T);
      case AsyncStatus.error:
        return error(this.error!);
      case AsyncStatus.refreshing:
        return (refreshing ?? success)(data as T);
    }
  }

  /// Simplified pattern matching with defaults
  R maybeWhen<R>({
    R Function()? initial,
    R Function()? loading,
    R Function(T data)? success,
    R Function(AppError error)? error,
    R Function(T data)? refreshing,
    required R Function() orElse,
  }) {
    switch (status) {
      case AsyncStatus.initial:
        return initial?.call() ?? orElse();
      case AsyncStatus.loading:
        return loading?.call() ?? orElse();
      case AsyncStatus.success:
        return success?.call(data as T) ?? orElse();
      case AsyncStatus.error:
        return error?.call(this.error!) ?? orElse();
      case AsyncStatus.refreshing:
        return refreshing?.call(data as T) ?? success?.call(data as T) ?? orElse();
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AsyncState<T> &&
        other.status == status &&
        other.data == data &&
        other.error == error;
  }

  @override
  int get hashCode => Object.hash(status, data, error);

  @override
  String toString() => 'AsyncState<$T>(status: $status, hasData: $hasData, error: $error)';
}

/// State for paginated data
class PaginatedState<T> {
  final AsyncStatus status;
  final List<T> items;
  final int currentPage;
  final int? totalPages;
  final int? totalItems;
  final bool hasMore;
  final AppError? error;

  const PaginatedState._({
    required this.status,
    required this.items,
    required this.currentPage,
    this.totalPages,
    this.totalItems,
    required this.hasMore,
    this.error,
  });

  /// Initial empty state
  const PaginatedState.initial()
      : status = AsyncStatus.initial,
        items = const [],
        currentPage = 0,
        totalPages = null,
        totalItems = null,
        hasMore = true,
        error = null;

  /// Loading first page
  const PaginatedState.loading()
      : status = AsyncStatus.loading,
        items = const [],
        currentPage = 0,
        totalPages = null,
        totalItems = null,
        hasMore = true,
        error = null;

  /// Success state with items
  PaginatedState.success({
    required this.items,
    required this.currentPage,
    this.totalPages,
    this.totalItems,
    bool? hasMore,
  })  : status = AsyncStatus.success,
        hasMore = hasMore ?? items.isNotEmpty,
        error = null;

  // Convenience getters
  bool get isInitial => status == AsyncStatus.initial;
  bool get isLoading => status == AsyncStatus.loading;
  bool get isSuccess => status == AsyncStatus.success;
  bool get isError => status == AsyncStatus.error;
  bool get isRefreshing => status == AsyncStatus.refreshing;
  bool get isEmpty => items.isEmpty && isSuccess;
  bool get hasData => items.isNotEmpty;

  /// Copy with new values
  PaginatedState<T> copyWith({
    AsyncStatus? status,
    List<T>? items,
    int? currentPage,
    int? totalPages,
    int? totalItems,
    bool? hasMore,
    AppError? error,
  }) {
    return PaginatedState._(
      status: status ?? this.status,
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      totalItems: totalItems ?? this.totalItems,
      hasMore: hasMore ?? this.hasMore,
      error: error ?? this.error,
    );
  }

  /// Add a page of items
  PaginatedState<T> addPage(
    List<T> newItems, {
    int? totalPages,
    int? totalItems,
    bool? hasMore,
  }) {
    return PaginatedState._(
      status: AsyncStatus.success,
      items: [...items, ...newItems],
      currentPage: currentPage + 1,
      totalPages: totalPages ?? this.totalPages,
      totalItems: totalItems ?? this.totalItems,
      hasMore: hasMore ?? newItems.isNotEmpty,
      error: null,
    );
  }

  /// Reset to initial state
  PaginatedState<T> reset() => const PaginatedState.initial();

  @override
  String toString() =>
      'PaginatedState<$T>(status: $status, items: ${items.length}, page: $currentPage, hasMore: $hasMore)';
}

/// State for form data with validation
class FormState<T> {
  final T data;
  final Map<String, String?> errors;
  final bool isSubmitting;
  final bool isValid;
  final bool isDirty;

  const FormState({
    required this.data,
    this.errors = const {},
    this.isSubmitting = false,
    this.isValid = true,
    this.isDirty = false,
  });

  bool get hasErrors => errors.values.any((e) => e != null);

  String? getError(String field) => errors[field];

  FormState<T> copyWith({
    T? data,
    Map<String, String?>? errors,
    bool? isSubmitting,
    bool? isValid,
    bool? isDirty,
  }) {
    return FormState(
      data: data ?? this.data,
      errors: errors ?? this.errors,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isValid: isValid ?? this.isValid,
      isDirty: isDirty ?? this.isDirty,
    );
  }

  FormState<T> setError(String field, String? error) {
    final newErrors = Map<String, String?>.from(errors);
    newErrors[field] = error;
    return copyWith(
      errors: newErrors,
      isValid: !newErrors.values.any((e) => e != null),
    );
  }

  FormState<T> clearErrors() {
    return copyWith(errors: {}, isValid: true);
  }
}
