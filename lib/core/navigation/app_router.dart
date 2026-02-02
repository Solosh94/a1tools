// App Router
//
// Centralized navigation service for consistent routing across the app.
// Handles platform-specific navigation, deep linking, and route management.

import 'dart:io';

import 'package:flutter/material.dart';

/// Route names for the app
class AppRoutes {
  AppRoutes._();

  // Auth routes
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';

  // Main routes
  static const String home = '/';
  static const String profile = '/profile';
  static const String settings = '/settings';

  // Feature routes
  static const String sunday = '/sunday';
  static const String sundayBoard = '/sunday/board';
  static const String inspection = '/inspection';
  static const String inspectionForm = '/inspection/form';
  static const String inspectionReport = '/inspection/report';
  static const String training = '/training';
  static const String trainingTest = '/training/test';
  static const String timeClock = '/timeclock';
  static const String inventory = '/inventory';
  static const String alerts = '/alerts';
  static const String calendar = '/calendar';
  static const String route = '/route';

  // Admin routes
  static const String admin = '/admin';
  static const String adminUsers = '/admin/users';
  static const String adminMetrics = '/admin/metrics';
  static const String adminPayroll = '/admin/payroll';

  // HR routes
  static const String hr = '/hr';
  static const String hrEmployee = '/hr/employee';
}

/// Navigation service for the app
///
/// Usage:
/// ```dart
/// // Navigate to a route
/// AppRouter.to(context, AppRoutes.sunday);
///
/// // Navigate with arguments
/// AppRouter.to(context, AppRoutes.sundayBoard, arguments: {'boardId': 123});
///
/// // Replace current route
/// AppRouter.replace(context, AppRoutes.home);
///
/// // Go back
/// AppRouter.back(context);
///
/// // Clear stack and navigate
/// AppRouter.clearAndNavigate(context, AppRoutes.login);
/// ```
class AppRouter {
  AppRouter._();

  /// Global navigator key for navigation without context
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Get current navigator state
  static NavigatorState? get navigator => navigatorKey.currentState;

  /// Check if running on desktop
  static bool get isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  /// Check if running on mobile
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;

  // ============================================================================
  // BASIC NAVIGATION
  // ============================================================================

