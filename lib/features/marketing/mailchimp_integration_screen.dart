import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../app_theme.dart';
import '../../config/api_config.dart';

/// Admin screen for managing Mailchimp API credentials
class MailchimpIntegrationScreen extends StatefulWidget {
  final String username;
  final String role;

  const MailchimpIntegrationScreen({
    super.key,
    required this.username,
    required this.role,
  });

  @override
  State<MailchimpIntegrationScreen> createState() => _MailchimpIntegrationScreenState();
}

class _MailchimpIntegrationScreenState extends State<MailchimpIntegrationScreen> {
  static const String _baseUrl = ApiConfig.mailchimpIntegration;
  static const Color _accent = AppColors.accent;
  static const Color _mailchimpYellow = Color(0xFFFFE01B);

  Map<String, dynamic>? _config;
  bool _isLoading = true;
  String? _error;

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
      final response = await http.get(
        Uri.parse('$_baseUrl?action=get_config&_=${DateTime.now().millisecondsSinceEpoch}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _config = data['config'];
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = data['error'] ?? 'Failed to load configuration';
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
        title: const Text('Mailchimp Integration'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadConfig,
            tooltip: 'Refresh',
          ),
        ],
      ),
      backgroundColor: bgColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(isDark),
                          const SizedBox(height: 24),
                          _buildConfigCard(cardColor, isDark),
                          const SizedBox(height: 16),
                          _buildHelpCard(cardColor),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadConfig,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _mailchimpYellow.withValues(alpha: 0.2),
            _mailchimpYellow.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _mailchimpYellow.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _mailchimpYellow.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.mail_outline,
              color: isDark ? _mailchimpYellow : Colors.black87,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mailchimp Integration',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Connect your Mailchimp account for email marketing',
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
    );
  }

  Widget _buildConfigCard(Color cardColor, bool isDark) {
    final hasConfig = _config != null && _config!['has_api_key'] == true;

    return Container(
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
              const Icon(Icons.vpn_key, color: _accent, size: 20),
              const SizedBox(width: 8),
              const Text(
                'API Configuration',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: hasConfig ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasConfig ? Colors.green.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasConfig ? Icons.check_circle : Icons.warning,
                      size: 14,
                      color: hasConfig ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasConfig ? 'Connected' : 'Not Configured',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: hasConfig ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (hasConfig) ...[
            _buildInfoRow('API Key', _config!['api_key_masked'] ?? '••••••••'),
            const SizedBox(height: 8),
            _buildInfoRow('Datacenter', _config!['datacenter'] ?? '-'),
            const SizedBox(height: 8),
            _buildInfoRow('From Name', _config!['from_name'] ?? '-'),
            const SizedBox(height: 8),
            _buildInfoRow('From Email', _config!['from_email'] ?? '-'),
            const SizedBox(height: 8),
            _buildInfoRow('Status', _config!['is_active'] == 1 ? 'Active' : 'Inactive'),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey.shade600, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No Mailchimp API key configured. Click the button below to add your credentials.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (hasConfig) ...[
                TextButton.icon(
                  onPressed: () => _testConnection(),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Test Connection'),
                  style: TextButton.styleFrom(foregroundColor: Colors.blue),
                ),
                const SizedBox(width: 8),
              ],
              ElevatedButton.icon(
                onPressed: () => _showConfigDialog(),
                icon: const Icon(Icons.edit, size: 18),
                label: Text(hasConfig ? 'Update Credentials' : 'Add Credentials'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildHelpCard(Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline, color: Colors.blue.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                'How to get your Mailchimp API Key',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStep('1', 'Log in to your Mailchimp account at mailchimp.com'),
          const SizedBox(height: 8),
          _buildStep('2', 'Go to Account & Billing > Extras > API Keys'),
          const SizedBox(height: 8),
          _buildStep('3', 'Click "Create A Key" and give it a name'),
          const SizedBox(height: 8),
          _buildStep('4', 'Copy the generated API key (format: xxxxx-us6)'),
          const SizedBox(height: 8),
          _buildStep('5', 'The part after the dash (e.g., us6) is your datacenter'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.amber.shade700, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Keep your API key secure. It provides full access to your Mailchimp account.',
                    style: TextStyle(fontSize: 12, color: Colors.amber.shade800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ),
      ],
    );
  }

  Future<void> _showConfigDialog() async {
    final apiKeyController = TextEditingController();
    final fromNameController = TextEditingController(text: _config?['from_name'] ?? '');
    final fromEmailController = TextEditingController(text: _config?['from_email'] ?? '');
    bool isLoading = false;
    String? errorMessage;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Mailchimp API Credentials'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: apiKeyController,
                    decoration: InputDecoration(
                      labelText: 'API Key *',
                      hintText: 'xxxxxxxxxxxxx-us6',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.vpn_key),
                      helperText: _config?['has_api_key'] == true
                          ? 'Leave blank to keep current key'
                          : 'Required - get this from Mailchimp',
                    ),
                    obscureText: true,
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: fromNameController,
                    decoration: const InputDecoration(
                      labelText: 'Default From Name',
                      hintText: 'A-1 Chimney Specialist',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: fromEmailController,
                    decoration: const InputDecoration(
                      labelText: 'Default Reply-To Email',
                      hintText: 'info@a-1chimney.com',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    enabled: !isLoading,
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 16),
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
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: const TextStyle(color: Colors.red, fontSize: 13),
                            ),
                          ),
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
                        Text('Saving configuration...'),
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
                      final apiKey = apiKeyController.text.trim();
                      final fromName = fromNameController.text.trim();
                      final fromEmail = fromEmailController.text.trim();

                      // Validate API key for new configs
                      if (apiKey.isEmpty && _config?['has_api_key'] != true) {
                        setDialogState(() => errorMessage = 'API key is required');
                        return;
                      }

                      // If new key provided, validate format
                      if (apiKey.isNotEmpty && !apiKey.contains('-')) {
                        setDialogState(() => errorMessage = 'Invalid API key format. Should be: xxxxx-datacenter');
                        return;
                      }

                      setDialogState(() {
                        isLoading = true;
                        errorMessage = null;
                      });

                      try {
                        final body = <String, dynamic>{
                          'from_name': fromName,
                          'from_email': fromEmail,
                        };

                        if (apiKey.isNotEmpty) {
                          body['api_key'] = apiKey;
                        }

                        final response = await http.post(
                          Uri.parse('$_baseUrl?action=save_config'),
                          headers: {'Content-Type': 'application/json'},
                          body: json.encode(body),
                        ).timeout(const Duration(seconds: 20));

                        final data = json.decode(response.body);
                        if (data['success'] == true) {
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          _loadConfig();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Mailchimp configuration saved'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          setDialogState(() {
                            isLoading = false;
                            errorMessage = data['error'] ?? 'Failed to save configuration';
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
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testConnection() async {
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
        Uri.parse('$_baseUrl?action=test_connection'),
      ).timeout(const Duration(seconds: 20));

      if (!mounted) return;
      Navigator.pop(context);

      final data = json.decode(response.body);

      if (data['success'] == true) {
        final account = data['account'];
        showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Connection Successful'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['message'] ?? 'Connected!'),
                  if (account != null) ...[
                    const SizedBox(height: 16),
                    _buildResultRow('Account', account['account_name'] ?? '-'),
                    _buildResultRow('Email', account['email'] ?? '-'),
                    _buildResultRow('Subscribers', '${account['total_subscribers'] ?? 0}'),
                  ],
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: ${data['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
