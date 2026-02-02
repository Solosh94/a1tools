// ignore_for_file: deprecated_member_use
// RadioListTile groupValue/onChanged deprecation will be addressed when migrating to Flutter 3.32+ RadioGroup

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import '../../config/api_config.dart';
import '../../app_theme.dart';
import 'chat_notification_service.dart';

// Extracted models
import 'models/alert_user.dart';
import 'models/chat_message.dart';
import 'models/chat_group.dart';
import 'models/group_member.dart';
import 'models/group_message.dart';

// Extracted widgets
import 'widgets/linkified_text.dart';
import 'widgets/forward_message_dialog.dart';
import 'widgets/image_viewer_dialog.dart';
import 'widgets/mobile_chat_screen.dart';
import 'widgets/mobile_alert_screen.dart';
import 'widgets/mobile_group_chat_screen.dart';

// Extracted utilities
import 'utils/message_timestamp.dart';

class AlertAdminScreen extends StatefulWidget {
 final String currentUsername;
 final String currentRole;
 final String? initialChatUsername; // Pre-select a chat user when opening
 final int? initialGroupId; // Pre-select a group when opening

 const AlertAdminScreen({
 super.key,
 required this.currentUsername,
 required this.currentRole,
 this.initialChatUsername,
 this.initialGroupId,
 });

 @override
 State<AlertAdminScreen> createState() => _AlertAdminScreenState();
}




class _AlertAdminScreenState extends State<AlertAdminScreen> with SingleTickerProviderStateMixin {
 // API URLs
 static String get _alertsBaseUrl => ApiConfig.alerts;
 static String get _chatBaseUrl => ApiConfig.chatMessages;
 static String get _groupsBaseUrl => ApiConfig.chatGroups;
 static String get _pictureUrl => ApiConfig.profilePicture;
 static String get _usersApiUrl => ApiConfig.userManagement;

 static const Color _accent = AppColors.accent;

 late TabController _tabController;

 // User list state
 List<AlertUser> _allUsers = [];
 List<AlertUser> _filteredUsers = [];
 bool _loadingUsers = true;
 String? _userLoadError;

 // Search and filter
 final TextEditingController _searchController = TextEditingController();

 // Profile picture cache
 final Map<String, Uint8List> _profilePictureCache = {};

 // Alert state
 String? _selectedAlertUsername;
 final TextEditingController _alertMessageController = TextEditingController();
 bool _sendingAlert = false;

 // Chat state - toggle between DMs and Groups
 bool _showGroupChats = false;
 
 // DM state
 String? _selectedChatUsername;
 List<ChatMessage> _chatMessages = [];
 bool _loadingChat = false;
 final TextEditingController _chatMessageController = TextEditingController();
 bool _sendingChat = false;
 final ScrollController _chatScrollController = ScrollController();
 
 // Group chat state
 List<ChatGroup> _groups = [];
 bool _loadingGroups = false;
 ChatGroup? _selectedGroup;
 List<GroupMessage> _groupMessages = [];
 List<GroupMember> _groupMembers = [];
 bool _loadingGroupChat = false;
 bool _sendingGroupChat = false;
 
 // File attachment state
 PlatformFile? _selectedFile;
 Uint8List? _selectedFileBytes;

 // Conversation data for WhatsApp-style chat list
 Map<String, Map<String, dynamic>> _conversationsData = {};

 // Refresh timers
 Timer? _refreshTimer;
 Timer? _chatRefreshTimer;

