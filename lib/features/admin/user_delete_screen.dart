import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../../app_theme.dart';

class UserDeleteScreen extends StatefulWidget {
  const UserDeleteScreen({super.key});

  @override
  State<UserDeleteScreen> createState() => _UserDeleteScreenState();
}

class _UserDeleteScreenState extends State<UserDeleteScreen> {
  AuthUser? _currentUser;
  bool _loading = true;

  bool _creating = false;
  bool _deleting = false;

  static const Color _accent = AppColors.accent;

  // Admin password for both operations
  final TextEditingController _adminPasswordController =
      TextEditingController();

  // Delete user fields
  final TextEditingController _userIdController = TextEditingController();

  // Create user fields
  final TextEditingController _newUsernameController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _newRepeatPasswordController =
      TextEditingController();
  final TextEditingController _newFirstNameController = TextEditingController();
  final TextEditingController _newLastNameController = TextEditingController();
  final TextEditingController _newEmailController = TextEditingController();
  final TextEditingController _newPhoneController = TextEditingController();

  // dispatcher | technician | manager | marketing
  String _newSelectedRole = 'dispatcher';

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _adminPasswordController.dispose();
    _userIdController.dispose();
    _newUsernameController.dispose();
    _newPasswordController.dispose();
    _newRepeatPasswordController.dispose();
    _newFirstNameController.dispose();
    _newLastNameController.dispose();
    _newEmailController.dispose();
    _newPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final user = await AuthService.getLoggedInUser();
    if (!mounted) return;
    setState(() {
      _currentUser = user;
      _loading = false;
    });
  }

  Future<void> _deleteUser() async {
    if (_deleting) return;
    final user = _currentUser;
    if (user == null || (user.role != 'administrator' && user.role != 'developer')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Administrator rights required')),
      );
      return;
    }

    final adminPassword = _adminPasswordController.text;
    final userIdText = _userIdController.text.trim();

    if (adminPassword.isEmpty || userIdText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password and User ID are required')),
      );
      return;
    }

    final id = int.tryParse(userIdText);
    if (id == null || id <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid User ID')),
      );
      return;
    }

    setState(() {
      _deleting = true;
    });

    try {
      await AuthService.deleteUserRemote(
        adminUsername: user.username,
        adminPassword: adminPassword,
        deleteUserId: id,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User $id deleted successfully')),
      );
      _userIdController.clear();
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      debugPrint('[UserDeleteScreen] Failed to delete user: \$e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete user')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _deleting = false;
        });
      }
    }
  }

  Future<void> _createUser() async {
    if (_creating) return;
    final user = _currentUser;
    if (user == null || (user.role != 'administrator' && user.role != 'developer')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Administrator rights required')),
      );
      return;
    }

    final adminPassword = _adminPasswordController.text;
    if (adminPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin password is required')),
      );
      return;
    }

    final username = _newUsernameController.text.trim();
    final password = _newPasswordController.text;
    final repeatPassword = _newRepeatPasswordController.text;
    final firstName = _newFirstNameController.text.trim();
    final lastName = _newLastNameController.text.trim();
    final email = _newEmailController.text.trim();
    final phone = _newPhoneController.text.trim();
    final role = _newSelectedRole;

    if (username.isEmpty || password.isEmpty || repeatPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username and passwords are required')),
      );
      return;
    }

    if (password != repeatPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    if (username.length < 3 || username.length > 64) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Username must be between 3 and 64 characters')),
      );
      return;
    }

    if (password.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Password must be at least 4 characters')),
      );
      return;
    }

    setState(() {
      _creating = true;
    });

    try {
      final created = await AuthService.adminCreateUserRemote(
        adminUsername: user.username,
        adminPassword: adminPassword,
        username: username,
        password: password,
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone,
        role: role,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'User created: ${created.username} (role: ${created.role})',
          ),
        ),
      );

      // Clear new user fields (keep admin password)
      _newUsernameController.clear();
      _newPasswordController.clear();
      _newRepeatPasswordController.clear();
      _newFirstNameController.clear();
      _newLastNameController.clear();
      _newEmailController.clear();
      _newPhoneController.clear();
      setState(() {
        _newSelectedRole = 'dispatcher';
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      debugPrint('[UserDeleteScreen] Failed to create user: \$e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create user')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _creating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('User Management'),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'You must be logged in as an admin to manage users.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textColor),
            ),
          ),
        ),
      );
    }

    if (_currentUser!.role != 'administrator' && _currentUser!.role != 'developer') {
      return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Image.asset(
            isDark ? 'assets/images/logo-white.png' : 'assets/images/logo.png',
            height: 40,
            fit: BoxFit.contain,
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Access denied.\n\n'
              'Your role is "${_currentUser!.role}". Only admin and developer accounts can manage users.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textColor),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Image.asset(
          isDark ? 'assets/images/logo-white.png' : 'assets/images/logo.png',
          height: 40,
          fit: BoxFit.contain,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Logged in as: ${_currentUser!.username} (admin)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Enter your admin password to perform user operations.',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _adminPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'Admin Password',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 24),

                  // CREATE USER CARD
                  Card(
                    elevation: 1,
                    color: cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Create User',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _newUsernameController,
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _newPasswordController,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              border: OutlineInputBorder(),
                            ),
                            obscureText: true,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _newRepeatPasswordController,
                            decoration: const InputDecoration(
                              labelText: 'Repeat Password',
                              border: OutlineInputBorder(),
                            ),
                            obscureText: true,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _newFirstNameController,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _newLastNameController,
                            decoration: const InputDecoration(
                              labelText: 'Last Name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _newEmailController,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _newPhoneController,
                            decoration: const InputDecoration(
                              labelText: 'Phone Number',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 12),

                          // Role dropdown
                          InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Role',
                              border: OutlineInputBorder(),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _newSelectedRole,
                                dropdownColor: cardColor,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'dispatcher',
                                    child: Text('Dispatcher'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'remote_dispatcher',
                                    child: Text('Remote Dispatcher'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'technician',
                                    child: Text('Technician'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'management',
                                    child: Text('Management'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'marketing',
                                    child: Text('Marketing'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'administrator',
                                    child: Text('Administrator'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'developer',
                                    child: Text('Developer'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() {
                                    _newSelectedRole = value;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accent,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: _creating ? null : _createUser,
                              child: _creating
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.black,
                                        ),
                                      ),
                                    )
                                  : const Text(
                                      'Create User',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // DELETE USER CARD
                  Card(
                    elevation: 1,
                    color: cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Delete User',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Enter the ID of the user you want to delete.\n'
                            'WARNING: This action is permanent.',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _userIdController,
                            decoration: const InputDecoration(
                              labelText: 'User ID to delete',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accent,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: _deleting ? null : _deleteUser,
                              child: _deleting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.black,
                                        ),
                                      ),
                                    )
                                  : const Text(
                                      'Delete User',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}