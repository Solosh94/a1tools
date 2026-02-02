import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../monitoring/remote_monitoring_viewer.dart';
import '../../metrics/metrics_service.dart';
import '../../config/api_config.dart';
import '../../app_theme.dart';

class OfficeMapScreen extends StatefulWidget {
  final String currentUsername;
  final String currentRole;

  const OfficeMapScreen({
    super.key,
    required this.currentUsername,
    required this.currentRole,
  });

  @override
  State<OfficeMapScreen> createState() => _OfficeMapScreenState();
}

class _Computer {
  final String id;
  double posX;
  double posY;
  String? assignedUsername;
  String? role;
  String? firstName;
  String? lastName;
  bool isOnline;

  _Computer({
    required this.id,
    required this.posX,
    required this.posY,
    this.assignedUsername,
    this.role,
    this.firstName,
    this.lastName,
    this.isOnline = false,
  });

  factory _Computer.fromJson(Map<String, dynamic> json) {
    return _Computer(
      id: json['computer_id'] ?? '',
      posX: (json['pos_x'] ?? 50).toDouble(),
      posY: (json['pos_y'] ?? 50).toDouble(),
      assignedUsername: json['assigned_username'],
      role: json['role'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      isOnline: json['is_online'] == true || json['is_online'] == 1,
    );
  }

  String get displayName {
    if (firstName != null && firstName!.isNotEmpty) {
      return firstName!;
    }
    return assignedUsername ?? 'Unassigned';
  }
}

class _Wall {
  final int id;
  final double startX;
  final double startY;
  final double endX;
  final double endY;

  _Wall({
    required this.id,
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
  });

  factory _Wall.fromJson(Map<String, dynamic> json) {
    return _Wall(
      id: json['id'] ?? 0,
      startX: (json['start_x'] ?? 0).toDouble(),
      startY: (json['start_y'] ?? 0).toDouble(),
      endX: (json['end_x'] ?? 0).toDouble(),
      endY: (json['end_y'] ?? 0).toDouble(),
    );
  }
}

class _User {
  final String username;
  final String role;
  final String? firstName;
  final String? lastName;

  _User({
    required this.username,
    required this.role,
    this.firstName,
    this.lastName,
  });

  factory _User.fromJson(Map<String, dynamic> json) {
    return _User(
      username: json['username'] ?? '',
      role: json['role'] ?? '',
      firstName: json['first_name'],
      lastName: json['last_name'],
    );
  }

  String get displayName {
    if (firstName != null && firstName!.isNotEmpty) {
      if (lastName != null && lastName!.isNotEmpty) {
        return '$firstName $lastName';
      }
      return firstName!;
    }
    return username;
  }
}

enum EditMode { none, move, drawWall, deleteWall }

class _OfficeMapScreenState extends State<OfficeMapScreen> {
  static const String _baseUrl = ApiConfig.officeMap;
  static const String _pictureUrl = ApiConfig.profilePicture;
  static const Color _accent = AppColors.accent;
  static const double computerSize = 60;
  
  // Fixed canvas size
  static const double canvasWidth = 1000;
  static const double canvasHeight = 700;

  Map<String, _Computer> _computers = {};
  List<_Wall> _walls = [];
  List<_User> _users = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;
  
  // Profile picture cache
  final Map<String, Uint8List> _profilePictureCache = {};

  EditMode _editMode = EditMode.none;
  Offset? _wallStartPoint;
  Offset? _wallPreviewEnd;

  // Current map scale for drag adjustment
  double _currentScale = 1.0;

  /// Check if current user can use remote tools (developer, administrator, management)
  bool get _canUseRemoteTools {
    final role = widget.currentRole.toLowerCase();
    return role == 'developer' || role == 'administrator' || role == 'management';
  }

  /// Check if current user is developer (for editing map layout)
  bool get _isDeveloper => widget.currentRole.toLowerCase() == 'developer';

