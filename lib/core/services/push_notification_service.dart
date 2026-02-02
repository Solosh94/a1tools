// Push Notification Service
//
// Handles Firebase Cloud Messaging for push notifications.
// Supports both mobile (iOS/Android) and desktop (Windows).

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/api_config.dart';
import 'api_client.dart';

// Note: Firebase imports should be conditional based on platform
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';

class PushNotificationService {
  static String get _baseUrl => ApiConfig.apiBase;
  static const String _fcmTokenKey = 'fcm_token';
  static const String _notificationSettingsKey = 'notification_settings';

  // Singleton pattern
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final ApiClient _api = ApiClient.instance;
  String? _fcmToken;
  String? _currentUsername;
  NotificationSettings _settings = NotificationSettings();

  // Callbacks
  Function(NotificationPayload payload)? onNotificationReceived;
  Function(NotificationPayload payload)? onNotificationTapped;

  /// Initialize the push notification service
  Future<void> initialize({required String username}) async {
    _currentUsername = username;
    await _loadSettings();

    if (!_settings.enabled) {
      debugPrint('[PushNotificationService] Notifications disabled by user');
      return;
    }

    // Only initialize Firebase on mobile platforms
    if (Platform.isAndroid || Platform.isIOS) {
      await _initializeFirebase();
    } else {
      // For Windows/desktop, use polling-based notifications (already handled by chat_notification_service)
      debugPrint('[PushNotificationService] Using polling for desktop notifications');
    }
  }

  Future<void> _initializeFirebase() async {
    try {
      // Initialize Firebase
      // await Firebase.initializeApp();

      // Get FCM token
      // final messaging = FirebaseMessaging.instance;

      // Request permission
      // final settings = await messaging.requestPermission(
      //   alert: true,
      //   badge: true,
      //   sound: true,
      // );

      // debugPrint('[PushNotificationService] Permission status: ${settings.authorizationStatus}');

      // Get token
      // _fcmToken = await messaging.getToken();
      // debugPrint('[PushNotificationService] FCM Token: $_fcmToken');

      // if (_fcmToken != null) {
      //   await _registerToken(_fcmToken!);
      // }

      // Listen for token refresh
      // messaging.onTokenRefresh.listen((newToken) {
      //   _fcmToken = newToken;
      //   _registerToken(newToken);
      // });

      // Handle foreground messages
      // FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background/terminated messages
      // FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

      // Check for initial message (app opened from terminated state)
      // final initialMessage = await messaging.getInitialMessage();
      // if (initialMessage != null) {
      //   _handleMessageTap(initialMessage);
      // }

      debugPrint('[PushNotificationService] Firebase messaging initialized (stub)');
    } catch (e) {
      debugPrint('[PushNotificationService] Error initializing Firebase: $e');
    }
  }

  /// Register FCM token with the server (used when Firebase is enabled)
  // ignore: unused_element
  Future<void> _registerToken(String token) async {
    if (_currentUsername == null) return;

    try {
      final response = await _api.post(
        '$_baseUrl/push_notifications.php',
        body: {
          'action': 'register_token',
          'username': _currentUsername,
          'token': token,
          'platform': Platform.operatingSystem,
          'device_name': Platform.localHostname,
        },
      );

      if (response.success) {
        debugPrint('[PushNotificationService] Token registered successfully');
        // Save token locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_fcmTokenKey, token);
      }
    } catch (e) {
      debugPrint('[PushNotificationService] Error registering token: $e');
    }
  }

  /// Unregister FCM token (on logout)
  Future<void> unregisterToken() async {
    if (_fcmToken == null || _currentUsername == null) return;

    try {
      await _api.post(
        '$_baseUrl/push_notifications.php',
        body: {
          'action': 'unregister_token',
          'username': _currentUsername,
          'token': _fcmToken,
        },
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_fcmTokenKey);
      _fcmToken = null;
    } catch (e) {
      debugPrint('[PushNotificationService] Error unregistering token: $e');
    }
  }

  /// Handle foreground message
  // void _handleForegroundMessage(RemoteMessage message) {
  //   debugPrint('[PushNotificationService] Foreground message received');
  //   final payload = NotificationPayload.fromRemoteMessage(message);
  //   onNotificationReceived?.call(payload);
  // }

  /// Handle message tap (background/terminated)
  // void _handleMessageTap(RemoteMessage message) {
  //   debugPrint('[PushNotificationService] Message tapped');
  //   final payload = NotificationPayload.fromRemoteMessage(message);
  //   onNotificationTapped?.call(payload);
  // }

