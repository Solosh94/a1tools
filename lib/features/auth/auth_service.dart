/// Authentication service for user management.
///
/// Handles user login, registration, logout, and session persistence
/// using secure storage. All methods are static for easy access.
///
/// ## Usage
///
/// ```dart
/// // Login
/// final user = await AuthService.loginRemote(
///   username: 'john',
///   password: 'secret',
/// );
///
/// // Check if logged in
/// final username = await AuthService.getLoggedInUsername();
/// if (username != null) {
///   // User is logged in
/// }
///
/// // Logout
/// await AuthService.logout();
/// ```
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../config/api_config.dart';
import '../../core/services/api_client.dart';

/// Data class representing an authenticated user.
///
/// Contains user profile information retrieved from the server
/// after successful authentication.
class AuthUser {
  final int? id;
  final String username;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String role; // dispatcher | technician | manager | admin | marketing | developer
  final String? birthday; // YYYY-MM-DD format

  const AuthUser({
    required this.username,
    this.id,
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.phone = '',
    this.role = 'dispatcher',
    this.birthday,
  });
}

/// Exception thrown when authentication operations fail.
///
/// Contains a human-readable [message] describing the error.
class AuthException implements Exception {
  /// Human-readable error message.
  final String message;
  const AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}

/// Authentication service providing login, registration, and session management.
///
/// Uses [FlutterSecureStorage] for persistent credential storage and
/// communicates with the remote API for authentication operations.
///
/// All methods are static - no instantiation required.
class AuthService {
  AuthService._();

  static const _storage = FlutterSecureStorage();
  static final ApiClient _api = ApiClient.instance;

  static const _keyUsername = 'a1_tools_username';
  static const _keyUserId = 'a1_tools_user_id';
  static const _keyFirstName = 'a1_tools_first_name';
  static const _keyLastName = 'a1_tools_last_name';
  static const _keyEmail = 'a1_tools_email';
  static const _keyPhone = 'a1_tools_phone';
  static const _keyRole = 'a1_tools_role';
  static const _keyBirthday = 'a1_tools_birthday';
  static const _keyBirthdayPromptDismissed = 'a1_tools_birthday_prompt_dismissed';

  // PHP endpoint you uploaded (user auth & management).
  static const String _authUrl = ApiConfig.auth;

  // Heartbeat endpoint used by the alerts plugin.
  static const String _heartbeatUrl = ApiConfig.alertsHeartbeat;

  // User management endpoint
  static const String _userManagementUrl = ApiConfig.userManagement;

  /// Check if user needs to set their birthday
  static Future<bool> shouldPromptForBirthday() async {
    try {
      final dismissed = await _storage.read(key: _keyBirthdayPromptDismissed);
      if (dismissed == 'true') return false;
      
      final birthday = await _storage.read(key: _keyBirthday);
      return birthday == null || birthday.isEmpty;
    } catch (e) {
      debugPrint('[AuthService] Error: $e');
      return false;
    }
  }

  /// Dismiss birthday prompt for this session
  static Future<void> dismissBirthdayPrompt() async {
    await _storage.write(key: _keyBirthdayPromptDismissed, value: 'true');
  }

  /// Get stored birthday
  static Future<String?> getBirthday() async {
    try {
      return await _storage.read(key: _keyBirthday);
    } catch (e) {
      debugPrint('[AuthService] Error: $e');
      return null;
    }
  }

  /// Save birthday locally
  static Future<void> saveBirthday(String birthday) async {
    await _storage.write(key: _keyBirthday, value: birthday);
  }

