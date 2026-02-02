import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../app_theme.dart';
import '../../config/api_config.dart';

/// Running Programs Dashboard Screen
/// Shows all running programs across all monitored computers
/// Allows admins to see what programs are open on employee machines
class RunningProgramsScreen extends StatefulWidget {
  final String currentUsername;
  final String currentRole;

  const RunningProgramsScreen({
    super.key,
    required this.currentUsername,
    required this.currentRole,
  });

  @override
  State<RunningProgramsScreen> createState() => _RunningProgramsScreenState();
}

class _RunningProgramsScreenState extends State<RunningProgramsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Programs to exclude from display (privacy - personal browser)
  static const List<String> _excludedPrograms = ['brave'];

  /// Check if a program name should be excluded from display
  bool _isExcludedProgram(String programName) {
    final lowerName = programName.toLowerCase();
    return _excludedPrograms.any((excluded) => lowerName.contains(excluded));
  }

  List<Map<String, dynamic>> _allMetrics = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();

    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.systemMetrics}?action=list_all'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              _allMetrics = List<Map<String, dynamic>>.from(data['metrics'] ?? []);
              _loading = false;
              _error = null;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _error = data['error'] ?? 'Failed to load data';
              _loading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Server error: ${response.statusCode}';
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Connection error: $e';
          _loading = false;
        });
      }
    }
  }

  /// Get aggregated list of all running apps across all computers
  List<Map<String, dynamic>> _getAggregatedPrograms() {
    final Map<String, List<Map<String, dynamic>>> programMap = {};

    for (final metric in _allMetrics) {
      final username = metric['username'] ?? '';
      final computerName = metric['computer_name'] ?? '';
      final runningApps = metric['running_apps'] as List? ?? [];

      for (final app in runningApps) {
        final name = (app['name'] ?? '').toString();
        if (name.isEmpty) continue;

        // Filter out excluded programs (privacy)
        if (_isExcludedProgram(name)) continue;

        // Apply search filter
        if (_searchQuery.isNotEmpty &&
            !name.toLowerCase().contains(_searchQuery.toLowerCase())) {
          continue;
        }

        if (!programMap.containsKey(name)) {
          programMap[name] = [];
        }
        programMap[name]!.add({
          'username': username,
          'computer_name': computerName,
          'title': app['title'] ?? '',
          'memory_bytes': app['memory_bytes'] ?? 0,
        });
      }
    }

    // Convert to sorted list
    final result = programMap.entries.map((e) {
      return {
        'name': e.key,
        'instances': e.value,
        'count': e.value.length,
      };
    }).toList();

    // Sort by instance count (most common first)
    result.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    return result;
  }

  /// Get programs grouped by computer
  List<Map<String, dynamic>> _getByComputer() {
    final List<Map<String, dynamic>> result = [];

    for (final metric in _allMetrics) {
      final username = metric['username'] ?? '';
      final computerName = metric['computer_name'] ?? '';
      final runningApps = (metric['running_apps'] as List? ?? []).where((app) {
        final name = (app['name'] ?? '').toString();
        // Filter out excluded programs (privacy)
        if (_isExcludedProgram(name)) return false;
        if (_searchQuery.isEmpty) return true;
        return name.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();

      if (runningApps.isEmpty && _searchQuery.isNotEmpty) continue;

      result.add({
        'username': username,
        'computer_name': computerName,
        'last_seen': metric['last_seen'] ?? '',
        'running_apps': runningApps,
        'app_count': runningApps.length,
      });
    }

    // Sort by app count (most apps first)
    result.sort((a, b) => (b['app_count'] as int).compareTo(a['app_count'] as int));

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Running Programs'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'By Program', icon: Icon(Icons.apps, size: 18)),
            Tab(text: 'By Computer', icon: Icon(Icons.computer, size: 18)),
            Tab(text: 'Search', icon: Icon(Icons.search, size: 18)),
          ],
        ),
      ),
      backgroundColor: bgColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildByProgramTab(),
                    _buildByComputerTab(),
                    _buildSearchTab(),
                  ],
                ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: Colors.red.shade400)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildByProgramTab() {
    final programs = _getAggregatedPrograms();

    if (programs.isEmpty) {
      return _buildEmptyState('No running programs found');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: programs.length,
      itemBuilder: (context, index) {
        final program = programs[index];
        return _buildProgramCard(program);
      },
    );
  }

  Widget _buildProgramCard(Map<String, dynamic> program) {
    final name = program['name'] as String;
    final instances = program['instances'] as List<Map<String, dynamic>>;
    final count = program['count'] as int;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.apps, color: AppColors.accent, size: 22),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '$count instance${count != 1 ? 's' : ''} running',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.accent,
            ),
          ),
        ),
        children: instances.map((instance) {
          return ListTile(
            dense: true,
            leading: Icon(Icons.person_outline, color: Colors.grey.shade500, size: 20),
            title: Text(instance['username'] ?? ''),
            subtitle: Text(
              instance['computer_name'] ?? '',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
            trailing: _formatMemory(instance['memory_bytes'] as int? ?? 0),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildByComputerTab() {
    final computers = _getByComputer();

    if (computers.isEmpty) {
      return _buildEmptyState('No computers found');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: computers.length,
      itemBuilder: (context, index) {
        final computer = computers[index];
        return _buildComputerCard(computer);
      },
    );
  }

  Widget _buildComputerCard(Map<String, dynamic> computer) {
    final username = computer['username'] as String;
    final computerName = computer['computer_name'] as String;
    final apps = computer['running_apps'] as List;
    final appCount = computer['app_count'] as int;
    final lastSeen = computer['last_seen'] as String;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.accent.withValues(alpha: 0.2),
          child: Text(
            username.isNotEmpty ? username[0].toUpperCase() : '?',
            style: const TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          username,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              computerName,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            if (lastSeen.isNotEmpty)
              Text(
                'Last seen: ${_formatLastSeen(lastSeen)}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$appCount apps',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.blue,
              fontSize: 12,
            ),
          ),
        ),
        children: apps.map((app) {
          return ListTile(
            dense: true,
            leading: Icon(Icons.circle, color: Colors.green.shade400, size: 8),
            title: Text(app['name'] ?? ''),
            subtitle: app['title'] != null && (app['title'] as String).isNotEmpty
                ? Text(
                    app['title'],
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            trailing: _formatMemory(app['memory_bytes'] as int? ?? 0),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search for a program...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
          ),
        ),
        Expanded(
          child: _searchQuery.isEmpty
              ? _buildEmptyState('Enter a program name to search')
              : _buildSearchResults(),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    final programs = _getAggregatedPrograms();

    if (programs.isEmpty) {
      return _buildEmptyState('No programs matching "$_searchQuery"');
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: programs.length,
      itemBuilder: (context, index) {
        final program = programs[index];
        return _buildProgramCard(program);
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _formatMemory(int bytes) {
    if (bytes <= 0) return const SizedBox.shrink();

    final mb = bytes / (1024 * 1024);
    return Text(
      '${mb.toStringAsFixed(1)} MB',
      style: TextStyle(
        fontSize: 11,
        color: Colors.grey.shade500,
        fontFamily: 'monospace',
      ),
    );
  }

  String _formatLastSeen(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return dateStr;
    }
  }
}