  /// Send a push notification to specific users
  Future<PushResult> sendNotification({
    required List<String> usernames,
    required String title,
    required String body,
    NotificationType type = NotificationType.general,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _api.post(
        '$_baseUrl/push_notifications.php',
        body: {
          'action': 'send_notification',
          'usernames': usernames,
          'title': title,
          'body': body,
          'type': type.value,
          'data': data,
          'sent_by': _currentUsername,
        },
      );

      if (response.success) {
        return PushResult(
          success: true,
          sentCount: response.rawJson?['sent_count'] ?? 0,
        );
      }
      return PushResult(success: false, error: response.message);
    } catch (e) {
      debugPrint('[PushNotificationService] Error sending notification: $e');
    }
    return PushResult(success: false, error: 'Failed to send notification');
  }

  /// Send notification to all users with a specific role
  Future<PushResult> sendToRole({
    required String role,
    required String title,
    required String body,
    NotificationType type = NotificationType.general,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _api.post(
        '$_baseUrl/push_notifications.php',
        body: {
          'action': 'send_to_role',
          'role': role,
          'title': title,
          'body': body,
          'type': type.value,
          'data': data,
          'sent_by': _currentUsername,
        },
      );

      if (response.success) {
        return PushResult(
          success: true,
          sentCount: response.rawJson?['sent_count'] ?? 0,
        );
      }
      return PushResult(success: false, error: response.message);
    } catch (e) {
      debugPrint('[PushNotificationService] Error sending to role: $e');
    }
    return PushResult(success: false, error: 'Failed to send notification');
  }

  /// Send notification to all users
  Future<PushResult> sendToAll({
    required String title,
    required String body,
    NotificationType type = NotificationType.general,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _api.post(
        '$_baseUrl/push_notifications.php',
        body: {
          'action': 'send_to_all',
          'title': title,
          'body': body,
          'type': type.value,
          'data': data,
          'sent_by': _currentUsername,
        },
      );

      if (response.success) {
        return PushResult(
          success: true,
          sentCount: response.rawJson?['sent_count'] ?? 0,
        );
      }
      return PushResult(success: false, error: response.message);
    } catch (e) {
      debugPrint('[PushNotificationService] Error sending to all: $e');
    }
    return PushResult(success: false, error: 'Failed to send notification');
  }

  /// Load notification settings from preferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_notificationSettingsKey);
      if (settingsJson != null) {
        _settings = NotificationSettings.fromJson(json.decode(settingsJson));
      }
    } catch (e) {
      debugPrint('[PushNotificationService] Error loading settings: $e');
    }
  }

  /// Save notification settings
  Future<void> saveSettings(NotificationSettings settings) async {
    _settings = settings;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_notificationSettingsKey, json.encode(settings.toJson()));
    } catch (e) {
      debugPrint('[PushNotificationService] Error saving settings: $e');
    }
  }

  NotificationSettings get settings => _settings;

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    // if (Platform.isAndroid || Platform.isIOS) {
    //   await FirebaseMessaging.instance.subscribeToTopic(topic);
    // }
    debugPrint('[PushNotificationService] Subscribed to topic: $topic (stub)');
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    // if (Platform.isAndroid || Platform.isIOS) {
    //   await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
    // }
    debugPrint('[PushNotificationService] Unsubscribed from topic: $topic (stub)');
  }

  /// Get notification history
  Future<List<NotificationRecord>> getNotificationHistory({int limit = 50}) async {
    try {
      final response = await _api.get(
        '$_baseUrl/push_notifications.php?action=get_history&username=$_currentUsername&limit=$limit',
      );

      if (response.success && response.rawJson?['notifications'] != null) {
        return (response.rawJson!['notifications'] as List)
            .map((n) => NotificationRecord.fromJson(n))
            .toList();
      }
    } catch (e) {
      debugPrint('[PushNotificationService] Error getting history: $e');
    }
    return [];
  }

  /// Mark notification as read
  Future<void> markAsRead(int notificationId) async {
    try {
      await _api.post(
        '$_baseUrl/push_notifications.php',
        body: {
          'action': 'mark_read',
          'notification_id': notificationId,
          'username': _currentUsername,
        },
      );
    } catch (e) {
      debugPrint('[PushNotificationService] Error marking as read: $e');
    }
  }

  /// Clear all notifications for user
  Future<void> clearAll() async {
    try {
      await _api.post(
        '$_baseUrl/push_notifications.php',
        body: {
          'action': 'clear_all',
          'username': _currentUsername,
        },
      );
    } catch (e) {
      debugPrint('[PushNotificationService] Error clearing notifications: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _currentUsername = null;
  }
}

/// Notification types
enum NotificationType {
  general('general'),
  alert('alert'),
  chat('chat'),
  jobAssignment('job_assignment'),
  jobUpdate('job_update'),
  reminder('reminder'),
  training('training'),
  system('system');

  final String value;
  const NotificationType(this.value);

  static NotificationType fromString(String? value) {
    return NotificationType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => NotificationType.general,
    );
  }
}

