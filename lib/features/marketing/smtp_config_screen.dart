import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../app_theme.dart';
import '../../config/api_config.dart';

class SmtpConfigScreen extends StatefulWidget {
  const SmtpConfigScreen({super.key});

  @override
  State<SmtpConfigScreen> createState() => _SmtpConfigScreenState();
}

class _SmtpConfigScreenState extends State<SmtpConfigScreen> {
  static const String _baseUrl = ApiConfig.apiBase;
  static const Color _accent = AppColors.accent;

  final _formKey = GlobalKey<FormState>();
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fromEmailController = TextEditingController();
  final _fromNameController = TextEditingController();
  final _testEmailController = TextEditingController();

  String _encryption = 'tls';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isTesting = false;
  bool _passwordSet = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _fromEmailController.dispose();
    _fromNameController.dispose();
    _testEmailController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/smtp_config.php?action=get'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final config = data['config'];
          setState(() {
            _hostController.text = config['host'] ?? 'smtp.gmail.com';
            _portController.text = config['port']?.toString() ?? '587';
            _usernameController.text = config['username'] ?? '';
            _fromEmailController.text = config['from_email'] ?? '';
            _fromNameController.text = config['from_name'] ?? 'A1 Tools';
            _encryption = config['encryption'] ?? 'tls';
            _passwordSet = config['password_set'] == true;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load configuration: $e');
    }
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/smtp_config.php?action=save'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'host': _hostController.text.trim(),
          'port': _portController.text.trim(),
          'username': _usernameController.text.trim(),
          'password': _passwordController.text, // Empty = don't change
          'from_email': _fromEmailController.text.trim(),
          'from_name': _fromNameController.text.trim(),
          'encryption': _encryption,
        }),
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _showSuccess('Configuration saved successfully');
        if (_passwordController.text.isNotEmpty) {
          setState(() {
            _passwordSet = true;
            _passwordController.clear();
          });
        }
      } else {
        _showError(data['error'] ?? 'Failed to save');
      }
    } catch (e) {
      _showError('Error saving configuration: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _sendTestEmail() async {
    final testEmail = _testEmailController.text.trim();
    if (testEmail.isEmpty) {
      _showError('Please enter a test email address');
      return;
    }

    setState(() => _isTesting = true);

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/smtp_config.php?action=test'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'test_email': testEmail}),
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _showSuccess(data['message'] ?? 'Test email sent!');
      } else {
        // Show detailed error with debug info if available
        final error = data['error'] ?? 'Failed to send test email';
        final debug = data['debug'];
        if (debug != null) {
          _showDetailedError(error, debug);
        } else {
          _showError(error);
        }
      }
    } catch (e) {
      _showError('Error sending test email: $e');
    } finally {
      setState(() => _isTesting = false);
    }
  }

  void _showDetailedError(String error, Map<String, dynamic> debug) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Text('SMTP Error'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('Debug Information:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _debugRow('Host', debug['host'] ?? 'N/A'),
              _debugRow('Port', debug['port']?.toString() ?? 'N/A'),
              _debugRow('Username', debug['username'] ?? 'N/A'),
              _debugRow('Encryption', debug['encryption'] ?? 'N/A'),
              if (debug['exception'] != null)
                _debugRow('Exception', debug['exception']),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline,
                            color: Colors.amber.shade700, size: 18),
                        const SizedBox(width: 8),
                        Text('Troubleshooting Tips',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade800)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Make sure you\'re using a Gmail App Password, not your regular password\n'
                      '2. Enable 2-Factor Authentication in your Google Account first\n'
                      '3. Generate App Password at: myaccount.google.com/apppasswords\n'
                      '4. Use port 587 with TLS, or port 465 with SSL',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _debugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text('$label:',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
                maxLines: 2),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade700,
      ),
    );
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
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: bgColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        const Row(
                          children: [
                            Icon(Icons.email_outlined, color: _accent, size: 28),
                            SizedBox(width: 12),
                            Text(
                              'SMTP Configuration',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Configure email settings for sending weekly time reports and other notifications.',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Server Settings Card
                        _buildCard(
                          cardColor: cardColor,
                          title: 'Server Settings',
                          icon: Icons.dns_outlined,
                          children: [
                            _buildTextField(
                              controller: _hostController,
                              label: 'SMTP Host',
                              hint: 'smtp.gmail.com',
                              icon: Icons.computer,
                              validator: (v) => v?.isEmpty == true
                                  ? 'Host is required'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _buildTextField(
                                    controller: _portController,
                                    label: 'Port',
                                    hint: '587',
                                    icon: Icons.numbers,
                                    keyboardType: TextInputType.number,
                                    validator: (v) => v?.isEmpty == true
                                        ? 'Required'
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 3,
                                  child: _buildDropdown(
                                    value: _encryption,
                                    label: 'Encryption',
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'tls',
                                        child: Text('TLS (STARTTLS)'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'ssl',
                                        child: Text('SSL'),
                                      ),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _encryption = v!),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Authentication Card
                        _buildCard(
                          cardColor: cardColor,
                          title: 'Authentication',
                          icon: Icons.lock_outline,
                          children: [
                            _buildTextField(
                              controller: _usernameController,
                              label: 'Username / Email',
                              hint: 'noreply@a-1chimney.com',
                              icon: Icons.person_outline,
                              validator: (v) => v?.isEmpty == true
                                  ? 'Username is required'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _passwordController,
                              label: _passwordSet
                                  ? 'Password (leave blank to keep current)'
                                  : 'Password (App Password)',
                              hint: _passwordSet
                                  ? '••••••••••••••••'
                                  : 'Enter app password',
                              icon: Icons.key,
                              obscureText: _obscurePassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.grey,
                                ),
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                              ),
                              validator: (v) {
                                if (!_passwordSet && (v?.isEmpty ?? true)) {
                                  return 'Password is required';
                                }
                                return null;
                              },
                            ),
                            if (!_passwordSet) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.blue.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline,
                                        color: Colors.blue.shade700, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'For Gmail, use an App Password instead of your regular password. Go to Google Account > Security > App passwords.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Sender Info Card
                        _buildCard(
                          cardColor: cardColor,
                          title: 'Sender Information',
                          icon: Icons.send_outlined,
                          children: [
                            _buildTextField(
                              controller: _fromEmailController,
                              label: 'From Email (optional)',
                              hint: 'Same as username if empty',
                              icon: Icons.alternate_email,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _fromNameController,
                              label: 'From Name',
                              hint: 'A1 Tools',
                              icon: Icons.badge_outlined,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _saveConfig,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save),
                            label: Text(_isSaving
                                ? 'Saving...'
                                : 'Save Configuration'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Test Email Card
                        _buildCard(
                          cardColor: cardColor,
                          title: 'Test Configuration',
                          icon: Icons.science_outlined,
                          children: [
                            Text(
                              'Send a test email to verify your SMTP settings are working correctly.',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller: _testEmailController,
                                    label: 'Test Email Address',
                                    hint: 'your@email.com',
                                    icon: Icons.email_outlined,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: _isTesting ? null : _sendTestEmail,
                                  icon: _isTesting
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.send, size: 18),
                                  label: Text(_isTesting ? 'Sending...' : 'Send'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade600,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildCard({
    required Color cardColor,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _accent, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _accent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required String label,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.security, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _accent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}
