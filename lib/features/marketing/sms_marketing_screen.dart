import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../app_theme.dart';

/// Comprehensive SMS Marketing tool using Twilio
class SmsMarketingScreen extends StatefulWidget {
  final String username;
  final String role;

  const SmsMarketingScreen({
    super.key,
    required this.username,
    required this.role,
  });

  @override
  State<SmsMarketingScreen> createState() => _SmsMarketingScreenState();
}

class _SmsMarketingScreenState extends State<SmsMarketingScreen> with SingleTickerProviderStateMixin {
  static const String _baseUrl = ApiConfig.twilioIntegration;
  static const Color _accent = AppColors.accent;
  static const Color _twilioRed = Color(0xFFF22F46);

  late TabController _tabController;
  bool _isLoading = true;
  bool _isConfigured = false;

  // Data
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _templates = [];
  List<Map<String, dynamic>> _phoneNumbers = [];
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _checkConfiguration();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkConfiguration() async {
    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl?action=get_config&_=${DateTime.now().millisecondsSinceEpoch}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['config']?['has_auth_token'] == true) {
          setState(() => _isConfigured = true);
          await _loadAllData();
        } else {
          setState(() {
            _isConfigured = false;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('SMS Marketing config error: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadContacts(),
      _loadGroups(),
      _loadMessages(),
      _loadTemplates(),
      _loadPhoneNumbers(),
      _loadStats(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadContacts() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl?action=get_contacts&limit=100'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _contacts = List<Map<String, dynamic>>.from(data['contacts'] ?? []);
        }
      }
    } catch (e) {
      // Silently ignore load errors
      debugPrint('[SmsMarketingScreen] Error: $e');
    }
  }

  Future<void> _loadGroups() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl?action=get_contact_groups'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _groups = List<Map<String, dynamic>>.from(data['groups'] ?? []);
        }
      }
    } catch (e) {
      // Silently ignore load errors
      debugPrint('[SmsMarketingScreen] Error: $e');
    }
  }

  Future<void> _loadMessages() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl?action=get_messages&limit=50'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _messages = List<Map<String, dynamic>>.from(data['messages'] ?? []);
        }
      }
    } catch (e) {
      // Silently ignore load errors
      debugPrint('[SmsMarketingScreen] Error: $e');
    }
  }

  Future<void> _loadTemplates() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl?action=get_templates'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _templates = List<Map<String, dynamic>>.from(data['templates'] ?? []);
        }
      }
    } catch (e) {
      // Silently ignore load errors
      debugPrint('[SmsMarketingScreen] Error: $e');
    }
  }

  Future<void> _loadPhoneNumbers() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl?action=get_phone_numbers'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _phoneNumbers = List<Map<String, dynamic>>.from(data['phone_numbers'] ?? []);
        }
      }
    } catch (e) {
      // Silently ignore load errors
      debugPrint('[SmsMarketingScreen] Error: $e');
    }
  }

  Future<void> _loadStats() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl?action=get_stats&days=30'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _stats = data['stats'];
        }
      }
    } catch (e) {
      // Silently ignore load errors
      debugPrint('[SmsMarketingScreen] Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Marketing'),
        backgroundColor: _twilioRed,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkConfiguration,
            tooltip: 'Refresh',
          ),
        ],
        bottom: _isConfigured
            ? TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(icon: Icon(Icons.send), text: 'Send'),
                  Tab(icon: Icon(Icons.people), text: 'Contacts'),
                  Tab(icon: Icon(Icons.history), text: 'History'),
                  Tab(icon: Icon(Icons.article), text: 'Templates'),
                ],
              )
            : null,
      ),
      backgroundColor: bgColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_isConfigured
              ? _buildNotConfiguredState(isDark)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSendTab(isDark),
                    _buildContactsTab(isDark),
                    _buildHistoryTab(isDark),
                    _buildTemplatesTab(isDark),
                  ],
                ),
    );
  }

  Widget _buildNotConfiguredState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _twilioRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Icon(
                Icons.sms_outlined,
                size: 64,
                color: _twilioRed,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Twilio Not Configured',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Connect your Twilio account in Management > Twilio Integration to use SMS marketing features.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendTab(bool isDark) {
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Stats Overview
              if (_stats != null) _buildStatsCard(cardColor),
              const SizedBox(height: 16),

              // Quick Send
              _buildQuickSendCard(cardColor),
              const SizedBox(height: 16),

              // Bulk Send
              _buildBulkSendCard(cardColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard(Color cardColor) {
    final overall = _stats?['overall'] ?? {};
    final contacts = _stats?['contacts'] ?? {};

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _twilioRed.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics, color: _twilioRed, size: 20),
              SizedBox(width: 8),
              Text(
                'Last 30 Days',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildStatItem('Messages Sent', '${overall['total_messages'] ?? 0}', Colors.blue)),
              Expanded(child: _buildStatItem('Delivered', '${overall['successful'] ?? 0}', Colors.green)),
              Expanded(child: _buildStatItem('Failed', '${overall['failed'] ?? 0}', Colors.red)),
              Expanded(child: _buildStatItem('Contacts', '${contacts['total_contacts'] ?? 0}', Colors.purple)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildQuickSendCard(Color cardColor) {
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
          const Row(
            children: [
              Icon(Icons.send, color: _accent, size: 20),
              SizedBox(width: 8),
              Text(
                'Quick Send SMS',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _showQuickSendDialog(),
            icon: const Icon(Icons.message),
            label: const Text('Send Single Message'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkSendCard(Color cardColor) {
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
              Icon(Icons.campaign, color: Colors.blue.shade600, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Bulk SMS Campaign',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Send messages to a contact group',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _groups.isEmpty ? null : () => _showBulkSendDialog(),
            icon: const Icon(Icons.group),
            label: Text(_groups.isEmpty ? 'Create a group first' : 'Send to Group'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactsTab(bool isDark) {
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;

    return Column(
      children: [
        // Actions bar
        Container(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showAddContactDialog(),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Add Contact'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showAddGroupDialog(),
                  icon: const Icon(Icons.group_add, size: 18),
                  label: const Text('Add Group'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Groups Section
        if (_groups.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.folder, size: 16, color: _accent),
                const SizedBox(width: 8),
                Text(
                  'Contact Groups (${_groups.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _groups.length,
              itemBuilder: (context, index) {
                final group = _groups[index];
                return Card(
                  color: cardColor,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: () => _filterByGroup(group['id']),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 120,
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            group['name'] ?? 'Unnamed',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${group['contact_count'] ?? 0} contacts',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],

        const Divider(),

        // Contacts List
        Expanded(
          child: _contacts.isEmpty
              ? _buildEmptyState(
                  icon: Icons.people_outline,
                  title: 'No Contacts Yet',
                  subtitle: 'Add contacts to start sending SMS messages',
                )
              : RefreshIndicator(
                  onRefresh: _loadContacts,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _contacts.length,
                    itemBuilder: (context, index) {
                      final contact = _contacts[index];
                      return Card(
                        color: cardColor,
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _accent.withValues(alpha: 0.1),
                            child: Text(
                              (contact['first_name'] ?? contact['phone_number'] ?? '?').toString().substring(0, 1).toUpperCase(),
                              style: const TextStyle(color: _accent, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(
                            '${contact['first_name'] ?? ''} ${contact['last_name'] ?? ''}'.trim().isEmpty
                                ? contact['phone_number'] ?? 'Unknown'
                                : '${contact['first_name'] ?? ''} ${contact['last_name'] ?? ''}'.trim(),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(contact['phone_number'] ?? ''),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (contact['opt_out'] == 1)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Opted Out',
                                    style: TextStyle(fontSize: 10, color: Colors.red),
                                  ),
                                ),
                              IconButton(
                                icon: const Icon(Icons.message, size: 20),
                                onPressed: () => _showQuickSendDialog(prefillPhone: contact['phone_number']),
                                color: _accent,
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20),
                                onPressed: () => _deleteContact(contact['id']),
                                color: Colors.red,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab(bool isDark) {
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;

    if (_messages.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history,
        title: 'No Messages Yet',
        subtitle: 'Sent messages will appear here',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMessages,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final msg = _messages[index];
          final status = msg['status'] ?? 'unknown';
          final statusColor = _getStatusColor(status);

          return Card(
            color: cardColor,
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        msg['direction'] == 'inbound' ? Icons.call_received : Icons.call_made,
                        size: 16,
                        color: msg['direction'] == 'inbound' ? Colors.green : Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          msg['to_number'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    msg['body'] ?? '',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        msg['created_at'] ?? '',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                      if (msg['segments'] != null && msg['segments'] > 1) ...[
                        const SizedBox(width: 12),
                        Text(
                          '${msg['segments']} segments',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return Colors.green;
      case 'sent':
        return Colors.blue;
      case 'queued':
      case 'sending':
        return Colors.orange;
      case 'failed':
      case 'undelivered':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildTemplatesTab(bool isDark) {
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton.icon(
            onPressed: () => _showAddTemplateDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Create Template'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),
        Expanded(
          child: _templates.isEmpty
              ? _buildEmptyState(
                  icon: Icons.article_outlined,
                  title: 'No Templates Yet',
                  subtitle: 'Create message templates for quick sending',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _templates.length,
                  itemBuilder: (context, index) {
                    final template = _templates[index];
                    return Card(
                      color: cardColor,
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.article, color: _accent),
                        ),
                        title: Text(template['name'] ?? 'Unnamed'),
                        subtitle: Text(
                          template['content'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.send, size: 20),
                              onPressed: () => _showQuickSendDialog(prefillMessage: template['content']),
                              color: Colors.green,
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 20),
                              onPressed: () => _deleteTemplate(template['id']),
                              color: Colors.red,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: Colors.grey.shade500), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Future<void> _showQuickSendDialog({String? prefillPhone, String? prefillMessage}) async {
    final phoneController = TextEditingController(text: prefillPhone ?? '');
    final messageController = TextEditingController(text: prefillMessage ?? '');
    String? selectedFromNumber = _phoneNumbers.isNotEmpty ? _phoneNumbers.first['phone_number'] : null;
    bool isLoading = false;
    String? errorMessage;
    String? successMessage;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Send SMS'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_phoneNumbers.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: selectedFromNumber,
                    decoration: const InputDecoration(
                      labelText: 'From Number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                    items: _phoneNumbers.map((n) => DropdownMenuItem<String>(
                      value: n['phone_number'],
                      child: Text(n['phone_number'] ?? ''),
                    )).toList(),
                    onChanged: (v) => setDialogState(() => selectedFromNumber = v),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'To Phone Number *',
                    hintText: '+1234567890',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone_android),
                  ),
                  keyboardType: TextInputType.phone,
                  enabled: !isLoading,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  decoration: InputDecoration(
                    labelText: 'Message *',
                    hintText: 'Enter your message...',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.message),
                    counterText: '${messageController.text.length}/160',
                  ),
                  maxLines: 4,
                  maxLength: 1600,
                  enabled: !isLoading,
                  onChanged: (_) => setDialogState(() {}),
                ),
                if (messageController.text.length > 160)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Message will be sent as ${(messageController.text.length / 160).ceil()} segments',
                      style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                    ),
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
                        Expanded(child: Text(errorMessage!, style: const TextStyle(color: Colors.red))),
                      ],
                    ),
                  ),
                ],
                if (successMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(successMessage!, style: const TextStyle(color: Colors.green))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (phoneController.text.isEmpty || messageController.text.isEmpty) {
                        setDialogState(() => errorMessage = 'Phone number and message are required');
                        return;
                      }

                      setDialogState(() {
                        isLoading = true;
                        errorMessage = null;
                        successMessage = null;
                      });

                      try {
                        final response = await http.post(
                          Uri.parse('$_baseUrl?action=send_message'),
                          headers: {'Content-Type': 'application/json'},
                          body: json.encode({
                            'to': phoneController.text,
                            'body': messageController.text,
                            'from': selectedFromNumber,
                            'sent_by': widget.username,
                          }),
                        );

                        final data = json.decode(response.body);
                        if (data['success'] == true) {
                          setDialogState(() {
                            isLoading = false;
                            successMessage = 'Message sent successfully!';
                          });
                          _loadMessages();
                          _loadStats();
                          // Clear form for next message
                          phoneController.clear();
                          messageController.clear();
                        } else {
                          setDialogState(() {
                            isLoading = false;
                            errorMessage = data['error'] ?? 'Failed to send message';
                          });
                        }
                      } catch (e) {
                        setDialogState(() {
                          isLoading = false;
                          errorMessage = e.toString();
                        });
                      }
                    },
              icon: Icon(isLoading ? Icons.hourglass_empty : Icons.send),
              label: Text(isLoading ? 'Sending...' : 'Send'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBulkSendDialog() async {
    final messageController = TextEditingController();
    int? selectedGroupId = _groups.isNotEmpty ? _groups.first['id'] : null;
    String? selectedFromNumber = _phoneNumbers.isNotEmpty ? _phoneNumbers.first['phone_number'] : null;
    bool isLoading = false;
    String? errorMessage;
    Map<String, dynamic>? results;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Bulk SMS Campaign'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: selectedGroupId,
                  decoration: const InputDecoration(
                    labelText: 'Contact Group *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.group),
                  ),
                  items: _groups.map((g) => DropdownMenuItem<int>(
                    value: g['id'],
                    child: Text('${g['name']} (${g['contact_count']} contacts)'),
                  )).toList(),
                  onChanged: (v) => setDialogState(() => selectedGroupId = v),
                ),
                const SizedBox(height: 16),
                if (_phoneNumbers.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: selectedFromNumber,
                    decoration: const InputDecoration(
                      labelText: 'From Number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                    items: _phoneNumbers.map((n) => DropdownMenuItem<String>(
                      value: n['phone_number'],
                      child: Text(n['phone_number'] ?? ''),
                    )).toList(),
                    onChanged: (v) => setDialogState(() => selectedFromNumber = v),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    labelText: 'Message *',
                    hintText: 'Enter your message...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.message),
                  ),
                  maxLines: 4,
                  maxLength: 1600,
                  enabled: !isLoading,
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                  ),
                ],
                if (results != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Campaign Complete!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                        Text('Sent: ${results!['sent']} | Failed: ${results!['failed']}'),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            if (results == null)
              ElevatedButton.icon(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (selectedGroupId == null || messageController.text.isEmpty) {
                          setDialogState(() => errorMessage = 'Please select a group and enter a message');
                          return;
                        }

                        setDialogState(() {
                          isLoading = true;
                          errorMessage = null;
                        });

                        try {
                          final response = await http.post(
                            Uri.parse('$_baseUrl?action=send_bulk'),
                            headers: {'Content-Type': 'application/json'},
                            body: json.encode({
                              'group_id': selectedGroupId,
                              'body': messageController.text,
                              'from': selectedFromNumber,
                              'sent_by': widget.username,
                            }),
                          );

                          final data = json.decode(response.body);
                          if (data['success'] == true) {
                            setDialogState(() {
                              isLoading = false;
                              results = data['results'];
                            });
                            _loadMessages();
                            _loadStats();
                          } else {
                            setDialogState(() {
                              isLoading = false;
                              errorMessage = data['error'];
                            });
                          }
                        } catch (e) {
                          setDialogState(() {
                            isLoading = false;
                            errorMessage = e.toString();
                          });
                        }
                      },
                icon: Icon(isLoading ? Icons.hourglass_empty : Icons.campaign),
                label: Text(isLoading ? 'Sending...' : 'Send Campaign'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddContactDialog() async {
    final phoneController = TextEditingController();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final companyController = TextEditingController();
    int? selectedGroupId;
    bool isLoading = false;
    String? errorMessage;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Contact'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number *',
                  hintText: '+1234567890',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                enabled: !isLoading,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: firstNameController,
                      decoration: const InputDecoration(labelText: 'First Name', border: OutlineInputBorder()),
                      enabled: !isLoading,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: lastNameController,
                      decoration: const InputDecoration(labelText: 'Last Name', border: OutlineInputBorder()),
                      enabled: !isLoading,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: companyController,
                decoration: const InputDecoration(labelText: 'Company', border: OutlineInputBorder()),
                enabled: !isLoading,
              ),
              if (_groups.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: selectedGroupId,
                  decoration: const InputDecoration(labelText: 'Group', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem<int>(value: null, child: Text('No Group')),
                    ..._groups.map((g) => DropdownMenuItem<int>(value: g['id'], child: Text(g['name'] ?? ''))),
                  ],
                  onChanged: (v) => setDialogState(() => selectedGroupId = v),
                ),
              ],
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: isLoading ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (phoneController.text.isEmpty) {
                        setDialogState(() => errorMessage = 'Phone number is required');
                        return;
                      }

                      setDialogState(() {
                        isLoading = true;
                        errorMessage = null;
                      });

                      try {
                        final response = await http.post(
                          Uri.parse('$_baseUrl?action=save_contact'),
                          headers: {'Content-Type': 'application/json'},
                          body: json.encode({
                            'phone_number': phoneController.text,
                            'first_name': firstNameController.text,
                            'last_name': lastNameController.text,
                            'company': companyController.text,
                            'group_id': selectedGroupId,
                          }),
                        );

                        final data = json.decode(response.body);
                        if (data['success'] == true) {
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          _loadContacts();
                          _loadGroups();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Contact added'), backgroundColor: Colors.green),
                          );
                        } else {
                          setDialogState(() {
                            isLoading = false;
                            errorMessage = data['error'];
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
              child: Text(isLoading ? 'Saving...' : 'Save', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddGroupDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    bool isLoading = false;
    String? errorMessage;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Create Contact Group'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Group Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.group),
                ),
                enabled: !isLoading,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                enabled: !isLoading,
              ),
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: isLoading ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (nameController.text.isEmpty) {
                        setDialogState(() => errorMessage = 'Group name is required');
                        return;
                      }

                      setDialogState(() {
                        isLoading = true;
                        errorMessage = null;
                      });

                      try {
                        final response = await http.post(
                          Uri.parse('$_baseUrl?action=save_contact_group'),
                          headers: {'Content-Type': 'application/json'},
                          body: json.encode({
                            'name': nameController.text,
                            'description': descriptionController.text,
                          }),
                        );

                        final data = json.decode(response.body);
                        if (data['success'] == true) {
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          _loadGroups();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Group created'), backgroundColor: Colors.green),
                          );
                        } else {
                          setDialogState(() {
                            isLoading = false;
                            errorMessage = data['error'];
                          });
                        }
                      } catch (e) {
                        setDialogState(() {
                          isLoading = false;
                          errorMessage = e.toString();
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: Text(isLoading ? 'Creating...' : 'Create', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddTemplateDialog() async {
    final nameController = TextEditingController();
    final contentController = TextEditingController();
    final categoryController = TextEditingController();
    bool isLoading = false;
    String? errorMessage;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Create SMS Template'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Template Name *',
                  border: OutlineInputBorder(),
                ),
                enabled: !isLoading,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  hintText: 'e.g., Promotion, Reminder, Welcome',
                  border: OutlineInputBorder(),
                ),
                enabled: !isLoading,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(
                  labelText: 'Message Content *',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                maxLength: 1600,
                enabled: !isLoading,
              ),
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: isLoading ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (nameController.text.isEmpty || contentController.text.isEmpty) {
                        setDialogState(() => errorMessage = 'Name and content are required');
                        return;
                      }

                      setDialogState(() {
                        isLoading = true;
                        errorMessage = null;
                      });

                      try {
                        final response = await http.post(
                          Uri.parse('$_baseUrl?action=save_template'),
                          headers: {'Content-Type': 'application/json'},
                          body: json.encode({
                            'name': nameController.text,
                            'content': contentController.text,
                            'category': categoryController.text,
                          }),
                        );

                        final data = json.decode(response.body);
                        if (data['success'] == true) {
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          _loadTemplates();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Template created'), backgroundColor: Colors.green),
                          );
                        } else {
                          setDialogState(() {
                            isLoading = false;
                            errorMessage = data['error'];
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
              child: Text(isLoading ? 'Creating...' : 'Create', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteContact(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Contact?'),
        content: const Text('Are you sure you want to delete this contact?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await http.delete(Uri.parse('$_baseUrl?action=delete_contact&id=$id'));
      _loadContacts();
      _loadGroups();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact deleted'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteTemplate(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Template?'),
        content: const Text('Are you sure you want to delete this template?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await http.delete(Uri.parse('$_baseUrl?action=delete_template&id=$id'));
      _loadTemplates();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template deleted'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _filterByGroup(int groupId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Filtering by group $groupId')),
    );
  }
}