 @override
 void initState() {
 super.initState();
 _tabController = TabController(length: 2, vsync: this);
 _tabController.addListener(_onTabChanged);
 
 _loadUsers();
 _loadConversations(); // Load conversation data for WhatsApp-style chat list
 _searchController.addListener(_applyFilters);

 _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
 _loadUsersSilent();
 _loadConversations(); // Refresh conversation data
 });
 
 // Start notification service for incoming messages
 ChatNotificationService.instance.start(widget.currentUsername);
 ChatNotificationService.instance.onNotificationClicked = (fromUsername) {
 // Switch to chat tab and select the user
 _tabController.animateTo(0);
 setState(() {
 _selectedChatUsername = fromUsername;
 _loadChatMessages();
 _startChatRefresh();
 });
 };
 ChatNotificationService.instance.onGroupNotificationClicked = (groupId) {
 // Switch to chat tab and select the group
 _tabController.animateTo(0);
 _selectGroupById(groupId);
 };
 
 // Handle initial selection from notification click (when navigated from home screen)
 if (widget.initialChatUsername != null) {
 // Pre-select a DM chat
 WidgetsBinding.instance.addPostFrameCallback((_) {
 setState(() {
 _selectedChatUsername = widget.initialChatUsername;
 _loadChatMessages();
 _startChatRefresh();
 });
 });
 } else if (widget.initialGroupId != null) {
 // Pre-select a group chat
 WidgetsBinding.instance.addPostFrameCallback((_) {
 _selectGroupById(widget.initialGroupId!);
 });
 }
 }

 @override
 void dispose() {
 _tabController.dispose();
 _refreshTimer?.cancel();
 _chatRefreshTimer?.cancel();
 _searchController.dispose();
 _alertMessageController.dispose();
 _chatMessageController.dispose();
 _chatScrollController.dispose();
 ChatNotificationService.instance.stop();
 super.dispose();
 }

 void _onTabChanged() {
 if (_tabController.index == 0 && _selectedChatUsername != null) {
 // Switched to chat tab, start chat refresh
 _startChatRefresh();
 } else {
 _stopChatRefresh();
 }
 }

 void _startChatRefresh() {
 _chatRefreshTimer?.cancel();
 _chatRefreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
 if (_showGroupChats && _selectedGroup != null) {
 _loadGroupMessagesSilent();
 } else if (_selectedChatUsername != null) {
 _loadChatMessagesSilent();
 }
 // Also refresh conversations list to update ordering and unread counts
 _loadConversations();
 });
 }

 void _stopChatRefresh() {
 _chatRefreshTimer?.cancel();
 _chatRefreshTimer = null;
 }

 // ============ USER LOADING ============

 Future<void> _loadProfilePicture(String username) async {
 if (_profilePictureCache.containsKey(username)) return;

 try {
 final response = await http.get(
 Uri.parse('$_pictureUrl?username=${Uri.encodeComponent(username)}'),
 );

 if (response.statusCode == 200) {
 final data = jsonDecode(response.body);
 if (data['success'] == true && data['picture'] != null) {
 final bytes = base64Decode(data['picture']);
 if (mounted) {
 setState(() {
 _profilePictureCache[username] = bytes;
 });
 }
 }
 }
 } catch (e) {
 // Silently fail
 }
 }

 Future<void> _loadUsers() async {
 setState(() {
 _loadingUsers = true;
 _userLoadError = null;
 });

 try {
 // Fetch users from a1tools_users table (has first_name, last_name)
 final usersResponse = await http.get(
   Uri.parse('$_usersApiUrl?action=list&requesting_username=${widget.currentUsername}'),
   headers: {'X-Username': widget.currentUsername},
 );

 if (usersResponse.statusCode != 200) {
 throw Exception('Failed to load users');
 }

 final usersData = jsonDecode(usersResponse.body);
 if (usersData['success'] != true) {
 throw Exception(usersData['error'] ?? 'Failed to load users');
 }

 final usersList = usersData['users'] as List;

 final List<AlertUser> users = [];
 for (final item in usersList) {
 if (item is! Map) continue;

 final username = (item['username'] ?? '').toString();
 final role = (item['role'] ?? '').toString();
 final firstName = item['first_name']?.toString();
 final lastName = item['last_name']?.toString();
 final appStatus = item['app_status']?.toString() ?? 'offline';
 final isBirthday = item['is_birthday'] == true;

 if (username.isEmpty || role.isEmpty) continue;

 users.add(AlertUser(
 username: username,
 role: role,
 firstName: firstName,
 lastName: lastName,
 appStatus: appStatus,
 isBirthday: isBirthday,
 ));
 }

 if (!context.mounted) return;

 _allUsers = _applyRoleVisibility(users);
 _applyFilters();

 setState(() {
 _loadingUsers = false;
 });

 // Load profile pictures in background
 for (final user in _allUsers) {
 _loadProfilePicture(user.username);
 }
 } catch (e) {
 if (!context.mounted) return;
 setState(() {
 _userLoadError = 'Error loading users: $e';
 _loadingUsers = false;
 });
 }
 }

 Future<void> _loadUsersSilent() async {
 try {
 // Fetch users from a1tools_users table
 final usersResponse = await http.get(
   Uri.parse('$_usersApiUrl?action=list&requesting_username=${widget.currentUsername}'),
   headers: {'X-Username': widget.currentUsername},
 );

 if (usersResponse.statusCode != 200) return;

 final usersData = jsonDecode(usersResponse.body);
 if (usersData['success'] != true) return;

 final usersList = usersData['users'] as List;

 final List<AlertUser> users = [];
 for (final item in usersList) {
 if (item is! Map) continue;

 final username = (item['username'] ?? '').toString();
 final role = (item['role'] ?? '').toString();
 final firstName = item['first_name']?.toString();
 final lastName = item['last_name']?.toString();
 final appStatus = item['app_status']?.toString() ?? 'offline';
 final isBirthday = item['is_birthday'] == true;

 if (username.isEmpty || role.isEmpty) continue;

 users.add(AlertUser(
 username: username,
 role: role,
 firstName: firstName,
 lastName: lastName,
 appStatus: appStatus,
 isBirthday: isBirthday,
 ));
 }

 if (!context.mounted) return;

 setState(() {
 _allUsers = _applyRoleVisibility(users);
 _applyFilters();
 });
 } catch (e) {
 // Silent fail
 debugPrint('[AlertAdminScreen] Error: $e');
 }
 }

 /// Get users sorted for chat (WhatsApp-style: unread first, then by last message time)
 List<AlertUser> _getChatSortedUsers() {
 // Merge conversation data with users
 final usersWithConv = _filteredUsers.map((user) {
 final convData = _conversationsData[user.username];
 if (convData != null) {
 return user.copyWithConversation(
 unreadCount: convData['unread_count'] as int? ?? 0,
 lastMessage: convData['last_message'] as String?,
 lastMessageAt: convData['last_message_at'] as DateTime?,
 lastMessageFrom: convData['last_message_from'] as String?,
 );
 }
 return user;
 }).toList();

 // Sort: users with unread messages first, then by last message time (newest first),
 // then users without conversations by online status then alphabetically
 usersWithConv.sort((a, b) {
 // First priority: users with unread messages at the top
 if (a.hasUnread && !b.hasUnread) return -1;
 if (!a.hasUnread && b.hasUnread) return 1;

 // Second priority: users with conversations sorted by last message time
 if (a.hasConversation && b.hasConversation) {
 return b.lastMessageAt!.compareTo(a.lastMessageAt!); // Newest first
 }

 // Users with conversations come before those without
 if (a.hasConversation && !b.hasConversation) return -1;
 if (!a.hasConversation && b.hasConversation) return 1;

 // For users without conversations: sort by online status then alphabetically
 int statusOrder(String status) {
 switch (status) {
 case 'online': return 0;
 case 'away': return 1;
 default: return 2;
 }
 }
 final statusCompare = statusOrder(a.appStatus).compareTo(statusOrder(b.appStatus));
 if (statusCompare != 0) return statusCompare;
 return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
 });

 return usersWithConv;
 }

 /// Load conversations data (unread counts, last messages) for WhatsApp-style chat list
 Future<void> _loadConversations() async {
 try {
 final response = await http.get(Uri.parse(
 '$_chatBaseUrl?action=get_conversations&username=${widget.currentUsername}'
 ));

 if (response.statusCode != 200) return;

 final data = jsonDecode(response.body);
 if (data['success'] != true) return;

 final conversations = data['conversations'] as List? ?? [];
 final newConversationsData = <String, Map<String, dynamic>>{};

 for (final conv in conversations) {
 final otherUser = conv['other_user']?.toString() ?? '';
 if (otherUser.isEmpty) continue;

 newConversationsData[otherUser] = {
 'unread_count': int.tryParse(conv['unread_count']?.toString() ?? '0') ?? 0,
 'last_message': conv['last_message']?.toString(),
 'last_message_at': conv['last_message_at'] != null
 ? DateTime.tryParse(conv['last_message_at'].toString())
 : null,
 'last_message_from': conv['last_message_from']?.toString(),
 };
 }

 if (!context.mounted) return;

 setState(() {
 _conversationsData = newConversationsData;
 _applyFilters(); // Re-apply filters to update sorting
 });
 } catch (e) {
 // Silent fail
 debugPrint('[AlertAdminScreen] Error: $e');
 }
 }

 List<AlertUser> _applyRoleVisibility(List<AlertUser> users) {
 final current = widget.currentUsername.toLowerCase();
 final currentRole = widget.currentRole.toLowerCase();

 return users.where((u) {
 // Don't show self
 if (u.username.toLowerCase() == current) return false;

 final targetRole = u.role.toLowerCase();

 // Everyone can see developers (so they can contact support)
 if (targetRole == 'developer') return true;

 // Developer can see everyone
 if (currentRole == 'developer') return true;

 // Administrator can see everyone
 if (currentRole == 'administrator') return true;

 // Management can see dispatchers, remote dispatchers, technicians, marketing, administrators
 if (currentRole == 'management') {
 return ['dispatcher', 'remote_dispatcher', 'technician', 'marketing', 'administrator'].contains(targetRole);
 }

 // Dispatcher/Marketing can see other dispatchers, technicians, management
 if (currentRole == 'dispatcher' || currentRole == 'marketing') {
 return ['dispatcher', 'remote_dispatcher', 'technician', 'management', 'marketing'].contains(targetRole);
 }

 // Technicians can see dispatchers, management
 if (currentRole == 'technician') {
 return ['dispatcher', 'remote_dispatcher', 'management'].contains(targetRole);
 }

 return false;
 }).toList();
 }

 void _applyFilters() {
 final searchQuery = _searchController.text.toLowerCase().trim();

 setState(() {
 _filteredUsers = _allUsers.where((user) {
 // Search filter
 if (searchQuery.isNotEmpty) {
 final matchesUsername = user.username.toLowerCase().contains(searchQuery);
 final matchesFirstName = user.firstName?.toLowerCase().contains(searchQuery) ?? false;
 final matchesLastName = user.lastName?.toLowerCase().contains(searchQuery) ?? false;
 if (!matchesUsername && !matchesFirstName && !matchesLastName) return false;
 }

 return true;
 }).toList();

 // Sort: online first, then away, then offline, then alphabetically by display name
 _filteredUsers.sort((a, b) {
 int statusOrder(String status) {
 switch (status) {
 case 'online': return 0;
 case 'away': return 1;
 default: return 2;
 }
 }
 final statusCompare = statusOrder(a.appStatus).compareTo(statusOrder(b.appStatus));
 if (statusCompare != 0) return statusCompare;
 return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
 });
 });
 }

 // ============ ALERTS ============

 Future<void> _sendAlert() async {
 final message = _alertMessageController.text.trim();
 if (_selectedAlertUsername == null || message.isEmpty) return;

 setState(() => _sendingAlert = true);

 try {
 final client = HttpClient();
 final request = await client.postUrl(Uri.parse(_alertsBaseUrl));
 request.headers.set('Content-Type', 'application/json');
 request.write(jsonEncode({
 'to_username': _selectedAlertUsername,
 'from_username': widget.currentUsername,
 'message': message,
 }));

 final response = await request.close();
 final body = await response.transform(utf8.decoder).join();

 if (response.statusCode == 200 || response.statusCode == 201) {
 if (mounted) {
 _alertMessageController.clear();
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Alert sent to $_selectedAlertUsername'),
 backgroundColor: Colors.green,
 ),
 );
 }
 } else {
 throw Exception('Failed: $body');
 }
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Error sending alert: $e'), backgroundColor: Colors.red),
 );
 }
 } finally {
 if (mounted) setState(() => _sendingAlert = false);
 }
 }

 bool get _canBroadcast {
 final role = widget.currentRole.toLowerCase();
 return role == 'developer' || role == 'administrator';
 }

 void _showBroadcastDialog() {
 final messageController = TextEditingController();
 String broadcastType = 'everyone'; // everyone, role
 String? selectedRole;
 bool sending = false;

 // Image attachment for broadcast
 PlatformFile? broadcastImage;
 Uint8List? broadcastImageBytes;

 final roles = ['dispatcher', 'remote_dispatcher', 'technician', 'management', 'marketing', 'administrator', 'developer'];

 showDialog(
 context: context,
 builder: (context) {
 return StatefulBuilder(
 builder: (context, setDialogState) {
 final isDark = Theme.of(context).brightness == Brightness.dark;
 
 Future<void> pickBroadcastImage() async {
 try {
 final result = await FilePicker.platform.pickFiles(
 type: FileType.image,
 allowMultiple: false,
 withData: true,
 );
 if (result != null && result.files.isNotEmpty) {
 final file = result.files.first;
 if (file.bytes != null) {
 setDialogState(() {
 broadcastImage = file;
 broadcastImageBytes = file.bytes;
 });
 }
 }
 } catch (e) {
 debugPrint('Error picking image: $e');
 }
 }
 
 return AlertDialog(
 title: const Row(
 children: [
 Icon(Icons.campaign, color: _accent),
 SizedBox(width: 8),
 Text('Broadcast Alert'),
 ],
 ),
 content: SizedBox(
 width: 450,
 child: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Broadcast type selection
 Text(
 'Send to:',
 style: TextStyle(
 fontWeight: FontWeight.bold,
 color: isDark ? Colors.white70 : Colors.black87,
 ),
 ),
 const SizedBox(height: 8),
 // Everyone option
 RadioListTile<String>(
 title: const Text('Everyone'),
 subtitle: Text('${_allUsers.length} users'),
 value: 'everyone',
 groupValue: broadcastType,
 activeColor: _accent,
 onChanged: (val) {
 setDialogState(() {
 broadcastType = val!;
 selectedRole = null;
 });
 },
 ),
 // By role option
 RadioListTile<String>(
 title: const Text('By Role'),
 value: 'role',
 groupValue: broadcastType,
 activeColor: _accent,
 onChanged: (val) {
 setDialogState(() => broadcastType = val!);
 },
 ),
 // Role dropdown (if by role selected)
 if (broadcastType == 'role')
 Padding(
 padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
 child: DropdownButtonFormField<String>(
 decoration: const InputDecoration(
 labelText: 'Select Role',
 border: OutlineInputBorder(),
 ),
 initialValue: selectedRole,
 items: roles.map((r) => DropdownMenuItem(
 value: r,
 child: Text(_formatRole(r)),
 )).toList(),
 onChanged: (val) {
 setDialogState(() => selectedRole = val);
 },
 ),
 ),
 const SizedBox(height: 16),
 // Message input
 TextField(
 controller: messageController,
 decoration: const InputDecoration(
 labelText: 'Alert Message',
 hintText: 'Enter your broadcast message...',
 border: OutlineInputBorder(),
 ),
 maxLines: 3,
 ),
 const SizedBox(height: 12),
 
 // Image attachment section
 Text(
 'Attach Image (optional):',
 style: TextStyle(
 fontWeight: FontWeight.bold,
 color: isDark ? Colors.white70 : Colors.black87,
 ),
 ),
 const SizedBox(height: 8),
 if (broadcastImage != null && broadcastImageBytes != null) ...[
 // Show selected image preview
 Container(
 constraints: const BoxConstraints(maxHeight: 150),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(8),
 border: Border.all(
 color: isDark ? Colors.white24 : Colors.grey.shade300,
 ),
 ),
 child: Stack(
 children: [
 ClipRRect(
 borderRadius: BorderRadius.circular(8),
 child: Image.memory(
 broadcastImageBytes!,
 fit: BoxFit.contain,
 width: double.infinity,
 ),
 ),
 Positioned(
 top: 4,
 right: 4,
 child: IconButton(
 onPressed: () {
 setDialogState(() {
 broadcastImage = null;
 broadcastImageBytes = null;
 });
 },
 icon: Container(
 padding: const EdgeInsets.all(4),
 decoration: BoxDecoration(
 color: Colors.black54,
 borderRadius: BorderRadius.circular(20),
 ),
 child: const Icon(
 Icons.close,
 color: Colors.white,
 size: 16,
 ),
 ),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 4),
 Text(
 broadcastImage!.name,
 style: TextStyle(
 fontSize: 12,
 color: isDark ? Colors.white60 : Colors.black54,
 ),
 ),
 ] else
 OutlinedButton.icon(
 onPressed: pickBroadcastImage,
 icon: const Icon(Icons.image, size: 18),
 label: const Text('Select Image'),
 style: OutlinedButton.styleFrom(
 foregroundColor: _accent,
 side: BorderSide(color: _accent.withValues(alpha: 0.5)),
 ),
 ),
 
 const SizedBox(height: 12),
 // Warning
 Container(
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: Colors.orange.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(8),
 border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
 ),
 child: Row(
 children: [
 const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 'This will send an instant alert popup to all selected users.',
 style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 ),
 actions: [
 TextButton(
 onPressed: sending ? null : () => Navigator.pop(context),
 child: const Text('Cancel'),
 ),
 ElevatedButton.icon(
 onPressed: sending || messageController.text.trim().isEmpty ||
 (broadcastType == 'role' && selectedRole == null)
 ? null
 : () async {
 setDialogState(() => sending = true);
 
 List<String> recipients = [];
 if (broadcastType == 'everyone') {
 recipients = _allUsers.map((u) => u.username).toList();
 } else if (selectedRole != null) {
 recipients = _allUsers
 .where((u) => u.role.toLowerCase() == selectedRole!.toLowerCase())
 .map((u) => u.username)
 .toList();
 }
 
 await _sendBroadcastAlert(
 messageController.text.trim(),
 recipients,
 imageFile: broadcastImage,
 imageBytes: broadcastImageBytes,
 );
 
 if (context.mounted) {
 Navigator.pop(context);
 }
 },
 icon: sending 
 ? const SizedBox(
 width: 16,
 height: 16,
 child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
 )
 : const Icon(Icons.send, size: 18),
 label: Text(sending ? 'Sending...' : 'Send Broadcast'),
 style: ElevatedButton.styleFrom(
 backgroundColor: _accent,
 foregroundColor: Colors.white,
 ),
 ),
 ],
 );
 },
 );
 },
 );
 }

 Future<void> _sendBroadcastAlert(
 String message, 
 List<String> recipients, {
 PlatformFile? imageFile,
 Uint8List? imageBytes,
 }) async {
 int successCount = 0;
 int failCount = 0;

 // Prepare attachment data if image is provided
 String? attachmentName;
 String? attachmentData;
 String? attachmentType;
 
 if (imageFile != null && imageBytes != null) {
 attachmentName = imageFile.name;
 attachmentData = base64Encode(imageBytes);
 attachmentType = 'image';
 }

 for (final username in recipients) {
 // Don't send to self
 if (username == widget.currentUsername) continue;
 
 try {
 final client = HttpClient();
 final request = await client.postUrl(Uri.parse(_alertsBaseUrl));
 request.headers.set('Content-Type', 'application/json');
 
 final body = <String, dynamic>{
 'to_username': username,
 'from_username': widget.currentUsername,
 'message': message,
 };
 
 // Add attachment if present
 if (attachmentName != null) {
 body['attachment_name'] = attachmentName;
 body['attachment_data'] = attachmentData;
 body['attachment_type'] = attachmentType;
 }
 
 request.write(jsonEncode(body));

 final response = await request.close();
 if (response.statusCode == 200 || response.statusCode == 201) {
 successCount++;
 } else {
 failCount++;
 }
 } catch (e) {
 debugPrint('[AlertAdminScreen] Send alert error: \$e');
 failCount++;
 }
 }

 if (mounted) {
 final hasImage = imageFile != null;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(
 'Broadcast${hasImage ? ' with image' : ''} sent to $successCount users${failCount > 0 ? ' ($failCount failed)' : ''}'
 ),
 backgroundColor: failCount == 0 ? Colors.green : Colors.orange,
 ),
 );
 }
 }

 // ============ CHAT ============

 Future<void> _loadChatMessages() async {
 if (_selectedChatUsername == null) return;

 setState(() => _loadingChat = true);

 try {
 final response = await http.get(Uri.parse(
 '$_chatBaseUrl?action=get_conversation&user1=${widget.currentUsername}&user2=$_selectedChatUsername',
 ));

 if (response.statusCode == 200) {
 final data = jsonDecode(response.body);
 if (data['success'] == true) {
 final messages = (data['messages'] as List)
 .map((m) => ChatMessage.fromJson(m))
 .toList();

 if (mounted) {
 setState(() {
 _chatMessages = messages;
 _loadingChat = false;
 });
 _scrollToBottom();
 _markMessagesAsRead();
 }
 } else {
 // API returned error
 if (mounted) {
 setState(() => _loadingChat = false);
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Error: ${data['error'] ?? 'Unknown error'}'),
 backgroundColor: Colors.red,
 ),
 );
 }
 }
 } else {
 // Non-200 status code
 if (mounted) {
 setState(() => _loadingChat = false);
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Server error: ${response.statusCode}'),
 backgroundColor: Colors.red,
 ),
 );
 }
 }
 } catch (e) {
 if (mounted) {
 setState(() => _loadingChat = false);
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Connection error: $e'),
 backgroundColor: Colors.red,
 ),
 );
 }
 }
 }

 Future<void> _loadChatMessagesSilent() async {
 if (_selectedChatUsername == null) return;

 try {
 final response = await http.get(Uri.parse(
 '$_chatBaseUrl?action=get_conversation&user1=${widget.currentUsername}&user2=$_selectedChatUsername',
 ));

 if (response.statusCode == 200) {
 final data = jsonDecode(response.body);
 if (data['success'] == true) {
 final messages = (data['messages'] as List)
 .map((m) => ChatMessage.fromJson(m))
 .toList();

 if (mounted && messages.length != _chatMessages.length) {
 setState(() {
 _chatMessages = messages;
 });
 _scrollToBottom();
 _markMessagesAsRead();
 }
 }
 }
 } catch (e) {
  debugPrint('[AlertAdminScreen] Error: $e');
}
 }

 Future<void> _markMessagesAsRead() async {
 if (_selectedChatUsername == null) return;

 try {
 await http.post(
 Uri.parse(_chatBaseUrl),
 headers: {'Content-Type': 'application/json'},
 body: jsonEncode({
 'action': 'mark_read',
 'from_username': _selectedChatUsername,
 'to_username': widget.currentUsername,
 }),
 );
 // Refresh conversations to update unread counts
 _loadConversations();
 } catch (e) {
  debugPrint('[AlertAdminScreen] Error: $e');
}
 }

 Future<void> _pickFile() async {
 try {
 final result = await FilePicker.platform.pickFiles(
 type: FileType.custom,
 allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt'],
 withData: true,
 );

 if (result != null && result.files.isNotEmpty) {
 final file = result.files.first;
 if (file.bytes != null) {
 setState(() {
 _selectedFile = file;
 _selectedFileBytes = file.bytes;
 });
 }
 }
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Error picking file: $e'), backgroundColor: Colors.red),
 );
 }
 }
 }

 void _clearSelectedFile() {
 setState(() {
 _selectedFile = null;
 _selectedFileBytes = null;
 });
 }

 Future<void> _sendChatMessage() async {
 final message = _chatMessageController.text.trim();
 if (_selectedChatUsername == null || (message.isEmpty && _selectedFile == null)) return;

 setState(() => _sendingChat = true);

 try {
 final Map<String, dynamic> body = {
 'action': 'send',
 'from_username': widget.currentUsername,
 'to_username': _selectedChatUsername,
 'message': message,
 };

 // Add attachment if present
 if (_selectedFile != null && _selectedFileBytes != null) {
 body['attachment_name'] = _selectedFile!.name;
 body['attachment_data'] = base64Encode(_selectedFileBytes!);
 body['attachment_type'] = _getFileType(_selectedFile!.name);
 }

 final response = await http.post(
 Uri.parse(_chatBaseUrl),
 headers: {'Content-Type': 'application/json'},
 body: jsonEncode(body),
 );

 if (response.statusCode == 200) {
 final data = jsonDecode(response.body);
 if (data['success'] == true) {
 _chatMessageController.clear();
 _clearSelectedFile();
 await _loadChatMessagesSilent();
 // Refresh conversations to update last message and move this chat to top
 _loadConversations();
 }
 }
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Error sending message: $e'), backgroundColor: Colors.red),
 );
 }
 } finally {
 if (mounted) setState(() => _sendingChat = false);
 }
 }

 String _getFileType(String filename) {
 final ext = filename.split('.').last.toLowerCase();
 if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) return 'image';
 if (['pdf'].contains(ext)) return 'pdf';
 if (['doc', 'docx'].contains(ext)) return 'document';
 if (['xls', 'xlsx'].contains(ext)) return 'spreadsheet';
 return 'file';
 }

 IconData _getFileIcon(String filename) {
 final ext = filename.split('.').last.toLowerCase();
 if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) return Icons.image;
 if (['pdf'].contains(ext)) return Icons.picture_as_pdf;
 if (['doc', 'docx'].contains(ext)) return Icons.description;
 if (['xls', 'xlsx'].contains(ext)) return Icons.table_chart;
 return Icons.insert_drive_file;
 }

 String _formatFileSize(int bytes) {
 if (bytes < 1024) return '$bytes B';
 if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
 return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
 }

 void _scrollToBottom() {
 WidgetsBinding.instance.addPostFrameCallback((_) {
 if (_chatScrollController.hasClients) {
 _chatScrollController.animateTo(
 _chatScrollController.position.maxScrollExtent,
 duration: const Duration(milliseconds: 300),
 curve: Curves.easeOut,
 );
 }
 });
 }

 // ============ GROUP CHAT METHODS ============

 bool get _canCreateGroups {
 final role = widget.currentRole.toLowerCase();
 return role == 'developer' || role == 'administrator' || role == 'management';
 }

 Future<void> _loadGroups() async {
 setState(() => _loadingGroups = true);

 try {
 final response = await http.get(Uri.parse(
 '$_groupsBaseUrl?action=list&username=${widget.currentUsername}',
 ));

 if (response.statusCode == 200) {
 final data = jsonDecode(response.body);
 if (data['success'] == true) {
 final groups = (data['groups'] as List)
 .map((g) => ChatGroup.fromJson(g))
 .toList();

 if (mounted) {
 setState(() {
 _groups = groups;
 _loadingGroups = false;
 });
 }
 }
 }
 } catch (e) {
 if (mounted) {
 setState(() => _loadingGroups = false);
 }
 }
 }

 /// Select a group by ID (used when clicking notification)
 Future<void> _selectGroupById(int groupId) async {
 // Make sure groups are loaded first
 if (_groups.isEmpty) {
 await _loadGroups();
 }
 
 // Find the group with matching ID
 final group = _groups.where((g) => g.id == groupId).firstOrNull;
 if (group != null && mounted) {
 setState(() {
 _showGroupChats = true;
 _selectedGroup = group;
 _groupMessages = [];
 _groupMembers = [];
 });
 _loadGroupMessages();
 _loadGroupInfo();
 _startChatRefresh();
 }
 }

 Future<void> _loadGroupMessages() async {
 if (_selectedGroup == null) return;

 setState(() => _loadingGroupChat = true);

 try {
 final response = await http.get(Uri.parse(
 '$_groupsBaseUrl?action=get_messages&group_id=${_selectedGroup!.id}&username=${widget.currentUsername}',
 ));

 if (response.statusCode == 200) {
 final data = jsonDecode(response.body);
 if (data['success'] == true) {
 final messages = (data['messages'] as List)
 .map((m) => GroupMessage.fromJson(m))
 .toList();

 if (mounted) {
 setState(() {
 _groupMessages = messages;
 _loadingGroupChat = false;
 });
 _scrollToBottom();
 _markGroupAsRead();
 }
 }
 }
 } catch (e) {
 if (mounted) {
 setState(() => _loadingGroupChat = false);
 }
 }
 }

 Future<void> _loadGroupMessagesSilent() async {
 if (_selectedGroup == null) return;

 try {
 final response = await http.get(Uri.parse(
 '$_groupsBaseUrl?action=get_messages&group_id=${_selectedGroup!.id}&username=${widget.currentUsername}',
 ));

 if (response.statusCode == 200) {
 final data = jsonDecode(response.body);
 if (data['success'] == true) {
 final messages = (data['messages'] as List)
 .map((m) => GroupMessage.fromJson(m))
 .toList();

 if (mounted && messages.length != _groupMessages.length) {
 setState(() => _groupMessages = messages);
 _scrollToBottom();
 _markGroupAsRead();
 }
 }
 }
 } catch (e) {
  debugPrint('[AlertAdminScreen] Error: $e');
}
 }

 Future<void> _loadGroupInfo() async {
 if (_selectedGroup == null) return;

 try {
 final response = await http.get(Uri.parse(
 '$_groupsBaseUrl?action=get_group&group_id=${_selectedGroup!.id}&username=${widget.currentUsername}',
 ));

 if (response.statusCode == 200) {
 final data = jsonDecode(response.body);
 if (data['success'] == true && data['group'] != null) {
 final members = (data['group']['members'] as List? ?? [])
 .map((m) => GroupMember.fromJson(m))
 .toList();

 if (mounted) {
 setState(() => _groupMembers = members);
 }
 }
 }
 } catch (e) {
  debugPrint('[AlertAdminScreen] Error: $e');
}
 }

 Future<void> _markGroupAsRead() async {
 if (_selectedGroup == null) return;

 try {
 await http.post(
 Uri.parse(_groupsBaseUrl),
 headers: {'Content-Type': 'application/json'},
 body: jsonEncode({
 'action': 'mark_read',
 'group_id': _selectedGroup!.id,
 'username': widget.currentUsername,
 }),
 );
 } catch (e) {
  debugPrint('[AlertAdminScreen] Error: $e');
}
 }

 Future<void> _sendGroupMessage() async {
 final message = _chatMessageController.text.trim();
 if (_selectedGroup == null || (message.isEmpty && _selectedFile == null)) return;

 setState(() => _sendingGroupChat = true);

 try {
 final Map<String, dynamic> body = {
 'action': 'send_message',
 'group_id': _selectedGroup!.id,
 'from_username': widget.currentUsername,
 'message': message,
 };

 if (_selectedFile != null && _selectedFileBytes != null) {
 body['attachment_name'] = _selectedFile!.name;
 body['attachment_data'] = base64Encode(_selectedFileBytes!);
 body['attachment_type'] = _getFileType(_selectedFile!.name);
 }

 final response = await http.post(
 Uri.parse(_groupsBaseUrl),
 headers: {'Content-Type': 'application/json'},
 body: jsonEncode(body),
 );

 if (response.statusCode == 200) {
 final data = jsonDecode(response.body);
 if (data['success'] == true) {
 _chatMessageController.clear();
 _clearSelectedFile();
 _loadGroupMessagesSilent();
 }
 }
 } catch (e) {
  debugPrint('[AlertAdminScreen] Error: $e');
}

 if (mounted) {
 setState(() => _sendingGroupChat = false);
 }
 }

 void _showCreateGroupDialog() {
 final nameController = TextEditingController();
 final descController = TextEditingController();
 final selectedMembers = <String>{};

 showDialog(
 context: context,
 builder: (context) {
 return StatefulBuilder(
 builder: (context, setDialogState) {
 final isDark = Theme.of(context).brightness == Brightness.dark;
 
 return AlertDialog(
 title: const Text('Create Group'),
 content: SizedBox(
 width: 400,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 TextField(
 controller: nameController,
 decoration: const InputDecoration(
 labelText: 'Group Name',
 hintText: 'Enter group name...',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 16),
 TextField(
 controller: descController,
 decoration: const InputDecoration(
 labelText: 'Description (optional)',
 hintText: 'Enter description...',
 border: OutlineInputBorder(),
 ),
 maxLines: 2,
 ),
 const SizedBox(height: 16),
 Text(
 'Select Members (${selectedMembers.length} selected)',
 style: TextStyle(
 fontWeight: FontWeight.bold,
 color: isDark ? Colors.white70 : Colors.black87,
 ),
 ),
 const SizedBox(height: 8),
 Container(
 height: 200,
 decoration: BoxDecoration(
 border: Border.all(color: Colors.grey),
 borderRadius: BorderRadius.circular(8),
 ),
 child: ListView.builder(
 itemCount: _allUsers.length,
 itemBuilder: (context, index) {
 final user = _allUsers[index];
 if (user.username == widget.currentUsername) return const SizedBox.shrink();
 
 final isSelected = selectedMembers.contains(user.username);
 return CheckboxListTile(
 dense: true,
 title: Text(user.displayName),
 subtitle: Text('@${user.username}'),
 value: isSelected,
 activeColor: _accent,
 onChanged: (val) {
 setDialogState(() {
 if (val == true) {
 selectedMembers.add(user.username);
 } else {
 selectedMembers.remove(user.username);
 }
 });
 },
 );
 },
 ),
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(context),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: nameController.text.trim().isEmpty
 ? null
 : () async {
 Navigator.pop(context);
 await _createGroup(
 nameController.text.trim(),
 descController.text.trim(),
 selectedMembers.toList(),
 );
 },
 style: ElevatedButton.styleFrom(backgroundColor: _accent),
 child: const Text('Create', style: TextStyle(color: Colors.white)),
 ),
 ],
 );
 },
 );
 },
 );
 }

 Future<void> _createGroup(String name, String description, List<String> members) async {
 try {
 final response = await http.post(
 Uri.parse(_groupsBaseUrl),
 headers: {'Content-Type': 'application/json'},
 body: jsonEncode({
 'action': 'create',
 'username': widget.currentUsername,
 'name': name,
 'description': description,
 'members': members,
 }),
 );

 if (response.statusCode == 200) {
 final data = jsonDecode(response.body);
 if (data['success'] == true) {
 _loadGroups();
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Group created successfully'), backgroundColor: Colors.green),
 );
 }
 }
 }
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Error creating group: $e'), backgroundColor: Colors.red),
 );
 }
 }
 }

 void _showGroupInfoDialog() {
 if (_selectedGroup == null) return;

 showDialog(
 context: context,
 builder: (dialogContext) {
 return StatefulBuilder(
 builder: (context, setDialogState) {
 final isDark = Theme.of(context).brightness == Brightness.dark;
 final isAdmin = _selectedGroup!.myRole == 'admin';
 
 return AlertDialog(
 title: Row(
 children: [
 const Icon(Icons.group, color: _accent),
 const SizedBox(width: 8),
 Expanded(child: Text(_selectedGroup!.name)),
 ],
 ),
 content: SizedBox(
 width: 400,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 if (_selectedGroup!.description?.isNotEmpty == true) ...[
 Text(
 _selectedGroup!.description!,
 style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
 ),
 const SizedBox(height: 16),
 ],
 Row(
 children: [
 Text(
 'Members (${_groupMembers.length})',
 style: const TextStyle(fontWeight: FontWeight.bold),
 ),
 const Spacer(),
 if (isAdmin)
 TextButton.icon(
 onPressed: () {
 Navigator.pop(context);
 _showAddMemberDialog();
 },
 icon: const Icon(Icons.person_add, size: 18),
 label: const Text('Add'),
 style: TextButton.styleFrom(foregroundColor: _accent),
 ),
 ],
 ),
 const SizedBox(height: 8),
 Container(
 height: 250,
 decoration: BoxDecoration(
 border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
 borderRadius: BorderRadius.circular(8),
 ),
 child: ListView.builder(
 itemCount: _groupMembers.length,
 itemBuilder: (context, index) {
 final member = _groupMembers[index];
 final isCurrentUser = member.username == widget.currentUsername;
 final canRemove = isAdmin && !isCurrentUser;
 final canLeave = isCurrentUser && _groupMembers.length > 1;
 
 return ListTile(
 dense: true,
 leading: CircleAvatar(
 radius: 16,
 backgroundColor: _accent.withValues(alpha: 0.2),
 child: Text(
 member.displayName.isNotEmpty ? member.displayName[0].toUpperCase() : '?',
 style: const TextStyle(color: _accent, fontSize: 14),
 ),
 ),
 title: Text(member.displayName),
 subtitle: Text('@${member.username}'),
 trailing: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 if (member.role == 'admin')
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
 margin: const EdgeInsets.only(right: 8),
 decoration: BoxDecoration(
 color: _accent.withValues(alpha: 0.2),
 borderRadius: BorderRadius.circular(10),
 ),
 child: const Text(
 'Admin',
 style: TextStyle(color: _accent, fontSize: 11),
 ),
 ),
 if (canRemove)
 IconButton(
 icon: const Icon(Icons.remove_circle_outline, size: 20),
 color: Colors.red,
 tooltip: 'Remove from group',
 onPressed: () async {
 final confirm = await showDialog<bool>(
 context: context,
 builder: (ctx) => AlertDialog(
 title: const Text('Remove Member'),
 content: Text('Remove ${member.displayName} from this group?'),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(ctx, false),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () => Navigator.pop(ctx, true),
 style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
 child: const Text('Remove', style: TextStyle(color: Colors.white)),
 ),
 ],
 ),
 );
 if (confirm == true) {
 if (!context.mounted) return;
 Navigator.pop(dialogContext);
 await _removeMemberFromGroup(member.username);
 }
 },
 ),
 if (canLeave && !canRemove)
 TextButton(
 onPressed: () async {
 final confirm = await showDialog<bool>(
 context: context,
 builder: (ctx) => AlertDialog(
 title: const Text('Leave Group'),
 content: const Text('Are you sure you want to leave this group?'),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(ctx, false),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () => Navigator.pop(ctx, true),
 style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
 child: const Text('Leave', style: TextStyle(color: Colors.white)),
 ),
 ],
 ),
 );
 if (confirm == true) {
 if (!context.mounted) return;
 Navigator.pop(dialogContext);
 await _leaveGroup();
 }
 },
 style: TextButton.styleFrom(foregroundColor: Colors.red),
 child: const Text('Leave'),
 ),
 ],
 ),
 );
 },
 ),
 ),
 ],
 ),
 ),
 actions: [
 if (isAdmin)
 TextButton(
 onPressed: () async {
 final confirm = await showDialog<bool>(
 context: context,
 builder: (ctx) => AlertDialog(
 title: const Text('Delete Group'),
 content: Text('Are you sure you want to delete "${_selectedGroup!.name}"? This cannot be undone.'),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(ctx, false),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () => Navigator.pop(ctx, true),
 style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
 child: const Text('Delete', style: TextStyle(color: Colors.white)),
 ),
 ],
 ),
 );
 if (confirm == true) {
 if (!context.mounted) return;
 Navigator.pop(dialogContext);
 await _deleteGroup();
 }
 },
 style: TextButton.styleFrom(foregroundColor: Colors.red),
 child: const Text('Delete Group'),
 ),
 TextButton(
 onPressed: () => Navigator.pop(context),
 child: const Text('Close'),
 ),
 ],
 );
 },
 );
 },
 );
 }

 void _showAddMemberDialog() {
 if (_selectedGroup == null) return;
 
 final currentMemberUsernames = _groupMembers.map((m) => m.username).toSet();
 final availableUsers = _allUsers.where((u) => !currentMemberUsernames.contains(u.username)).toList();
 
 if (availableUsers.isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('All users are already members of this group')),
 );
 return;
 }
 
 final selectedMembers = <String>{};
 
 showDialog(
 context: context,
 builder: (context) {
 return StatefulBuilder(
 builder: (context, setDialogState) {
 final isDark = Theme.of(context).brightness == Brightness.dark;
 
 return AlertDialog(
 title: const Text('Add Members'),
 content: SizedBox(
 width: 350,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Select members to add (${selectedMembers.length} selected)',
 style: TextStyle(
 fontWeight: FontWeight.bold,
 color: isDark ? Colors.white70 : Colors.black87,
 ),
 ),
 const SizedBox(height: 8),
 Container(
 height: 300,
 decoration: BoxDecoration(
 border: Border.all(color: Colors.grey),
 borderRadius: BorderRadius.circular(8),
 ),
 child: ListView.builder(
 itemCount: availableUsers.length,
 itemBuilder: (context, index) {
 final user = availableUsers[index];
 final isSelected = selectedMembers.contains(user.username);
 
 return CheckboxListTile(
 dense: true,
 title: Text(user.displayName),
 subtitle: Text('@${user.username}'),
 value: isSelected,
 activeColor: _accent,
 onChanged: (val) {
 setDialogState(() {
 if (val == true) {
 selectedMembers.add(user.username);
 } else {
 selectedMembers.remove(user.username);
 }
 });
 },
 );
 },
 ),
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(context),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: selectedMembers.isEmpty
 ? null
 : () async {
 Navigator.pop(context);
 await _addMembersToGroup(selectedMembers.toList());
 },
 style: ElevatedButton.styleFrom(backgroundColor: _accent),
 child: const Text('Add Members', style: TextStyle(color: Colors.white)),
 ),
 ],
 );
 },
 );
 },
 );
 }

 Future<void> _addMembersToGroup(List<String> memberUsernames) async {
 if (_selectedGroup == null) return;
 
 try {
 int added = 0;
 for (final memberUsername in memberUsernames) {
 final response = await http.post(
 Uri.parse(_groupsBaseUrl),
 headers: {'Content-Type': 'application/json'},
 body: jsonEncode({
 'action': 'add_member',
 'group_id': _selectedGroup!.id,
 'username': widget.currentUsername,
 'member_username': memberUsername,
 }),
 );
 
 if (response.statusCode == 200) {
 final data = jsonDecode(response.body);
 if (data['success'] == true) {
 added++;
 }
 }
 }
 
 // Reload group members
 await _loadGroupInfo();
 await _loadGroupMessages();
 
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Added $added member${added == 1 ? '' : 's'} to the group'),
 backgroundColor: Colors.green,
 ),
 );
 }
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Error adding members: $e'), backgroundColor: Colors.red),
 );
 }
 }
 }

 Future<void> _removeMemberFromGroup(String memberUsername) async {
 if (_selectedGroup == null) return;
 
 try {
 final response = await http.post(
 Uri.parse(_groupsBaseUrl),
 headers: {'Content-Type': 'application/json'},
 body: jsonEncode({
 'action': 'remove_member',
 'group_id': _selectedGroup!.id,
 'username': widget.currentUsername,
 'member_username': memberUsername,
 }),
 );
 
 if (response.statusCode == 200) {
 final data = jsonDecode(response.body);
 if (data['success'] == true) {
 // Reload group members
 await _loadGroupInfo();
 await _loadGroupMessages();
 
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Member removed from group'), backgroundColor: Colors.green),
 );
 }
 }
 }
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Error removing member: $e'), backgroundColor: Colors.red),
 );
 }
 }
 }

 Future<void> _leaveGroup() async {
 if (_selectedGroup == null) return;
 
 try {
 final response = await http.post(
 Uri.parse(_groupsBaseUrl),
 headers: {'Content-Type': 'application/json'},
 body: jsonEncode({
 'action': 'remove_member',
 'group_id': _selectedGroup!.id,
 'username': widget.currentUsername,
 'member_username': widget.currentUsername,
 }),
 );
 
 if (response.statusCode == 200) {
 final data = jsonDecode(response.body);
 if (data['success'] == true) {
 setState(() {
 _selectedGroup = null;
 _groupMessages = [];
 _groupMembers = [];
 });
 await _loadGroups();
 
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('You left the group'), backgroundColor: Colors.green),
 );
 }
 }
 }
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Error leaving group: $e'), backgroundColor: Colors.red),
 );
 }
 }
 }

 Future<void> _deleteGroup() async {
 if (_selectedGroup == null) return;
 
 try {
 final response = await http.post(
 Uri.parse(_groupsBaseUrl),
 headers: {'Content-Type': 'application/json'},
 body: jsonEncode({
 'action': 'delete',
 'group_id': _selectedGroup!.id,
 'username': widget.currentUsername,
 }),
 );
 
 if (response.statusCode == 200) {
 final data = jsonDecode(response.body);
 if (data['success'] == true) {
 setState(() {
 _selectedGroup = null;
 _groupMessages = [];
 _groupMembers = [];
 });
 await _loadGroups();
 
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Group deleted'), backgroundColor: Colors.green),
 );
 }
 }
 }
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Error deleting group: $e'), backgroundColor: Colors.red),
 );
 }
 }
 }

 String _formatRole(String role) {
 return role
 .replaceAll('_', ' ')
 .split(' ')
 .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
 .join(' ');
 }

 Color _getStatusColor(String status) {
 switch (status) {
 case 'online':
 return Colors.green;
 case 'away':
 return Colors.amber;
 default:
 return Colors.red;
 }
 }

 String _formatMessageTime(DateTime time) => formatMessageTimestamp(time);

 // ============ BUILD ============

 @override
 Widget build(BuildContext context) {
 final isDark = Theme.of(context).brightness == Brightness.dark;

 return Scaffold(
 backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[100],
 appBar: AppBar(
 title: const Text('Messages'),
 bottom: TabBar(
 controller: _tabController,
 indicatorColor: _accent,
 labelColor: _accent,
 unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
 tabs: const [
 Tab(icon: Icon(Icons.chat), text: 'Chat'),
 Tab(icon: Icon(Icons.notifications_active), text: 'Alerts'),
 ],
 ),
 ),
 body: TabBarView(
 controller: _tabController,
 children: [
 _buildChatTab(isDark),
 _buildAlertsTab(isDark),
 ],
 ),
 );
 }

 Widget _buildAlertsTab(bool isDark) {
 // Check if we're on mobile (narrow screen)
 final screenWidth = MediaQuery.of(context).size.width;
 final isMobile = screenWidth < 600;
 
 if (isMobile) {
 // Mobile: Full screen user list with broadcast option
 return Column(
 children: [
 // Broadcast button (admin/developer only)
 if (_canBroadcast)
 Padding(
 padding: const EdgeInsets.all(12),
 child: SizedBox(
 width: double.infinity,
 child: ElevatedButton.icon(
 onPressed: _showBroadcastDialog,
 icon: const Icon(Icons.campaign, size: 18),
 label: const Text('Broadcast Alert'),
 style: ElevatedButton.styleFrom(
 backgroundColor: Colors.orange,
 foregroundColor: Colors.white,
 padding: const EdgeInsets.symmetric(vertical: 12),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
 ),
 ),
 ),
 ),
 Expanded(child: _buildUserList(isDark, isChat: false)),
 ],
 );
 }
 
 // Desktop: Side-by-side layout
 return Row(
 children: [
 // User list with broadcast option
 SizedBox(
 width: 300,
 child: Column(
 children: [
 // Broadcast button (admin/developer only)
 if (_canBroadcast)
 Padding(
 padding: const EdgeInsets.all(12),
 child: SizedBox(
 width: double.infinity,
 child: ElevatedButton.icon(
 onPressed: _showBroadcastDialog,
 icon: const Icon(Icons.campaign, size: 18),
 label: const Text('Broadcast Alert'),
 style: ElevatedButton.styleFrom(
 backgroundColor: Colors.orange,
 foregroundColor: Colors.white,
 padding: const EdgeInsets.symmetric(vertical: 12),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
 ),
 ),
 ),
 ),
 Expanded(child: _buildUserList(isDark, isChat: false)),
 ],
 ),
 ),
 // Divider
 VerticalDivider(width: 1, color: isDark ? Colors.white12 : Colors.black12),
 // Alert compose area
 Expanded(
 child: _buildAlertCompose(isDark),
 ),
 ],
 );
 }

 Widget _buildChatTab(bool isDark) {
 // Check if we're on mobile (narrow screen)
 final screenWidth = MediaQuery.of(context).size.width;
 final isMobile = screenWidth < 600;
 
 if (isMobile) {
 // Mobile: Full screen user/group list
 return _showGroupChats 
 ? _buildGroupList(isDark)
 : _buildUserList(isDark, isChat: true);
 }
 
 // Desktop: Side-by-side layout
 return Row(
 children: [
 // User/Group list
 SizedBox(
 width: 300,
 child: _showGroupChats 
 ? _buildGroupList(isDark)
 : _buildUserList(isDark, isChat: true),
 ),
 // Divider
 VerticalDivider(width: 1, color: isDark ? Colors.white12 : Colors.black12),
 // Chat area
 Expanded(
 child: _showGroupChats 
 ? _buildGroupChatArea(isDark)
 : _buildChatArea(isDark),
 ),
 ],
 );
 }

 Widget _buildGroupList(bool isDark) {
 final bgColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;

 return Container(
 color: bgColor,
 child: Column(
 children: [
 // Toggle header
 _buildChatToggleHeader(isDark),
 // Create group button (if authorized)
 if (_canCreateGroups)
 Padding(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 child: SizedBox(
 width: double.infinity,
 child: ElevatedButton.icon(
 onPressed: _showCreateGroupDialog,
 icon: const Icon(Icons.add, size: 18),
 label: const Text('Create Group'),
 style: ElevatedButton.styleFrom(
 backgroundColor: _accent,
 foregroundColor: Colors.white,
 padding: const EdgeInsets.symmetric(vertical: 12),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
 ),
 ),
 ),
 ),
 // Group count
 Padding(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
 child: Row(
 children: [
 Text(
 '${_groups.length} groups',
 style: TextStyle(
 fontSize: 12,
 color: isDark ? Colors.white38 : Colors.black38,
 ),
 ),
 const Spacer(),
 if (_loadingGroups)
 const SizedBox(
 width: 12,
 height: 12,
 child: CircularProgressIndicator(strokeWidth: 2),
 ),
 ],
 ),
 ),
 // Group list
 Expanded(
 child: _loadingGroups && _groups.isEmpty
 ? const Center(child: CircularProgressIndicator())
 : _groups.isEmpty
 ? Center(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(
 Icons.group_outlined,
 size: 48,
 color: isDark ? Colors.white24 : Colors.black26,
 ),
 const SizedBox(height: 8),
 Text(
 'No groups yet',
 style: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
 ),
 if (_canCreateGroups) ...[
 const SizedBox(height: 16),
 TextButton.icon(
 onPressed: _showCreateGroupDialog,
 icon: const Icon(Icons.add),
 label: const Text('Create one'),
 ),
 ],
 ],
 ),
 )
 : ListView.builder(
 itemCount: _groups.length,
 itemBuilder: (context, index) {
 final group = _groups[index];
 final isSelected = _selectedGroup?.id == group.id;
 return _buildGroupTile(group, isDark, isSelected);
 },
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildChatToggleHeader(bool isDark) {
 return Container(
 padding: const EdgeInsets.all(12),
 child: Container(
 decoration: BoxDecoration(
 color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
 borderRadius: BorderRadius.circular(25),
 ),
 child: Row(
 children: [
 Expanded(
 child: GestureDetector(
 onTap: () {
 setState(() {
 _showGroupChats = false;
 _selectedGroup = null;
 });
 },
 child: Container(
 padding: const EdgeInsets.symmetric(vertical: 10),
 decoration: BoxDecoration(
 color: !_showGroupChats ? _accent : Colors.transparent,
 borderRadius: BorderRadius.circular(25),
 ),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 Icon(
 Icons.person,
 size: 18,
 color: !_showGroupChats ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
 ),
 const SizedBox(width: 6),
 Text(
 'Direct',
 style: TextStyle(
 color: !_showGroupChats ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
 fontWeight: !_showGroupChats ? FontWeight.bold : FontWeight.normal,
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 Expanded(
 child: GestureDetector(
 onTap: () {
 setState(() {
 _showGroupChats = true;
 _selectedChatUsername = null;
 });
 _loadGroups();
 },
 child: Container(
 padding: const EdgeInsets.symmetric(vertical: 10),
 decoration: BoxDecoration(
 color: _showGroupChats ? _accent : Colors.transparent,
 borderRadius: BorderRadius.circular(25),
 ),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 Icon(
 Icons.group,
 size: 18,
 color: _showGroupChats ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
 ),
 const SizedBox(width: 6),
 Text(
 'Groups',
 style: TextStyle(
 color: _showGroupChats ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
 fontWeight: _showGroupChats ? FontWeight.bold : FontWeight.normal,
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 ],
 ),
 ),
 );
 }

 Widget _buildGroupTile(ChatGroup group, bool isDark, bool isSelected) {
 final screenWidth = MediaQuery.of(context).size.width;
 final isMobile = screenWidth < 600;
 
 return InkWell(
 onTap: () {
 if (isMobile) {
 // Mobile: Navigate to full-screen group chat
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => MobileGroupChatScreen(
 currentUsername: widget.currentUsername,
 currentRole: widget.currentRole,
 group: group,
 ),
 ),
 ).then((_) {
 // Refresh groups when returning
 _loadGroups();
 });
 } else {
 // Desktop: Select group in split view
 setState(() {
 _selectedGroup = group;
 _groupMessages = [];
 _groupMembers = [];
 });
 _loadGroupMessages();
 _loadGroupInfo();
 _startChatRefresh();
 }
 },
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 color: isSelected ? _accent.withValues(alpha: 0.15) : null,
 child: Row(
 children: [
 // Group icon
 CircleAvatar(
 backgroundColor: _accent.withValues(alpha: 0.2),
 child: const Icon(Icons.group, color: _accent, size: 20),
 ),
 const SizedBox(width: 12),
 // Group info
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Expanded(
 child: Text(
 group.name,
 style: TextStyle(
 fontWeight: group.unreadCount > 0 ? FontWeight.bold : FontWeight.w500,
 fontSize: 15,
 ),
 overflow: TextOverflow.ellipsis,
 ),
 ),
 if (group.lastMessageAt != null)
 Text(
 _formatMessageTime(group.lastMessageAt!),
 style: TextStyle(
 fontSize: 11,
 color: isDark ? Colors.white38 : Colors.black38,
 ),
 ),
 ],
 ),
 const SizedBox(height: 4),
 Row(
 children: [
 Expanded(
 child: Text(
 group.lastMessage != null
 ? '${group.lastMessageFromName ?? group.lastMessageFrom ?? ''}: ${group.lastMessage}'
 : '${group.memberCount} members',
 style: TextStyle(
 fontSize: 13,
 color: isDark ? Colors.white60 : Colors.black54,
 fontWeight: group.unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 ),
 if (group.unreadCount > 0)
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
 decoration: BoxDecoration(
 color: _accent,
 borderRadius: BorderRadius.circular(10),
 ),
 child: Text(
 group.unreadCount > 99 ? '99+' : group.unreadCount.toString(),
 style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
 ),
 ),
 ],
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }

 Widget _buildGroupChatArea(bool isDark) {
 if (_selectedGroup == null) {
 return Center(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(
 Icons.groups_outlined,
 size: 64,
 color: isDark ? Colors.white24 : Colors.black26,
 ),
 const SizedBox(height: 16),
 Text(
 'Select a group to start chatting',
 style: TextStyle(
 fontSize: 16,
 color: isDark ? Colors.white38 : Colors.black38,
 ),
 ),
 ],
 ),
 );
 }

 return Column(
 children: [
 // Group header
 Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: isDark ? const Color(0xFF252525) : Colors.grey[50],
 border: Border(
 bottom: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
 ),
 ),
 child: Row(
 children: [
 CircleAvatar(
 backgroundColor: _accent.withValues(alpha: 0.2),
 child: const Icon(Icons.group, color: _accent),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 _selectedGroup!.name,
 style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
 ),
 Text(
 '${_groupMembers.length} members',
 style: TextStyle(
 fontSize: 12,
 color: isDark ? Colors.white60 : Colors.black54,
 ),
 ),
 ],
 ),
 ),
 IconButton(
 icon: const Icon(Icons.info_outline),
 onPressed: _showGroupInfoDialog,
 tooltip: 'Group Info',
 ),
 ],
 ),
 ),
 const Divider(height: 1),
 // Messages
 Expanded(
 child: _loadingGroupChat
 ? const Center(child: CircularProgressIndicator())
 : _groupMessages.isEmpty
 ? Center(
 child: Text(
 'No messages yet. Say hello!',
 style: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
 ),
 )
 : ListView.builder(
 controller: _chatScrollController,
 padding: const EdgeInsets.all(16),
 itemCount: _groupMessages.length,
 itemBuilder: (context, index) {
 final message = _groupMessages[index];
 final isMe = message.fromUsername == widget.currentUsername;
 return _buildGroupMessageBubble(message, isMe, isDark);
 },
 ),
 ),
 // Input area
 _buildGroupInputArea(isDark),
 ],
 );
 }

 Widget _buildGroupMessageBubble(GroupMessage message, bool isMe, bool isDark) {
 // System message (centered, gray)
 if (message.isSystem) {
 return Padding(
 padding: const EdgeInsets.symmetric(vertical: 8),
 child: Center(
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
 decoration: BoxDecoration(
 color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200],
 borderRadius: BorderRadius.circular(16),
 ),
 child: Text(
 message.message,
 style: TextStyle(
 fontSize: 12,
 color: isDark ? Colors.white60 : Colors.black54,
 fontStyle: FontStyle.italic,
 ),
 ),
 ),
 ),
 );
 }

 return Align(
 alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
 child: Container(
 constraints: const BoxConstraints(maxWidth: 400),
 margin: const EdgeInsets.symmetric(vertical: 4),
 child: Column(
 crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
 children: [
 // Sender name (only for others)
 if (!isMe)
 Padding(
 padding: const EdgeInsets.only(left: 12, bottom: 4),
 child: Text(
 message.fromDisplayName,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w500,
 color: _accent,
 ),
 ),
 ),
 Container(
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: isMe ? _accent : (isDark ? const Color(0xFF303030) : Colors.grey[200]),
 borderRadius: BorderRadius.circular(16),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Attachment (image or file)
 if (message.hasAttachment)
 GestureDetector(
 onTap: () => _openAttachment(
 message.attachmentUrl!,
 type: message.attachmentType,
 name: message.attachmentName,
 ),
 child: Container(
 margin: const EdgeInsets.only(bottom: 8),
 constraints: const BoxConstraints(maxWidth: 250, maxHeight: 300),
 child: message.attachmentType == 'image'
 ? ClipRRect(
 borderRadius: BorderRadius.circular(8),
 child: Image.network(
 message.attachmentUrl!,
 fit: BoxFit.cover,
 errorBuilder: (_, __, ___) => Container(
 padding: const EdgeInsets.all(10),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(Icons.broken_image, color: isMe ? Colors.white : _accent),
 const SizedBox(width: 8),
 Text(message.attachmentName ?? 'Image'),
 ],
 ),
 ),
 ),
 )
 : Container(
 padding: const EdgeInsets.all(10),
 decoration: BoxDecoration(
 color: isMe ? Colors.white.withValues(alpha: 0.15) : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100]),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(
 _getFileIconFromType(message.attachmentType),
 color: isMe ? Colors.white : _accent,
 size: 24,
 ),
 const SizedBox(width: 8),
 Flexible(
 child: Text(
 message.attachmentName ?? 'Attachment',
 style: TextStyle(
 color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black),
 fontSize: 13,
 decoration: TextDecoration.underline,
 ),
 overflow: TextOverflow.ellipsis,
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 // Message text
 if (message.message.isNotEmpty)
 Text(
 message.message,
 style: TextStyle(
 color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black),
 fontSize: 15,
 ),
 ),
 const SizedBox(height: 4),
 Text(
 _formatMessageTime(message.createdAt),
 style: TextStyle(
 fontSize: 11,
 color: isMe ? Colors.white.withValues(alpha: 0.7) : (isDark ? Colors.white38 : Colors.black38),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }

 Widget _buildGroupInputArea(bool isDark) {
 return Container(
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: isDark ? const Color(0xFF252525) : Colors.grey[50],
 border: Border(
 top: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
 ),
 ),
 child: Column(
 children: [
 // Selected file preview
 if (_selectedFile != null)
 Container(
 margin: const EdgeInsets.only(bottom: 8),
 padding: const EdgeInsets.all(8),
 decoration: BoxDecoration(
 color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200],
 borderRadius: BorderRadius.circular(8),
 ),
 child: Row(
 children: [
 Icon(_getFileIconFromType(_getFileType(_selectedFile!.name)), color: _accent),
 const SizedBox(width: 8),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 _selectedFile!.name,
 style: const TextStyle(fontWeight: FontWeight.w500),
 overflow: TextOverflow.ellipsis,
 ),
 Text(
 _formatFileSize(_selectedFile!.size),
 style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
 ),
 ],
 ),
 ),
 IconButton(
 icon: const Icon(Icons.close),
 onPressed: _clearSelectedFile,
 iconSize: 20,
 ),
 ],
 ),
 ),
 Row(
 children: [
 IconButton(
 icon: const Icon(Icons.attach_file),
 onPressed: _pickFile,
 color: _accent,
 ),
 const SizedBox(width: 8),
 Expanded(
 child: TextField(
 controller: _chatMessageController,
 decoration: InputDecoration(
 hintText: 'Type a message...',
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(25),
 borderSide: BorderSide.none,
 ),
 filled: true,
 fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
 contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 ),
 onSubmitted: (_) => _sendGroupMessage(),
 ),
 ),
 const SizedBox(width: 8),
 FloatingActionButton.small(
 onPressed: _sendingGroupChat ? null : _sendGroupMessage,
 backgroundColor: _accent,
 child: _sendingGroupChat
 ? const SizedBox(
 width: 20,
 height: 20,
 child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
 )
 : const Icon(Icons.send, color: Colors.white),
 ),
 ],
 ),
 ],
 ),
 );
 }

 Widget _buildUserList(bool isDark, {required bool isChat}) {
 final bgColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
 final selectedUsername = isChat ? _selectedChatUsername : _selectedAlertUsername;
 // Use WhatsApp-style sorted list for chat, regular filtered list for alerts
 final displayUsers = isChat ? _getChatSortedUsers() : _filteredUsers;

 return Container(
 color: bgColor,
 child: Column(
 children: [
 // Toggle header for chat tab
 if (isChat) _buildChatToggleHeader(isDark),
 // Search bar
 Padding(
 padding: const EdgeInsets.all(12),
 child: TextField(
 controller: _searchController,
 decoration: InputDecoration(
 hintText: 'Search users...',
 prefixIcon: const Icon(Icons.search),
 suffixIcon: _searchController.text.isNotEmpty
 ? IconButton(
 icon: const Icon(Icons.clear),
 onPressed: () {
 _searchController.clear();
 },
 )
 : null,
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(25),
 borderSide: BorderSide.none,
 ),
 filled: true,
 fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
 contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 ),
 ),
 ),
 // User count
 Padding(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
 child: Row(
 children: [
 Text(
 '${displayUsers.length} users',
 style: TextStyle(
 fontSize: 12,
 color: isDark ? Colors.white38 : Colors.black38,
 ),
 ),
 const Spacer(),
 if (_loadingUsers)
 const SizedBox(
 width: 12,
 height: 12,
 child: CircularProgressIndicator(strokeWidth: 2),
 ),
 ],
 ),
 ),
 const SizedBox(height: 8),
 // User list
 Expanded(
 child: _loadingUsers && displayUsers.isEmpty
 ? const Center(child: CircularProgressIndicator())
 : _userLoadError != null && displayUsers.isEmpty
 ? Center(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 const Icon(Icons.error_outline, size: 48, color: Colors.red),
 const SizedBox(height: 8),
 Text(_userLoadError!, textAlign: TextAlign.center),
 const SizedBox(height: 16),
 ElevatedButton(onPressed: _loadUsers, child: const Text('Retry')),
 ],
 ),
 )
 : displayUsers.isEmpty
 ? Center(
 child: Text(
 'No users found',
 style: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
 ),
 )
 : ListView.builder(
 itemCount: displayUsers.length,
 itemBuilder: (context, index) {
 final user = displayUsers[index];
 return _buildUserTile(user, isDark, selectedUsername == user.username, isChat);
 },
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildUserTile(AlertUser user, bool isDark, bool selected, bool isChat) {
 final profilePicture = _profilePictureCache[user.username];
 final screenWidth = MediaQuery.of(context).size.width;
 final isMobile = screenWidth < 600;

 return Material(
 color: selected
 ? _accent.withValues(alpha: isDark ? 0.2 : 0.12)
 : (isDark ? const Color(0xFF1A1A1A) : Colors.white),
 child: InkWell(
 onTap: () {
 if (isMobile) {
 // Mobile: Navigate to full-screen chat/alert
 if (isChat) {
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => MobileChatScreen(
 currentUsername: widget.currentUsername,
 currentRole: widget.currentRole,
 targetUser: user,
 profilePicture: profilePicture,
 ),
 ),
 );
 } else {
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => MobileAlertScreen(
 currentUsername: widget.currentUsername,
 targetUser: user,
 profilePicture: profilePicture,
 ),
 ),
 );
 }
 } else {
 // Desktop: Select user in split view
 setState(() {
 if (isChat) {
 _selectedChatUsername = user.username;
 _loadChatMessages();
 _startChatRefresh();
 } else {
 _selectedAlertUsername = user.username;
 }
 });
 }
 },
 child: Padding(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 child: Row(
 children: [
 // Profile picture with online indicator
 Stack(
 children: [
 CircleAvatar(
 radius: 22,
 backgroundColor: _accent.withValues(alpha: 0.2),
 backgroundImage: profilePicture != null ? MemoryImage(profilePicture) : null,
 child: profilePicture == null
 ? Text(
 user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
 style: const TextStyle(
 color: _accent,
 fontWeight: FontWeight.bold,
 fontSize: 16,
 ),
 )
 : null,
 ),
 Positioned(
 right: 0,
 bottom: 0,
 child: Container(
 width: 12,
 height: 12,
 decoration: BoxDecoration(
 color: _getStatusColor(user.appStatus),
 shape: BoxShape.circle,
 border: Border.all(
 color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
 width: 2,
 ),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(width: 12),
 // User info
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 user.displayName,
 style: TextStyle(
 // Bold if selected OR has unread messages in chat mode
 fontWeight: selected || (isChat && user.hasUnread) ? FontWeight.bold : FontWeight.w500,
 color: isDark ? Colors.white : Colors.black,
 ),
 overflow: TextOverflow.ellipsis,
 ),
 const SizedBox(height: 2),
 // Always show username/role row first
 Row(
 children: [
 Text(
 '@${user.username}',
 style: TextStyle(
 fontSize: 12,
 color: isDark ? Colors.white38 : Colors.black38,
 ),
 ),
 Text(
 ' • ',
 style: TextStyle(
 fontSize: 12,
 color: isDark ? Colors.white24 : Colors.black26,
 ),
 ),
 Text(
 _formatRole(user.role),
 style: const TextStyle(
 fontSize: 12,
 color: _accent,
 fontWeight: FontWeight.w500,
 ),
 ),
 ],
 ),
 // In chat mode: also show last message preview if available
 if (isChat && user.lastMessage != null) ...[
 const SizedBox(height: 2),
 Text(
 // Show "You: message" if current user sent it, otherwise just message
 user.lastMessageFrom == widget.currentUsername
 ? 'You: ${user.lastMessage}'
 : user.lastMessage!,
 style: TextStyle(
 fontSize: 12,
 color: user.hasUnread
 ? (isDark ? Colors.white70 : Colors.black87)
 : (isDark ? Colors.white38 : Colors.black38),
 fontWeight: user.hasUnread ? FontWeight.w500 : FontWeight.normal,
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 ],
 ],
 ),
 ),
 // Unread badge for chat mode
 if (isChat && user.hasUnread) ...[
 const SizedBox(width: 8),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: _accent,
 borderRadius: BorderRadius.circular(12),
 ),
 child: Text(
 user.unreadCount > 99 ? '99+' : user.unreadCount.toString(),
 style: const TextStyle(
 color: Colors.white,
 fontSize: 11,
 fontWeight: FontWeight.bold,
 ),
 ),
 ),
 ],
 ],
 ),
 ),
 ),
 );
 }

 Widget _buildAlertCompose(bool isDark) {
 if (_selectedAlertUsername == null) {
 return Center(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Container(
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: Colors.orange.withValues(alpha: 0.1),
 shape: BoxShape.circle,
 ),
 child: Icon(
 Icons.campaign_outlined,
 size: 64,
 color: Colors.orange.withValues(alpha: 0.6),
 ),
 ),
 const SizedBox(height: 24),
 Text(
 'Select a user to send an alert',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w500,
 color: isDark ? Colors.white54 : Colors.black54,
 ),
 ),
 const SizedBox(height: 8),
 Text(
 'Alerts pop up immediately on the user\'s screen',
 style: TextStyle(
 fontSize: 14,
 color: isDark ? Colors.white38 : Colors.black38,
 ),
 ),
 ],
 ),
 );
 }

 final user = _allUsers.firstWhere(
 (u) => u.username == _selectedAlertUsername,
 orElse: () => AlertUser(username: _selectedAlertUsername!, role: '', appStatus: 'offline'),
 );
 final profilePicture = _profilePictureCache[_selectedAlertUsername];

 return Container(
 color: isDark ? const Color(0xFF121212) : Colors.grey[50],
 child: Center(
 child: SingleChildScrollView(
 padding: const EdgeInsets.all(32),
 child: ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 500),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 // Alert icon header
 Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.orange.withValues(alpha: 0.15),
 shape: BoxShape.circle,
 ),
 child: const Icon(
 Icons.notifications_active,
 size: 48,
 color: Colors.orange,
 ),
 ),
 const SizedBox(height: 24),
 // Title
 Text(
 'Send Alert',
 style: TextStyle(
 fontSize: 24,
 fontWeight: FontWeight.bold,
 color: isDark ? Colors.white : Colors.black87,
 ),
 ),
 const SizedBox(height: 24),
 // Recipient card
 Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(
 color: isDark ? Colors.white12 : Colors.black12,
 ),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withValues(alpha: 0.05),
 blurRadius: 10,
 offset: const Offset(0, 2),
 ),
 ],
 ),
 child: Row(
 children: [
 // Profile picture
 Stack(
 children: [
 CircleAvatar(
 radius: 28,
 backgroundColor: _accent.withValues(alpha: 0.2),
 backgroundImage: profilePicture != null ? MemoryImage(profilePicture) : null,
 child: profilePicture == null
 ? Text(
 user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
 style: const TextStyle(color: _accent, fontWeight: FontWeight.bold, fontSize: 20),
 )
 : null,
 ),
 Positioned(
 right: 0,
 bottom: 0,
 child: Container(
 width: 14,
 height: 14,
 decoration: BoxDecoration(
 color: _getStatusColor(user.appStatus),
 shape: BoxShape.circle,
 border: Border.all(
 color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
 width: 2,
 ),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(width: 16),
 // User info
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 user.displayName,
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.bold,
 color: isDark ? Colors.white : Colors.black87,
 ),
 ),
 const SizedBox(height: 4),
 Row(
 children: [
 Text(
 '@${user.username}',
 style: TextStyle(
 fontSize: 13,
 color: isDark ? Colors.white54 : Colors.black54,
 ),
 ),
 Text(
 ' • ',
 style: TextStyle(
 fontSize: 13,
 color: isDark ? Colors.white24 : Colors.black26,
 ),
 ),
 Text(
 _formatRole(user.role),
 style: const TextStyle(
 fontSize: 13,
 color: _accent,
 fontWeight: FontWeight.w500,
 ),
 ),
 ],
 ),
 ],
 ),
 ),
 // Status badge
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: _getStatusColor(user.appStatus).withValues(alpha: 0.15),
 borderRadius: BorderRadius.circular(20),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Container(
 width: 8,
 height: 8,
 decoration: BoxDecoration(
 color: _getStatusColor(user.appStatus),
 shape: BoxShape.circle,
 ),
 ),
 const SizedBox(width: 6),
 Text(
 user.appStatus == 'online' ? 'Online' : (user.appStatus == 'away' ? 'Away' : 'Offline'),
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w500,
 color: _getStatusColor(user.appStatus),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 24),
 // Message input card
 Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(
 color: isDark ? Colors.white12 : Colors.black12,
 ),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withValues(alpha: 0.05),
 blurRadius: 10,
 offset: const Offset(0, 2),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Alert Message',
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: isDark ? Colors.white70 : Colors.black54,
 ),
 ),
 const SizedBox(height: 12),
 TextField(
 controller: _alertMessageController,
 maxLines: 4,
 minLines: 3,
 decoration: InputDecoration(
 hintText: 'Type your urgent message here...',
 hintStyle: TextStyle(
 color: isDark ? Colors.white30 : Colors.black26,
 ),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: BorderSide(
 color: isDark ? Colors.white24 : Colors.black12,
 ),
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: BorderSide(
 color: isDark ? Colors.white12 : Colors.black12,
 ),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: const BorderSide(
 color: Colors.orange,
 width: 2,
 ),
 ),
 filled: true,
 fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey[50],
 contentPadding: const EdgeInsets.all(16),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 24),
 // Info banner
 Container(
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: Colors.orange.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
 ),
 child: Row(
 children: [
 const Icon(Icons.info_outline, color: Colors.orange, size: 20),
 const SizedBox(width: 12),
 Expanded(
 child: Text(
 'This alert will pop up instantly on ${user.displayName}\'s screen',
 style: TextStyle(
 fontSize: 13,
 color: isDark ? Colors.orange[200] : Colors.orange[800],
 ),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 24),
 // Send button
 SizedBox(
 width: double.infinity,
 height: 52,
 child: ElevatedButton.icon(
 onPressed: _sendingAlert ? null : _sendAlert,
 style: ElevatedButton.styleFrom(
 backgroundColor: Colors.orange,
 foregroundColor: Colors.white,
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12),
 ),
 elevation: 0,
 ),
 icon: _sendingAlert
 ? const SizedBox(
 width: 20,
 height: 20,
 child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
 )
 : const Icon(Icons.send_rounded),
 label: Text(
 _sendingAlert ? 'Sending...' : 'Send Alert',
 style: const TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w600,
 ),
 ),
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 );
 }

 Widget _buildChatArea(bool isDark) {
 if (_selectedChatUsername == null) {
 return Center(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(
 Icons.chat_bubble_outline,
 size: 64,
 color: isDark ? Colors.white24 : Colors.black26,
 ),
 const SizedBox(height: 16),
 Text(
 'Select a user to start chatting',
 style: TextStyle(
 fontSize: 16,
 color: isDark ? Colors.white38 : Colors.black38,
 ),
 ),
 ],
 ),
 );
 }

 final user = _allUsers.firstWhere(
 (u) => u.username == _selectedChatUsername,
 orElse: () => AlertUser(username: _selectedChatUsername!, role: '', appStatus: 'offline'),
 );
 final profilePicture = _profilePictureCache[_selectedChatUsername];

 return Container(
 color: isDark ? const Color(0xFF121212) : Colors.grey[100],
 child: Column(
 children: [
 // Header
 Container(
 padding: const EdgeInsets.all(12),
 color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
 child: Row(
 children: [
 Stack(
 children: [
 CircleAvatar(
 radius: 20,
 backgroundColor: _accent.withValues(alpha: 0.2),
 backgroundImage: profilePicture != null ? MemoryImage(profilePicture) : null,
 child: profilePicture == null
 ? Text(
 user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
 style: const TextStyle(color: _accent, fontWeight: FontWeight.bold),
 )
 : null,
 ),
 Positioned(
 right: 0,
 bottom: 0,
 child: Container(
 width: 10,
 height: 10,
 decoration: BoxDecoration(
 color: _getStatusColor(user.appStatus),
 shape: BoxShape.circle,
 border: Border.all(color: isDark ? const Color(0xFF1A1A1A) : Colors.white, width: 2),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 user.displayName,
 style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
 ),
 Text(
 user.appStatus == 'online' ? 'Online' : (user.appStatus == 'away' ? 'Away' : 'Offline'),
 style: TextStyle(
 fontSize: 12,
 color: _getStatusColor(user.appStatus),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 const Divider(height: 1),
 // Messages
 Expanded(
 child: _loadingChat
 ? const Center(child: CircularProgressIndicator())
 : _chatMessages.isEmpty
 ? Center(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(
 Icons.chat_bubble_outline,
 size: 48,
 color: isDark ? Colors.white24 : Colors.black26,
 ),
 const SizedBox(height: 12),
 Text(
 'No messages yet',
 style: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
 ),
 const SizedBox(height: 4),
 Text(
 'Send a message to start the conversation',
 style: TextStyle(
 fontSize: 12,
 color: isDark ? Colors.white24 : Colors.black26,
 ),
 ),
 ],
 ),
 )
 : ListView.builder(
 controller: _chatScrollController,
 padding: const EdgeInsets.all(16),
 itemCount: _chatMessages.length,
 itemBuilder: (context, index) {
 final message = _chatMessages[index];
 final isMe = message.fromUsername == widget.currentUsername;
 final showDate = index == 0 ||
 _chatMessages[index - 1].createdAt.day != message.createdAt.day;

 return Column(
 children: [
 if (showDate)
 Padding(
 padding: const EdgeInsets.symmetric(vertical: 16),
 child: Text(
 _formatDateHeader(message.createdAt),
 style: TextStyle(
 fontSize: 12,
 color: isDark ? Colors.white38 : Colors.black38,
 ),
 ),
 ),
 _buildMessageBubble(message, isMe, isDark),
 ],
 );
 },
 ),
 ),
 // Message input
 Container(
 padding: const EdgeInsets.all(12),
 color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 // Selected file preview
 if (_selectedFile != null)
 Container(
 margin: const EdgeInsets.only(bottom: 8),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 decoration: BoxDecoration(
 color: _accent.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: _accent.withValues(alpha: 0.3)),
 ),
 child: Row(
 children: [
 Icon(
 _getFileIcon(_selectedFile!.name),
 color: _accent,
 size: 20,
 ),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 _selectedFile!.name,
 style: const TextStyle(fontSize: 13),
 overflow: TextOverflow.ellipsis,
 ),
 ),
 Text(
 _formatFileSize(_selectedFile!.size),
 style: TextStyle(
 fontSize: 11,
 color: isDark ? Colors.white38 : Colors.black38,
 ),
 ),
 const SizedBox(width: 8),
 GestureDetector(
 onTap: _clearSelectedFile,
 child: Icon(
 Icons.close,
 size: 18,
 color: isDark ? Colors.white54 : Colors.black54,
 ),
 ),
 ],
 ),
 ),
 Row(
 children: [
 // Attachment button
 IconButton(
 onPressed: _sendingChat ? null : _pickFile,
 icon: const Icon(Icons.attach_file),
 color: _accent,
 tooltip: 'Attach file',
 ),
 Expanded(
 child: TextField(
 controller: _chatMessageController,
 maxLines: 4,
 minLines: 1,
 textInputAction: TextInputAction.send,
 onSubmitted: (_) => _sendChatMessage(),
 decoration: InputDecoration(
 hintText: 'Type a message...',
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(24),
 borderSide: BorderSide.none,
 ),
 filled: true,
 fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
 contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
 ),
 ),
 ),
 const SizedBox(width: 8),
 FloatingActionButton.small(
 onPressed: _sendingChat ? null : _sendChatMessage,
 backgroundColor: _accent,
 child: _sendingChat
 ? const SizedBox(
 width: 20,
 height: 20,
 child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
 )
 : const Icon(Icons.send, color: Colors.white, size: 20),
 ),
 ],
 ),
 ],
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildMessageBubble(ChatMessage message, bool isMe, bool isDark) {
 return Align(
 alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
 child: GestureDetector(
 onSecondaryTapUp: (details) => _showDesktopMessageMenu(context, details.globalPosition, message),
 onLongPress: () => _showMobileMessageOptions(message),
 child: Container(
 margin: EdgeInsets.only(
 top: 4,
 bottom: 4,
 left: isMe ? 60 : 0,
 right: isMe ? 0 : 60,
 ),
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 decoration: BoxDecoration(
 color: isMe
 ? _accent
 : (isDark ? const Color(0xFF2A2A2A) : Colors.white),
 borderRadius: BorderRadius.only(
 topLeft: const Radius.circular(16),
 topRight: const Radius.circular(16),
 bottomLeft: Radius.circular(isMe ? 16 : 4),
 bottomRight: Radius.circular(isMe ? 4 : 16),
 ),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withValues(alpha: 0.05),
 blurRadius: 4,
 offset: const Offset(0, 2),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Attachment - show image inline if it's an image
 if (message.hasAttachment)
 GestureDetector(
 onTap: () => _openAttachment(
 message.attachmentUrl!,
 type: message.attachmentType,
 name: message.attachmentName,
 ),
 child: Container(
 margin: const EdgeInsets.only(bottom: 8),
 constraints: const BoxConstraints(maxWidth: 250, maxHeight: 300),
 child: message.attachmentType == 'image'
 ? ClipRRect(
 borderRadius: BorderRadius.circular(8),
 child: Image.network(
 message.attachmentUrl!,
 fit: BoxFit.cover,
 loadingBuilder: (context, child, loadingProgress) {
 if (loadingProgress == null) return child;
 return Container(
 width: 200,
 height: 150,
 decoration: BoxDecoration(
 color: isMe
 ? Colors.white.withValues(alpha: 0.15)
 : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100]),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Center(
 child: CircularProgressIndicator(
 value: loadingProgress.expectedTotalBytes != null
 ? loadingProgress.cumulativeBytesLoaded /
 loadingProgress.expectedTotalBytes!
 : null,
 color: _accent,
 strokeWidth: 2,
 ),
 ),
 );
 },
 errorBuilder: (context, error, stackTrace) {
 return Container(
 padding: const EdgeInsets.all(10),
 decoration: BoxDecoration(
 color: isMe
 ? Colors.white.withValues(alpha: 0.15)
 : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100]),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(Icons.broken_image, color: isMe ? Colors.white : _accent),
 const SizedBox(width: 8),
 Flexible(
 child: Text(
 message.attachmentName ?? 'Image',
 style: TextStyle(
 color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black),
 fontSize: 13,
 ),
 overflow: TextOverflow.ellipsis,
 ),
 ),
 ],
 ),
 );
 },
 ),
 )
 : Container(
 padding: const EdgeInsets.all(10),
 decoration: BoxDecoration(
 color: isMe
 ? Colors.white.withValues(alpha: 0.15)
 : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100]),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(
 _getFileIconFromType(message.attachmentType),
 color: isMe ? Colors.white : _accent,
 size: 24,
 ),
 const SizedBox(width: 8),
 Flexible(
 child: Text(
 message.attachmentName ?? 'Attachment',
 style: TextStyle(
 color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black),
 fontSize: 13,
 decoration: TextDecoration.underline,
 ),
 overflow: TextOverflow.ellipsis,
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 // Message text with clickable links
 if (message.message.isNotEmpty)
 LinkifiedText(
 text: message.message,
 style: TextStyle(
 color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black),
 fontSize: 15,
 ),
 linkStyle: TextStyle(
 color: isMe ? Colors.lightBlue[100] : Colors.blue,
 fontSize: 15,
 decoration: TextDecoration.underline,
 decorationColor: isMe ? Colors.lightBlue[100] : Colors.blue,
 ),
 ),
 const SizedBox(height: 4),
 Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(
 _formatMessageTime(message.createdAt),
 style: TextStyle(
 fontSize: 11,
 color: isMe
 ? Colors.white.withValues(alpha: 0.7)
 : (isDark ? Colors.white38 : Colors.black38),
 ),
 ),
 if (isMe) ...[
 const SizedBox(width: 4),
 Icon(
 message.isRead ? Icons.done_all : Icons.done,
 size: 14,
 color: message.isRead ? Colors.blue[200] : Colors.white70,
 ),
 ],
 ],
 ),
 ],
 ),
 ),
 ),
 );
 }

 void _showDesktopMessageMenu(BuildContext context, Offset position, ChatMessage message) {
 showMenu<String>(
 context: context,
 position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
 items: [
 const PopupMenuItem(value: 'copy', child: Row(children: [Icon(Icons.copy, size: 18), SizedBox(width: 8), Text('Copy')])),
 const PopupMenuItem(value: 'forward', child: Row(children: [Icon(Icons.forward, size: 18), SizedBox(width: 8), Text('Forward')])),
 ],
 ).then((value) {
 if (value == 'copy') {
 Clipboard.setData(ClipboardData(text: message.message));
 if (!context.mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Message copied'), duration: Duration(seconds: 1)),
 );
 } else if (value == 'forward') {
 _showForwardDialog(message);
 }
 });
 }

 void _showMobileMessageOptions(ChatMessage message) {
 showModalBottomSheet(
 context: context,
 builder: (ctx) => SafeArea(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 ListTile(
 leading: const Icon(Icons.copy),
 title: const Text('Copy'),
 onTap: () {
 Clipboard.setData(ClipboardData(text: message.message));
 Navigator.pop(ctx);
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Message copied'), duration: Duration(seconds: 1)),
 );
 },
 ),
 ListTile(
 leading: const Icon(Icons.forward),
 title: const Text('Forward'),
 onTap: () {
 Navigator.pop(ctx);
 _showForwardDialog(message);
 },
 ),
 ],
 ),
 ),
 );
 }

 void _showForwardDialog(ChatMessage message) {
 showDialog(
 context: context,
 builder: (context) => ForwardMessageDialog(
 message: message.message,
 currentUsername: widget.currentUsername,
 onForward: (toUsername) async {
 try {
 final response = await http.post(
 Uri.parse(ApiConfig.chatMessages),
 headers: {'Content-Type': 'application/json'},
 body: jsonEncode({
 'action': 'send',
 'from_username': widget.currentUsername,
 'to_username': toUsername,
 'message': message.message,
 }),
 );
 if (response.statusCode == 200 || response.statusCode == 201) {
 if (!context.mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Message forwarded to $toUsername'), backgroundColor: Colors.green),
 );
 }
 } catch (e) {
 if (!context.mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Failed to forward: $e'), backgroundColor: Colors.red),
 );
 }
 },
 ),
 );
 }

 IconData _getFileIconFromType(String? type) {
 switch (type) {
 case 'image':
 return Icons.image;
 case 'pdf':
 return Icons.picture_as_pdf;
 case 'document':
 return Icons.description;
 case 'spreadsheet':
 return Icons.table_chart;
 default:
 return Icons.insert_drive_file;
 }
 }

 Future<void> _openAttachment(String url, {String? type, String? name}) async {
 // Check if it's an image
 final isImage = type == 'image' || 
 url.toLowerCase().endsWith('.jpg') ||
 url.toLowerCase().endsWith('.jpeg') ||
 url.toLowerCase().endsWith('.png') ||
 url.toLowerCase().endsWith('.gif') ||
 url.toLowerCase().endsWith('.webp');
 
 if (isImage) {
 _showImageViewer(url, name);
 } else {
 // For other files, try to open in browser/system
 try {
 // Use url_launcher if available, otherwise show download option
 _showFileDownloadDialog(url, name);
 } catch (e) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Could not open file: $e')),
 );
 }
 }
 }

 void _showImageViewer(String imageUrl, String? imageName) {
 showDialog(
 context: context,
 barrierColor: Colors.black.withValues(alpha: 0.9),
 builder: (context) => ImageViewerDialog(
 imageUrl: imageUrl,
 imageName: imageName,
 ),
 );
 }

 void _showFileDownloadDialog(String url, String? name) {
 final fileName = name ?? url.split('/').last;

 showDialog(
 context: context,
 builder: (ctx) => AlertDialog(
 title: Row(
 children: [
 Icon(_getFileIconFromName(fileName), color: _accent),
 const SizedBox(width: 12),
 Expanded(
 child: Text(
 fileName,
 overflow: TextOverflow.ellipsis,
 ),
 ),
 ],
 ),
 content: const Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('What would you like to do with this file?'),
 ],
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(ctx),
 child: const Text('Cancel'),
 ),
 TextButton(
 onPressed: () async {
 Navigator.pop(ctx);
 await Clipboard.setData(ClipboardData(text: url));
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Link copied to clipboard'),
 backgroundColor: Colors.green,
 ),
 );
 }
 },
 child: const Text('Copy Link'),
 ),
 TextButton(
 onPressed: () async {
 Navigator.pop(ctx);
 await _downloadAndSaveFile(url, fileName);
 },
 child: const Text('Save to Downloads'),
 ),
 ElevatedButton(
 onPressed: () async {
 Navigator.pop(ctx);
 await _openFileFromUrl(url, fileName);
 },
 style: ElevatedButton.styleFrom(backgroundColor: _accent),
 child: const Text('Open', style: TextStyle(color: Colors.white)),
 ),
 ],
 ),
 );
 }

 IconData _getFileIconFromName(String fileName) {
 final ext = fileName.split('.').last.toLowerCase();
 if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) return Icons.image;
 if (['pdf'].contains(ext)) return Icons.picture_as_pdf;
 if (['doc', 'docx'].contains(ext)) return Icons.description;
 if (['xls', 'xlsx'].contains(ext)) return Icons.table_chart;
 if (['mp4', 'mov', 'avi'].contains(ext)) return Icons.video_file;
 if (['mp3', 'wav', 'aac'].contains(ext)) return Icons.audio_file;
 return Icons.insert_drive_file;
 }

 Future<void> _downloadAndSaveFile(String url, String fileName) async {
 try {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Downloading file...')),
 );

 // Download the file
 final response = await http.get(Uri.parse(url));
 if (response.statusCode != 200) {
 throw Exception('Failed to download: HTTP ${response.statusCode}');
 }

 // Save to Downloads folder
 String savePath;
 if (Platform.isWindows) {
 final downloadsDir = Directory('${Platform.environment['USERPROFILE']}\\Downloads');
 savePath = '${downloadsDir.path}\\$fileName';
 } else {
 final dir = await getApplicationDocumentsDirectory();
 savePath = '${dir.path}/$fileName';
 }

 final file = File(savePath);
 await file.writeAsBytes(response.bodyBytes);

 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Saved to: $savePath'),
 backgroundColor: Colors.green,
 duration: const Duration(seconds: 4),
 action: SnackBarAction(
 label: 'Open Folder',
 textColor: Colors.white,
 onPressed: () async {
 if (Platform.isWindows) {
 await launchUrl(Uri.file(file.parent.path));
 }
 },
 ),
 ),
 );
 }
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Failed to save: $e'),
 backgroundColor: Colors.red,
 ),
 );
 }
 }
 }

 Future<void> _openFileFromUrl(String url, String fileName) async {
 try {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Opening file...')),
 );

 // Download to temp location
 final response = await http.get(Uri.parse(url));
 if (response.statusCode != 200) {
 throw Exception('Failed to download: HTTP ${response.statusCode}');
 }

 // Save to temp directory
 final tempDir = await getTemporaryDirectory();
 final tempFile = File('${tempDir.path}/$fileName');
 await tempFile.writeAsBytes(response.bodyBytes);

 // Open the file
 final fileUri = Uri.file(tempFile.path);
 if (await canLaunchUrl(fileUri)) {
 await launchUrl(fileUri);
 } else {
 // Try opening in browser as fallback
 final webUrl = Uri.parse(url);
 if (await canLaunchUrl(webUrl)) {
 await launchUrl(webUrl, mode: LaunchMode.externalApplication);
 } else {
 throw Exception('Cannot open file');
 }
 }
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Failed to open: $e'),
 backgroundColor: Colors.red,
 ),
 );
 }
 }
 }

 String _formatDateHeader(DateTime date) {
 final now = DateTime.now();
 final today = DateTime(now.year, now.month, now.day);
 final yesterday = today.subtract(const Duration(days: 1));
 final messageDate = DateTime(date.year, date.month, date.day);

 if (messageDate == today) {
 return 'Today';
 } else if (messageDate == yesterday) {
 return 'Yesterday';
 } else {
 return '${date.month}/${date.day}/${date.year}';
 }
 }
}