  /// Update birthday on server
  static Future<bool> updateBirthday(String birthday) async {
    try {
      final userId = await getLoggedInUserId();
      final username = await getLoggedInUsername();
      if (userId == null || username == null) return false;

      final response = await _api.post(
        _userManagementUrl,
        body: {
          'action': 'update',
          'id': userId,
          'birthday': birthday,
          'requesting_username': username,
        },
      );

      if (response.success) {
        await saveBirthday(birthday);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[AuthService] Error: $e');
      return false;
    }
  }

  /// Returns the currently logged in username, or null if not logged in.
  static Future<String?> getLoggedInUsername() async {
    try {
      final username = await _storage.read(key: _keyUsername);
      if (username == null || username.trim().isEmpty) {
        return null;
      }
      return username;
    } catch (e) {
      debugPrint('[AuthService] Error: $e');
      return null;
    }
  }

  /// Returns the currently logged in user id (from server), or null.
  static Future<int?> getLoggedInUserId() async {
    try {
      final raw = await _storage.read(key: _keyUserId);
      if (raw == null || raw.trim().isEmpty) return null;
      return int.tryParse(raw);
    } catch (e) {
      debugPrint('[AuthService] Error: $e');
      return null;
    }
  }

  /// Returns the stored role (dispatcher|technician|manager|admin|marketing|developer) or null.
  static Future<String?> getLoggedInRole() async {
    try {
      final raw = await _storage.read(key: _keyRole);
      if (raw == null || raw.trim().isEmpty) return null;
      return raw;
    } catch (e) {
      debugPrint('[AuthService] Error: $e');
      return null;
    }
  }

  /// Returns the full stored user, or null if no username.
  static Future<AuthUser?> getLoggedInUser() async {
    try {
      final username = await _storage.read(key: _keyUsername);
      if (username == null || username.trim().isEmpty) return null;

      final idRaw = await _storage.read(key: _keyUserId);
      final firstName = await _storage.read(key: _keyFirstName) ?? '';
      final lastName = await _storage.read(key: _keyLastName) ?? '';
      final email = await _storage.read(key: _keyEmail) ?? '';
      final phone = await _storage.read(key: _keyPhone) ?? '';
      final role = await _storage.read(key: _keyRole) ?? 'dispatcher';
      final birthday = await _storage.read(key: _keyBirthday);

      return AuthUser(
        username: username,
        id: idRaw != null ? int.tryParse(idRaw) : null,
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone,
        role: role,
        birthday: birthday,
      );
    } catch (e) {
      debugPrint('[AuthService] Error: $e');
      return null;
    }
  }

  /// INTERNAL: saves user data locally.
  static Future<void> _saveLocalUser({
    required String username,
    int? userId,
    String firstName = '',
    String lastName = '',
    String email = '',
    String phone = '',
    String role = 'dispatcher',
    String? birthday,
  }) async {
    final clean = username.trim();
    if (clean.isEmpty) return;

    await _storage.write(key: _keyUsername, value: clean);

    if (userId != null) {
      await _storage.write(key: _keyUserId, value: userId.toString());
    } else {
      await _storage.delete(key: _keyUserId);
    }

    await _storage.write(key: _keyFirstName, value: firstName);
    await _storage.write(key: _keyLastName, value: lastName);
    await _storage.write(key: _keyEmail, value: email);
    await _storage.write(key: _keyPhone, value: phone);
    await _storage.write(key: _keyRole, value: role);
    
    if (birthday != null && birthday.isNotEmpty) {
      await _storage.write(key: _keyBirthday, value: birthday);
    }
    // Reset birthday prompt when logging in
    await _storage.delete(key: _keyBirthdayPromptDismissed);
  }

  /// Updates stored profile data locally (after successful server update).
  /// Does not change username, userId, or role.
  static Future<void> updateStoredProfile({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
  }) async {
    await _storage.write(key: _keyFirstName, value: firstName);
    await _storage.write(key: _keyLastName, value: lastName);
    await _storage.write(key: _keyEmail, value: email);
    await _storage.write(key: _keyPhone, value: phone);
  }

  /// OLD behavior (kept so current HomeScreen keeps compiling):
  /// Saves the username as the logged-in user *locally only*.
  static Future<void> login(String username) async {
    await _saveLocalUser(username: username, userId: null);
  }

  /// Clears the logged-in user.
  /// Uses Future.wait to ensure all deletions complete atomically.
  static Future<void> logout() async {
    try {
      await Future.wait([
        _storage.delete(key: _keyUsername),
        _storage.delete(key: _keyUserId),
        _storage.delete(key: _keyFirstName),
        _storage.delete(key: _keyLastName),
        _storage.delete(key: _keyEmail),
        _storage.delete(key: _keyPhone),
        _storage.delete(key: _keyRole),
        _storage.delete(key: _keyBirthday),
        _storage.delete(key: _keyBirthdayPromptDismissed),
      ]);
    } catch (e) {
      debugPrint('[AuthService] Logout error: $e');
      // Even if some deletions fail, try to clear remaining keys
      // by attempting a second pass with individual error handling
      final keys = [
        _keyUsername,
        _keyUserId,
        _keyFirstName,
        _keyLastName,
        _keyEmail,
        _keyPhone,
        _keyRole,
        _keyBirthday,
        _keyBirthdayPromptDismissed,
      ];
      for (final key in keys) {
        try {
          await _storage.delete(key: key);
        } catch (e) {
          debugPrint('[AuthService] Failed to delete $key: $e');
        }
      }
    }
  }

  /// Registers a new user in the remote API (public endpoint), then saves locally.
  /// Throws [AuthException] on error.
  ///
  /// Note: server will enforce that public registration can only create
  /// dispatcher/technician roles.
  static Future<AuthUser> registerRemote({
    required String username,
    required String password,
    String firstName = '',
    String lastName = '',
    String email = '',
    String phone = '',
    String role = 'dispatcher',
    String? birthday,
  }) async {
    final Map<String, dynamic> body = {
      'action': 'register',
      'username': username.trim(),
      'password': password,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'role': role.toLowerCase(),
    };

    if (birthday != null && birthday.isNotEmpty) {
      body['birthday'] = birthday;
    }

    final response = await _api.post(_authUrl, body: body);

    if (!response.success) {
      throw AuthException(response.message ?? 'Registration failed');
    }

    final json = response.rawJson ?? {};
    final String name = (json['username'] ?? username).toString();
    final int? id = json['user_id'] is int
        ? json['user_id'] as int
        : int.tryParse(json['user_id']?.toString() ?? '');

    final String fName = (json['first_name'] ?? firstName).toString();
    final String lName = (json['last_name'] ?? lastName).toString();
    final String mail = (json['email'] ?? email).toString();
    final String ph = (json['phone'] ?? phone).toString();
    final String roleResp =
        (json['role'] ?? role).toString().toLowerCase();
    final String? bday = json['birthday']?.toString();

    await _saveLocalUser(
      username: name,
      userId: id,
      firstName: fName,
      lastName: lName,
      email: mail,
      phone: ph,
      role: roleResp,
      birthday: bday,
    );

    // Fire one heartbeat after registration.
    await sendHeartbeat(name);

    return AuthUser(
      username: name,
      id: id,
      firstName: fName,
      lastName: lName,
      email: mail,
      phone: ph,
      role: roleResp,
      birthday: bday,
    );
  }

  /// Logs in an existing user via the remote API, then saves locally.
  /// Throws [AuthException] on error.
  static Future<AuthUser> loginRemote({
    required String username,
    required String password,
  }) async {
    final response = await _api.post(
      _authUrl,
      body: {
        'action': 'login',
        'username': username.trim(),
        'password': password,
      },
    );

    if (!response.success) {
      throw AuthException(response.message ?? 'Login failed');
    }

    final json = response.rawJson ?? {};
    final String name = (json['username'] ?? username).toString();
    final int? id = json['user_id'] is int
        ? json['user_id'] as int
        : int.tryParse(json['user_id']?.toString() ?? '');

    final String fName = (json['first_name'] ?? '').toString();
    final String lName = (json['last_name'] ?? '').toString();
    final String mail = (json['email'] ?? '').toString();
    final String ph = (json['phone'] ?? '').toString();
    final String role =
        (json['role'] ?? 'dispatcher').toString().toLowerCase();
    final String? birthday = json['birthday']?.toString();

    await _saveLocalUser(
      username: name,
      userId: id,
      firstName: fName,
      lastName: lName,
      email: mail,
      phone: ph,
      role: role,
      birthday: birthday,
    );

    // Fire one heartbeat after login.
    await sendHeartbeat(name);

    return AuthUser(
      username: name,
      id: id,
      firstName: fName,
      lastName: lName,
      email: mail,
      phone: ph,
      role: role,
      birthday: birthday,
    );
  }

  /// Password reset URL
  static const String _passwordResetUrl = ApiConfig.passwordReset;

  /// Request a password reset email
  /// Returns true if the request was successful (email sent if exists)
  static Future<String> requestPasswordReset(String email) async {
    final response = await _api.post(
      _passwordResetUrl,
      body: {
        'action': 'request',
        'email': email.trim(),
      },
    );

    if (response.success) {
      return response.rawJson?['message'] ?? 'If the email exists, a reset link has been sent';
    } else {
      throw AuthException(response.message ?? 'Failed to send reset email');
    }
  }

  /// Admin-only delete user endpoint.
  /// Uses action=delete_user on the PHP side.
  static Future<void> deleteUserRemote({
    required String adminUsername,
    required String adminPassword,
    required int deleteUserId,
  }) async {
    final response = await _api.post(
      _authUrl,
      body: {
        'action': 'delete_user',
        'admin_username': adminUsername.trim(),
        'admin_password': adminPassword,
        'delete_user_id': deleteUserId,
      },
    );

    if (!response.success) {
      throw AuthException(response.message ?? 'Delete failed');
    }
  }

  /// Admin-only user creation (can create manager / marketing / admin).
  /// Uses action=admin_create_user on the PHP side.
  ///
  /// Does NOT change the currently logged-in user; just returns the created user.
  static Future<AuthUser> adminCreateUserRemote({
    required String adminUsername,
    required String adminPassword,
    required String username,
    required String password,
    String firstName = '',
    String lastName = '',
    String email = '',
    String phone = '',
    String role =
        'dispatcher', // dispatcher | technician | manager | marketing | admin | developer (server-enforced)
  }) async {
    final response = await _api.post(
      _authUrl,
      body: {
        'action': 'admin_create_user',
        'admin_username': adminUsername.trim(),
        'admin_password': adminPassword,
        'username': username.trim(),
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'phone': phone,
        'role': role.toLowerCase(),
      },
    );

    if (!response.success) {
      throw AuthException(response.message ?? 'Admin create user failed');
    }

    final json = response.rawJson ?? {};
    final String name = (json['username'] ?? username).toString();
    final int? id = json['user_id'] is int
        ? json['user_id'] as int
        : int.tryParse(json['user_id']?.toString() ?? '');

    final String fName = (json['first_name'] ?? firstName).toString();
    final String lName = (json['last_name'] ?? lastName).toString();
    final String mail = (json['email'] ?? email).toString();
    final String ph = (json['phone'] ?? phone).toString();
    final String roleResp =
        (json['role'] ?? role).toString().toLowerCase();

    return AuthUser(
      username: name,
      id: id,
      firstName: fName,
      lastName: lName,
      email: mail,
      phone: ph,
      role: roleResp,
    );
  }

  /// Best-effort heartbeat: updates a1tools_presence.last_seen on the backend.
  /// This should NOT throw in normal use — errors are swallowed.
  static Future<void> sendHeartbeat(String username) async {
    final trimmed = username.trim();
    if (trimmed.isEmpty) return;

    try {
      await _api.post(
        _heartbeatUrl,
        body: {'username': trimmed},
      );
      // We ignore response body; best-effort.
    } catch (e) {
      // Ignore errors — presence is not critical to app flow.
      debugPrint('[AuthService] Error: $e');
    }
  }
}