/// Notification payload
class NotificationPayload {
  final String? title;
  final String? body;
  final NotificationType type;
  final Map<String, dynamic> data;

  NotificationPayload({
    this.title,
    this.body,
    this.type = NotificationType.general,
    this.data = const {},
  });

  // Factory from Firebase RemoteMessage
  // factory NotificationPayload.fromRemoteMessage(RemoteMessage message) {
  //   return NotificationPayload(
  //     title: message.notification?.title,
  //     body: message.notification?.body,
  //     type: NotificationType.fromString(message.data['type']),
  //     data: message.data,
  //   );
  // }

  factory NotificationPayload.fromJson(Map<String, dynamic> json) {
    return NotificationPayload(
      title: json['title'],
      body: json['body'],
      type: NotificationType.fromString(json['type']),
      data: Map<String, dynamic>.from(json['data'] ?? {}),
    );
  }
}

/// Push notification result
class PushResult {
  final bool success;
  final int sentCount;
  final String? error;

  PushResult({
    required this.success,
    this.sentCount = 0,
    this.error,
  });
}

/// Notification settings
class NotificationSettings {
  final bool enabled;
  final bool alerts;
  final bool chats;
  final bool jobAssignments;
  final bool jobUpdates;
  final bool reminders;
  final bool training;
  final bool soundEnabled;
  final bool vibrationEnabled;

  NotificationSettings({
    this.enabled = true,
    this.alerts = true,
    this.chats = true,
    this.jobAssignments = true,
    this.jobUpdates = true,
    this.reminders = true,
    this.training = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      enabled: json['enabled'] ?? true,
      alerts: json['alerts'] ?? true,
      chats: json['chats'] ?? true,
      jobAssignments: json['job_assignments'] ?? true,
      jobUpdates: json['job_updates'] ?? true,
      reminders: json['reminders'] ?? true,
      training: json['training'] ?? true,
      soundEnabled: json['sound_enabled'] ?? true,
      vibrationEnabled: json['vibration_enabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'alerts': alerts,
    'chats': chats,
    'job_assignments': jobAssignments,
    'job_updates': jobUpdates,
    'reminders': reminders,
    'training': training,
    'sound_enabled': soundEnabled,
    'vibration_enabled': vibrationEnabled,
  };

  NotificationSettings copyWith({
    bool? enabled,
    bool? alerts,
    bool? chats,
    bool? jobAssignments,
    bool? jobUpdates,
    bool? reminders,
    bool? training,
    bool? soundEnabled,
    bool? vibrationEnabled,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      alerts: alerts ?? this.alerts,
      chats: chats ?? this.chats,
      jobAssignments: jobAssignments ?? this.jobAssignments,
      jobUpdates: jobUpdates ?? this.jobUpdates,
      reminders: reminders ?? this.reminders,
      training: training ?? this.training,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    );
  }
}

/// Notification history record
class NotificationRecord {
  final int id;
  final String title;
  final String body;
  final NotificationType type;
  final Map<String, dynamic> data;
  final String? sentBy;
  final DateTime createdAt;
  final bool isRead;

  NotificationRecord({
    required this.id,
    required this.title,
    required this.body,
    this.type = NotificationType.general,
    this.data = const {},
    this.sentBy,
    required this.createdAt,
    this.isRead = false,
  });

  factory NotificationRecord.fromJson(Map<String, dynamic> json) {
    return NotificationRecord(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      type: NotificationType.fromString(json['type']),
      data: json['data'] is Map ? Map<String, dynamic>.from(json['data']) : {},
      sentBy: json['sent_by'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      isRead: json['is_read'] == true || json['is_read'] == 1,
    );
  }
}
