// Route Optimization Configuration Screen
//
// Allows administrators to configure Google Maps API settings
// for route optimization features.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../app_theme.dart';
import '../../config/api_config.dart';

class RouteConfigScreen extends StatefulWidget {
  final String username;
  final String role;

  const RouteConfigScreen({
    super.key,
    required this.username,
    required this.role,
  });

  @override
  State<RouteConfigScreen> createState() => _RouteConfigScreenState();
}

class _RouteConfigScreenState extends State<RouteConfigScreen> {
  static const String _baseUrl = ApiConfig.apiBase;
  static const Color _accent = AppColors.accent;

  final _formKey = GlobalKey<FormState>();
  final _apiKeyController = TextEditingController();
  final _defaultStartController = TextEditingController();
  final _defaultEndController = TextEditingController();

  bool _enabled = false;
  bool _loading = true;
  bool _saving = false;
  bool _obscureApiKey = true;

  // Stats
  int _activeRoutesToday = 0;
  int _trackedTechnicians = 0;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _loadStats();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _defaultStartController.dispose();
    _defaultEndController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/route_optimization.php?action=get_config'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _apiKeyController.text = data['config']['google_maps_api_key'] ?? '';
            _defaultStartController.text = data['config']['default_start_address'] ?? '';
            _defaultEndController.text = data['config']['default_end_address'] ?? '';
            _enabled = data['config']['enabled'] ?? false;
            _loading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading route config: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _loadStats() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/route_optimization.php?action=get_stats'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _activeRoutesToday = data['stats']['active_routes_today'] ?? 0;
            _trackedTechnicians = data['stats']['tracked_technicians'] ?? 0;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading route stats: $e');
    }
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/route_optimization.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'save_config',
          'google_maps_api_key': _apiKeyController.text.trim(),
          'default_start_address': _defaultStartController.text.trim(),
          'default_end_address': _defaultEndController.text.trim(),
          'enabled': _enabled,
          'updated_by': widget.username,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Route optimization settings saved successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception(data['error'] ?? 'Failed to save');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving configuration: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[100],
      appBar: AppBar(
        title: const Text('Route Optimization Settings'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveConfig,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Card
                    _buildStatsCard(isDark),
                    const SizedBox(height: 24),

                    // Enable Switch
                    _buildSettingsCard(
                      isDark: isDark,
                      child: SwitchListTile(
                        title: const Text(
                          'Enable Route Optimization',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text(
                          'Allow technicians to optimize their daily routes',
                        ),
                        value: _enabled,
                        activeTrackColor: _accent.withValues(alpha: 0.5),
                        activeThumbColor: _accent,
                        onChanged: (value) {
                          setState(() => _enabled = value);
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Google Maps API Configuration
                    Text(
                      'Google Maps API',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildSettingsCard(
                      isDark: isDark,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // API Key
                            TextFormField(
                              controller: _apiKeyController,
                              obscureText: _obscureApiKey,
                              decoration: InputDecoration(
                                labelText: 'Google Maps API Key',
                                hintText: 'Enter your Google Maps Platform API key',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureApiKey
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureApiKey = !_obscureApiKey;
                                    });
                                  },
                                ),
                              ),
                              validator: (value) {
                                if (_enabled && (value == null || value.isEmpty)) {
                                  return 'API key is required when enabled';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Default Addresses
                    Text(
                      'Default Addresses',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildSettingsCard(
                      isDark: isDark,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _defaultStartController,
                              decoration: const InputDecoration(
                                labelText: 'Default Start Location',
                                hintText: 'e.g., Company warehouse address',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.home),
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _defaultEndController,
                              decoration: const InputDecoration(
                                labelText: 'Default End Location (optional)',
                                hintText: 'Leave blank to end at last job',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.flag),
                              ),
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Instructions
                    _buildSettingsCard(
                      isDark: isDark,
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: _accent, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'How to get your Google Maps API Key',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Text(
                              '1. Go to Google Cloud Console (console.cloud.google.com)\n'
                              '2. Create a project or select an existing one\n'
                              '3. Enable the following APIs:\n'
                              '   - Distance Matrix API\n'
                              '   - Directions API\n'
                              '   - Geocoding API\n'
                              '4. Go to Credentials and create an API key\n'
                              '5. Restrict the API key to only the required APIs\n'
                              '6. Paste the key in the field above',
                              style: TextStyle(fontSize: 13, height: 1.6),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Features Info
                    _buildSettingsCard(
                      isDark: isDark,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.route, color: _accent, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Route Optimization Features',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildFeatureItem(
                              icon: Icons.map,
                              title: 'Optimized Routes',
                              description: 'Automatically calculate the best route order',
                            ),
                            _buildFeatureItem(
                              icon: Icons.timer,
                              title: 'Time Estimates',
                              description: 'Get accurate travel time between jobs',
                            ),
                            _buildFeatureItem(
                              icon: Icons.navigation,
                              title: 'Turn-by-Turn Navigation',
                              description: 'Open routes directly in Google Maps',
                            ),
                            _buildFeatureItem(
                              icon: Icons.location_on,
                              title: 'Live Tracking',
                              description: 'Track technician locations in real-time',
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.route,
            label: 'Active Routes Today',
            value: _activeRoutesToday.toString(),
          ),
          _buildStatItem(
            icon: Icons.person_pin_circle,
            label: 'Tracked Technicians',
            value: _trackedTechnicians.toString(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: _accent, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsCard({
    required bool isDark,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: child,
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
