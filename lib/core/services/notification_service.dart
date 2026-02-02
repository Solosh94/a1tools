import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Callback for handling notification taps
typedef NotificationTapCallback = void Function(String? payload);

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Callback invoked when user taps on a notification
  NotificationTapCallback? onNotificationTap;

  /// Counter for unique notification IDs
  /// Uses modulo to prevent overflow after ~2 billion notifications
  /// Wraps around to 0 when reaching max safe int for notification IDs
  int _notificationIdCounter = 0;
  static const int _maxNotificationId = 2147483647; // Max 32-bit signed int

  Future<void> init({NotificationTapCallback? onTap}) async {
    onNotificationTap = onTap;

    // Platform-specific initialization
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );
  }

  /// Handle notification tap
  void _handleNotificationResponse(NotificationResponse response) {
    debugPrint('[NotificationService] Notification tapped: ${response.payload}');
    if (onNotificationTap != null && response.payload != null) {
      onNotificationTap!(response.payload);
    }
  }

  Future<void> showAlert({
    required String title,
    required String body,
    String? payload,
  }) async {
    // Android channel/details
    const androidDetails = AndroidNotificationDetails(
      'dispatcher_alerts',        // channel id
      'Dispatcher Alerts',        // channel name
      channelDescription: 'Alerts from dispatcher manager',
      importance: Importance.max,
      priority: Priority.high,
    );

    // iOS/macOS details
    const darwinDetails = DarwinNotificationDetails();

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    // Get next ID and wrap around to prevent overflow
    final notificationId = _notificationIdCounter;
    _notificationIdCounter = (_notificationIdCounter + 1) % _maxNotificationId;

    await _plugin.show(
      notificationId,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Show a Sunday notification with board/item context for click handling
  Future<void> showSundayNotification({
    required String title,
    required String body,
    int? boardId,
    int? itemId,
  }) async {
    // Create payload with context for navigation
    final payload = jsonEncode({
      'type': 'sunday',
      'boardId': boardId,
      'itemId': itemId,
    });

    await showAlert(
      title: title,
      body: body,
      payload: payload,
    );
  }
}
