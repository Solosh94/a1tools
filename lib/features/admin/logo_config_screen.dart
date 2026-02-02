import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../../app_theme.dart';
import '../../config/api_config.dart';

/// Logo Configuration Screen
///
/// Allows admin/developer users to configure the company logo
/// used in PDF inspection reports.
class LogoConfigScreen extends StatefulWidget {
  final String username;
  final String role;

  const LogoConfigScreen({
    required this.username,
    required this.role,
    super.key,
  });

  @override
  State<LogoConfigScreen> createState() => _LogoConfigScreenState();
}

class _LogoConfigScreenState extends State<LogoConfigScreen> {
  static const Color _accent = AppColors.accent;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  // Current config
  String _logoType = 'default';
  String? _updatedAt;
  String? _updatedBy;

  // Preview
  Uint8List? _currentLogoBytes;
  Uint8List? _selectedLogoBytes;
  String? _selectedFilename;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load config
      final configResponse = await http.get(
        Uri.parse('${ApiConfig.logoConfig}?action=get_config'),
      );

      if (configResponse.statusCode == 200) {
        final configData = jsonDecode(configResponse.body);
        if (configData['success'] == true && configData['config'] != null) {
          final config = configData['config'];
          setState(() {
            _logoType = config['logo_type'] ?? 'default';
            _updatedAt = config['updated_at'];
            _updatedBy = config['updated_by'];
          });
        }
      }

      // Load current logo
      final logoResponse = await http.get(
        Uri.parse('${ApiConfig.logoConfig}?action=get_logo'),
      );

      if (logoResponse.statusCode == 200) {
        final logoData = jsonDecode(logoResponse.body);
        if (logoData['success'] == true) {
          if (logoData['logo_type'] == 'custom' && logoData['logo_base64'] != null) {
            setState(() {
              _currentLogoBytes = base64Decode(logoData['logo_base64']);
            });
          } else {
            // Load default logo from assets
            try {
              final assetData = await rootBundle.load('assets/images/logo.png');
              setState(() {
                _currentLogoBytes = assetData.buffer.asUint8List();
              });
            } catch (e) {
              // Asset not available
            }
          }
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load configuration: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickLogo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          setState(() {
            _selectedLogoBytes = file.bytes;
            _selectedFilename = file.name;
          });
        } else if (file.path != null) {
          // Read from path on desktop
          final bytes = await File(file.path!).readAsBytes();
          setState(() {
            _selectedLogoBytes = bytes;
            _selectedFilename = file.name;
          });
        }
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _uploadLogo() async {
    if (_selectedLogoBytes == null) {
      _showError('No logo selected');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.logoConfig),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'upload_logo',
          'username': widget.username,
          'logo_base64': base64Encode(_selectedLogoBytes!),
          'logo_filename': _selectedFilename ?? 'custom_logo.png',
        }),
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _showSuccess('Logo uploaded successfully');
        setState(() {
          _selectedLogoBytes = null;
          _selectedFilename = null;
        });
        _loadConfig();
      } else {
        _showError(data['error'] ?? 'Failed to upload logo');
      }
    } catch (e) {
      _showError('Failed to upload logo: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _resetToDefault() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Logo'),
        content: const Text(
          'Are you sure you want to reset to the default A1 Tools logo? '
          'The current custom logo will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.logoConfig),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'reset_logo',
          'username': widget.username,
        }),
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _showSuccess('Logo reset to default');
        setState(() {
          _selectedLogoBytes = null;
          _selectedFilename = null;
        });
        _loadConfig();
      } else {
        _showError(data['error'] ?? 'Failed to reset logo');
      }
    } catch (e) {
      _showError('Failed to reset logo: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Logo Configuration'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _accent.withValues(alpha: 0.1),
                              _accent.withValues(alpha: 0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _accent.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.image_outlined,
                                color: _accent,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'PDF Report Logo',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Configure the company logo used in inspection PDF reports',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark ? Colors.white60 : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Error message
                      if (_error != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red),
                              const SizedBox(width: 12),
                              Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red))),
                            ],
                          ),
                        ),

                      // Current Logo Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _accent.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.check_circle, color: _accent, size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'Current Logo',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _logoType == 'custom'
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    _logoType == 'custom' ? 'Custom' : 'Default',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _logoType == 'custom' ? Colors.green : Colors.blue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: Container(
                                height: 120,
                                width: 300,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                                ),
                                child: _currentLogoBytes != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.memory(
                                          _currentLogoBytes!,
                                          fit: BoxFit.contain,
                                        ),
                                      )
                                    : const Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
                                            SizedBox(height: 8),
                                            Text('No logo available', style: TextStyle(color: Colors.grey)),
                                          ],
                                        ),
                                      ),
                              ),
                            ),
                            if (_updatedAt != null || _updatedBy != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Last updated: ${_updatedAt ?? 'Unknown'} by ${_updatedBy ?? 'Unknown'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white54 : Colors.black45,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Upload New Logo Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _accent.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.upload_file, color: _accent, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Upload New Logo',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Select a PNG, JPEG, or WebP image to use as the logo in PDF reports. '
                              'Recommended size: 300x80 pixels.',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Selected file preview
                            if (_selectedLogoBytes != null) ...[
                              Center(
                                child: Container(
                                  height: 100,
                                  width: 250,
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      _selectedLogoBytes!,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: Text(
                                  _selectedFilename ?? 'Selected file',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _isSaving ? null : _pickLogo,
                                    icon: const Icon(Icons.folder_open),
                                    label: Text(_selectedLogoBytes != null ? 'Change File' : 'Select File'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _accent,
                                      side: const BorderSide(color: _accent),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                                if (_selectedLogoBytes != null) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _isSaving ? null : _uploadLogo,
                                      icon: _isSaving
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(Icons.cloud_upload),
                                      label: Text(_isSaving ? 'Uploading...' : 'Upload Logo'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _accent,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (_selectedLogoBytes != null) ...[
                              const SizedBox(height: 8),
                              Center(
                                child: TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedLogoBytes = null;
                                      _selectedFilename = null;
                                    });
                                  },
                                  child: const Text('Cancel'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Reset to Default
                      if (_logoType == 'custom')
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.restore, color: Colors.red, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Reset to Default',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Remove the custom logo and use the default A1 Tools logo in PDF reports.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _isSaving ? null : _resetToDefault,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Reset to Default Logo'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Info Card
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Logo Usage',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'The configured logo will appear in:\n'
                                    '  - PDF inspection report header\n'
                                    '  - PDF inspection report footer\n'
                                    '\nChanges will apply to all new PDFs generated.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
