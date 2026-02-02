// lib/workiz_integration_screen.dart
// Admin screen for managing Workiz location credentials
// Uses official Workiz API tokens (permanent, no expiration)

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../app_theme.dart';
import '../../config/api_config.dart';
import 'workiz_webview_login.dart';

class WorkizIntegrationScreen extends StatefulWidget {
  final String username;
  final String role;

  const WorkizIntegrationScreen({
    super.key,
    required this.username,
    required this.role,
  });

  @override
  State<WorkizIntegrationScreen> createState() => _WorkizIntegrationScreenState();
}

class _WorkizIntegrationScreenState extends State<WorkizIntegrationScreen> {
  static const String _baseUrl = ApiConfig.workizLocations;
  static const Color _accent = AppColors.accent;

  List<WorkizLocation> _locations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl?action=list_locations&requesting_role=${widget.role}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _locations = (data['locations'] as List)
                .map((l) => WorkizLocation.fromJson(l))
                .toList();
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = data['error'] ?? 'Failed to load locations';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = 'HTTP ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workiz Integration'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLocations,
            tooltip: 'Refresh',
          ),
        ],
      ),
      backgroundColor: bgColor,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddLocationDialog(),
        backgroundColor: _accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadLocations,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _locations.isEmpty
                  ? _buildEmptyState()
                  : _buildLocationsList(cardColor),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No Workiz locations configured',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add a location',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationsList(Color cardColor) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _locations.length,
      itemBuilder: (context, index) {
        final location = _locations[index];
        return _buildLocationCard(location, cardColor);
      },
    );
  }

  Widget _buildLocationCard(WorkizLocation location, Color cardColor) {
    final statusColor = location.status == 'working'
        ? Colors.green
        : location.status == 'auth_error'
            ? Colors.red
            : Colors.orange;

    final statusText = location.status == 'working'
        ? 'Connected'
        : location.status == 'auth_error'
            ? 'Auth Error'
            : 'Not Configured';

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.location_on, color: _accent, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        location.locationName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Code: ${location.locationCode}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        location.status == 'working'
                            ? Icons.check_circle
                            : location.status == 'auth_error'
                                ? Icons.error
                                : Icons.warning,
                        size: 14,
                        color: statusColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Credentials info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildInfoRow(
                    'API Token',
                    location.hasApiToken ? 'Configured (for jobs)' : 'Not configured',
                  ),
                  const SizedBox(height: 6),
                  _buildInfoRow(
                    'Session',
                    location.hasSession ? 'Configured (for invoice items)' : 'Not configured',
                  ),
                  if (location.hasApiToken && location.hasApiSecret) ...[
                    const SizedBox(height: 6),
                    _buildInfoRow('API Secret', 'Configured'),
                  ],
                  if (location.workizAccountId != null && location.workizAccountId!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _buildInfoRow('Account ID', location.workizAccountId!),
                  ],
                  if (location.userCount > 0) ...[
                    const SizedBox(height: 6),
                    _buildInfoRow('Users', '${location.userCount} assigned'),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Session credentials info (for invoice items)
            if (location.hasApiToken && !location.hasSession) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Invoice Items Sync Unavailable',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'API tokens can fetch jobs, but syncing invoice items requires a Workiz session login.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showWorkizLoginDialog(location),
                      style: TextButton.styleFrom(foregroundColor: Colors.orange),
                      child: const Text('Login'),
                    ),
                  ],
                ),
              ),
            ],
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // API Credentials button
                TextButton.icon(
                  onPressed: () => _showLoginDialog(location),
                  icon: const Icon(Icons.key, size: 18),
                  label: Text(location.hasApiToken ? 'Update Credentials' : 'Set API Credentials'),
                  style: TextButton.styleFrom(foregroundColor: _accent),
                ),
                // Session Login button (if has API token but not session)
                if (location.hasApiToken && !location.hasSession) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _showWorkizLoginDialog(location),
                    icon: const Icon(Icons.login, size: 18),
                    label: const Text('Login for Items'),
                    style: TextButton.styleFrom(foregroundColor: Colors.orange),
                  ),
                ],
                const SizedBox(width: 8),
                // Test button
                TextButton.icon(
                  onPressed: location.status != 'not_configured'
                      ? () => _testLocation(location)
                      : null,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Test'),
                  style: TextButton.styleFrom(foregroundColor: Colors.blue),
                ),
                const SizedBox(width: 8),
                // Delete button
                TextButton.icon(
                  onPressed: () => _deleteLocation(location),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Future<void> _showAddLocationDialog() async {
    final nameController = TextEditingController();
    final codeController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Workiz Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Location Name',
                hintText: 'e.g., Connecticut',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Location Code',
                hintText: 'e.g., CT',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _accent),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.isNotEmpty && codeController.text.isNotEmpty) {
      await _addLocation(nameController.text, codeController.text.toUpperCase());
    }
  }

  Future<void> _addLocation(String name, String code) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?action=save_location&requesting_role=${widget.role}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'location_name': name,
          'location_code': code,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _loadLocations();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location added'), backgroundColor: Colors.green),
            );
          }
        } else {
          throw Exception(data['error'] ?? 'Failed to add location');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showLoginDialog(WorkizLocation location) async {
    // API Token is the recommended method - show API token dialog directly
    await _showApiTokenDialog(location);
  }

  Future<void> _showApiTokenDialog(WorkizLocation location) async {
    final tokenController = TextEditingController();
    final secretController = TextEditingController();
    bool isLoading = false;
    String? errorMessage;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('API Credentials - ${location.locationName}'),
          content: SizedBox(
            width: 550,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.key, color: Colors.blue, size: 18),
                            SizedBox(width: 8),
                            Text('Get your Workiz API Credentials:', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        SizedBox(height: 10),
                        Text('1. Login to Workiz at app.workiz.com'),
                        SizedBox(height: 4),
                        Text('2. Go to Settings ? Integrations ? API'),
                        SizedBox(height: 4),
                        Text('3. Copy your API Token (required)'),
                        SizedBox(height: 4),
                        Text('4. Copy your API Secret (optional - for future features)'),
                        SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 16),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'API tokens are permanent and work from any location/device',
                                style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: tokenController,
                    decoration: const InputDecoration(
                      labelText: 'Workiz API Token (required)',
                      hintText: 'Paste your API token here...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.vpn_key),
                    ),
                    maxLines: 1,
                    enabled: !isLoading,
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: secretController,
                    decoration: const InputDecoration(
                      labelText: 'Workiz API Secret (optional)',
                      hintText: 'Paste your API secret here...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                      helperText: 'Required for future write operations (estimates, etc.)',
                    ),
                    maxLines: 1,
                    enabled: !isLoading,
                    obscureText: true,
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                        ],
                      ),
                    ),
                  ],
                  if (isLoading) ...[
                    const SizedBox(height: 16),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Validating API token...'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final token = tokenController.text.trim();
                      if (token.isEmpty) {
                        setDialogState(() => errorMessage = 'Please enter your API token');
                        return;
                      }

                      setDialogState(() {
                        isLoading = true;
                        errorMessage = null;
                      });

                      try {
                        // Save and validate the API token (and optional secret)
                        final secret = secretController.text.trim();
                        final response = await http.post(
                          Uri.parse('$_baseUrl?action=save_api_token&requesting_role=${widget.role}'),
                          headers: {'Content-Type': 'application/json'},
                          body: json.encode({
                            'location_id': location.id,
                            'api_token': token,
                            if (secret.isNotEmpty) 'api_secret': secret,
                          }),
                        ).timeout(const Duration(seconds: 20));

                        final data = json.decode(response.body);
                        if (data['success'] == true) {
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          _loadLocations();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('API token saved for ${location.locationName}'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          setDialogState(() {
                            isLoading = false;
                            errorMessage = data['error'] ?? 'Failed to validate API token';
                          });
                        }
                      } catch (e) {
                        setDialogState(() {
                          isLoading = false;
                          errorMessage = e.toString();
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: _accent),
              child: const Text('Save & Validate', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  /// Show dialog to login to Workiz and extract session credentials
  /// This is needed for invoice items sync (unofficial API)
  /// On Windows, uses WebView to support 2FA. On other platforms, uses form dialog.
  Future<void> _showWorkizLoginDialog(WorkizLocation location) async {
    // On Windows, use WebView for better 2FA support
    if (Platform.isWindows) {
      final result = await Navigator.push<WorkizLoginResult>(
        context,
        MaterialPageRoute(
          builder: (context) => WorkizWebViewLoginScreen(
            locationId: location.id,
            locationName: location.locationName,
            userRole: widget.role,
          ),
        ),
      );

      if (result != null && result.success) {
        _loadLocations();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Session established for ${location.locationName}. Invoice items sync is now available!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else if (result != null && result.error != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Login failed: ${result.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
      return;
    }

    // Fallback: Form-based login for non-Windows platforms
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isLoading = false;
    String? errorMessage;
    bool obscurePassword = true;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Login to Workiz - ${location.locationName}'),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue, size: 18),
                            SizedBox(width: 8),
                            Text('Why is this needed?', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Invoice items can only be fetched using Workiz\'s internal API, '
                          'which requires a login session. This is separate from the API token.\n\n'
                          'Your credentials are only used to establish a session and are not stored.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Workiz Email',
                      hintText: 'Your Workiz login email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText: 'Workiz Password',
                      hintText: 'Your Workiz login password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                      ),
                    ),
                    obscureText: obscurePassword,
                    enabled: !isLoading,
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                        ],
                      ),
                    ),
                  ],
                  if (isLoading) ...[
                    const SizedBox(height: 16),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Logging in to Workiz...'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final email = emailController.text.trim();
                      final password = passwordController.text;

                      if (email.isEmpty || password.isEmpty) {
                        setDialogState(() => errorMessage = 'Please enter email and password');
                        return;
                      }

                      setDialogState(() {
                        isLoading = true;
                        errorMessage = null;
                      });

                      try {
                        final response = await http.post(
                          Uri.parse('$_baseUrl?action=login_workiz&requesting_role=${widget.role}'),
                          headers: {'Content-Type': 'application/json'},
                          body: json.encode({
                            'location_id': location.id,
                            'email': email,
                            'password': password,
                          }),
                        ).timeout(const Duration(seconds: 45));

                        final data = json.decode(response.body);
                        if (data['success'] == true) {
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          _loadLocations();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Session established for ${location.locationName}. Invoice items sync is now available!'),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        } else {
                          setDialogState(() {
                            isLoading = false;
                            errorMessage = data['error'] ?? 'Login failed';
                          });
                        }
                      } catch (e) {
                        setDialogState(() {
                          isLoading = false;
                          errorMessage = 'Error: $e';
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: _accent),
              child: const Text('Login', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testLocation(WorkizLocation location) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Testing connection...'),
          ],
        ),
      ),
    );

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?action=test_location&requesting_role=${widget.role}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'id': location.id}),
      ).timeout(const Duration(seconds: 20));

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      final data = json.decode(response.body);

      if (data['success'] == true) {
        _loadLocations();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${location.locationName}: Connection successful!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${location.locationName}: ${data['error'] ?? data['message'] ?? 'Test failed'}'),
            backgroundColor: Colors.red,
          ),
        );
        _loadLocations();
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteLocation(WorkizLocation location) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Location'),
        content: Text('Delete "${location.locationName}"? This will remove all credentials and user assignments.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?action=delete_location&requesting_role=${widget.role}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'id': location.id}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _loadLocations();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location deleted'), backgroundColor: Colors.green),
            );
          }
        } else {
          throw Exception(data['error'] ?? 'Failed to delete');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class WorkizLocation {
  final int id;
  final String locationName;
  final String locationCode;
  final String? workizAccountId;
  final String? workizUserId;
  final String? franchiseId;
  final String status;
  final int userCount;
  final bool hasApiToken;
  final bool hasApiSecret;
  final bool hasSession;
  final String authType; // 'api_token', 'session', or 'none'

  WorkizLocation({
    required this.id,
    required this.locationName,
    required this.locationCode,
    this.workizAccountId,
    this.workizUserId,
    this.franchiseId,
    required this.status,
    required this.userCount,
    required this.hasApiToken,
    required this.hasApiSecret,
    required this.hasSession,
    required this.authType,
  });

  factory WorkizLocation.fromJson(Map<String, dynamic> json) {
    return WorkizLocation(
      id: json['id'] is String ? int.parse(json['id']) : json['id'],
      locationName: json['location_name'] ?? '',
      locationCode: json['location_code'] ?? '',
      workizAccountId: json['workiz_account_id'],
      workizUserId: json['workiz_user_id'],
      franchiseId: json['franchise_id'],
      status: json['status'] ?? 'not_configured',
      userCount: json['user_count'] is String
          ? int.tryParse(json['user_count']) ?? 0
          : json['user_count'] ?? 0,
      hasApiToken: json['has_api_token'] == true,
      hasApiSecret: json['has_api_secret'] == true,
      hasSession: json['has_session'] == true,
      authType: json['auth_type'] ?? 'none',
    );
  }
}