  /// Check if a target user is protected from remote viewing (administrator or developer)
  bool _isProtectedUser(String? targetRole) {
    if (targetRole == null) return false;
    final role = targetRole.toLowerCase();
    return role == 'developer' || role == 'administrator';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _sendHeartbeat(); // Send heartbeat on open

    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_editMode == EditMode.none) {
        _loadDataSilent();
      }
      _sendHeartbeat(); // Send heartbeat on each refresh
    });
  }
  
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

  Future<void> _sendHeartbeat() async {
    try {
      await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'heartbeat',
          'username': widget.currentUsername,
        }),
      );
    } catch (e) {
      // Silent fail for heartbeat
      debugPrint('[OfficeMapScreen] Error: $e');
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Add cache-buster to prevent caching
      final cacheBuster = DateTime.now().millisecondsSinceEpoch;
      final resp = await http.get(
        Uri.parse('$_baseUrl?action=get_all&_=$cacheBuster'),
        headers: {
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        },
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['success'] == true) {
          final List computers = data['computers'] ?? [];
          final List walls = data['walls'] ?? [];

          _computers = {
            for (var c in computers) c['computer_id']: _Computer.fromJson(c)
          };
          _walls = walls.map((w) => _Wall.fromJson(w)).toList();
        } else {
          throw Exception(data['error'] ?? 'Failed to load');
        }
      } else {
        throw Exception('Server error: ${resp.statusCode}');
      }

      if (_canUseRemoteTools) {
        final usersResp = await http.get(
          Uri.parse('$_baseUrl?action=get_users&_=$cacheBuster'),
          headers: {
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache',
          },
        );
        if (usersResp.statusCode == 200) {
          final data = jsonDecode(usersResp.body);
          if (data['success'] == true) {
            _users = (data['users'] as List).map((u) => _User.fromJson(u)).toList();
          }
        }
      }

      if (mounted) {
        setState(() => _loading = false);
        
        // Load profile pictures for assigned users
        for (final computer in _computers.values) {
          if (computer.assignedUsername != null) {
            _loadProfilePicture(computer.assignedUsername!);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _loadDataSilent() async {
    try {
      final cacheBuster = DateTime.now().millisecondsSinceEpoch;
      final resp = await http.get(
        Uri.parse('$_baseUrl?action=get_all&_=$cacheBuster'),
        headers: {
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        },
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['success'] == true && mounted) {
          final List computers = data['computers'] ?? [];
          final List walls = data['walls'] ?? [];
          setState(() {
            _computers = {
              for (var c in computers) c['computer_id']: _Computer.fromJson(c)
            };
            _walls = walls.map((w) => _Wall.fromJson(w)).toList();
          });
        }
      }
    } catch (e) {
  debugPrint('[OfficeMapScreen] Error: $e');
}
  }

  Future<void> _updatePosition(String computerId, double x, double y) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'update_position',
          'computer_id': computerId,
          'pos_x': x,
          'pos_y': y,
          'requesting_role': widget.currentRole,
        }),
      );

      final data = jsonDecode(response.body);
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Failed to save position');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _assignUser(String computerId, String? username) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'assign',
          'computer_id': computerId,
          'username': username ?? '',
          'requesting_role': widget.currentRole,
        }),
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(username != null ? 'Assigned $username' : 'Unassigned'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception(data['error']);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addWall(double startX, double startY, double endX, double endY) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'add_wall',
          'start_x': startX,
          'start_y': startY,
          'end_x': endX,
          'end_y': endY,
          'requesting_role': widget.currentRole,
        }),
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        setState(() {
          _walls.add(_Wall(
            id: data['wall_id'],
            startX: startX,
            startY: startY,
            endX: endX,
            endY: endY,
          ));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add wall: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteWall(int wallId) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'delete_wall',
          'wall_id': wallId,
          'requesting_role': widget.currentRole,
        }),
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        setState(() {
          _walls.removeWhere((w) => w.id == wallId);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete wall: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _clearAllWalls() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Walls?'),
        content: const Text('This will delete all walls. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'clear_walls',
          'requesting_role': widget.currentRole,
        }),
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        setState(() => _walls.clear());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showComputerDialog(String computerId) {
    final computer = _computers[computerId];
    if (computer == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasUser = computer.assignedUsername != null;
    final profilePicture = hasUser ? _profilePictureCache[computer.assignedUsername!] : null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: hasUser
                    ? (computer.isOnline ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1))
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.computer,
                color: hasUser
                    ? (computer.isOnline ? Colors.green : Colors.red)
                    : Colors.grey,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Text('Computer $computerId'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasUser) ...[
              // User info with profile picture
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    // Profile picture
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: _accent.withValues(alpha: 0.2),
                          backgroundImage: profilePicture != null
                              ? MemoryImage(profilePicture)
                              : null,
                          child: profilePicture == null
                              ? Text(
                                  computer.assignedUsername!.isNotEmpty 
                                      ? computer.assignedUsername![0].toUpperCase() 
                                      : '?',
                                  style: const TextStyle(
                                    color: _accent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22,
                                  ),
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
                              color: computer.isOnline ? Colors.green : Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? const Color(0xFF252525) : Colors.white,
                                width: 2,
                              ),
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
                            computer.displayName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '@${computer.assignedUsername}',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          if (computer.role != null) ...[
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _displayRole(computer.role!),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _accent,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Online/Offline status
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: computer.isOnline ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    computer.isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: computer.isOnline ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
              // Remote control buttons (admin/manager/developer only, when online, not for protected users)
              if (_canUseRemoteTools && computer.isOnline && !_isProtectedUser(computer.role)) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Remote Control',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                // Remote view button
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openScreenshots(
                      computer.assignedUsername ?? '',
                      computer.displayName,
                    );
                  },
                  icon: const Icon(Icons.monitor, size: 18),
                  label: const Text('Remote View'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _accent,
                    side: const BorderSide(color: _accent),
                    minimumSize: const Size(double.infinity, 40),
                  ),
                ),
                const SizedBox(height: 8),
                // Restart/Shutdown buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _sendRemoteCommand(computer, 'restart');
                        },
                        icon: const Icon(Icons.restart_alt, size: 18),
                        label: const Text('Restart'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _sendRemoteCommand(computer, 'shutdown');
                        },
                        icon: const Icon(Icons.power_settings_new, size: 18),
                        label: const Text('Shutdown'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Push Update button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showPushUpdateDialog(computer);
                    },
                    icon: const Icon(Icons.system_update, size: 18),
                    label: const Text('Push Update'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.purple,
                      side: const BorderSide(color: Colors.purple),
                    ),
                  ),
                ),
              ],
            ] else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'No user assigned',
                  style: TextStyle(fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          if (hasUser)
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _showSendAlertDialog(computer);
              },
              icon: const Icon(Icons.send, size: 18),
              label: const Text('Send Alert'),
            ),
          if (_canUseRemoteTools && hasUser)
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _showAssignDialog(computerId, computer);
              },
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text('Reassign'),
            ),
          if (_canUseRemoteTools && !hasUser)
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _showAssignDialog(computerId, computer);
              },
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text('Assign'),
            ),
        ],
      ),
    );
  }

  void _showSendAlertDialog(_Computer computer) {
    final messageController = TextEditingController();
    bool isSending = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.send, color: Color(0xFFF49320)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Send Alert to ${computer.displayName}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 350,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Computer ${computer.id} - @${computer.assignedUsername}',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white60
                        : Colors.black54,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    hintText: 'Type your message...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                  autofocus: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSending ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: isSending
                  ? null
                  : () async {
                      final message = messageController.text.trim();
                      if (message.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a message'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isSending = true);

                      try {
                        final response = await http.post(
                          Uri.parse(ApiConfig.alerts),
                          headers: {'Content-Type': 'application/json'},
                          body: jsonEncode({
                            'from_username': widget.currentUsername,
                            'to_username': computer.assignedUsername,
                            'message': message,
                          }),
                        );

                        if (!context.mounted) return;
                        Navigator.pop(ctx);

                        if (response.statusCode == 200 || response.statusCode == 201) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Alert sent to ${computer.displayName}'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          final data = jsonDecode(response.body);
                          throw Exception(data['message'] ?? data['error'] ?? 'Failed to send (${response.statusCode})');
                        }
                      } catch (e) {
                        setDialogState(() => isSending = false);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              icon: isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send, size: 18),
              label: Text(isSending ? 'Sending...' : 'Send'),
            ),
          ],
        ),
      ),
    );
  }

  /// Send a remote command (shutdown/restart) to a computer
  Future<void> _sendRemoteCommand(_Computer computer, String command) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Confirm dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              command == 'shutdown' ? Icons.power_settings_new : Icons.restart_alt,
              color: command == 'shutdown' ? Colors.red : Colors.orange,
            ),
            const SizedBox(width: 8),
            Text('Confirm ${command == 'shutdown' ? 'Shutdown' : 'Restart'}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to ${command == 'shutdown' ? 'shut down' : 'restart'} this computer?',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.computer, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          computer.displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Computer ${computer.id} - @${computer.assignedUsername}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (command == 'shutdown' ? Colors.red : Colors.orange).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (command == 'shutdown' ? Colors.red : Colors.orange).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: command == 'shutdown' ? Colors.red : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      command == 'shutdown'
                          ? 'The computer will shut down after user confirmation.'
                          : 'The computer will restart after user confirmation.',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: Icon(
              command == 'shutdown' ? Icons.power_settings_new : Icons.restart_alt,
              size: 18,
            ),
            label: Text(command == 'shutdown' ? 'Shut Down' : 'Restart'),
            style: ElevatedButton.styleFrom(
              backgroundColor: command == 'shutdown' ? Colors.red : Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Send the command
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.officeMap),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'remote_command',
          'target_username': computer.assignedUsername,
          'command': command,
          'issued_by': widget.currentUsername,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${command == 'shutdown' ? 'Shutdown' : 'Restart'} command sent to ${computer.displayName}',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          throw Exception(data['error'] ?? 'Failed to send command');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show dialog to push update to a specific computer
  void _showPushUpdateDialog(_Computer computer) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final versionController = TextEditingController();
    final downloadUrlController = TextEditingController();
    bool isPushing = false;

    // Auto-fill download URL when version changes
    void updateDownloadUrl() {
      final version = versionController.text.trim();
      if (version.isNotEmpty) {
        downloadUrlController.text = ApiConfig.installerDownload(version);
      }
    }

    versionController.addListener(updateDownloadUrl);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.system_update, color: Colors.purple),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Push Update'),
                    Text(
                      'To ${computer.displayName}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Target info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.computer, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Computer ${computer.id}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '@${computer.assignedUsername}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: computer.isOnline ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          computer.isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            fontSize: 11,
                            color: computer.isOnline ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Version field
                TextField(
                  controller: versionController,
                  decoration: InputDecoration(
                    labelText: 'Version',
                    hintText: 'e.g., 2.5.31',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.tag),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                // Download URL field
                TextField(
                  controller: downloadUrlController,
                  decoration: InputDecoration(
                    labelText: 'Download URL',
                    hintText: '${ApiConfig.downloadsBase}/...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.link),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),
                // Info box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.purple.shade300, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'This will send an update command only to this computer. '
                          'Use this to test updates before pushing to everyone.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isPushing ? null : () {
                versionController.removeListener(updateDownloadUrl);
                Navigator.pop(ctx);
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: isPushing
                  ? null
                  : () async {
                      final version = versionController.text.trim();
                      final downloadUrl = downloadUrlController.text.trim();

                      if (version.isEmpty || downloadUrl.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter version and download URL'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isPushing = true);

                      try {
                        final response = await http.post(
                          Uri.parse(ApiConfig.officeMap),
                          headers: {'Content-Type': 'application/json'},
                          body: jsonEncode({
                            'action': 'remote_command',
                            'target_username': computer.assignedUsername,
                            'command': 'update',
                            'version': version,
                            'download_url': downloadUrl,
                            'issued_by': widget.currentUsername,
                          }),
                        );

                        versionController.removeListener(updateDownloadUrl);
                        if (!context.mounted) return;
                        Navigator.pop(ctx);

                        if (response.statusCode == 200) {
                          final data = jsonDecode(response.body);
                          if (data['success'] == true) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Update v$version pushed to ${computer.displayName}'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            throw Exception(data['error'] ?? 'Failed to push update');
                          }
                        } else {
                          throw Exception('Server error: ${response.statusCode}');
                        }
                      } catch (e) {
                        setDialogState(() => isPushing = false);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              icon: isPushing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.rocket_launch, size: 18),
              label: Text(isPushing ? 'Pushing...' : 'Push Update'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.purple,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get computer name for a user from remote monitoring API
  /// This is more reliable than metrics for new users
  Future<String?> _getComputerNameFromRemoteMonitoring(String username) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.remoteMonitoring}?action=list_online'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['computers'] != null) {
          final computers = data['computers'] as List;
          // Find computer for this username (case-insensitive)
          for (final computer in computers) {
            if ((computer['username'] as String?)?.toLowerCase() == username.toLowerCase()) {
              return computer['computer_name'] as String?;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching computer from remote monitoring: $e');
    }
    return null;
  }

  /// Open screenshots for a user - fetches actual computer name from metrics
  Future<void> _openScreenshots(String username, String displayName) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Loading screenshots...'),
          ],
        ),
      ),
    );

    try {
      // First try to get computer name from remote_monitoring API (most reliable for new users)
      String? computerName = await _getComputerNameFromRemoteMonitoring(username);
      
      // Fall back to metrics service if not found in remote monitoring
      if (computerName == null) {
        final metrics = await MetricsService.getAllMetrics();
        final userMetrics = metrics.where((m) => m.username == username).toList();
        if (userMetrics.isNotEmpty) {
          computerName = userMetrics.first.computerName;
        }
      }

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (computerName == null || computerName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No computer found for $displayName. User may not be online or not sending data.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RemoteMonitoringViewer(
            computerName: computerName!,
            username: username,
            viewerUsername: widget.currentUsername,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading screenshots: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAssignDialog(String computerId, _Computer computer) {
    String? selectedUsername = computer.assignedUsername;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Assign to Computer $computerId'),
          content: SizedBox(
            width: 300,
            child: DropdownButtonFormField<String?>(
              initialValue: selectedUsername,
              decoration: const InputDecoration(
                labelText: 'Select User',
                border: OutlineInputBorder(),
              ),
              isExpanded: true,
              items: [
                const DropdownMenuItem(value: null, child: Text('-- Unassigned --')),
                ..._users.map((u) => DropdownMenuItem(
                      value: u.username,
                      child: Text('${u.displayName} (${_displayRole(u.role)})'),
                    )),
              ],
              onChanged: (v) => setDialogState(() => selectedUsername = v),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _assignUser(computerId, selectedUsername);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  String _displayRole(String role) {
    switch (role.toLowerCase()) {
      case 'developer': return 'Developer';
      case 'administrator': return 'Administrator';
      case 'management': return 'Management';
      case 'dispatcher': return 'Dispatcher';
      case 'remote_dispatcher': return 'Remote Dispatcher';
      case 'technician': return 'Technician';
      case 'marketing': return 'Marketing';
      default: return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Image.asset(
          isDark ? 'assets/images/logo-white.png' : 'assets/images/logo.png',
          height: 40,
          fit: BoxFit.contain,
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
                    ],
                  ),
                )
              : _buildMapEditor(isDark),
    );
  }

  Widget _buildMapEditor(bool isDark) {
    final bgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);

    return Column(
      children: [
        if (_isDeveloper) _buildToolbar(isDark),
        _buildLegend(isDark),
        Expanded(
          child: Container(
            color: bgColor,
            width: double.infinity,
            height: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth - 40; // padding
                final availableHeight = constraints.maxHeight - 40; // padding
                
                // Calculate the scale to fit the entire map
                final scaleX = availableWidth / canvasWidth;
                final scaleY = availableHeight / canvasHeight;
                final scale = scaleX < scaleY ? scaleX : scaleY;
                
                // Store scale for drag handling
                _currentScale = scale;
                
                // Calculate the actual displayed size
                final displayWidth = canvasWidth * scale;
                final displayHeight = canvasHeight * scale;
                
                // On mobile (small screens), allow pinch-to-zoom starting from fitted view
                final isMobileSize = constraints.maxWidth < 600;
                
                // Build the map content at full size - FittedBox will scale it
                final mapContent = Container(
                  width: canvasWidth,
                  height: canvasHeight,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF252525) : Colors.white,
                    border: Border.all(
                      color: isDark ? Colors.white24 : Colors.black26,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: GestureDetector(
                      onTapDown: _editMode == EditMode.drawWall ? _handleWallTap : null,
                      onPanUpdate: _editMode == EditMode.drawWall ? _handleWallPan : null,
                      child: CustomPaint(
                        painter: _WallPainter(
                          walls: _walls,
                          isDark: isDark,
                          previewStart: _wallStartPoint,
                          previewEnd: _wallPreviewEnd,
                          showSnapPoints: _editMode == EditMode.drawWall,
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Canvas size indicator in corner
                            Positioned(
                              right: 8,
                              bottom: 8,
                              child: Text(
                                '${canvasWidth.toInt()} x ${canvasHeight.toInt()}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? Colors.white30 : Colors.black26,
                                ),
                              ),
                            ),
                            for (final computer in _computers.values)
                              _buildDraggableComputer(computer, isDark),
                            if (_editMode == EditMode.deleteWall)
                              for (final wall in _walls)
                                _buildWallDeleteButton(wall),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
                
                // Use FittedBox to scale the entire map to fit
                final fittedMap = Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: displayWidth,
                      height: displayHeight,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: mapContent,
                      ),
                    ),
                  ),
                );
                
                // Wrap in InteractiveViewer for mobile to allow pinch-zoom and pan
                if (isMobileSize) {
                  return InteractiveViewer(
                    boundaryMargin: const EdgeInsets.all(50),
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: fittedMap,
                  );
                }
                
                // Desktop: just show the fitted map (no scrolling needed since it always fits)
                return fittedMap;
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? Colors.black26 : Colors.grey.shade200,
      child: Row(
        children: [
          const Text('Edit Mode: ', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          _toolbarButton('View', EditMode.none, Icons.visibility),
          _toolbarButton('Move', EditMode.move, Icons.open_with),
          _toolbarButton('Draw Wall', EditMode.drawWall, Icons.draw),
          _toolbarButton('Delete Wall', EditMode.deleteWall, Icons.delete),
          const SizedBox(width: 16),
          // Save Layout button
          FilledButton.icon(
            onPressed: _saveAllPositions,
            icon: const Icon(Icons.save, size: 18),
            label: const Text('Save Layout'),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
          ),
          const Spacer(),
          if (_walls.isNotEmpty)
            TextButton.icon(
              onPressed: _clearAllWalls,
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              label: const Text('Clear All Walls', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }

  Future<void> _saveAllPositions() async {
    int saved = 0;
    int failed = 0;
    
    for (final computer in _computers.values) {
      try {
        final response = await http.post(
          Uri.parse(_baseUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'action': 'update_position',
            'computer_id': computer.id,
            'pos_x': computer.posX,
            'pos_y': computer.posY,
            'requesting_role': widget.currentRole,
          }),
        );

        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          saved++;
        } else {
          failed++;
          debugPrint('Failed to save ${computer.id}: ${data['error']}');
        }
      } catch (e) {
        failed++;
        debugPrint('Error saving ${computer.id}: $e');
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failed == 0 
            ? 'Saved all $saved computer positions!' 
            : 'Saved $saved, failed $failed'),
          backgroundColor: failed == 0 ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  Widget _toolbarButton(String label, EditMode mode, IconData icon) {
    final isSelected = _editMode == mode;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
        selected: isSelected,
        selectedColor: _accent,
        onSelected: (_) => setState(() {
          _editMode = mode;
          _wallStartPoint = null;
          _wallPreviewEnd = null;
        }),
      ),
    );
  }

  Widget _buildLegend(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? Colors.black12 : Colors.white,
      child: Row(
        children: [
          _legendItem(Colors.green, 'Online', isDark),
          const SizedBox(width: 16),
          _legendItem(Colors.red, 'Offline', isDark),
          const SizedBox(width: 16),
          _legendItem(Colors.grey, 'Unassigned', isDark),
          const SizedBox(width: 16),
          Text(
            'Canvas: ${canvasWidth.toInt()}x${canvasHeight.toInt()}',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          if (_editMode == EditMode.drawWall) ...[
            const Spacer(),
            Text(
              _wallStartPoint == null 
                  ? 'Click to start wall (snaps to endpoints)' 
                  : 'Click to end wall (5 degree angles, snaps to endpoints)',
              style: const TextStyle(color: _accent, fontWeight: FontWeight.w500),
            ),
            if (_wallStartPoint != null && _wallPreviewEnd != null) ...[
              const SizedBox(width: 16),
              Text(
                'Angle: ${_getCurrentAngle()} deg',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _getCurrentAngle() {
    if (_wallStartPoint == null || _wallPreviewEnd == null) return '0';
    final dx = _wallPreviewEnd!.dx - _wallStartPoint!.dx;
    final dy = _wallPreviewEnd!.dy - _wallStartPoint!.dy;
    double angle = math.atan2(dy, dx) * 180 / math.pi;
    // Snap to nearest 5
    angle = (angle / 5).round() * 5;
    return angle.toStringAsFixed(0);
  }

  Widget _legendItem(Color color, String label, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.3),
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
      ],
    );
  }

  Widget _buildDraggableComputer(_Computer computer, bool isDark) {
    final hasUser = computer.assignedUsername != null;
    final isOnline = computer.isOnline;

    Color bgColor, borderColor, iconColor;
    if (!hasUser) {
      bgColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
      borderColor = iconColor = Colors.grey;
    } else if (isOnline) {
      bgColor = isDark ? Colors.green.shade900 : Colors.green.shade50;
      borderColor = iconColor = Colors.green;
    } else {
      bgColor = isDark ? Colors.red.shade900 : Colors.red.shade50;
      borderColor = iconColor = Colors.red;
    }

    final computerWidget = Container(
      width: computerSize,
      height: computerSize,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 2.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4, offset: const Offset(2, 2)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.computer, color: iconColor, size: 22),
          Text(
            computer.id,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: iconColor),
          ),
        ],
      ),
    );

    if (_editMode == EditMode.move && _isDeveloper) {
      return Positioned(
        left: computer.posX,
        top: computer.posY,
        child: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              // Adjust delta by scale factor since FittedBox scales the view
              final adjustedDx = details.delta.dx / _currentScale;
              final adjustedDy = details.delta.dy / _currentScale;
              computer.posX += adjustedDx;
              computer.posY += adjustedDy;
              // Clamp to canvas bounds
              computer.posX = computer.posX.clamp(0.0, canvasWidth - computerSize);
              computer.posY = computer.posY.clamp(0.0, canvasHeight - computerSize);
            });
          },
          onPanEnd: (details) {
            _updatePosition(computer.id, computer.posX, computer.posY);
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: computerWidget,
          ),
        ),
      );
    }

    return Positioned(
      left: computer.posX,
      top: computer.posY,
      child: GestureDetector(
        onTap: () => _showComputerDialog(computer.id),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: computerWidget,
        ),
      ),
    );
  }

  Widget _buildWallDeleteButton(_Wall wall) {
    final midX = (wall.startX + wall.endX) / 2;
    final midY = (wall.startY + wall.endY) / 2;

    return Positioned(
      left: midX - 12,
      top: midY - 12,
      child: GestureDetector(
        onTap: () => _deleteWall(wall.id),
        child: Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
          child: const Icon(Icons.close, color: Colors.white, size: 16),
        ),
      ),
    );
  }

  void _handleWallTap(TapDownDetails details) {
    final pos = details.localPosition;

    if (_wallStartPoint == null) {
      // Snap start point to existing wall endpoints
      final snappedStart = _snapToWallEndpoint(pos);
      setState(() {
        _wallStartPoint = snappedStart;
        _wallPreviewEnd = snappedStart;
      });
    } else {
      // Snap end point to angle first, then to wall endpoints
      final angledEnd = _snapToAngle(_wallStartPoint!, pos);
      final snappedEnd = _snapToWallEndpoint(angledEnd);
      _addWall(_wallStartPoint!.dx, _wallStartPoint!.dy, snappedEnd.dx, snappedEnd.dy);
      setState(() {
        _wallStartPoint = null;
        _wallPreviewEnd = null;
      });
    }
  }

  void _handleWallPan(DragUpdateDetails details) {
    if (_wallStartPoint != null) {
      // Snap preview to angle first, then to wall endpoints
      final angledEnd = _snapToAngle(_wallStartPoint!, details.localPosition);
      final snappedEnd = _snapToWallEndpoint(angledEnd);
      setState(() => _wallPreviewEnd = snappedEnd);
    }
  }

  /// Snaps point to nearby wall endpoints (within snapDistance pixels)
  Offset _snapToWallEndpoint(Offset point) {
    const double snapDistance = 15.0;
    
    // Collect all wall endpoints
    final List<Offset> endpoints = [];
    for (final wall in _walls) {
      endpoints.add(Offset(wall.startX, wall.startY));
      endpoints.add(Offset(wall.endX, wall.endY));
    }
    
    // Find closest endpoint
    Offset? closest;
    double closestDist = double.infinity;
    
    for (final endpoint in endpoints) {
      final dist = (point - endpoint).distance;
      if (dist < snapDistance && dist < closestDist) {
        closest = endpoint;
        closestDist = dist;
      }
    }
    
    return closest ?? point;
  }

  /// Snaps the end point to the nearest 5-degree angle from the start point
  /// Supported angles: 0, 5, 10, 15... 85, 90, 95... 175, 180, etc.
  Offset _snapToAngle(Offset start, Offset end) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    
    // Calculate distance
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance < 5) return end; // Too close, don't snap
    
    // Calculate current angle in degrees
    double angle = math.atan2(dy, dx) * 180 / math.pi;
    
    // Snap to nearest 5 degrees
    const snapDegrees = 5.0;
    angle = (angle / snapDegrees).round() * snapDegrees;
    
    // Convert back to radians
    final radians = angle * math.pi / 180;
    
    // Calculate new end point
    final newDx = start.dx + distance * math.cos(radians);
    final newDy = start.dy + distance * math.sin(radians);
    
    return Offset(newDx, newDy);
  }
}

class _WallPainter extends CustomPainter {
  final List<_Wall> walls;
  final bool isDark;
  final Offset? previewStart;
  final Offset? previewEnd;
  final bool showSnapPoints;

  _WallPainter({
    required this.walls,
    required this.isDark,
    this.previewStart,
    this.previewEnd,
    this.showSnapPoints = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw grid (always shown)
    final gridPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)
      ..strokeWidth = 1;

    const gridSize = 50.0;

    // Vertical lines
    for (double x = 0; x <= size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // Horizontal lines
    for (double y = 0; y <= size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    
    // Draw walls
    final wallPaint = Paint()
      ..color = isDark ? Colors.white70 : Colors.black87
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    for (final wall in walls) {
      canvas.drawLine(
        Offset(wall.startX, wall.startY),
        Offset(wall.endX, wall.endY),
        wallPaint,
      );
    }
    
    // Draw snap points when in draw mode
    if (showSnapPoints && walls.isNotEmpty) {
      final snapPaint = Paint()
        ..color = const Color(0xFFF49320).withValues(alpha: 0.5);
      final snapBorderPaint = Paint()
        ..color = const Color(0xFFF49320)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      
      // Collect unique endpoints
      final Set<String> seen = {};
      for (final wall in walls) {
        final startKey = '${wall.startX},${wall.startY}';
        final endKey = '${wall.endX},${wall.endY}';
        
        if (!seen.contains(startKey)) {
          seen.add(startKey);
          canvas.drawCircle(Offset(wall.startX, wall.startY), 8, snapPaint);
          canvas.drawCircle(Offset(wall.startX, wall.startY), 8, snapBorderPaint);
        }
        if (!seen.contains(endKey)) {
          seen.add(endKey);
          canvas.drawCircle(Offset(wall.endX, wall.endY), 8, snapPaint);
          canvas.drawCircle(Offset(wall.endX, wall.endY), 8, snapBorderPaint);
        }
      }
    }

    // Draw preview wall
    if (previewStart != null && previewEnd != null) {
      final previewPaint = Paint()
        ..color = const Color(0xFFF49320).withValues(alpha: 0.7)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(previewStart!, previewEnd!, previewPaint);
      canvas.drawCircle(previewStart!, 6, Paint()..color = const Color(0xFFF49320));
      
      // Show end point indicator
      canvas.drawCircle(previewEnd!, 6, Paint()..color = const Color(0xFFF49320).withValues(alpha: 0.5));
    }
  }

  @override
  bool shouldRepaint(covariant _WallPainter oldDelegate) {
    return walls != oldDelegate.walls ||
        previewStart != oldDelegate.previewStart ||
        previewEnd != oldDelegate.previewEnd ||
        showSnapPoints != oldDelegate.showSnapPoints;
  }
}

/// Live Screen Monitor - Fast screenshot polling for near-real-time viewing
class _LiveScreenMonitor extends StatefulWidget {
  final String computerName;
  final String username;
  final String displayName;

  const _LiveScreenMonitor({
    required this.computerName,
    required this.username,
    required this.displayName,
  });

  @override
  State<_LiveScreenMonitor> createState() => _LiveScreenMonitorState();
}

class _LiveScreenMonitorState extends State<_LiveScreenMonitor> {
  static const String _screenshotUrl = ApiConfig.screenshotGet;
  static const String _commandUrl = ApiConfig.officeMap;

  Uint8List? _currentImage;
  DateTime? _lastUpdate;
  bool _loading = true;
  bool _connected = false;
  String? _error;
  Timer? _pollTimer;
  int _pollIntervalSeconds = 2;
  bool _isPaused = false;
  int _failedAttempts = 0;
  String? _lastFilename;
  int _frameCount = 0;

  @override
  void initState() {
    super.initState();
    _startPolling();
    _requestImmediateCapture();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _loadLatestScreenshot();
    _pollTimer = Timer.periodic(Duration(seconds: _pollIntervalSeconds), (_) {
      if (!_isPaused) {
        _loadLatestScreenshot();
      }
    });
  }

  void _changePollInterval(int seconds) {
    _pollTimer?.cancel();
    setState(() => _pollIntervalSeconds = seconds);
    _pollTimer = Timer.periodic(Duration(seconds: seconds), (_) {
      if (!_isPaused) {
        _loadLatestScreenshot();
      }
    });
  }

  Future<void> _requestImmediateCapture() async {
    try {
      await http.post(
        Uri.parse(_commandUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'remote_command',
          'target_username': widget.username,
          'command': 'capture_now',
          'issued_by': 'LiveView',
        }),
      );
    } catch (e) {
  debugPrint('[OfficeMapScreen] Error: $e');
}
  }

  Future<void> _loadLatestScreenshot() async {
    try {
      final listResponse = await http.get(
        Uri.parse('$_screenshotUrl?computer=${Uri.encodeComponent(widget.computerName)}&list=1'),
      ).timeout(const Duration(seconds: 5));

      if (listResponse.statusCode == 200) {
        final listData = jsonDecode(listResponse.body);
        if (listData['success'] == true) {
          final List<dynamic> screenshots = listData['screenshots'] ?? [];
          
          if (screenshots.isEmpty) {
            setState(() {
              _connected = true;
              _loading = false;
              _error = 'No screenshots available yet';
              _failedAttempts = 0;
            });
            return;
          }

          final latest = screenshots.first;
          final filename = latest['filename'];
          
          if (filename != _lastFilename) {
            final imageResponse = await http.get(
              Uri.parse('$_screenshotUrl?computer=${Uri.encodeComponent(widget.computerName)}&file=$filename'),
            ).timeout(const Duration(seconds: 10));

            if (imageResponse.statusCode == 200) {
              final imageData = jsonDecode(imageResponse.body);
              if (imageData['success'] == true && imageData['screenshot'] != null) {
                final bytes = base64Decode(imageData['screenshot']);
                
                if (mounted) {
                  setState(() {
                    _currentImage = bytes;
                    _lastUpdate = DateTime.tryParse(latest['datetime'] ?? '') ?? DateTime.now();
                    _lastFilename = filename;
                    _loading = false;
                    _connected = true;
                    _error = null;
                    _failedAttempts = 0;
                    _frameCount++;
                  });
                }
              }
            }
          } else {
            if (mounted) {
              setState(() {
                _connected = true;
                _loading = false;
                _failedAttempts = 0;
              });
            }
          }
        } else {
          setState(() {
            _error = listData['error'] ?? 'Failed to load';
            _loading = false;
            _failedAttempts++;
          });
        }
      } else {
        setState(() {
          _failedAttempts++;
          if (_failedAttempts > 3) {
            _connected = false;
            _error = 'Connection lost';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _failedAttempts++;
          if (_failedAttempts > 3) {
            _connected = false;
            _error = 'Connection error';
          }
          _loading = false;
        });
      }
    }
  }

  String _formatTimestamp(DateTime? dt) {
    if (dt == null) return 'Never';
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 5) {
      return 'Just now';
    } else if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ${diff.inSeconds % 60}s ago';
    } else {
      return '${diff.inHours}h ${diff.inMinutes % 60}m ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _connected 
                    ? (_isPaused ? Colors.orange : Colors.green) 
                    : Colors.red,
                boxShadow: [
                  BoxShadow(
                    color: (_connected 
                        ? (_isPaused ? Colors.orange : Colors.green) 
                        : Colors.red).withValues(alpha: 0.5),
                    blurRadius: 6,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.displayName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _isPaused 
                        ? 'PAUSED' 
                        : (_connected ? 'LIVE - ${_pollIntervalSeconds}s refresh' : 'DISCONNECTED'),
                    style: TextStyle(
                      fontSize: 11,
                      color: _isPaused 
                          ? Colors.orange 
                          : (_connected ? Colors.green : Colors.red),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.speed),
            tooltip: 'Refresh Rate',
            onSelected: _changePollInterval,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 1, child: Text('Fastest (1s)')),
              const PopupMenuItem(value: 2, child: Text('Fast (2s)')),
              const PopupMenuItem(value: 3, child: Text('Normal (3s)')),
              const PopupMenuItem(value: 5, child: Text('Slow (5s)')),
            ],
          ),
          IconButton(
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
            tooltip: _isPaused ? 'Resume' : 'Pause',
            onPressed: () => setState(() => _isPaused = !_isPaused),
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt),
            tooltip: 'Capture Now',
            onPressed: () {
              _requestImmediateCapture();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Capture requested'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Now',
            onPressed: _loadLatestScreenshot,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_currentImage != null)
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.memory(
                  _currentImage!,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              ),
            )
          else if (_loading)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text('Connecting...', style: TextStyle(color: Colors.white70)),
                ],
              ),
            )
          else if (_error != null)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.white.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(_error!, style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _loadLatestScreenshot,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                    ),
                  ),
                ],
              ),
            ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.computer, size: 14, color: Colors.white.withValues(alpha: 0.5)),
                  const SizedBox(width: 6),
                  Text(
                    widget.computerName,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                  ),
                  const Spacer(),
                  if (_lastUpdate != null) ...[
                    Icon(Icons.access_time, size: 14, color: Colors.white.withValues(alpha: 0.5)),
                    const SizedBox(width: 4),
                    Text(
                      _formatTimestamp(_lastUpdate),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$_frameCount frames',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_loading && _currentImage != null)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