  /// Navigate to a named route
  static Future<T?> to<T>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.of(context).pushNamed<T>(
      routeName,
      arguments: arguments,
    );
  }

  /// Navigate to a route using a widget builder
  static Future<T?> toPage<T>(
    BuildContext context,
    Widget page, {
    bool fullscreenDialog = false,
  }) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute(
        builder: (_) => page,
        fullscreenDialog: fullscreenDialog,
      ),
    );
  }

  /// Replace current route with a named route
  static Future<T?> replace<T, TO>(
    BuildContext context,
    String routeName, {
    Object? arguments,
    TO? result,
  }) {
    return Navigator.of(context).pushReplacementNamed<T, TO>(
      routeName,
      arguments: arguments,
      result: result,
    );
  }

  /// Replace current route with a widget
  static Future<T?> replacePage<T, TO>(
    BuildContext context,
    Widget page, {
    TO? result,
  }) {
    return Navigator.of(context).pushReplacement<T, TO>(
      MaterialPageRoute(builder: (_) => page),
      result: result,
    );
  }

  /// Go back to previous route
  static void back<T>(BuildContext context, [T? result]) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(result);
    }
  }

  /// Check if can go back
  static bool canPop(BuildContext context) {
    return Navigator.of(context).canPop();
  }

  /// Clear navigation stack and navigate to a route
  static Future<T?> clearAndNavigate<T>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.of(context).pushNamedAndRemoveUntil<T>(
      routeName,
      (_) => false,
      arguments: arguments,
    );
  }

  /// Pop until a specific route
  static void popUntil(BuildContext context, String routeName) {
    Navigator.of(context).popUntil(ModalRoute.withName(routeName));
  }

  /// Pop until first route (home)
  static void popToFirst(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // ============================================================================
  // FEATURE-SPECIFIC NAVIGATION
  // ============================================================================

  /// Navigate to Sunday board
  static Future<void> toSundayBoard(
    BuildContext context, {
    required int boardId,
    required String username,
    String? boardName,
  }) {
    return to(
      context,
      AppRoutes.sundayBoard,
      arguments: {
        'boardId': boardId,
        'username': username,
        'boardName': boardName,
      },
    );
  }

  /// Navigate to inspection form
  static Future<void> toInspectionForm(
    BuildContext context, {
    required String username,
    int? inspectionId,
    bool isEdit = false,
  }) {
    return to(
      context,
      AppRoutes.inspectionForm,
      arguments: {
        'username': username,
        'inspectionId': inspectionId,
        'isEdit': isEdit,
      },
    );
  }

  /// Navigate to inspection report
  static Future<void> toInspectionReport(
    BuildContext context, {
    required int inspectionId,
  }) {
    return to(
      context,
      AppRoutes.inspectionReport,
      arguments: {'inspectionId': inspectionId},
    );
  }

  /// Navigate to training test
  static Future<void> toTrainingTest(
    BuildContext context, {
    required int testId,
    required String username,
  }) {
    return to(
      context,
      AppRoutes.trainingTest,
      arguments: {
        'testId': testId,
        'username': username,
      },
    );
  }

  /// Navigate to HR employee details
  static Future<void> toHrEmployee(
    BuildContext context, {
    required int employeeId,
  }) {
    return to(
      context,
      AppRoutes.hrEmployee,
      arguments: {'employeeId': employeeId},
    );
  }

  // ============================================================================
  // AUTH NAVIGATION
  // ============================================================================

  /// Navigate to login (clears stack)
  static Future<void> toLogin(BuildContext context) {
    return clearAndNavigate(context, AppRoutes.login);
  }

  /// Navigate to home after login (clears stack)
  static Future<void> toHomeAfterLogin(BuildContext context) {
    return clearAndNavigate(context, AppRoutes.home);
  }

  // ============================================================================
  // NAVIGATION WITHOUT CONTEXT
  // ============================================================================

  /// Navigate without context (uses global navigator key)
  static Future<T?>? toGlobal<T>(String routeName, {Object? arguments}) {
    return navigator?.pushNamed<T>(routeName, arguments: arguments);
  }

  /// Replace without context
  static Future<T?>? replaceGlobal<T, TO>(
    String routeName, {
    Object? arguments,
  }) {
    return navigator?.pushReplacementNamed<T, TO>(
      routeName,
      arguments: arguments,
    );
  }

  /// Clear and navigate without context
  static Future<T?>? clearAndNavigateGlobal<T>(
    String routeName, {
    Object? arguments,
  }) {
    return navigator?.pushNamedAndRemoveUntil<T>(
      routeName,
      (_) => false,
      arguments: arguments,
    );
  }

  // ============================================================================
  // DIALOGS & MODALS
  // ============================================================================

  /// Show a dialog
  static Future<T?> showAppDialog<T>(
    BuildContext context, {
    required Widget Function(BuildContext) builder,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: builder,
    );
  }

  /// Show a bottom sheet
  static Future<T?> showAppBottomSheet<T>(
    BuildContext context, {
    required Widget Function(BuildContext) builder,
    bool isScrollControlled = false,
    bool isDismissible = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      builder: builder,
    );
  }

  /// Show a confirmation dialog
  static Future<bool> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDangerous = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelText),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: isDangerous
                ? FilledButton.styleFrom(backgroundColor: Colors.red)
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ============================================================================
  // ROUTE ARGUMENTS HELPERS
  // ============================================================================

  /// Get route arguments from context
  static T? getArguments<T>(BuildContext context) {
    return ModalRoute.of(context)?.settings.arguments as T?;
  }

  /// Get a specific argument by key
  static T? getArgument<T>(BuildContext context, String key) {
    final args = getArguments<Map<String, dynamic>>(context);
    return args?[key] as T?;
  }
}

/// Extension for easier navigation from BuildContext
extension NavigationExtension on BuildContext {
  /// Navigate to a named route
  Future<T?> navigateTo<T>(String routeName, {Object? arguments}) {
    return AppRouter.to<T>(this, routeName, arguments: arguments);
  }

  /// Navigate to a page widget
  Future<T?> navigateToPage<T>(Widget page, {bool fullscreenDialog = false}) {
    return AppRouter.toPage<T>(this, page, fullscreenDialog: fullscreenDialog);
  }

  /// Go back
  void goBack<T>([T? result]) {
    AppRouter.back<T>(this, result);
  }

  /// Check if can go back
  bool get canGoBack => AppRouter.canPop(this);

  /// Clear stack and navigate
  Future<T?> clearAndNavigateTo<T>(String routeName, {Object? arguments}) {
    return AppRouter.clearAndNavigate<T>(this, routeName, arguments: arguments);
  }

  /// Get route arguments
  T? routeArguments<T>() => AppRouter.getArguments<T>(this);

  /// Get specific route argument
  T? routeArgument<T>(String key) => AppRouter.getArgument<T>(this, key);
}
