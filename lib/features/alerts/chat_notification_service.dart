import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Desktop-only import
import 'package:local_notifier/local_notifier.dart' as desktop_notifier;

import '../../config/api_config.dart';
import '../../core/services/api_client.dart';

/// Cross-platform notification service for chat messages
class ChatNotificationService {
  static ChatNotificationService? _instance;
  static ChatNotificationService get instance => _instance ??= ChatNotificationService._();

  ChatNotificationService._();

  static String get _chatBaseUrl => ApiConfig.chatMessages;
  static String get _groupsBaseUrl => ApiConfig.chatGroups;
  static String get _usersApiUrl => ApiConfig.userManagement;
  static const Duration _checkInterval = Duration(seconds: 10);
  final ApiClient _api = ApiClient.instance;

  Timer? _checkTimer;
  String? _currentUsername;
  Set<int> _notifiedMessageIds = {};
  Set<int> _notifiedGroupMessageIds = {};
  bool _initialized = false;
  final Map<String, String> _userDisplayNames = {};
  
  // Mobile notifications plugin
  final FlutterLocalNotificationsPlugin _mobileNotifications = FlutterLocalNotificationsPlugin();
  
  // Callbacks when notification is clicked
  void Function(String fromUsername)? onNotificationClicked;
  void Function(int groupId)? onGroupNotificationClicked;
  
  bool get _isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  bool get _isMobile => Platform.isAndroid || Platform.isIOS;
  
  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      if (_isDesktop) {
        // Desktop: use local_notifier
        await desktop_notifier.localNotifier.setup(
          appName: 'A1 Tools',
          shortcutPolicy: desktop_notifier.ShortcutPolicy.requireCreate,
        );
        debugPrint('[ChatNotification] Desktop notifier initialized');
      } else if (_isMobile) {
        // Mobile: use flutter_local_notifications
        const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
        const iosSettings = DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
        
        const initSettings = InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        );
        
        await _mobileNotifications.initialize(
          initSettings,
          onDidReceiveNotificationResponse: (NotificationResponse response) {
            // Handle notification tap
            final payload = response.payload;
            if (payload != null) {
              if (payload.startsWith('chat:')) {
                final username = payload.substring(5);
                onNotificationClicked?.call(username);
              } else if (payload.startsWith('group:')) {
                final groupId = int.tryParse(payload.substring(6)) ?? 0;
                onGroupNotificationClicked?.call(groupId);
              }
            }
          },
        );
        
