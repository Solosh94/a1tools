// State Builder Widgets
//
// Convenience widgets for building UI based on async state.
// Handles loading, error, and success states with consistent patterns.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_error.dart';
import '../widgets/error_widgets.dart';
import 'async_state.dart';
import 'state_notifier.dart';

/// Builder widget for AsyncState
class AsyncStateBuilder<T> extends StatelessWidget {
  final AsyncState<T> state;
  final Widget Function(T data) builder;
  final Widget Function()? loading;
  final Widget Function(AppError error, VoidCallback? retry)? error;
  final Widget Function()? initial;
  final Widget Function(T data)? refreshing;
  final VoidCallback? onRetry;

  const AsyncStateBuilder({
    super.key,
    required this.state,
    required this.builder,
    this.loading,
    this.error,
    this.initial,
    this.refreshing,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return state.when(
      initial: () => initial?.call() ?? _defaultLoading(),
      loading: () => loading?.call() ?? _defaultLoading(),
      success: (data) => builder(data),
      error: (err) => error?.call(err, onRetry) ?? _defaultError(err),
      refreshing: (data) => refreshing?.call(data) ?? _buildWithRefreshIndicator(data),
    );
  }

  Widget _defaultLoading() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _defaultError(AppError err) {
    return ErrorView(
      error: err,
      onRetry: onRetry,
    );
  }

  Widget _buildWithRefreshIndicator(T data) {
    return Stack(
      children: [
        builder(data),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: LinearProgressIndicator(),
        ),
      ],
    );
  }
}

/// Consumer for AsyncStateNotifier with automatic rebuilds
class AsyncStateConsumer<N extends AsyncStateNotifier<T>, T> extends StatelessWidget {
  final Widget Function(BuildContext context, AsyncState<T> state, N notifier) builder;
  final Widget Function()? loading;
  final Widget Function(AppError error, VoidCallback? retry)? error;
  final VoidCallback? onRetry;

  const AsyncStateConsumer({
    super.key,
    required this.builder,
    this.loading,
    this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<N>(
      builder: (context, notifier, _) {
        final state = notifier.state;

        if (state.isLoading) {
          return loading?.call() ?? const Center(child: CircularProgressIndicator());
        }

        if (state.isError && !state.hasData) {
          return error?.call(state.error!, onRetry ?? notifier.clearError) ??
              ErrorView(error: state.error!, onRetry: onRetry ?? notifier.clearError);
        }

        return builder(context, state, notifier);
      },
    );
  }
}

/// Selector for specific data from AsyncStateNotifier
class AsyncStateSelector<N extends AsyncStateNotifier<T>, T, S> extends StatelessWidget {
  final S Function(T? data) selector;
  final Widget Function(BuildContext context, S selected) builder;

  const AsyncStateSelector({
    super.key,
    required this.selector,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<N, S>(
      selector: (_, notifier) => selector(notifier.data),
      builder: (context, selected, _) => builder(context, selected),
    );
  }
}

/// Builder for paginated state
class PaginatedStateBuilder<T> extends StatelessWidget {
  final PaginatedState<T> state;
  final Widget Function(List<T> items, bool hasMore) builder;
  final Widget Function()? loading;
  final Widget Function(AppError error)? error;
  final Widget Function()? empty;
  final VoidCallback? onLoadMore;
  final VoidCallback? onRetry;

  const PaginatedStateBuilder({
    super.key,
    required this.state,
    required this.builder,
    this.loading,
    this.error,
    this.empty,
    this.onLoadMore,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.items.isEmpty) {
      return loading?.call() ?? const Center(child: CircularProgressIndicator());
    }

    if (state.isError && state.items.isEmpty) {
      return error?.call(state.error!) ??
          ErrorView(error: state.error!, onRetry: onRetry);
    }

    if (state.isEmpty) {
      return empty?.call() ?? const Center(child: Text('No items'));
    }

    return builder(state.items, state.hasMore);
  }
}

/// List view with built-in pagination support
class PaginatedListView<T> extends StatelessWidget {
  final PaginatedState<T> state;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget Function()? loading;
  final Widget Function(AppError error)? error;
  final Widget Function()? empty;
  final Widget Function()? loadingMore;
  final VoidCallback? onLoadMore;
  final VoidCallback? onRetry;
  final VoidCallback? onRefresh;
  final EdgeInsets? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final Widget? separator;

  const PaginatedListView({
    super.key,
    required this.state,
    required this.itemBuilder,
    this.loading,
    this.error,
    this.empty,
    this.loadingMore,
    this.onLoadMore,
    this.onRetry,
    this.onRefresh,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.separator,
  });

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.items.isEmpty) {
      return loading?.call() ?? const Center(child: CircularProgressIndicator());
    }

    if (state.isError && state.items.isEmpty) {
      return error?.call(state.error!) ??
          ErrorView(error: state.error!, onRetry: onRetry);
    }

    if (state.isEmpty) {
      return empty?.call() ?? const Center(child: Text('No items'));
    }

    final itemCount = state.items.length + (state.hasMore ? 1 : 0);

    Widget listView = ListView.separated(
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemCount: itemCount,
      separatorBuilder: (_, __) => separator ?? const SizedBox.shrink(),
      itemBuilder: (context, index) {
        if (index >= state.items.length) {
          // Load more indicator
          if (onLoadMore != null && !state.isRefreshing) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              onLoadMore!();
            });
          }
          return loadingMore?.call() ??
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
        }
        return itemBuilder(context, state.items[index], index);
      },
    );

    if (onRefresh != null) {
      listView = RefreshIndicator(
        onRefresh: () async => onRefresh!(),
        child: listView,
      );
    }

    return listView;
  }
}

/// Extension methods for BuildContext
extension StateBuilderContext on BuildContext {
  /// Read a notifier without listening
  T readNotifier<T>() => read<T>();

  /// Watch a notifier and rebuild on changes
  T watchNotifier<T>() => watch<T>();

  /// Select specific data from a notifier
  R selectFrom<T, R>(R Function(T notifier) selector) {
    return select<T, R>(selector);
  }
}

/// Widget that shows different content based on multiple conditions
class ConditionalBuilder extends StatelessWidget {
  final List<(bool condition, Widget widget)> conditions;
  final Widget fallback;

  const ConditionalBuilder({
    super.key,
    required this.conditions,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    for (final (condition, widget) in conditions) {
      if (condition) return widget;
    }
    return fallback;
  }
}

/// Simple loading overlay wrapper
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final Color? barrierColor;
  final Widget? loadingWidget;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.barrierColor,
    this.loadingWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: Container(
              color: barrierColor ?? Colors.black26,
              child: Center(
                child: loadingWidget ?? const CircularProgressIndicator(),
              ),
            ),
          ),
      ],
    );
  }
}
