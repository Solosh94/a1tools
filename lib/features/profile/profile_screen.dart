// File: lib/profile_screen.dart
//
// User profile screen for viewing and editing personal details
// and uploading a profile picture.

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../app_theme.dart';
import '../../config/api_config.dart';
import '../auth/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  final AuthUser user;
  final VoidCallback? onProfileUpdated;

  const ProfileScreen({
    super.key,
    required this.user,
    this.onProfileUpdated,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _accent = AppColors.accent;

  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;
  bool _loadingPicture = true;
  bool _savingPicture = false;
  String? _error;
  String? _successMessage;
  Uint8List? _profilePicture;
  bool _showPasswordFields = false;
  DateTime? _selectedBirthday;

  // Track which fields are missing
  bool get _isPhoneMissing => _phoneController.text.trim().isEmpty;
  bool get _isBirthdayMissing => _selectedBirthday == null;
  bool get _hasIncompleteProfile => _isPhoneMissing || _isBirthdayMissing;

  @override
  void initState() {
    super.initState();
    _firstNameController.text = widget.user.firstName;
    _lastNameController.text = widget.user.lastName;
    _emailController.text = widget.user.email;
    _phoneController.text = widget.user.phone;
    
    // Parse birthday if exists
    if (widget.user.birthday != null && widget.user.birthday!.isNotEmpty) {
      _selectedBirthday = DateTime.tryParse(widget.user.birthday!);
    }
    
    _loadProfilePicture();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _formatBirthday(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatBirthdayForApi(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthday ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      helpText: 'Select your birthday',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: _accent,
              brightness: Theme.of(context).brightness,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedBirthday = picked);
    }
  }

  Future<void> _loadProfilePicture() async {
    setState(() => _loadingPicture = true);

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.profilePicture}?username=${Uri.encodeComponent(widget.user.username)}'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['picture'] != null) {
          setState(() {
            _profilePicture = base64Decode(data['picture']);
          });
        }
      }
    } catch (e) {
      debugPrint('[Profile] Error loading picture: $e');
    } finally {
      if (mounted) setState(() => _loadingPicture = false);
    }
  }

  Future<void> _pickAndUploadPicture() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() => _savingPicture = true);

      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse(ApiConfig.profilePicture),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': widget.user.username,
          'picture': base64Image,
          'filename': image.name,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _profilePicture = bytes;
            _successMessage = 'Profile picture updated!';
          });
          _clearMessageAfterDelay();
        } else {
          setState(() => _error = data['error'] ?? 'Failed to upload picture');
          _clearMessageAfterDelay();
        }
      } else {
        setState(() => _error = 'Server error: ${response.statusCode}');
        _clearMessageAfterDelay();
      }
    } catch (e) {
      setState(() => _error = 'Error uploading picture: $e');
      _clearMessageAfterDelay();
    } finally {
      if (mounted) setState(() => _savingPicture = false);
    }
  }

  Future<void> _removePicture() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Picture'),
        content: const Text('Are you sure you want to remove your profile picture?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _savingPicture = true);

    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.profilePicture}?username=${Uri.encodeComponent(widget.user.username)}'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _profilePicture = null;
            _successMessage = 'Profile picture removed';
          });
          _clearMessageAfterDelay();
        }
      }
    } catch (e) {
      setState(() => _error = 'Error removing picture: $e');
      _clearMessageAfterDelay();
    } finally {
      if (mounted) setState(() => _savingPicture = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    // Check password fields if changing password
    if (_showPasswordFields) {
      if (_currentPasswordController.text.isEmpty) {
        setState(() => _error = 'Current password is required');
        _clearMessageAfterDelay();
        return;
      }
      if (_newPasswordController.text.isEmpty) {
        setState(() => _error = 'New password is required');
        _clearMessageAfterDelay();
        return;
      }
      if (_newPasswordController.text != _confirmPasswordController.text) {
        setState(() => _error = 'New passwords do not match');
        _clearMessageAfterDelay();
        return;
      }
      if (_newPasswordController.text.length < 6) {
        setState(() => _error = 'Password must be at least 6 characters');
        _clearMessageAfterDelay();
        return;
      }
    }

    setState(() {
      _loading = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final Map<String, dynamic> body = {
        'action': 'update_profile',
        'username': widget.user.username,
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
      };

      // Add birthday if set
      if (_selectedBirthday != null) {
        body['birthday'] = _formatBirthdayForApi(_selectedBirthday!);
      }

      if (_showPasswordFields && _newPasswordController.text.isNotEmpty) {
        body['current_password'] = _currentPasswordController.text;
        body['new_password'] = _newPasswordController.text;
      }

      final response = await http.post(
        Uri.parse(ApiConfig.auth),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        // Update local storage with new values
        await AuthService.updateStoredProfile(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
        );
        
        // Save birthday if set
        if (_selectedBirthday != null) {
          await AuthService.saveBirthday(_formatBirthdayForApi(_selectedBirthday!));
        }

        setState(() {
          _successMessage = 'Profile updated successfully!';
          _showPasswordFields = false;
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        });

        widget.onProfileUpdated?.call();
        _clearMessageAfterDelay();
      } else {
        setState(() => _error = data['error'] ?? 'Failed to update profile');
        _clearMessageAfterDelay();
      }
    } catch (e) {
      setState(() => _error = 'Connection error: $e');
      _clearMessageAfterDelay();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clearMessageAfterDelay() {
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _error = null;
          _successMessage = null;
        });
      }
    });
  }

  String _formatRole(String role) {
    switch (role.toLowerCase()) {
      case 'developer':
        return 'Developer';
      case 'administrator':
        return 'Administrator';
      case 'management':
        return 'Management';
      case 'dispatcher':
        return 'Dispatcher';
      case 'remote_dispatcher':
        return 'Remote Dispatcher';
      case 'technician':
        return 'Technician';
      case 'marketing':
        return 'Marketing';
      default:
        return role[0].toUpperCase() + role.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Image.asset(
          isDark ? 'assets/images/logo-white.png' : 'assets/images/logo.png',
          height: 40,
          fit: BoxFit.contain,
        ),
      ),
      backgroundColor: bgColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              children: [
                // Profile Picture Section
                Card(
                  color: cardColor,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            // Avatar
                            _loadingPicture
                                ? const CircleAvatar(
                                    radius: 60,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : CircleAvatar(
                                    radius: 60,
                                    backgroundColor: _accent.withValues(alpha: 0.2),
                                    backgroundImage: _profilePicture != null
                                        ? MemoryImage(_profilePicture!)
                                        : null,
                                    child: _profilePicture == null
                                        ? Text(
                                            widget.user.username[0].toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 48,
                                              fontWeight: FontWeight.bold,
                                              color: _accent,
                                            ),
                                          )
                                        : null,
                                  ),

                            // Edit button
                            if (!_loadingPicture)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: GestureDetector(
                                  onTap: _savingPicture ? null : _pickAndUploadPicture,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _accent,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: cardColor, width: 2),
                                    ),
                                    child: _savingPicture
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.camera_alt,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Username (read-only)
                        Text(
                          widget.user.username,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 4),

                        // Role badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _formatRole(widget.user.role),
                            style: const TextStyle(
                              color: _accent,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),

                        // Remove picture button
                        if (_profilePicture != null && !_loadingPicture) ...[
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: _savingPicture ? null : _removePicture,
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Remove Picture'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Messages
                if (_error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (_successMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _successMessage!,
                            style: const TextStyle(color: Colors.green),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Profile incomplete warning banner
                if (_hasIncompleteProfile)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Profile Incomplete',
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please complete the following fields:',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (_isPhoneMissing)
                          Padding(
                            padding: const EdgeInsets.only(left: 28),
                            child: Row(
                              children: [
                                Icon(Icons.circle, size: 6, color: Colors.orange.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'Phone number',
                                  style: TextStyle(color: Colors.orange.shade700, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        if (_isBirthdayMissing)
                          Padding(
                            padding: const EdgeInsets.only(left: 28),
                            child: Row(
                              children: [
                                Icon(Icons.circle, size: 6, color: Colors.orange.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'Birthday',
                                  style: TextStyle(color: Colors.orange.shade700, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                // Profile Details Form
                Card(
                  color: cardColor,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Personal Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // First Name
                          TextFormField(
                            controller: _firstNameController,
                            decoration: const InputDecoration(
                              labelText: 'First Name',
                              prefixIcon: Icon(Icons.person_outline),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'First name is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Last Name
                          TextFormField(
                            controller: _lastNameController,
                            decoration: const InputDecoration(
                              labelText: 'Last Name',
                              prefixIcon: Icon(Icons.person_outline),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Last name is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Email
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Email is required';
                              }
                              if (!value.contains('@') || !value.contains('.')) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Phone
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: 'Phone',
                              prefixIcon: const Icon(Icons.phone_outlined),
                              border: const OutlineInputBorder(),
                              // Highlight missing field
                              enabledBorder: _isPhoneMissing
                                  ? OutlineInputBorder(
                                      borderSide: BorderSide(color: Colors.orange.shade400, width: 2),
                                    )
                                  : null,
                              focusedBorder: _isPhoneMissing
                                  ? OutlineInputBorder(
                                      borderSide: BorderSide(color: Colors.orange.shade600, width: 2),
                                    )
                                  : null,
                              suffixIcon: _isPhoneMissing
                                  ? Tooltip(
                                      message: 'Required field',
                                      child: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade600, size: 20),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Birthday
                          InkWell(
                            onTap: _pickBirthday,
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Birthday',
                                prefixIcon: const Icon(Icons.cake_outlined),
                                border: const OutlineInputBorder(),
                                // Highlight missing field
                                enabledBorder: _isBirthdayMissing
                                    ? OutlineInputBorder(
                                        borderSide: BorderSide(color: Colors.orange.shade400, width: 2),
                                      )
                                    : null,
                                focusedBorder: _isBirthdayMissing
                                    ? OutlineInputBorder(
                                        borderSide: BorderSide(color: Colors.orange.shade600, width: 2),
                                      )
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _selectedBirthday != null
                                        ? _formatBirthday(_selectedBirthday!)
                                        : 'Select your birthday',
                                    style: TextStyle(
                                      color: _selectedBirthday != null
                                          ? null
                                          : Theme.of(context).hintColor,
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_isBirthdayMissing)
                                        Padding(
                                          padding: const EdgeInsets.only(right: 8),
                                          child: Tooltip(
                                            message: 'Required field',
                                            child: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade600, size: 20),
                                          ),
                                        ),
                                      if (_selectedBirthday != null)
                                        IconButton(
                                          icon: const Icon(Icons.clear, size: 18),
                                          onPressed: () {
                                            setState(() => _selectedBirthday = null);
                                          },
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Change Password Toggle
                          InkWell(
                            onTap: () {
                              setState(() {
                                _showPasswordFields = !_showPasswordFields;
                                if (!_showPasswordFields) {
                                  _currentPasswordController.clear();
                                  _newPasswordController.clear();
                                  _confirmPasswordController.clear();
                                }
                              });
                            },
                            child: Row(
                              children: [
                                Icon(
                                  _showPasswordFields
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: _accent,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Change Password',
                                  style: TextStyle(
                                    color: _accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Password Fields
                          if (_showPasswordFields) ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _currentPasswordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Current Password',
                                prefixIcon: Icon(Icons.lock_outline),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _newPasswordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'New Password',
                                prefixIcon: Icon(Icons.lock_outline),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Confirm New Password',
                                prefixIcon: Icon(Icons.lock_outline),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),

                          // Save Button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _saveProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Save Changes',
                                      style: TextStyle(
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

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
