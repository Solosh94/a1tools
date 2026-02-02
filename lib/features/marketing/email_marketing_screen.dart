import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../app_theme.dart';
import '../../config/api_config.dart';

/// Comprehensive Email Marketing tool using Mailchimp
class EmailMarketingScreen extends StatefulWidget {
  final String username;
  final String role;

  const EmailMarketingScreen({
    super.key,
    required this.username,
    required this.role,
  });

  @override
  State<EmailMarketingScreen> createState() => _EmailMarketingScreenState();
}

class _EmailMarketingScreenState extends State<EmailMarketingScreen> with SingleTickerProviderStateMixin {
  static const String _baseUrl = ApiConfig.mailchimpIntegration;
  static const Color _accent = AppColors.accent;
  static const Color _mailchimpYellow = Color(0xFFFFE01B);

  late TabController _tabController;
  bool _isLoading = true;
  bool _isConfigured = false;

  // Data
  List<Map<String, dynamic>> _audiences = [];
  List<Map<String, dynamic>> _campaigns = [];
  List<Map<String, dynamic>> _templates = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        if (data['success'] == true && data['config']?['has_api_key'] == true) {
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
      debugPrint('Email marketing error: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadAudiences(),
      _loadCampaigns(),
      _loadTemplates(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadAudiences() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl?action=get_audiences'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _audiences = List<Map<String, dynamic>>.from(data['audiences'] ?? []);
        }
      }
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _loadCampaigns() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl?action=get_campaigns'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _campaigns = List<Map<String, dynamic>>.from(data['campaigns'] ?? []);
        }
      }
    } catch (e) {
      // Silently fail
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
      // Silently fail
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Marketing'),
        backgroundColor: _accent,
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
                  Tab(icon: Icon(Icons.campaign), text: 'Campaigns'),
                  Tab(icon: Icon(Icons.people), text: 'Audiences'),
                  Tab(icon: Icon(Icons.article), text: 'Templates'),
                ],
              )
            : null,
      ),
      backgroundColor: bgColor,
      floatingActionButton: _isConfigured
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateCampaignDialog(),
              backgroundColor: _accent,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('New Campaign', style: TextStyle(color: Colors.white)),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_isConfigured
              ? _buildNotConfiguredState(isDark)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCampaignsTab(isDark),
                    _buildAudiencesTab(isDark),
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
                color: _mailchimpYellow.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Icon(
                Icons.mail_outline,
                size: 64,
                color: isDark ? _mailchimpYellow : Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Mailchimp Not Configured',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Connect your Mailchimp account in Management > Mailchimp Integration to use email marketing features.',
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

  Widget _buildCampaignsTab(bool isDark) {
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;

    if (_campaigns.isEmpty) {
      return _buildEmptyState(
        icon: Icons.campaign_outlined,
        title: 'No Campaigns Yet',
        subtitle: 'Create your first email campaign to get started',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCampaigns,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _campaigns.length,
        itemBuilder: (context, index) {
          final campaign = _campaigns[index];
          return _buildCampaignCard(campaign, cardColor);
        },
      ),
    );
  }

  Widget _buildCampaignCard(Map<String, dynamic> campaign, Color cardColor) {
    final status = campaign['status'] ?? 'draft';
    final statusColor = _getStatusColor(status);

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _accent.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        campaign['title'] ?? 'Untitled Campaign',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        campaign['subject_line'] ?? 'No subject',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildCampaignStat(Icons.people, '${campaign['recipient_count'] ?? 0}', 'Recipients'),
                const SizedBox(width: 16),
                _buildCampaignStat(Icons.send, '${campaign['emails_sent'] ?? 0}', 'Sent'),
                if (campaign['report_summary'] != null) ...[
                  const SizedBox(width: 16),
                  _buildCampaignStat(
                    Icons.visibility,
                    '${((campaign['report_summary']?['open_rate'] ?? 0) * 100).toStringAsFixed(1)}%',
                    'Opens',
                  ),
                  const SizedBox(width: 16),
                  _buildCampaignStat(
                    Icons.touch_app,
                    '${((campaign['report_summary']?['click_rate'] ?? 0) * 100).toStringAsFixed(1)}%',
                    'Clicks',
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (status == 'save' || status == 'paused') ...[
                  TextButton.icon(
                    onPressed: () => _editCampaign(campaign),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                    style: TextButton.styleFrom(foregroundColor: _accent),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _sendCampaign(campaign['id']),
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text('Send'),
                    style: TextButton.styleFrom(foregroundColor: Colors.green),
                  ),
                ],
                if (status == 'sent') ...[
                  TextButton.icon(
                    onPressed: () => _viewReport(campaign['id']),
                    icon: const Icon(Icons.analytics, size: 16),
                    label: const Text('View Report'),
                    style: TextButton.styleFrom(foregroundColor: Colors.blue),
                  ),
                ],
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _deleteCampaign(campaign['id']),
                  icon: const Icon(Icons.delete, size: 16),
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

  Widget _buildCampaignStat(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'sent':
        return Colors.green;
      case 'sending':
        return Colors.blue;
      case 'schedule':
        return Colors.orange;
      case 'paused':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  Widget _buildAudiencesTab(bool isDark) {
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;

    if (_audiences.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline,
        title: 'No Audiences Found',
        subtitle: 'Create an audience in Mailchimp to manage your subscribers',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAudiences,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _audiences.length,
        itemBuilder: (context, index) {
          final audience = _audiences[index];
          return _buildAudienceCard(audience, cardColor);
        },
      ),
    );
  }

  Widget _buildAudienceCard(Map<String, dynamic> audience, Color cardColor) {
    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.withValues(alpha: 0.2)),
      ),
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
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.people, color: Colors.blue, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        audience['name'] ?? 'Unnamed Audience',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID: ${audience['id']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildAudienceStat('${audience['member_count'] ?? 0}', 'Subscribers', Colors.green),
                const SizedBox(width: 16),
                _buildAudienceStat('${audience['unsubscribe_count'] ?? 0}', 'Unsubscribed', Colors.red),
                const SizedBox(width: 16),
                _buildAudienceStat(
                  '${((audience['open_rate'] ?? 0) * 100).toStringAsFixed(1)}%',
                  'Avg Open Rate',
                  Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _viewMembers(audience),
                  icon: const Icon(Icons.list, size: 16),
                  label: const Text('View Members'),
                  style: TextButton.styleFrom(foregroundColor: Colors.blue),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _showAddMemberDialog(audience),
                  icon: const Icon(Icons.person_add, size: 16),
                  label: const Text('Add Member'),
                  style: TextButton.styleFrom(foregroundColor: Colors.green),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudienceStat(String value, String label, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildTemplatesTab(bool isDark) {
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;

    if (_templates.isEmpty) {
      return _buildEmptyState(
        icon: Icons.article_outlined,
        title: 'No Templates Found',
        subtitle: 'Create templates in Mailchimp to use them in campaigns',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTemplates,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _templates.length,
        itemBuilder: (context, index) {
          final template = _templates[index];
          return Card(
            color: cardColor,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.article, color: _accent),
              ),
              title: Text(template['name'] ?? 'Unnamed Template'),
              subtitle: Text('Type: ${template['type'] ?? 'user'}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // Preview template
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateCampaignDialog() async {
    if (_audiences.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please create an audience in Mailchimp first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final titleController = TextEditingController();
    final subjectController = TextEditingController();
    final previewTextController = TextEditingController();
    final fromNameController = TextEditingController();
    final replyToController = TextEditingController();
    String? selectedAudienceId = _audiences.isNotEmpty ? _audiences.first['id'] : null;
    bool isLoading = false;
    String? errorMessage;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Create Email Campaign'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedAudienceId,
                    decoration: const InputDecoration(
                      labelText: 'Audience *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.people),
                    ),
                    items: _audiences.map((a) => DropdownMenuItem<String>(
                      value: a['id'],
                      child: Text('${a['name']} (${a['member_count']} subscribers)'),
                    )).toList(),
                    onChanged: (v) => setDialogState(() => selectedAudienceId = v),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Campaign Title *',
                      hintText: 'Internal name for this campaign',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.title),
                    ),
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: subjectController,
                    decoration: const InputDecoration(
                      labelText: 'Email Subject Line *',
                      hintText: 'What subscribers will see',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.subject),
                    ),
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: previewTextController,
                    decoration: const InputDecoration(
                      labelText: 'Preview Text',
                      hintText: 'Text shown after subject in inbox',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.preview),
                    ),
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: fromNameController,
                    decoration: const InputDecoration(
                      labelText: 'From Name *',
                      hintText: 'A-1 Chimney Specialist',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: replyToController,
                    decoration: const InputDecoration(
                      labelText: 'Reply-To Email *',
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
                          Expanded(child: Text(errorMessage!, style: const TextStyle(color: Colors.red))),
                        ],
                      ),
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
                      if (selectedAudienceId == null ||
                          titleController.text.isEmpty ||
                          subjectController.text.isEmpty ||
                          fromNameController.text.isEmpty ||
                          replyToController.text.isEmpty) {
                        setDialogState(() => errorMessage = 'Please fill in all required fields');
                        return;
                      }

                      setDialogState(() {
                        isLoading = true;
                        errorMessage = null;
                      });

                      try {
                        final response = await http.post(
                          Uri.parse('$_baseUrl?action=create_campaign'),
                          headers: {'Content-Type': 'application/json'},
                          body: json.encode({
                            'list_id': selectedAudienceId,
                            'title': titleController.text,
                            'subject_line': subjectController.text,
                            'preview_text': previewTextController.text,
                            'from_name': fromNameController.text,
                            'reply_to': replyToController.text,
                          }),
                        );

                        final data = json.decode(response.body);
                        if (data['success'] == true) {
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          _loadCampaigns();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Campaign created! Now add content to it.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          // Open content editor
                          _showContentEditorDialog(data['campaign']);
                        } else {
                          setDialogState(() {
                            isLoading = false;
                            errorMessage = data['error'] ?? 'Failed to create campaign';
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
              child: Text(isLoading ? 'Creating...' : 'Create Campaign', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showContentEditorDialog(Map<String, dynamic> campaign) async {
    final htmlController = TextEditingController();
    bool isLoading = false;
    String? errorMessage;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Edit Content: ${campaign['settings']?['title'] ?? 'Campaign'}'),
          content: SizedBox(
            width: 600,
            height: 400,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter your email HTML content:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TextField(
                    controller: htmlController,
                    maxLines: null,
                    expands: true,
                    decoration: const InputDecoration(
                      hintText: '<html><body>Your email content here...</body></html>',
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    enabled: !isLoading,
                  ),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                ],
              ],
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
                      if (htmlController.text.isEmpty) {
                        setDialogState(() => errorMessage = 'Please enter HTML content');
                        return;
                      }

                      setDialogState(() {
                        isLoading = true;
                        errorMessage = null;
                      });

                      try {
                        final response = await http.post(
                          Uri.parse('$_baseUrl?action=update_campaign_content'),
                          headers: {'Content-Type': 'application/json'},
                          body: json.encode({
                            'campaign_id': campaign['id'],
                            'html': htmlController.text,
                          }),
                        );

                        final data = json.decode(response.body);
                        if (data['success'] == true) {
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          _loadCampaigns();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Campaign content saved!'),
                              backgroundColor: Colors.green,
                            ),
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
              child: Text(isLoading ? 'Saving...' : 'Save Content', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editCampaign(Map<String, dynamic> campaign) async {
    _showContentEditorDialog(campaign);
  }

  Future<void> _sendCampaign(String campaignId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Campaign?'),
        content: const Text('Are you sure you want to send this campaign? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Send Now', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Sending campaign...'),
          ],
        ),
      ),
    );

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?action=send_campaign'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'campaign_id': campaignId}),
      );

      if (!mounted) return;
      Navigator.pop(context);

      final data = json.decode(response.body);
      if (data['success'] == true) {
        _loadCampaigns();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Campaign sent successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send: ${data['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteCampaign(String campaignId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Campaign?'),
        content: const Text('Are you sure you want to delete this campaign?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
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
      final response = await http.delete(
        Uri.parse('$_baseUrl?action=delete_campaign&id=$campaignId'),
      );

      final data = json.decode(response.body);
      if (data['success'] == true) {
        _loadCampaigns();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Campaign deleted'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _viewReport(String campaignId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Loading report...'),
          ],
        ),
      ),
    );

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl?action=get_campaign_report&id=$campaignId'),
      );

      if (!mounted) return;
      Navigator.pop(context);

      final data = json.decode(response.body);
      if (data['success'] == true) {
        final report = data['report'];
        showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(report['campaign_title'] ?? 'Campaign Report'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildReportRow('Emails Sent', '${report['emails_sent'] ?? 0}'),
                    _buildReportRow('Opens', '${report['opens']?['opens_total'] ?? 0} (${((report['opens']?['open_rate'] ?? 0) * 100).toStringAsFixed(1)}%)'),
                    _buildReportRow('Unique Opens', '${report['opens']?['unique_opens'] ?? 0}'),
                    _buildReportRow('Clicks', '${report['clicks']?['clicks_total'] ?? 0} (${((report['clicks']?['click_rate'] ?? 0) * 100).toStringAsFixed(1)}%)'),
                    _buildReportRow('Unique Clicks', '${report['clicks']?['unique_clicks'] ?? 0}'),
                    _buildReportRow('Bounces', '${(report['bounces']?['hard_bounces'] ?? 0) + (report['bounces']?['soft_bounces'] ?? 0)}'),
                    _buildReportRow('Unsubscribes', '${report['unsubscribed'] ?? 0}'),
                    _buildReportRow('Abuse Reports', '${report['abuse_reports'] ?? 0}'),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Failed to load report'), backgroundColor: Colors.red),
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

  Widget _buildReportRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _viewMembers(Map<String, dynamic> audience) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Loading members...'),
          ],
        ),
      ),
    );

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl?action=get_members&audience_id=${audience['id']}&count=50'),
      );

      if (!mounted) return;
      Navigator.pop(context);

      final data = json.decode(response.body);
      if (data['success'] == true) {
        final members = List<Map<String, dynamic>>.from(data['members'] ?? []);
        showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('${audience['name']} Members'),
              content: SizedBox(
                width: 500,
                height: 400,
                child: members.isEmpty
                    ? const Center(child: Text('No members found'))
                    : ListView.builder(
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final member = members[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _accent.withValues(alpha: 0.1),
                              child: Text(
                                (member['email'] as String?)?.substring(0, 1).toUpperCase() ?? '?',
                                style: const TextStyle(color: _accent),
                              ),
                            ),
                            title: Text(member['email'] ?? ''),
                            subtitle: Text(
                              '${member['merge_fields']?['FNAME'] ?? ''} ${member['merge_fields']?['LNAME'] ?? ''}'.trim(),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: member['status'] == 'subscribed' ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                member['status'] ?? '',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: member['status'] == 'subscribed' ? Colors.green : Colors.grey,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ],
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

  Future<void> _showAddMemberDialog(Map<String, dynamic> audience) async {
    final emailController = TextEditingController();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    bool isLoading = false;
    String? errorMessage;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Add Member to ${audience['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                enabled: !isLoading,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                enabled: !isLoading,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                enabled: !isLoading,
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(errorMessage!, style: const TextStyle(color: Colors.red)),
              ],
            ],
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
                      if (emailController.text.isEmpty) {
                        setDialogState(() => errorMessage = 'Email is required');
                        return;
                      }

                      setDialogState(() {
                        isLoading = true;
                        errorMessage = null;
                      });

                      try {
                        final response = await http.post(
                          Uri.parse('$_baseUrl?action=add_member'),
                          headers: {'Content-Type': 'application/json'},
                          body: json.encode({
                            'audience_id': audience['id'],
                            'email': emailController.text,
                            'status': 'subscribed',
                            'merge_fields': {
                              'FNAME': firstNameController.text,
                              'LNAME': lastNameController.text,
                            },
                          }),
                        );

                        final data = json.decode(response.body);
                        if (data['success'] == true) {
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          _loadAudiences();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Member added successfully!'),
                              backgroundColor: Colors.green,
                            ),
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
              child: Text(isLoading ? 'Adding...' : 'Add Member', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