        // Request permissions on iOS
        if (Platform.isIOS) {
          await _mobileNotifications
              .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true);
        }
        
        // Request permissions on Android 13+
        if (Platform.isAndroid) {
          final androidPlugin = _mobileNotifications
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
          await androidPlugin?.requestNotificationsPermission();
        }
        
        debugPrint('[ChatNotification] Mobile notifier initialized');
      }
      
      _initialized = true;
    } catch (e) {
      debugPrint('[ChatNotification] Init failed: $e');
    }
  }
  
  /// Start monitoring for new messages
  void start(String username) {
    _currentUsername = username;
    
    // Initialize if not done
    initialize();
    
    // Load user display names
    _loadUserNames();
    
    // Check immediately
    _checkForNewMessages();
    
    // Then check periodically
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(_checkInterval, (_) => _checkForNewMessages());
    
    debugPrint('[ChatNotification] Started monitoring for $username');
  }
  
  /// Stop monitoring
  void stop() {
    _checkTimer?.cancel();
    _checkTimer = null;
    debugPrint('[ChatNotification] Stopped');
  }
  
  /// Load user display names for notifications
  Future<void> _loadUserNames() async {
    try {
      // Note: ApiClient.onGetHeaders adds X-Username header automatically
      final requestingUsername = _currentUsername ?? '';
      final response = await _api.get('$_usersApiUrl?action=list&requesting_username=$requestingUsername');
      if (response.success && response.rawJson?['users'] != null) {
        for (final user in response.rawJson!['users']) {
          final username = user['username'] ?? '';
          final firstName = user['first_name'] ?? '';
          final lastName = user['last_name'] ?? '';
          if (username.isNotEmpty) {
            if (firstName.isNotEmpty || lastName.isNotEmpty) {
              _userDisplayNames[username] = '$firstName $lastName'.trim();
            } else {
              _userDisplayNames[username] = username;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[ChatNotification] Load user names failed: $e');
    }
  }
  
  /// Check for new unread messages (DMs and Groups)
  Future<void> _checkForNewMessages() async {
    if (_currentUsername == null) return;
    
    // Check DMs
    await _checkDirectMessages();
    
    // Check Group messages
    await _checkGroupMessages();
  }
  
  /// Check for new direct messages
  Future<void> _checkDirectMessages() async {
    try {
      final response = await _api.get(
        '$_chatBaseUrl?action=get_unread&username=$_currentUsername',
        timeout: const Duration(seconds: 10),
      );

      if (response.success && response.rawJson?['messages'] != null) {
        final messages = response.rawJson!['messages'] as List;

        for (final msg in messages) {
          final messageId = int.tryParse(msg['id'].toString()) ?? 0;

          // Only notify for messages we haven't notified about yet
          if (!_notifiedMessageIds.contains(messageId)) {
            _notifiedMessageIds.add(messageId);

            final fromUsername = msg['from_username'] ?? 'Unknown';
            final displayName = _userDisplayNames[fromUsername] ?? fromUsername;
            final messageText = msg['message'] ?? '';
            final hasAttachment = msg['attachment_name'] != null;

            await _showNotification(
              id: messageId,
              title: displayName,
              body: hasAttachment && messageText.isEmpty
                  ? 'Sent an attachment'
                  : messageText,
              payload: 'chat:$fromUsername',
            );
          }
        }

        // Keep only last 100 message IDs to prevent memory bloat
        if (_notifiedMessageIds.length > 100) {
          _notifiedMessageIds = _notifiedMessageIds.toList().sublist(_notifiedMessageIds.length - 100).toSet();
        }
      }
    } catch (e) {
      debugPrint('[ChatNotification] Check DMs failed: $e');
    }
  }
  
  /// Check for new group messages
  Future<void> _checkGroupMessages() async {
    try {
      final response = await _api.get(
        '$_groupsBaseUrl?action=get_unread_all&username=$_currentUsername',
        timeout: const Duration(seconds: 10),
      );

      if (response.success && response.rawJson?['messages'] != null) {
        final messages = response.rawJson!['messages'] as List;

        for (final msg in messages) {
          final messageId = int.tryParse(msg['id'].toString()) ?? 0;

          if (!_notifiedGroupMessageIds.contains(messageId)) {
            _notifiedGroupMessageIds.add(messageId);

            final groupName = msg['group_name'] ?? 'Group';
            final groupId = int.tryParse(msg['group_id'].toString()) ?? 0;
            final fromUsername = msg['from_username'] ?? '';
            final fromDisplayName = msg['from_display_name'] ?? fromUsername;
            final messageText = msg['message'] ?? '';

            // Don't notify for system messages or own messages
            if (fromUsername != 'system' && fromUsername != _currentUsername) {
              await _showNotification(
                id: messageId + 100000, // Offset to avoid ID collision with DMs
                title: groupName,
                body: '$fromDisplayName: $messageText',
                payload: 'group:$groupId',
              );
            }
          }
        }

        // Keep only last 100 message IDs
        if (_notifiedGroupMessageIds.length > 100) {
          _notifiedGroupMessageIds = _notifiedGroupMessageIds.toList().sublist(_notifiedGroupMessageIds.length - 100).toSet();
        }
      }
    } catch (e) {
      debugPrint('[ChatNotification] Check groups failed: $e');
    }
  }
  
  /// Show notification (cross-platform)
  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (!_initialized) return;
    
    try {
      if (_isDesktop) {
        await _showDesktopNotification(title: title, body: body, payload: payload);
      } else if (_isMobile) {
        await _showMobileNotification(id: id, title: title, body: body, payload: payload);
      }
      debugPrint('[ChatNotification] Showed notification: $title');
    } catch (e) {
      debugPrint('[ChatNotification] Show notification failed: $e');
    }
  }
  
  /// Show desktop notification using local_notifier
  Future<void> _showDesktopNotification({
    required String title,
    required String body,
    required String payload,
  }) async {
    final notification = desktop_notifier.LocalNotification(
      identifier: 'chat_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      body: body.length > 100 ? '${body.substring(0, 100)}...' : body,
    );
    
    notification.onClick = () {
      if (payload.startsWith('chat:')) {
        final username = payload.substring(5);
        onNotificationClicked?.call(username);
      } else if (payload.startsWith('group:')) {
        final groupId = int.tryParse(payload.substring(6)) ?? 0;
        onGroupNotificationClicked?.call(groupId);
      }
    };
    
    await notification.show();
  }
  
  /// Show mobile notification using flutter_local_notifications
  Future<void> _showMobileNotification({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'chat_messages',
      'Chat Messages',
      channelDescription: 'Notifications for new chat messages',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _mobileNotifications.show(
      id,
      title,
      body.length > 100 ? '${body.substring(0, 100)}...' : body,
      notificationDetails,
      payload: payload,
    );
  }
  
  /// Clear notified messages for a user (call when opening their chat)
  void clearNotifiedForUser(String username) {
    // This allows re-notification if they close and reopen
  }
}
