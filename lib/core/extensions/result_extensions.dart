// Result Extensions
//
// Extensions on Result<T> for easier error handling in UI code.
// Provides convenient methods to show errors, handle results, etc.

import 'package:flutter/material.dart';

import '../models/app_error.dart';
import '../repository/repository.dart';
import '../services/error_handler.dart';

/// Extension methods for Result to simplify UI error handling
extension ResultExtensions<T> on Result<T> {
  /// Handle the result and show error if failed
  ///
  /// Returns the data if successful, null if failed.
  /// Shows a SnackBar error message on failure.
  ///
  /// ```dart
  /// final users = await repository.getAll().handleError(context);
  /// if (users != null) {
  ///   // Use users
  /// }
  /// ```
  T? handleError(BuildContext context, {VoidCallback? onRetry}) {
    if (isSuccess) {
      return data;
    }
    if (context.mounted) {
      ErrorHandler.showErrorSnackBar(context, error!, onRetry: onRetry);
    }
    return null;
  }

  /// Handle the result with custom success/failure callbacks
  ///
  /// ```dart
  /// await repository.create(item).handle(
  ///   context,
  ///   onSuccess: (data) => showSuccessMessage('Created!'),
  ///   onFailure: (error) => log('Failed: $error'),
  /// );
  /// ```
  void handle(
    BuildContext context, {
    void Function(T data)? onSuccess,
    void Function(AppError error)? onFailure,
    bool showError = true,
    VoidCallback? onRetry,
  }) {
    if (isSuccess && data != null) {
      onSuccess?.call(data as T);
    } else {
      onFailure?.call(error!);
      if (showError && context.mounted) {
        ErrorHandler.showErrorSnackBar(context, error!, onRetry: onRetry);
      }
    }
  }

  /// Execute an action on success, show error on failure
  ///
  /// ```dart
  /// await repository.delete(id).onSuccess(context, () {
  ///   refreshList();
  ///   showMessage('Deleted successfully');
  /// });
  /// ```
  void onSuccess(BuildContext context, void Function(T data) action, {
    bool showError = true,
    VoidCallback? onRetry,
  }) {
    if (isSuccess && data != null) {
      action(data as T);
    } else if (showError && context.mounted) {
      ErrorHandler.showErrorSnackBar(context, error!, onRetry: onRetry);
    }
  }

  /// Get data or show error and return default value
  ///
  /// ```dart
  /// final users = await repository.getAll().dataOrError(context, []);
  /// // Always returns a list, shows error if fetch failed
  /// ```
  T dataOrError(BuildContext context, T defaultValue, {VoidCallback? onRetry}) {
    if (isSuccess && data != null) {
      return data as T;
    }
    if (context.mounted) {
      ErrorHandler.showErrorSnackBar(context, error!, onRetry: onRetry);
    }
    return defaultValue;
  }

  /// Show success message if successful
  ///
  /// ```dart
  /// await repository.update(item).showSuccess(context, 'Updated successfully!');
  /// ```
  void showSuccess(BuildContext context, String message, {
    bool showErrorOnFailure = true,
    VoidCallback? onRetry,
  }) {
    if (isSuccess && context.mounted) {
      ErrorHandler.showSuccess(context, message);
    } else if (showErrorOnFailure && context.mounted) {
      ErrorHandler.showErrorSnackBar(context, error!, onRetry: onRetry);
    }
  }

  /// Convert to AsyncSnapshot-like state for widgets
  ResultState<T> toState() {
    if (isSuccess) {
      return ResultState.success(data as T);
    }
    return ResultState.error(error!);
  }
}

/// Extension for Future Result for chained operations
extension FutureResultExtensions<T> on Future<Result<T>> {
  /// Handle the result when it completes
  ///
  /// Note: Caller must ensure context is still mounted after await.
  /// Best used with mounted check:
  /// ```dart
  /// final users = await repository.getAll().thenHandle();
  /// if (mounted) users.handleError(context);
  /// ```
  Future<Result<T>> thenHandle() async {
    return this;
  }

  /// Execute action on success after awaiting
  /// Returns the result for chaining
  Future<Result<T>> thenOnSuccess(void Function(T data) action) async {
    final result = await this;
    if (result.isSuccess && result.data != null) {
      action(result.data as T);
    }
    return result;
  }

  /// Get data or default value after awaiting
  Future<T> thenDataOr(T defaultValue) async {
    final result = await this;
    return result.dataOr(defaultValue);
  }
}

/// State wrapper for Result to use in StatefulWidgets
class ResultState<T> {
  final T? data;
  final AppError? error;
  final bool isLoading;

  const ResultState._({
    this.data,
    this.error,
    this.isLoading = false,
  });

  factory ResultState.initial() => const ResultState._();
  factory ResultState.loading() => const ResultState._(isLoading: true);
  factory ResultState.success(T data) => ResultState._(data: data);
  factory ResultState.error(AppError error) => ResultState._(error: error);

  bool get hasData => data != null;
  bool get hasError => error != null;
  bool get isEmpty => !hasData && !hasError && !isLoading;

  /// Build widget based on state
  Widget when({
    required Widget Function() loading,
    required Widget Function(T data) success,
    required Widget Function(AppError error) failure,
    Widget Function()? empty,
  }) {
    if (isLoading) return loading();
    if (hasError) return failure(error!);
    if (hasData) return success(data as T);
    return empty?.call() ?? const SizedBox.shrink();
  }

  /// Copy with new values
  ResultState<T> copyWith({
    T? data,
    AppError? error,
    bool? isLoading,
  }) {
    return ResultState._(
      data: data ?? this.data,
      error: error ?? this.error,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Extension for List of Results to handle multiple results
extension ResultListExtensions<T> on List<Result<T>> {
  /// Check if all results are successful
  bool get allSuccessful => every((r) => r.isSuccess);

  /// Check if any result failed
  bool get anyFailed => any((r) => r.isFailure);

  /// Get all successful data
  List<T> get successfulData => where((r) => r.isSuccess).map((r) => r.data as T).toList();

  /// Get first error if any
  AppError? get firstError {
    for (final result in this) {
      if (result.isFailure) return result.error;
    }
    return null;
  }

  /// Combine all results into a single Result containing List
  Result<List<T>> combine() {
    if (anyFailed) {
      return Result.failure(firstError!);
    }
    return Result.success(successfulData);
  }
}
